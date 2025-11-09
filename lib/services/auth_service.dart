// lib/services/auth_service.dart - admins 컬렉션 확인 버전

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/device_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceService _deviceService = DeviceService();

  // 현재 사용자
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 안전한 디바이스 정보 수집
  Future<Map<String, dynamic>> _getSafeDeviceInfo() async {
    try {
      final deviceFingerprint = await _deviceService.getDeviceFingerprint();
      final deviceInfo = await _deviceService.getDeviceInfo();

      return {
        'fingerprint': deviceFingerprint,
        'info': deviceInfo,
      };
    } catch (e) {
      print('디바이스 정보 수집 실패 (기본값 사용): $e');
      return {
        'fingerprint': 'error_${DateTime.now().millisecondsSinceEpoch}',
        'info': <String, String>{'platform': 'Unknown', 'error': 'Device info collection failed'},
      };
    }
  }

  // 🔐 이메일이 관리자 목록에 있는지 확인
  Future<bool> _isAdminEmail(String email) async {
    try {
      print('관리자 확인 중: $email');

      final adminDoc = await _firestore
          .collection('admins')
          .doc(email.trim())
          .get();

      final isAdmin = adminDoc.exists && adminDoc.data()?['isAdmin'] == true;
      print('관리자 여부: $isAdmin');

      return isAdmin;
    } catch (e) {
      print('관리자 확인 실패: $e');
      return false; // 에러 시 기본값은 일반 사용자
    }
  }

  // 🔐 회원가입 (admins 컬렉션 확인)
  Future<Map<String, dynamic>> signUp(String email, String password, String name) async {
    try {
      print('회원가입 시도: $email');

      // 1. 관리자 여부 먼저 확인
      final isAdmin = await _isAdminEmail(email);
      final userRole = isAdmin ? 'admin' : 'user';
      print('할당된 역할: $userRole');

      // 2. Firebase 계정 생성
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        print('Firebase 회원가입 성공: ${result.user!.uid}');

        // 3. 사용자 이름 설정
        await result.user!.updateDisplayName(name.trim());

        // 4. 디바이스 정보 수집
        final deviceData = await _getSafeDeviceInfo();

        // 5. Firestore에 사용자 정보 저장
        final userData = {
          'email': email.trim(),
          'name': name.trim(),
          'role': userRole, // 🔐 admins 컬렉션 확인 결과로 설정
          'emailVerified': true,
          'deviceFingerprint': deviceData['fingerprint'],
          'deviceInfo': deviceData['info'],
          'lastLoginAt': Timestamp.now(),
          'loginHistory': [DateTime.now().toIso8601String()],
          'coins': 0,
          'dailyAdCount': 0,
          'lastAdDate': '',
          'createdAt': Timestamp.now(),
        };

        // 🔐 Security Rules가 role을 검증함
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userData);

        print('Firestore 저장 완료 - role: $userRole');

        // 6. 사용자 데이터 가져오기
        UserModel? user = await getUserData(result.user!.uid);

        return {
          'success': true,
          'message': isAdmin
              ? '관리자로 회원가입이 완료되었습니다! 🎉'
              : '회원가입이 완료되었습니다!',
          'user': user,
        };
      }

      return {
        'success': false,
        'message': '회원가입 실패',
      };

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth 에러: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약습니다. (최소 6자 이상)';
          break;
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          errorMessage = '올바르지 않은 이메일 형식입니다.';
          break;
        default:
          errorMessage = '회원가입 중 오류가 발생했습니다: ${e.message}';
      }

      return {
        'success': false,
        'message': errorMessage,
      };

    } catch (e) {
      print('일반 에러: $e');
      return {
        'success': false,
        'message': '회원가입 중 예상치 못한 오류가 발생했습니다.',
      };
    }
  }

  // 🔐 로그인
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      print('로그인 시도: $email');

      // 1. 로그인 시도
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        print('Firebase 로그인 성공: ${result.user!.uid}');

        // 2. 로그인 정보 업데이트
        await _updateLoginInfo(result.user!.uid);

        // 3. Firestore에서 사용자 데이터 가져오기
        UserModel? userData = await getUserData(result.user!.uid);

        if (userData != null) {
          print('로그인 완료 - role: ${userData.role}');
        }

        return {
          'success': true,
          'message': '로그인 성공!',
          'user': userData,
        };
      }

      return {
        'success': false,
        'message': '로그인 실패',
      };

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth 에러: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '등록되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          errorMessage = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          errorMessage = '올바르지 않은 이메일 형식입니다.';
          break;
        case 'user-disabled':
          errorMessage = '비활성화된 계정입니다.';
          break;
        default:
          errorMessage = '로그인 중 오류가 발생했습니다: ${e.message}';
      }

      return {
        'success': false,
        'message': errorMessage,
      };

    } catch (e) {
      print('일반 에러: $e');
      return {
        'success': false,
        'message': '로그인 중 예상치 못한 오류가 발생했습니다.',
      };
    }
  }

  // 로그인 정보 업데이트
  Future<void> _updateLoginInfo(String uid) async {
    try {
      final deviceData = await _getSafeDeviceInfo();
      final now = DateTime.now();

      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final existingHistory = List<String>.from(userData['loginHistory'] ?? []);

        existingHistory.add(now.toIso8601String());
        if (existingHistory.length > 5) {
          existingHistory.removeAt(0);
        }

        // 🔐 role은 업데이트하지 않음 (Security Rules로 차단됨)
        await _firestore.collection('users').doc(uid).update({
          'deviceFingerprint': deviceData['fingerprint'] as String,
          'deviceInfo': deviceData['info'] as Map<String, String>,
          'lastLoginAt': Timestamp.fromDate(now),
          'loginHistory': existingHistory,
          'emailVerified': true,
        });

        print('로그인 정보 업데이트 완료');
      }
    } catch (e) {
      print('로그인 정보 업데이트 실패: $e');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('로그아웃 성공');
    } catch (e) {
      print('로그아웃 에러: $e');
    }
  }

  // 사용자 데이터 가져오기
  Future<UserModel?> getUserData(String uid) async {
    try {
      print('사용자 데이터 가져오기: $uid');

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        print('Firestore 데이터 로드 성공');
        return UserModel.fromFirestore(doc);
      } else {
        print('Firestore에 사용자 데이터 없음, 기본값 생성');
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // 🔐 기본값 생성 시에도 admins 컬렉션 확인
          final isAdmin = await _isAdminEmail(currentUser.email ?? '');
          final userRole = isAdmin ? 'admin' : 'user';

          final deviceData = await _getSafeDeviceInfo();

          final defaultUser = UserModel(
            email: currentUser.email ?? '',
            name: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '사용자',
            role: userRole, // 🔐 admins 컬렉션 확인 결과로 설정
            deviceFingerprint: deviceData['fingerprint'] as String,
            deviceInfo: deviceData['info'] as Map<String, String>,
            lastLoginAt: DateTime.now(),
            loginHistory: [DateTime.now().toIso8601String()],
            isEmailVerified: true,
          );

          try {
            await _firestore
                .collection('users')
                .doc(uid)
                .set(defaultUser.toFirestore());
          } catch (saveError) {
            print('기본 사용자 데이터 저장 실패: $saveError');
          }

          return defaultUser;
        }
      }
      return null;
    } catch (e) {
      print('사용자 데이터 가져오기 실패: $e');
      return null;
    }
  }
}