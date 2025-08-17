import 'package:flutter/material.dart';

class FifaColors {
  // FIFA 메인 컬러
  static const Color primary = Color(0xFF326295); // FIFA 블루
  static const Color secondary = Color(0xFF009639); // FIFA 그린
  static const Color accent = Color(0xFFFFD700); // 골드

  // 이벤트 상태별 컬러
  static const Color eventSafe = Color(0xFF4CAF50); // 파랑 (여유)
  static const Color eventWarning = Color(0xFFFF9800); // 노랑 (주의)
  static const Color eventDanger = Color(0xFFF44336); // 빨강 (위험)

  // 기본 컬러
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

class FifaTheme {
  static ThemeData get theme {
    return ThemeData(
      primarySwatch: MaterialColor(0xFF326295, {
        50: Color(0xFFE6EDF5),
        100: Color(0xFFC1D2E6),
        200: Color(0xFF98B5D5),
        300: Color(0xFF6F97C4),
        400: Color(0xFF5081B7),
        500: Color(0xFF326295),
        600: Color(0xFF2D5A8D),
        700: Color(0xFF264F82),
        800: Color(0xFF1F4578),
        900: Color(0xFF133467),
      }),
      primaryColor: FifaColors.primary,
      scaffoldBackgroundColor: FifaColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: FifaColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: FifaColors.surface,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FifaColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FifaColors.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }
}