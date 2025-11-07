import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String email;
  final String name;
  final String role;
  final String? deviceFingerprint; // 🔑 디바이스 고유 식별자
  final Map<String, String>? deviceInfo; // 📱 디바이스 정보
  final DateTime? lastLoginAt; // 🕐 마지막 로그인 시간
  final List<String>? loginHistory; // 📊 로그인 기록 (최근 5개)

  // ========== 새로 추가된 코인 시스템 필드들 ==========
  final int coins;         // 💰 사용자 보유 코인
  final int dailyAdCount;  // 📺 오늘 광고 시청 횟수
  final String lastAdDate; // 📅 마지막 광고 본 날짜

  UserModel({
    required this.email,
    required this.name,
    required this.role,
    this.deviceFingerprint,
    this.deviceInfo,
    this.lastLoginAt,
    this.loginHistory,
    // ========== 새로 추가된 필드들을 생성자에 추가 ==========
    this.coins = 0,              // 기본값 0
    this.dailyAdCount = 0,       // 기본값 0
    this.lastAdDate = '',        // 기본값 빈 문자열
  });

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';

  // 🔑 중복 계정 체크용 - 같은 디바이스에서 로그인했는지 확인
  bool isSameDevice(String fingerprint) {
    return deviceFingerprint == fingerprint;
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'user',
      deviceFingerprint: data['deviceFingerprint'],
      deviceInfo: data['deviceInfo'] != null
          ? Map<String, String>.from(data['deviceInfo'])
          : null,
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      loginHistory: data['loginHistory'] != null
          ? List<String>.from(data['loginHistory'])
          : null,
      // ========== 새로 추가된 필드들을 fromFirestore에 추가 ==========
      coins: data['coins'] ?? 0,
      dailyAdCount: data['dailyAdCount'] ?? 0,
      lastAdDate: data['lastAdDate'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'deviceFingerprint': deviceFingerprint,
      'deviceInfo': deviceInfo,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'loginHistory': loginHistory,
      // ========== 새로 추가된 필드들을 toFirestore에 추가 ==========
      'coins': coins,
      'dailyAdCount': dailyAdCount,
      'lastAdDate': lastAdDate,
    };
  }

  // 🔄 로그인 기록 업데이트
  UserModel updateLoginHistory() {
    final now = DateTime.now();
    final newHistory = List<String>.from(loginHistory ?? []);

    // 현재 시간을 추가
    newHistory.add(now.toIso8601String());

    // 최근 5개만 유지
    if (newHistory.length > 5) {
      newHistory.removeAt(0);
    }

    return UserModel(
      email: email,
      name: name,
      role: role,
      deviceFingerprint: deviceFingerprint,
      deviceInfo: deviceInfo,
      lastLoginAt: now,
      loginHistory: newHistory,
      // ========== 새로 추가된 필드들도 포함 ==========
      coins: coins,
      dailyAdCount: dailyAdCount,
      lastAdDate: lastAdDate,
    );
  }

  // ========== 코인 시스템용 새로운 메서드들 ==========

  // 💰 코인 추가
  UserModel addCoins(int amount) {
    return UserModel(
      email: email,
      name: name,
      role: role,
      deviceFingerprint: deviceFingerprint,
      deviceInfo: deviceInfo,
      lastLoginAt: lastLoginAt,
      loginHistory: loginHistory,
      coins: coins + amount,
      dailyAdCount: dailyAdCount,
      lastAdDate: lastAdDate,
    );
  }

  // 💸 코인 차감
  UserModel subtractCoins(int amount) {
    return UserModel(
      email: email,
      name: name,
      role: role,
      deviceFingerprint: deviceFingerprint,
      deviceInfo: deviceInfo,
      lastLoginAt: lastLoginAt,
      loginHistory: loginHistory,
      coins: coins - amount < 0 ? 0 : coins - amount, // 0 이하로 내려가지 않게
      dailyAdCount: dailyAdCount,
      lastAdDate: lastAdDate,
    );
  }

  // 📺 광고 시청 기록 업데이트
  UserModel updateAdWatch() {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    // 오늘이 아니면 dailyAdCount 리셋
    final newDailyCount = (lastAdDate == todayString) ? dailyAdCount + 1 : 1;

    return UserModel(
      email: email,
      name: name,
      role: role,
      deviceFingerprint: deviceFingerprint,
      deviceInfo: deviceInfo,
      lastLoginAt: lastLoginAt,
      loginHistory: loginHistory,
      coins: coins,
      dailyAdCount: newDailyCount,
      lastAdDate: todayString,
    );
  }

  // 🔍 오늘 광고 시청 가능 여부 체크
  bool canWatchAdToday({int maxDaily = 5}) {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    // 오늘이 아니면 시청 가능
    if (lastAdDate != todayString) return true;

    // 오늘이면 최대 횟수 체크
    return dailyAdCount < maxDaily;
  }

  // 📊 오늘 광고 시청 횟수 반환 (오늘 기준)
  int getTodayAdCount() {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    return (lastAdDate == todayString) ? dailyAdCount : 0;
  }
}