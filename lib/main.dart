import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth_wrapper.dart'; // 🎯 AuthWrapper로 변경 (Native Splash 사용하므로)
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
      title: '피온 이벤트 알림', // 🎯 앱 이름 변경
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ), // 🎯 기본 테마 사용
      // 🎯 한국어 지원 추가
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      locale: Locale('ko', 'KR'), // 기본 언어를 한국어로 설정
      // 🎯 AuthWrapper로 시작 (Native Splash 이후)
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}