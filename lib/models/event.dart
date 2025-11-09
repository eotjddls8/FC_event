import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Event {
  final String? id;
  final String title;
  final String content;
  final String author;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime rewardEndDate; // 🎯 보상 종료 날짜 추가
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
    required this.rewardEndDate, // 🎯 필수 필드로 추가
    this.likes = 0,
    this.likedUsers = const [],
  });

  // 남은 일수 계산
  int get daysRemaining {
    final now = DateTime.now();

    // 3단계 상태에 따른 남은 일수 계산
    if (now.isBefore(startDate)) {
      // 시작 전: 시작까지 남은 일수
      return startDate.difference(now).inDays;
    } else if (now.isBefore(endDate)) {
      // 진행 중: 종료까지 남은 일수
      return endDate.difference(now).inDays;
    } else if (now.isBefore(rewardEndDate)) {
      // 보상 기간: 보상 종료까지 남은 일수
      return rewardEndDate.difference(now).inDays;
    } else {
      // 완전 종료
      return -1;
    }
  }

  // 🎯 3단계 이벤트 상태
  EventStatus get status {
    final now = DateTime.now();

    if (now.isBefore(startDate)) {
      return EventStatus.upcoming; // 시작 예정
    } else if (now.isBefore(endDate)) {
      return EventStatus.active; // 진행 중
    } else if (now.isBefore(rewardEndDate)) {
      return EventStatus.rewardPeriod; // 보상 수령 기간
    } else {
      return EventStatus.ended; // 완전 종료
    }
  }

  // 🎯 상태별 색상 (3단계)
  Color get statusColor {
    switch (status) {
      case EventStatus.upcoming:
        return Color(0xFF9E9E9E); // 회색 (시작 예정)
      case EventStatus.active:
      // 진행 중 - 남은 기간에 따라 색상 변경
        if (daysRemaining > 3) return Color(0xFF2196F3); // 파랑
        if (daysRemaining > 1) return Color(0xFFFF9800); // 주황
        return Color(0xFFF44336); // 빨강 (마감 임박)
      case EventStatus.rewardPeriod:
        return Color(0xFFFFC107); // 노랑 (보상 수령 가능)
      case EventStatus.ended:
        return Color(0xFF616161); // 진한 회색 (완전 종료)
    }
  }

  // 🎯 상태 텍스트 (3단계)
  String get statusText {
    switch (status) {
      case EventStatus.upcoming:
        final days = daysRemaining;
        if (days == 0) return '오늘 시작!';
        return '${days}일 후 시작';
      case EventStatus.active:
        final days = daysRemaining;
        if (days == 0) return '오늘 마감!';
        return 'D-${days}';
      case EventStatus.rewardPeriod:
        final days = daysRemaining;
        if (days == 0) return '보상 마감!';
        return '보상 D-${days}';
      case EventStatus.ended:
        return '종료됨';
    }
  }

  // 🎯 상태 아이콘
  IconData get statusIcon {
    switch (status) {
      case EventStatus.upcoming:
        return Icons.schedule; // 시계
      case EventStatus.active:
        return Icons.play_circle_filled; // 재생
      case EventStatus.rewardPeriod:
        return Icons.card_giftcard; // 선물
      case EventStatus.ended:
        return Icons.check_circle; // 체크
    }
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // 기존 데이터 호환성: rewardEndDate가 없으면 endDate + 7일로 설정
    DateTime rewardEnd = data['rewardEndDate'] != null
        ? (data['rewardEndDate'] as Timestamp).toDate()
        : (data['endDate'] as Timestamp).toDate().add(Duration(days: 7));

    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      author: data['author'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      rewardEndDate: rewardEnd,
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
      'rewardEndDate': Timestamp.fromDate(rewardEndDate), // 🎯 추가
      'likes': likes,
      'likedUsers': likedUsers,
    };
  }

  bool isLikedBy(String userEmail) {
    return likedUsers.contains(userEmail);
  }
}

// 🎯 4단계 상태로 확장
enum EventStatus {
  upcoming,      // 시작 예정
  active,        // 진행 중
  rewardPeriod,  // 보상 수령 기간
  ended          // 완전 종료
}