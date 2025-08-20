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

  // 회원가입 (디바이스 정보 추가)
  Future<UserModel?> signUp(String email, String password, String name) async {
    try {
      print('회원가입 시도: $email');

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        print('Firebase 회원가입 성공: ${result.user!.uid}');

        // 디바이스 정보 수집
        final deviceFingerprint = await _deviceService.getDeviceFingerprint();
        final deviceInfo = await _deviceService.getDeviceInfo();

        // UserModel 생성
        final userData = UserModel(
          email: email.trim(),
          name: name.trim(),
          role: email.trim() == 'admin@test.com' ? 'admin' : 'user',
          deviceFingerprint: deviceFingerprint,
          deviceInfo: deviceInfo,
          lastLoginAt: DateTime.now(),
          loginHistory: [DateTime.now().toIso8601String()],
        );

        // Firestore에 저장
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userData.toFirestore());

        print('Firestore 저장 성공');
        return userData;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth 에러: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약합니다.';
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
      throw Exception(errorMessage);
    } catch (e) {
      print('일반 에러: $e');
      throw Exception('회원가입 중 예상치 못한 오류가 발생했습니다.');
    }
  }

  // 로그인
  Future<UserModel?> signIn(String email, String password) async {
    try {
      print('로그인 시도: $email');

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Firebase 로그인 성공: ${currentUser.uid}');

        // 로그인 정보 업데이트
        await _updateLoginInfo(currentUser.uid);

        return await getUserData(currentUser.uid);
      }
      return null;
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
      throw Exception(errorMessage);
    } catch (e) {
      print('일반 에러: $e');
      if (e.toString().contains('PigeonUserDetails')) {
        print('타입 에러 감지 - 현재 사용자로 재시도');
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          print('현재 사용자 발견: ${currentUser.uid}');
          await _updateLoginInfo(currentUser.uid);
          return await getUserData(currentUser.uid);
        }
      }
      throw Exception('로그인 중 예상치 못한 오류가 발생했습니다.');
    }
  }

  // 로그인 정보 업데이트
  Future<void> _updateLoginInfo(String uid) async {
    try {
      final deviceFingerprint = await _deviceService.getDeviceFingerprint();
      final deviceInfo = await _deviceService.getDeviceInfo();
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
          'deviceFingerprint': deviceFingerprint,
          'deviceInfo': deviceInfo,
          'lastLoginAt': Timestamp.fromDate(now),
          'loginHistory': existingHistory,
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
          final deviceFingerprint = await _deviceService.getDeviceFingerprint();
          final deviceInfo = await _deviceService.getDeviceInfo();

          final defaultUser = UserModel(
            email: currentUser.email ?? '',
            name: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '사용자',
            role: currentUser.email == 'admin@test.com' ? 'admin' : 'user',
            deviceFingerprint: deviceFingerprint,
            deviceInfo: deviceInfo,
            lastLoginAt: DateTime.now(),
            loginHistory: [DateTime.now().toIso8601String()],
          );

          await _firestore
              .collection('users')
              .doc(uid)
              .set(defaultUser.toFirestore());

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