// prize_model.dart (전체 수정된 코드)

import 'package:cloud_firestore/cloud_firestore.dart';

class PrizeModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final PrizeTier tier;
  final DateTime startDate;
  final DateTime endDate;
  //final int maxParticipants;
  final int currentParticipants;
  final int requiredCoins; // ⭐ 1. 필드 추가
  final PrizeStatus status;
  final String createdBy; // 관리자 ID
  final DateTime createdAt;
  final String? winnerId;
  final DateTime? winnerSelectedAt;

  PrizeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.tier,
    required this.startDate,
    required this.endDate,
    //required this.maxParticipants,
    required this.currentParticipants,
    required this.requiredCoins, // ⭐ 2. 생성자에 추가
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.winnerId,
    this.winnerSelectedAt,
  });

  // Firestore에서 데이터 가져오기
  factory PrizeModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PrizeModel(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      tier: PrizeTier.values.firstWhere(
            (tier) => tier.name == data['tier'],
        orElse: () => PrizeTier.bronze,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      //maxParticipants: data['maxParticipants'] ?? 0,
      currentParticipants: data['currentParticipants'] ?? 0,
      requiredCoins: (data['requiredCoins'] ?? 0).toInt(), // ⭐ 3. fromFirestore에 추가 (기본값 0)
      status: PrizeStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => PrizeStatus.upcoming,
      ),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      winnerId: data['winnerId'],
      winnerSelectedAt: data['winnerSelectedAt'] != null
          ? (data['winnerSelectedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Firestore에 데이터 저장하기
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'tier': tier.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      //'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'requiredCoins': requiredCoins, // ⭐ 4. toFirestore에 추가
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt), // 참고: 생성 시에는 FieldValue.serverTimestamp() 사용
      'winnerId': winnerId,
      'winnerSelectedAt': winnerSelectedAt != null
          ? Timestamp.fromDate(winnerSelectedAt!)
          : null,
    };
  }

  // 현재 상태 체크
  PrizeStatus getCurrentStatus() {
    final now = DateTime.now();

    if (now.isBefore(startDate)) {
      return PrizeStatus.upcoming;
    } else if (now.isAfter(endDate)) {
      if (winnerId != null && winnerId!.isNotEmpty) { // ⭐ null이 아니고 비어있지 않은지 확인
        return PrizeStatus.completed;
      }
      return PrizeStatus.expired; // 당첨자가 없으면 '만료됨'
    } else {
      return PrizeStatus.active;
    }
  }

  // 추첨 가능한지 체크
  bool canParticipate() {
    final status = getCurrentStatus();
    return status == PrizeStatus.active;
        //currentParticipants < maxParticipants;
  }

  // 필요한 코인 (이제 모델에 필드가 있으므로 getter 불필요)
  // int get requiredAdViews => tier.requiredAdViews; // 이 줄은 requiredCoins 필드로 대체됨

  // 상품 가치 (원)
  String get valueDisplay => tier.valueDisplay;
}

// 상품 티어
enum PrizeTier {
  bronze(1, '1,000원 상당', '🥉'),
  silver(3, '5,000원 상당', '🥈'),
  gold(5, '10,000원 상당', '🥇'),
  diamond(10, '50,000원 상당', '💎');

  const PrizeTier(this.requiredAdViews, this.valueDisplay, this.emoji);

  final int requiredAdViews; // 이 값은 이제 참고용 (requiredCoins가 메인)
  final String valueDisplay;
  final String emoji;
}

// 상품 상태
enum PrizeStatus {
  upcoming('시작 전'),
  active('진행 중'),
  expired('만료됨'), // '추첨 전' 또는 '마감됨'
  completed('추첨 완료');

  const PrizeStatus(this.displayName);
  final String displayName;
}

// 사용자 응모 정보
class PrizeEntryModel {
  final String id;
  final String prizeId;
  final String userId;
  final DateTime entryDate;
  final List<String> adViewIds; // 시청한 광고 ID들

  PrizeEntryModel({
    required this.id,
    required this.prizeId,
    required this.userId,
    required this.entryDate,
    required this.adViewIds,
  });

  factory PrizeEntryModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PrizeEntryModel(
      id: documentId,
      prizeId: data['prizeId'] ?? '',
      userId: data['userId'] ?? '',
      entryDate: (data['entryDate'] as Timestamp).toDate(),
      adViewIds: List<String>.from(data['adViewIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'prizeId': prizeId,
      'userId': userId,
      'entryDate': Timestamp.fromDate(entryDate),
      'adViewIds': adViewIds,
    };
  }
}

// 광고 시청 이력
class AdViewHistoryModel {
  final String id;
  final String userId;
  final String? prizeId; // 상품 관련 광고인 경우
  final DateTime viewDate;
  final String adType; // 'reward', 'prize_entry' 등
  final int pointsEarned;

  AdViewHistoryModel({
    required this.id,
    required this.userId,
    required this.viewDate,
    required this.adType,
    required this.pointsEarned,
    this.prizeId,
  });

  factory AdViewHistoryModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return AdViewHistoryModel(
      id: documentId,
      userId: data['userId'] ?? '',
      prizeId: data['prizeId'],
      viewDate: (data['viewDate'] as Timestamp).toDate(),
      adType: data['adType'] ?? '',
      pointsEarned: data['pointsEarned'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'prizeId': prizeId,
      'viewDate': Timestamp.fromDate(viewDate),
      'adType': adType,
      'pointsEarned': pointsEarned,
    };
  }
}