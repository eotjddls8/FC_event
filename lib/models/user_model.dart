import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;


class UserModel {
  final String email;
  final String name;
  final String role;
  final String? deviceFingerprint;
  final Map<String, String>? deviceInfo;
  final DateTime? lastLoginAt;
  final List<String>? loginHistory;
  final bool isEmailVerified;

  // 🔑 [추가됨] createdAt 필드
  final DateTime? createdAt;

  // ========== 코인 시스템 필드들 ==========
  final int coins;
  final int dailyAdCount;
  final String lastAdDate;

  UserModel({
    required this.email,
    required this.name,
    required this.role,
    this.deviceFingerprint,
    this.deviceInfo,
    this.lastLoginAt,
    this.loginHistory,
    // 🔑 [추가됨] createdAt 필드를 생성자에 추가
    this.createdAt,
    this.coins = 0,
    this.dailyAdCount = 0,
    this.lastAdDate = '',
    this.isEmailVerified = false,
  });

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';

  // 🔑 중복 계정 체크용 - 같은 디바이스에서 로그인했는지 확인
  bool isSameDevice(String fingerprint) {
    return deviceFingerprint == fingerprint;
  }

  // 🔑 [추가됨] Map에서 UserModel을 생성하는 팩토리 (AuthService에서 사용)
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'user',
      deviceFingerprint: data['deviceFingerprint'],
      deviceInfo: data['deviceInfo'] != null
          ? Map<String, String>.from(data['deviceInfo'])
          : null,
      lastLoginAt: data['lastLoginAt'] is Timestamp
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : data['lastLoginAt'] is DateTime
          ? data['lastLoginAt']
          : null,
      loginHistory: data['loginHistory'] != null
          ? List<String>.from(data['loginHistory'])
          : null,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is DateTime
          ? data['createdAt']
          : null,
      coins: data['coins'] ?? 0,
      dailyAdCount: data['dailyAdCount'] ?? 0,
      lastAdDate: data['lastAdDate'] ?? '',
      isEmailVerified: data['emailVerified'] ?? false,
    );
  }


  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    // 🚨 [수정 필요] doc.data()를 Map<String, dynamic>으로 안전하게 명시적 캐스팅
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // return UserModel.fromMap(data); // 기존 코드 (타입 불일치 오류 발생)
    return UserModel.fromMap(data); // 💡 이제 Map<String, dynamic>을 전달하므로 오류 해결
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null, // 🔑 [추가됨]
      'coins': coins,
      'dailyAdCount': dailyAdCount,
      'lastAdDate': lastAdDate,
      'emailVerified': isEmailVerified,
    };
  }

  // 🔑 [추가됨] 객체 불변성을 유지하며 특정 필드만 업데이트하는 'copyWith' 메서드
  UserModel copyWith({
    String? email,
    String? name,
    String? role,
    String? deviceFingerprint,
    Map<String, String>? deviceInfo,
    DateTime? lastLoginAt,
    List<String>? loginHistory,
    DateTime? createdAt,
    int? coins,
    int? dailyAdCount,
    String? lastAdDate,
    bool? isEmailVerified,
  }) {
    return UserModel(
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      loginHistory: loginHistory ?? this.loginHistory,
      createdAt: createdAt ?? this.createdAt,
      coins: coins ?? this.coins,
      dailyAdCount: dailyAdCount ?? this.dailyAdCount,
      lastAdDate: lastAdDate ?? this.lastAdDate,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }


  // 🔄 로그인 기록 업데이트 (copyWith 사용으로 변경)
  UserModel updateLoginHistory() {
    final now = DateTime.now();
    // 🔑 기존 코드를 List<String>이 확실하도록 수정 (List<String>? --> List<String>)
    final newHistory = List<String>.from(loginHistory ?? []);

    // 현재 시간을 추가
    newHistory.add(now.toIso8601String());

    // 최근 5개만 유지
    if (newHistory.length > 5) {
      newHistory.removeAt(0);
    }

    // 🔑 copyWith 사용
    return copyWith(
      lastLoginAt: now,
      loginHistory: newHistory,
    );
  }

  // 💰 코인 추가 (copyWith 사용으로 변경)
  UserModel addCoins(int amount) {
    return copyWith(
      coins: coins + amount,
    );
  }

  // 💸 코인 차감 (copyWith 사용으로 변경)
  UserModel subtractCoins(int amount) {
    return copyWith(
      coins: coins - amount < 0 ? 0 : coins - amount,
    );
  }

  // 📺 광고 시청 기록 업데이트 (copyWith 사용으로 변경)
  UserModel updateAdWatch() {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    final newDailyCount = (lastAdDate == todayString) ? dailyAdCount + 1 : 1;

    return copyWith(
      dailyAdCount: newDailyCount,
      lastAdDate: todayString,
    );
  }

// ... (나머지 메서드는 변경 없음)
}


extension UserModelFactories on UserModel {
  // Firebase User → UserModel 매핑
  static UserModel fromFirebaseUser(User user) {
    final nowIso = DateTime.now().toIso8601String();
    return UserModel(
      email: user.email ?? '',
      name: user.displayName ?? (user.email?.split('@').first ?? '사용자'),
      role: 'user',
      isEmailVerified: user.emailVerified,
      deviceFingerprint: null,
      deviceInfo: null,
      lastLoginAt: DateTime.now(),
      loginHistory: [nowIso],
      // 🔑 [추가됨] createdAt도 초기화
      createdAt: DateTime.now(),
      coins: 0,
      dailyAdCount: 0,
      lastAdDate: '',
    );
  }
}