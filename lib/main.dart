import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/auth_wrapper.dart';
import 'theme/fifa_theme.dart';

// -----------------------------------------------------------
// 로컬 알림 플러그인 인스턴스
// -----------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// -----------------------------------------------------------
// 백그라운드 메시지 핸들러
// -----------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 백그라운드 메시지 수신: ${message.messageId}");
  print("제목: ${message.notification?.title}");
  print("내용: ${message.notification?.body}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // -----------------------------------------------------------
  // FCM 및 로컬 알림 초기화
  // -----------------------------------------------------------
  await initFCM();

  runApp(MyApp());
}

// -----------------------------------------------------------
// FCM 초기화 함수 (로깅 강화)
// -----------------------------------------------------------
Future<void> initFCM() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  print("🔔 ===== FCM 초기화 시작 =====");

  // -----------------------------------------------------------
  // 1. 알림 권한 요청
  // -----------------------------------------------------------
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print("📱 알림 권한 상태: ${settings.authorizationStatus}");
  // AuthorizationStatus.authorized = 권한 허용
  // AuthorizationStatus.denied = 권한 거부
  // AuthorizationStatus.notDetermined = 아직 결정 안함

  if (settings.authorizationStatus == AuthorizationStatus.denied) {
    print("⚠️ 알림 권한이 거부되었습니다. 설정에서 허용해주세요!");
  }

  // -----------------------------------------------------------
  // 2. FCM 토큰 가져오기 및 로깅
  // -----------------------------------------------------------
  String? fcmToken = await messaging.getToken();
  print("🔑 FCM 토큰: $fcmToken");

  if (fcmToken == null) {
    print("❌ FCM 토큰 생성 실패!");
  } else {
    print("✅ FCM 토큰 생성 성공");
  }

  // 토큰 갱신 리스너
  messaging.onTokenRefresh.listen((newToken) {
    print("🔄 FCM 토큰 갱신: $newToken");
  });

  // -----------------------------------------------------------
  // 3. 토픽 구독
  // -----------------------------------------------------------
  try {
    await messaging.subscribeToTopic('event_reminders');
    print("✅ 'event_reminders' 토픽 구독 성공!");
  } catch (e) {
    print("❌ 토픽 구독 실패: $e");
  }

  // -----------------------------------------------------------
  // 4. Android 알림 채널 생성
  // -----------------------------------------------------------
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'event_channel_id', // 서버와 동일한 ID
    '이벤트 마감 알림',
    description: '이벤트 마감일 하루 전 알림 채널',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  print("📢 알림 채널 생성 완료");

  // -----------------------------------------------------------
  // 5. 로컬 알림 플러그인 초기화
  // -----------------------------------------------------------
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print("🔔 알림 탭됨: ${response.payload}");
      // TODO: 여기서 특정 화면으로 이동 가능
    },
  );

  // -----------------------------------------------------------
  // 6. 포그라운드 메시지 수신 핸들러
  // -----------------------------------------------------------
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📩 포그라운드 메시지 수신!");
    print("제목: ${message.notification?.title}");
    print("내용: ${message.notification?.body}");
    print("데이터: ${message.data}");

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // 알림 표시
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['screen'], // 화면 이동용 데이터
      );
      print("✅ 포그라운드 알림 표시 완료");
    }
  });

  // -----------------------------------------------------------
  // 7. 알림 탭해서 앱 열었을 때 처리
  // -----------------------------------------------------------
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🚀 알림을 탭해서 앱 열림!");
    print("데이터: ${message.data}");
    // TODO: 특정 화면으로 이동
  });

  print("🔔 ===== FCM 초기화 완료 =====");
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
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: Locale('ko', 'KR'),
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}