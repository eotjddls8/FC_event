import 'package:flutter/material.dart';
import '../services/notification_service.dart';

// 알림 설정 다이얼로그 표시 함수
Future<void> showNotificationSettingsDialog(BuildContext context) async {
  // 현재 알림 상태 가져오기
  bool isEnabled = await NotificationService.isNotificationEnabled();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.notifications, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text('알림 설정'),
            ],
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '알림 받기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (value) async {
                  setState(() {
                    isEnabled = value;
                  });
                  await NotificationService.setNotificationEnabled(value);

                  // 스낵바로 피드백
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value ? '✅ 알림이 켜졌습니다' : '❌ 알림이 꺼졌습니다',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                activeColor: Colors.blue[600],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('닫기'),
            ),
          ],
        );
      },
    ),
  );
}