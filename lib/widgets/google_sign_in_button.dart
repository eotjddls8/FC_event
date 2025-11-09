// lib/widgets/google_sign_in_button.dart
import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.grey, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎨 코드로 그린 G 로고
            CustomPaint(
              size: const Size(24, 24),
              painter: GoogleLogoPainter(),
            ),
            const SizedBox(width: 12),
            Text(
              isLoading ? '로그인 중...' : 'Google 계정으로 로그인',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double stroke = width * 0.2;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // 🔴 빨강
    paint.color = const Color(0xFFDB4437);
    canvas.drawArc(
      Rect.fromLTWH(stroke, stroke, width - stroke * 2, height - stroke * 2),
      -0.2,
      1.2,
      false,
      paint,
    );

    // 🟢 초록
    paint.color = const Color(0xFF0F9D58);
    canvas.drawArc(
      Rect.fromLTWH(stroke, stroke, width - stroke * 2, height - stroke * 2),
      1.0,
      1.1,
      false,
      paint,
    );

    // 🔵 파랑
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(stroke, stroke, width - stroke * 2, height - stroke * 2),
      2.1,
      1.2,
      false,
      paint,
    );

    // 🟡 노랑
    paint.color = const Color(0xFFF4B400);
    canvas.drawArc(
      Rect.fromLTWH(stroke, stroke, width - stroke * 2, height - stroke * 2),
      3.3,
      1.1,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
