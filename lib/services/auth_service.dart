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

  // 회원가입 (새로 추가)
  Future<UserModel?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // 새 사용자 데이터를 Firestore에 저장
        final userData = UserModel(
          email: email,
          name: name,
          role: 'user', // 일반 사용자로 가입
        );

        await _firestore
            .collection('users')
            .doc(email)
            .set(userData.toFirestore());

        return userData;
      }
      return null;
    } catch (e) {
      throw e;
    }
  }

  // 로그인
  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        return await getUserData(email);
      }
      return null;
    } catch (e) {
      throw e;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 사용자 데이터 가져오기
  Future<UserModel?> getUserData(String email) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(email)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('사용자 데이터 가져오기 실패: $e');
      return null;
    }
  }
}