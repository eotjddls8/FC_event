import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth_wrapper.dart'; // 🎯 간소화된 AuthWrapper 사용
import 'theme/fifa_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '피온 이벤트 알림',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Color(0xFFF5F7FA), // 🎯 기본 배경색 설정
      ),
      // 한국어 지원
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      locale: Locale('ko', 'KR'),
      // 🎯 간소화된 AuthWrapper 사용 (로그인 없이 바로 시작)
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}