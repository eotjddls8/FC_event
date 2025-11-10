// lib/services/auth_service.dart - admins 컬렉션 확인 + Google 로그인 + Firestore upsert 완성본

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../services/device_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  //final GoogleSignIn _google = GoogleSignIn.standard();
  final GoogleSignIn _google = GoogleSignIn();
  final DeviceService _deviceService = DeviceService();

  // 현재 사용자
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==============================
  // 내부 유틸
  // ==============================

  // 안전한 디바이스 정보 수집
  Future<Map<String, dynamic>> _getSafeDeviceInfo() async {
    try {
      final deviceFingerprint = await _deviceService.getDeviceFingerprint();
      final deviceInfo = await _deviceService.getDeviceInfo();
      return {
        'fingerprint': deviceFingerprint,
        'info': deviceInfo, // Map<String, String>
      };
    } catch (e) {
      print('디바이스 정보 수집 실패 (기본값 사용): $e');
      return {
        'fingerprint': 'error_${DateTime.now().millisecondsSinceEpoch}',
        'info': <String, String>{
          'platform': 'Unknown',
          'error': 'Device info collection failed'
        },
      };
    }
  }

  // 🔐 이메일이 관리자 목록에 있는지 확인 (admins 컬렉션의 문서ID = 이메일, 필드 isAdmin=true)
  Future<bool> _isAdminEmail(String email) async {
    try {
      print('관리자 확인 중: $email');
      final adminDoc =
      await _firestore.collection('admins').doc(email.trim()).get();
      final isAdmin = adminDoc.exists && adminDoc.data()?['isAdmin'] == true;
      print('관리자 여부: $isAdmin');
      return isAdmin;
    } catch (e) {
      print('관리자 확인 실패: $e');
      return false; // 에러 시 일반 사용자 처리
    }
  }

  // Firestore에 users/{uid} upsert (기본 구조 반영)
  Future<void> _upsertUserDoc({
    required String uid,
    required UserModel model,
    bool merge = true,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(model.toFirestore(), SetOptions(merge: merge));
  }

  // 로그인 정보 업데이트 (마지막 로그인 시간, 이력, 디바이스 정보)
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

        // 🔐 role은 업데이트하지 않음 (보안규칙으로 차단/보호)
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

  // ==============================
  // 회원가입 / 이메일 로그인
  // ==============================

  // 🔐 회원가입 (admins 컬렉션 확인)
  Future<Map<String, dynamic>> signUp(
      String email, String password, String name) async {
    try {
      print('회원가입 시도: $email');

      // 1) 관리자 여부 확인
      final isAdmin = await _isAdminEmail(email);
      final userRole = isAdmin ? 'admin' : 'user';
      print('할당된 역할: $userRole');

      // 2) Firebase 계정 생성
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user;
      if (user != null) {
        print('Firebase 회원가입 성공: ${user.uid}');

        // 3) 사용자 이름 설정
        await user.updateDisplayName(name.trim());

        // 4) 디바이스 정보 수집
        final deviceData = await _getSafeDeviceInfo();

        // 5) Firestore에 사용자 정보 저장
        final userData = {
          'email': email.trim(),
          'name': name.trim(),
          'role': userRole, // admins 컬렉션 확인 결과
          'emailVerified': true,
          'deviceFingerprint': deviceData['fingerprint'],
          'deviceInfo': deviceData['info'],
          'lastLoginAt': Timestamp.now(),
          'loginHistory': [DateTime.now().toIso8601String()],
          // 코인 시스템 기본값
          'coins': 0,
          'dailyAdCount': 0,
          'lastAdDate': '',
          'createdAt': Timestamp.now(),
        };

        await _firestore.collection('users').doc(user.uid).set(userData);
        print('Firestore 저장 완료 - role: $userRole');

        // 6) 사용자 데이터 가져오기
        final userModel = await getUserData(user.uid);

        return {
          'success': true,
          'message':
          isAdmin ? '관리자로 회원가입이 완료되었습니다! 🎉' : '회원가입이 완료되었습니다!',
          'user': userModel,
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
          errorMessage = '비밀번호가 너무 약합니다. (최소 6자 이상)';
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

  // 🔐 이메일 로그인
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      print('로그인 시도: $email');

      // 1) 로그인 시도
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = result.user;

      if (user != null) {
        print('Firebase 로그인 성공: ${user.uid}');

        // 2) 로그인 정보 업데이트
        await _updateLoginInfo(user.uid);

        // 3) Firestore에서 사용자 데이터 가져오기
        final userData = await getUserData(user.uid);

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

  // ==============================
  // Google 로그인 (UI에서 UserModel로 바로 사용)
  // ==============================

  /// Google 계정으로 로그인 → admins 컬렉션 확인 → Firestore upsert → UserModel 반환
  Future<UserModel> signInWithGoogle() async {
    // 1) ~ 3) Firebase 인증까지 기존과 동일
    final GoogleSignInAccount? googleUser = await _google.signIn();
    if (googleUser == null) {
      throw Exception('사용자가 구글 로그인을 취소했습니다.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user;
    if (user == null) {
      throw Exception('로그인에 실패했습니다. 다시 시도해주세요.');
    }

    // 4) 기존 사용자 문서 로드 시도
    UserModel? existingModel = await getUserData(user.uid);

    // 5) admins 컬렉션으로 role 판단 (최초 생성 시 또는 문서 없을 때 사용)
    final email = user.email ?? '';
    final isAdminFromAdmins = await _isAdminEmail(email);

    // 6) 디바이스 정보 수집
    final deviceData = await _getSafeDeviceInfo();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // 7) 최종 Firestore에 저장할 데이터 Map 생성
    Map<String, dynamic> updateData = {};

    if (existingModel == null) {
      // 7-A) 💡 최초 로그인: 문서가 없으므로 모든 필드를 'set' (role/isAdmin 기본값은 여기서 결정)
      print('Google 로그인: Firestore에 새 사용자 문서 생성');

      // (getUserData 내부에서 생성된 defaultUser와 동일한 로직)
      final role = isAdminFromAdmins ? 'admin' : 'user';

      updateData = UserModel(
        email: email,
        name: user.displayName ?? email.split('@').first,
        role: role,
        isEmailVerified: true,
        deviceFingerprint: deviceData['fingerprint'] as String,
        deviceInfo: deviceData['info'] as Map<String, String>,
        lastLoginAt: now,
        loginHistory: [nowIso],
        coins: 0,
        dailyAdCount: 0,
        lastAdDate: '',
        createdAt: now,
      ).toFirestore();

      // 'set' 명령을 사용하여 새로운 문서를 생성
      await _firestore.collection('users').doc(user.uid).set(updateData);

      // 생성된 모델을 반환
      return UserModel.fromMap(updateData);

    } else {
      // 7-B) 💡 재로그인: 기존 사용자 문서 업데이트
      print('Google 로그인: 기존 사용자 문서 업데이트');

      // _updateLoginInfo와 동일한 로직을 사용하여 history 업데이트
      // 🚨 [수정됨] existingModel.loginHistory가 null일 경우 빈 리스트를 사용하도록 처리
      final existingHistory = List<String>.from(existingModel!.loginHistory ?? []);
      existingHistory.add(nowIso);
      if (existingHistory.length > 5) {
        existingHistory.removeAt(0);
      }

      updateData = {
        'deviceFingerprint': deviceData['fingerprint'] as String,
        'deviceInfo': deviceData['info'] as Map<String, String>,
        'lastLoginAt': Timestamp.fromDate(now),
        'loginHistory': existingHistory,
        'emailVerified': true,
        // 🚨 role, isAdmin, name, coins 등은 절대로 여기에 포함하지 않습니다.
      };

      await _firestore.collection('users').doc(user.uid).update(updateData);

      // 업데이트된 정보를 기존 모델에 반영
      // (role/isAdmin은 유지되고, 나머지 필드가 업데이트됩니다.)
      existingModel = existingModel.copyWith(
        deviceFingerprint: deviceData['fingerprint'] as String,
        deviceInfo: deviceData['info'] as Map<String, String>,
        lastLoginAt: now,
        loginHistory: existingHistory,
        isEmailVerified: true,
      );

      return existingModel;
    }
  }

  // ==============================
  // 공용: 로그아웃 / 유저 로드
  // ==============================

  // 로그아웃 (구글/파이어베이스 모두 정리)
  Future<void> signOut() async {
    try {
      // 구글 세션 정리 (구글로 로그인하지 않았더라도 안전)
      await _google.signOut();
    } catch (_) {
      // ignore
    }
    try {
      await _auth.signOut();
      print('로그아웃 성공');
    } catch (e) {
      print('로그아웃 에러: $e');
    }
  }

  // 사용자 데이터 가져오기 (users/{uid})
  Future<UserModel?> getUserData(String uid) async {
    try {
      print('사용자 데이터 가져오기: $uid');

      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        print('Firestore 데이터 로드 성공');
        return UserModel.fromFirestore(doc);
      } else {
        print('Firestore에 사용자 데이터 없음, 기본값 생성 시도');
        final current = _auth.currentUser;
        if (current != null) {
          // admins 확인
          final isAdmin = await _isAdminEmail(current.email ?? '');
          final role = isAdmin ? 'admin' : 'user';

          final deviceData = await _getSafeDeviceInfo();

          final defaultUser = UserModel(
            email: current.email ?? '',
            name: current.displayName ??
                current.email?.split('@').first ??
                '사용자',
            role: role,
            deviceFingerprint: deviceData['fingerprint'] as String,
            deviceInfo: deviceData['info'] as Map<String, String>,
            lastLoginAt: DateTime.now(),
            loginHistory: [DateTime.now().toIso8601String()],
            isEmailVerified: true,
            // 코인 시스템 기본값 유지
            coins: 0,
            dailyAdCount: 0,
            lastAdDate: '',
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
