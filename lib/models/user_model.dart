import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String email;
  final String name;
  final String role;
  final String? deviceFingerprint; // 🔑 디바이스 고유 식별자
  final Map<String, String>? deviceInfo; // 📱 디바이스 정보
  final DateTime? lastLoginAt; // 🕐 마지막 로그인 시간
  final List<String>? loginHistory; // 📊 로그인 기록 (최근 5개)

  UserModel({
    required this.email,
    required this.name,
    required this.role,
    this.deviceFingerprint,
    this.deviceInfo,
    this.lastLoginAt,
    this.loginHistory,
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
    );
  }
}