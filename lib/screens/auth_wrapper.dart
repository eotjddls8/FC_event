import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 🔧 실제 로그인 상태 확인
        if (snapshot.hasData && snapshot.data != null) {
          User user = snapshot.data!;

          // 로그인한 사용자의 데이터 로드
          return FutureBuilder<UserModel?>(
            future: _authService.getUserData(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('사용자 정보를 불러오는 중...'),
                      ],
                    ),
                  ),
                );
              }

              UserModel? currentUser = userSnapshot.data;

              // 🔧 사용자 데이터가 있으면 메인 화면으로
              if (currentUser != null) {
                return MainNavigationScreen(currentUser: currentUser);
              }

              // 🔧 사용자 데이터가 없으면 로그아웃 후 로그인 화면으로
              _authService.signOut();
              return LoginScreen();
            },
          );
        } else {
          // 🔧 로그인 안됨 - 로그인 화면 표시
          return MainNavigationScreen();
        }
      },
    );
  }
}