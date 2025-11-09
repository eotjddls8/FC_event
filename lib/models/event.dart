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
  final DateTime rewardEndDate; // 🎯 보상 종료 날짜
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
    required this.rewardEndDate,
    this.likes = 0,
    this.likedUsers = const [],
  });

  // 🎯 3단계 이벤트 상태 (수정됨 - 명확한 로직)
  EventStatus get status {
    final now = DateTime.now();

    // 시간 제거하고 날짜만 비교
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final rewardEndDay = DateTime(rewardEndDate.year, rewardEndDate.month, rewardEndDate.day);

    // 조건 체크 순서: 가장 나중 → 가장 이른 순서
    if (today.isBefore(startDay)) {
      // 오늘 < 시작일
      return EventStatus.upcoming;
    } else if (today.isAfter(rewardEndDay)) {
      // 오늘 > 보상종료일
      return EventStatus.ended;
    } else if (today.isAfter(endDay)) {
      // 이벤트종료일 < 오늘 <= 보상종료일
      return EventStatus.rewardPeriod;
    } else {
      // 시작일 <= 오늘 <= 이벤트종료일
      return EventStatus.active;
    }
  }

  // 남은 일수 계산
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 날짜만 비교
    int calculateDaysDifference(DateTime targetDate) {
      final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      return targetDay.difference(today).inDays;
    }

    // 상태에 따른 남은 일수
    switch (status) {
      case EventStatus.upcoming:
        return calculateDaysDifference(startDate);
      case EventStatus.active:
        return calculateDaysDifference(endDate);
      case EventStatus.rewardPeriod:
        return calculateDaysDifference(rewardEndDate);
      case EventStatus.ended:
        return -1;
    }
  }

  // 🎯 상태별 색상
  Color get statusColor {
    switch (status) {
      case EventStatus.upcoming:
        return Color(0xFF9E9E9E); // 회색 (시작 예정)
      case EventStatus.active:
      // 진행 중 - 남은 기간에 따라 색상 변경
        if (daysRemaining > 7) return Color(0xFF2196F3); // 파랑
        if (daysRemaining > 3) return Color(0xFFFFC107); // 노랑
        if (daysRemaining > 1) return Color(0xFFFF9800); // 주황
        return Color(0xFFF44336); // 빨강 (마감 임박)
      case EventStatus.rewardPeriod:
        return Color(0xFFFFC107); // 노랑 (보상 수령 가능)
      case EventStatus.ended:
        return Color(0xFF616161); // 진한 회색 (완전 종료)
    }
  }

  // 🎯 상태 텍스트
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

  // Firestore에서 데이터 가져오기
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

  // Firestore에 데이터 저장
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'author': author,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'rewardEndDate': Timestamp.fromDate(rewardEndDate),
      'likes': likes,
      'likedUsers': likedUsers,
    };
  }

  // 좋아요 여부 확인
  bool isLikedBy(String userEmail) {
    return likedUsers.contains(userEmail);
  }
}

// 🎯 이벤트 상태 Enum
enum EventStatus {
  upcoming,      // 시작 예정
  active,        // 진행 중
  rewardPeriod,  // 보상 수령 기간
  ended          // 완전 종료
}