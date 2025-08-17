import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // 이 줄 추가!


class Event {
  final String? id;
  final String title;
  final String content;
  final String author;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final int likes;
  final List<String> likedUsers;

  Event({
    this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    this.likes = 0,
    this.likedUsers = const [],
  });

  // 남은 일수 계산
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return -1; // 이미 끝남
    if (now.isBefore(startDate)) {
      // 아직 시작 안함 - 시작까지 남은 일수
      return startDate.difference(now).inDays;
    }
    // 진행 중 - 종료까지 남은 일수
    return endDate.difference(now).inDays;
  }

  // 이벤트 상태
  EventStatus get status {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return EventStatus.upcoming;
    if (now.isAfter(endDate)) return EventStatus.ended;
    return EventStatus.active;
  }

  // 상태별 색상
  Color get statusColor {
    switch (status) {
      case EventStatus.upcoming:
        return Color(0xFF2196F3); // 파랑
      case EventStatus.active:
        if (daysRemaining > 3) return Color(0xFF4CAF50); // 초록
        if (daysRemaining > 1) return Color(0xFFFF9800); // 노랑
        return Color(0xFFF44336); // 빨강
      case EventStatus.ended:
        return Color(0xFF9E9E9E); // 회색
    }
  }

  // 상태 텍스트
  String get statusText {
    switch (status) {
      case EventStatus.upcoming:
        return 'D-${daysRemaining}일 후 시작';
      case EventStatus.active:
        if (daysRemaining == 0) return '오늘 마감!';
        return 'D-${daysRemaining}일 남음';
      case EventStatus.ended:
        return '종료됨';
    }
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      author: data['author'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      likedUsers: List<String>.from(data['likedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'author': author,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'likes': likes,
      'likedUsers': likedUsers,
    };
  }

  bool isLikedBy(String userEmail) {
    return likedUsers.contains(userEmail);
  }
}

enum EventStatus { upcoming, active, ended }