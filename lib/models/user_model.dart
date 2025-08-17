import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String email;
  final String name;
  final String role;

  UserModel({
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'user',
    );
  }

  // 새로 추가
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
    };
  }
}