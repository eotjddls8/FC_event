import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 회원가입 (UserModel 구조에 맞게 수정)
  Future<UserModel?> signUp(String email, String password, String name) async {
    try {
      print('회원가입 시도: $email'); // 디버그

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (result.user != null) {
        print('Firebase 회원가입 성공: ${result.user!.uid}'); // 디버그

        // UserModel 구조에 맞게 데이터 생성
        final userData = UserModel(
          email: email.trim(),
          name: name.trim(),
          role: email.trim() == 'admin@test.com' ? 'admin' : 'user',
        );

        // Firestore에 저장 (toFirestore 메서드 사용)
        await _firestore
            .collection('users')
            .doc(result.user!.uid)  // uid를 문서 ID로 사용
            .set(userData.toFirestore());

        print('Firestore 저장 성공'); // 디버그
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

  // 로그인 (타입 에러 회피를 위한 수정)
  Future<UserModel?> signIn(String email, String password) async {
    try {
      print('로그인 시도: $email'); // 디버그

      // 타입 에러 회피를 위해 다른 방식으로 접근
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 로그인 성공 후 현재 사용자로 데이터 가져오기
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Firebase 로그인 성공: ${currentUser.uid}'); // 디버그
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
      // 타입 에러인 경우 로그인은 성공했을 가능성이 높음
      if (e.toString().contains('PigeonUserDetails')) {
        print('타입 에러 감지 - 현재 사용자로 재시도');
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          print('현재 사용자 발견: ${currentUser.uid}');
          return await getUserData(currentUser.uid);
        }
      }
      throw Exception('로그인 중 예상치 못한 오류가 발생했습니다.');
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

  // 사용자 데이터 가져오기 (UserModel 구조에 맞게 수정)
  Future<UserModel?> getUserData(String uid) async {
    try {
      print('사용자 데이터 가져오기: $uid'); // 디버그

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        print('Firestore 데이터 로드 성공'); // 디버그

        // fromFirestore 메서드 사용
        return UserModel.fromFirestore(doc);
      } else {
        print('Firestore에 사용자 데이터 없음, 기본값 생성');
        // 기본값 생성 후 Firestore에 저장
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final defaultUser = UserModel(
            email: currentUser.email ?? '',
            name: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '사용자',
            role: currentUser.email == 'admin@test.com' ? 'admin' : 'user',
          );

          // 기본값을 Firestore에 저장
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