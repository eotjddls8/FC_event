import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _notificationKey = 'notification_enabled';

  // 알림 설정 상태 가져오기
  static Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationKey) ?? true; // 기본값: true (켜짐)
  }

  // 알림 설정 저장하기
  static Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey, enabled);

    if (enabled) {
      // 알림 켜기 → 토픽 구독
      await _messaging.subscribeToTopic('event_reminders');
      print("✅ 알림 켜짐: 'event_reminders' 토픽 구독");
    } else {
      // 알림 끄기 → 토픽 구독 해제
      await _messaging.unsubscribeFromTopic('event_reminders');
      print("❌ 알림 꺼짐: 'event_reminders' 토픽 구독 해제");
    }
  }

  // 알림 ON/OFF 토글
  static Future<void> toggleNotification() async {
    final currentState = await isNotificationEnabled();
    await setNotificationEnabled(!currentState);
  }
}