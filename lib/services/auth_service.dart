// lib/services/auth_service.dart - 이메일 인증 추가 버전

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

  // 안전한 디바이스 정보 수집 (기존 코드 유지)
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

  // 🔥 회원가입 (이메일 인증 추가)
  Future<Map<String, dynamic>> signUp(String email, String password, String name) async {
    try {
      print('회원가입 시도: $email');

      // 1. Firebase 계정 생성
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        print('Firebase 회원가입 성공: ${result.user!.uid}');

        // 2. 사용자 이름 설정
        await result.user!.updateDisplayName(name.trim());

        // 3. 🔥 이메일 인증 메일 발송
        await result.user!.sendEmailVerification();
        print('인증 이메일 발송 완료');

        // 4. 디바이스 정보 수집
        final deviceData = await _getSafeDeviceInfo();

        // 5. Firestore에 사용자 정보 저장
        final userData = {
          'email': email.trim(),
          'name': name.trim(),
          'role': email.trim() == 'admin@test.com' ? 'admin' : 'user',
          'emailVerified': false,  // 🔥 이메일 미인증 상태
          'deviceFingerprint': deviceData['fingerprint'],
          'deviceInfo': deviceData['info'],
          'lastLoginAt': Timestamp.now(),
          'loginHistory': [DateTime.now().toIso8601String()],
          'coins': 0,
          'dailyAdCount': 0,
          'lastAdDate': '',
          'createdAt': Timestamp.now(),
        };

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userData);

        // 6. 🔥 로그아웃 (인증 완료 후 로그인하도록)
        await _auth.signOut();

        return {
          'success': true,
          'message': '인증 이메일을 발송했습니다. 메일함을 확인해주세요!',
          'needsVerification': true,
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

  // 🔥 로그인 (이메일 인증 확인 추가)
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

        // 2. 🔥 이메일 인증 상태 새로고침
        await result.user!.reload();
        User? refreshedUser = _auth.currentUser;

        // 3. 🔥 이메일 인증 확인
        if (refreshedUser != null && refreshedUser.emailVerified) {
          // 인증 완료된 사용자

          // 로그인 정보 업데이트
          await _updateLoginInfo(refreshedUser.uid);

          // Firestore에서 사용자 데이터 가져오기
          UserModel? userData = await getUserData(refreshedUser.uid);

          return {
            'success': true,
            'message': '로그인 성공!',
            'user': userData,
          };

        } else {
          // 🔥 이메일 미인증 사용자는 로그아웃 처리
          await _auth.signOut();

          return {
            'success': false,
            'message': '이메일 인증이 필요합니다. 메일함을 확인해주세요.',
            'needsVerification': true,
          };
        }
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

  // 🔥 인증 이메일 재발송 (새로 추가)
  Future<Map<String, dynamic>> resendVerificationEmail(String email, String password) async {
    try {
      // 임시 로그인
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();  // 다시 로그아웃

        return {
          'success': true,
          'message': '인증 이메일을 재발송했습니다. 메일함을 확인해주세요.',
        };
      }

      return {
        'success': false,
        'message': '이미 인증된 계정이거나 오류가 발생했습니다.',
      };

    } catch (e) {
      return {
        'success': false,
        'message': '재발송 실패: $e',
      };
    }
  }

  // 로그인 정보 업데이트 (기존 코드에 emailVerified 추가)
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

        await _firestore.collection('users').doc(uid).update({
          'deviceFingerprint': deviceData['fingerprint'] as String,
          'deviceInfo': deviceData['info'] as Map<String, String>,
          'lastLoginAt': Timestamp.fromDate(now),
          'loginHistory': existingHistory,
          'emailVerified': true,  // 🔥 이메일 인증 완료 표시
        });

        print('로그인 정보 업데이트 완료');
      }
    } catch (e) {
      print('로그인 정보 업데이트 실패: $e');
    }
  }

  // 로그아웃 (기존 코드 유지)
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('로그아웃 성공');
    } catch (e) {
      print('로그아웃 에러: $e');
    }
  }

  // 사용자 데이터 가져오기 (기존 코드 유지)
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
          final deviceData = await _getSafeDeviceInfo();

          final defaultUser = UserModel(
            email: currentUser.email ?? '',
            name: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '사용자',
            role: currentUser.email == 'admin@test.com' ? 'admin' : 'user',
            deviceFingerprint: deviceData['fingerprint'] as String,
            deviceInfo: deviceData['info'] as Map<String, String>,
            lastLoginAt: DateTime.now(),
            loginHistory: [DateTime.now().toIso8601String()],
            isEmailVerified: currentUser.emailVerified,  // 🔥 이메일 인증 상태 추가
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