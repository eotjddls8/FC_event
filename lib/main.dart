import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'theme/fifa_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIFA Event App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      // 항상 MainNavigationScreen부터 시작 (비회원도 접근 가능)
      home: MainNavigationScreen(currentUser: null), // null = 비회원
      debugShowCheckedModeBanner: false,
    );
  }
}