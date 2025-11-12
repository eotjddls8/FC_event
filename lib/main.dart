import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ⬅️ 새로 추가
import 'screens/auth_wrapper.dart';
import 'theme/fifa_theme.dart';

// -----------------------------------------------------------
// 🚨 [필수] 로컬 알림 플러그인 인스턴스 (전역 변수)
// -----------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// -----------------------------------------------------------
// 🚨 [필수] 백그라운드 메시지 핸들러 (최상위 함수)
// -----------------------------------------------------------
// 앱이 완전히 닫혀있거나 백그라운드에 있을 때 FCM 메시지를 처리합니다.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  // 백그라운드에서도 로컬 알림을 띄우고 싶다면 여기에 show 로직 추가 가능
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // -----------------------------------------------------------
  // 1. FCM 및 로컬 알림 초기화
  // -----------------------------------------------------------

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Android 알림 채널 정의 (서버가 보낸 메시지를 이 채널로 수신)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'event_channel_id', // ID: 서버 코드(Cloud Function)와 일치해야 합니다.
    '이벤트 마감 알림', // Name: 사용자에게 보이는 알림 채널 이름
    description: '이벤트 마감일 하루 전 알림 채널입니다.',
    importance: Importance.high,
  );

  // 로컬 알림 플러그인 초기화 설정 (Android)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // -----------------------------------------------------------
  // 2. 권한 요청 및 토픽 구독
  // -----------------------------------------------------------

  // 알림 권한 요청 (iOS 및 Android 13+)
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 'event_reminders' 주제를 구독 (서버 함수가 이 토픽으로 알림을 보냅니다)
  await messaging.subscribeToTopic('event_reminders');

  // -----------------------------------------------------------
  // 3. 포그라운드(앱 실행 중) 메시지 수신 핸들러
  // -----------------------------------------------------------
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode, // 알림 ID
        notification.title,    // 알림 제목
        notification.body,     // 알림 내용
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android.smallIcon, // Android에서 사용할 아이콘
          ),
        ),
      );
    }
  });


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
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
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
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}