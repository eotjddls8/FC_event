import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prize_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'rewarded_ad_service.dart';
import 'dart:math';

class PrizeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prizesCollection = 'prizes';
  static const String _entriesCollection = 'prize_entries';
  static const String _adHistoryCollection = 'ad_history';

  // 상품 스트림 가져오기
  static Stream<List<PrizeModel>> getPrizesStream() {
    return _firestore
        .collection(_prizesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PrizeModel.fromFirestore(doc.data(), doc.id))
        .toList());
  }

  // 활성 상품만 가져오기
  static Stream<List<PrizeModel>> getActivePrizesStream() {
    final now = DateTime.now();
    return _firestore
        .collection(_prizesCollection)
        .where('status', isEqualTo: 'active')
        .where('endDate', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('endDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PrizeModel.fromFirestore(doc.data(), doc.id))
        .toList());
  }

  // 상품 등록 (관리자만 가능)
  static Future<String> createPrize({
    required String title,
    required String description,
    required String imageUrl,
    required PrizeTier tier,
    required DateTime startDate,
    required DateTime endDate,
    required int maxParticipants,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    // 관리자 권한 체크
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null || userData['isAdmin'] != true) {
      throw Exception('관리자 권한이 필요합니다');
    }

    final prizeData = {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'tier': tier.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'maxParticipants': maxParticipants,
      'currentParticipants': 0,
      'status': _getStatusFromDates(startDate, endDate).name,
      'createdBy': user.uid,
      'createdAt': Timestamp.now(),
      'winnerId': null,
      'winnerSelectedAt': null,
    };

    final docRef = await _firestore.collection(_prizesCollection).add(prizeData);
    return docRef.id;
  }

  // 상품 응모 (광고 시청 후)
  static Future<bool> participateInPrize(String prizeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    // 상품 정보 가져오기
    final prizeDoc = await _firestore.collection(_prizesCollection).doc(prizeId).get();
    if (!prizeDoc.exists) throw Exception('상품을 찾을 수 없습니다');

    final prize = PrizeModel.fromFirestore(prizeDoc.data()!, prizeDoc.id);

    // 응모 가능 여부 체크
    if (!prize.canParticipate()) {
      throw Exception('응모 기간이 아니거나 정원이 초과되었습니다');
    }

    // 이미 응모했는지 체크
    final existingEntry = await _firestore
        .collection(_entriesCollection)
        .where('prizeId', isEqualTo: prizeId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingEntry.docs.isNotEmpty) {
      throw Exception('이미 응모한 상품입니다');
    }

    // 필요한 광고 시청 횟수 체크
    final requiredViews = prize.tier.requiredAdViews;
    final adViews = await _getTodayAdViewsForPrize(user.uid, prizeId);

    if (adViews.length < requiredViews) {
      final remaining = requiredViews - adViews.length;
      throw Exception('광고를 $remaining번 더 시청해야 응모할 수 있습니다');
    }

    // 트랜잭션으로 응모 처리
    return await _firestore.runTransaction((transaction) async {
      // 현재 참가자 수 다시 확인
      final currentPrizeDoc = await transaction.get(_firestore.collection(_prizesCollection).doc(prizeId));
      final currentPrize = PrizeModel.fromFirestore(currentPrizeDoc.data()!, currentPrizeDoc.id);

      if (currentPrize.currentParticipants >= currentPrize.maxParticipants) {
        throw Exception('정원이 초과되었습니다');
      }

      // 응모 데이터 생성
      final entryData = PrizeEntryModel(
        id: '',
        prizeId: prizeId,
        userId: user.uid,
        entryDate: DateTime.now(),
        adViewIds: adViews.map((view) => view.id).toList(),
      );

      // 응모 추가
      final entryRef = _firestore.collection(_entriesCollection).doc();
      transaction.set(entryRef, entryData.toFirestore());

      // 참가자 수 증가
      transaction.update(_firestore.collection(_prizesCollection).doc(prizeId), {
        'currentParticipants': FieldValue.increment(1),
      });

      return true;
    });
  }

  // 광고 시청 이력 추가
  static Future<String> addAdViewHistory({
    required String userId,
    required String adType,
    required int pointsEarned,
    String? prizeId,
  }) async {
    final adViewData = AdViewHistoryModel(
      id: '',
      userId: userId,
      prizeId: prizeId,
      viewDate: DateTime.now(),
      adType: adType,
      pointsEarned: pointsEarned,
    );

    final docRef = await _firestore.collection(_adHistoryCollection).add(adViewData.toFirestore());
    return docRef.id;
  }

  // 상품 관련 오늘의 광고 시청 이력 가져오기
  static Future<List<AdViewHistoryModel>> _getTodayAdViewsForPrize(String userId, String prizeId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final snapshot = await _firestore
        .collection(_adHistoryCollection)
        .where('userId', isEqualTo: userId)
        .where('prizeId', isEqualTo: prizeId)
        .where('viewDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('viewDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => AdViewHistoryModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // 헬퍼: 날짜로부터 상태 계산
  static PrizeStatus _getStatusFromDates(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();

    if (now.isBefore(startDate)) {
      return PrizeStatus.upcoming;
    } else if (now.isAfter(endDate)) {
      return PrizeStatus.expired;
    } else {
      return PrizeStatus.active;
    }
  }
}