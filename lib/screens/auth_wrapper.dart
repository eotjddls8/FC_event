import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'main_navigation_screen.dart';

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
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'FIFA 이벤트 앱',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  SizedBox(height: 32),
                  CircularProgressIndicator(
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '로그인 상태를 확인하는 중...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Firebase 사용자 정보가 있는 경우 (자동 로그인)
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<UserModel?>(
            future: _authService.getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF1976D2)),
                        SizedBox(height: 16),
                        Text(
                          '사용자 정보를 불러오는 중...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                // 자동 로그인 성공
                print('자동 로그인 성공: ${userSnapshot.data!.name}');
                return MainNavigationScreen(currentUser: userSnapshot.data);
              } else {
                // Firestore에 사용자 데이터가 없음
                print('Firestore에 사용자 데이터 없음');
                return MainNavigationScreen(currentUser: null);
              }
            },
          );
        }

        // Firebase 사용자 정보가 없는 경우 (비회원)
        print('Firebase 사용자 없음 - 비회원으로 시작');
        return MainNavigationScreen(currentUser: null);
      },
    );
  }
}