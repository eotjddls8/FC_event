import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prize_model.dart';
import '../models/user_model.dart';

class PrizeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prizesCollection = 'prizes';

  // 🚀 복합 쿼리 (인덱스 활용)
  // 인덱스: status (Asc) + createdAt (Desc)
  static Stream<List<PrizeModel>> getPrizesStream() {
    return _firestore
        .collection(_prizesCollection)
    // 1. 상태 필터링: 'active' 상태만 보여주거나, 필요에 따라 조정
    // 현재는 모든 상품을 가져오도록 필터링을 제거하고,
    // 인덱스 활용을 위해 정렬만 사용합니다.

    // 2. 인덱스에 맞게 정렬 조건 추가
        .orderBy('status', descending: false) // 'status' 오름차순 (Ascending)
        .orderBy('createdAt', descending: true) // 'createdAt' 내림차순 (Descending)
        .snapshots()
        .map((snapshot) {
      final prizes = snapshot.docs
          .map((doc) => PrizeModel.fromFirestore(doc.data(), doc.id))
          .toList();

      // 클라이언트 정렬(prizes.sort)은 더 이상 필요 없습니다.
      return prizes;
    });
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('사용자 인증이 필요합니다');
      }

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
        'status': 'active', // 기본 상태
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'winnerId': null,
        'winnerSelectedAt': null,
      };

      final docRef = await _firestore.collection(_prizesCollection).add(prizeData);
      return docRef.id;
    } catch (e) {
      throw Exception('상품 등록 실패: $e');
    }
  }

  // 상품 삭제
  static Future<void> deletePrize(String prizeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('인증이 필요합니다');

      // 관리자 권한 체크
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null || userData['isAdmin'] != true) {
        throw Exception('관리자 권한이 필요합니다');
      }

      await _firestore.collection(_prizesCollection).doc(prizeId).delete();
    } catch (e) {
      throw Exception('상품 삭제 실패: $e');
    }
  }

  // 상품 수정
  static Future<void> updatePrize({
    required String prizeId,
    String? title,
    String? description,
    String? imageUrl,
    PrizeTier? tier,
    DateTime? startDate,
    DateTime? endDate,
    int? maxParticipants,
    String? status, // 상태 업데이트 추가
    String? winnerId, // 우승자 ID 업데이트 추가
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('인증이 필요합니다');

      // 관리자 권한 체크
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null || userData['isAdmin'] != true) {
        throw Exception('관리자 권한이 필요합니다');
      }

      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (tier != null) updateData['tier'] = tier.name;
      if (startDate != null) updateData['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updateData['endDate'] = Timestamp.fromDate(endDate);
      if (maxParticipants != null) updateData['maxParticipants'] = maxParticipants;
      if (status != null) updateData['status'] = status;
      if (winnerId != null) updateData['winnerId'] = winnerId;

      await _firestore.collection(_prizesCollection).doc(prizeId).update(updateData);
    } catch (e) {
      throw Exception('상품 수정 실패: $e');
    }
  }

  // 상품 참가
  static Future<void> participateInPrize(String prizeId, int requiredAdViews) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 사용자의 광고 시청 횟수 체크
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final currentPoints = userData?['points'] ?? 0;

      if (currentPoints < requiredAdViews) {
        throw Exception('포인트가 부족합니다. 광고를 더 시청해주세요.');
      }

      await _firestore.runTransaction((transaction) async {
        // 상품 정보 가져오기
        final prizeDoc = await transaction.get(_firestore.collection(_prizesCollection).doc(prizeId));
        if (!prizeDoc.exists) {
          throw Exception('존재하지 않는 상품입니다');
        }

        final prizeData = prizeDoc.data()!;
        final currentParticipants = prizeData['currentParticipants'] ?? 0;
        final maxParticipants = prizeData['maxParticipants'] ?? 0;

        if (currentParticipants >= maxParticipants) {
          throw Exception('참가자가 가득 찼습니다');
        }

        // 포인트 차감
        transaction.update(_firestore.collection('users').doc(user.uid), {
          'points': FieldValue.increment(-requiredAdViews),
        });

        // 참가자 수 증가
        transaction.update(_firestore.collection(_prizesCollection).doc(prizeId), {
          'currentParticipants': FieldValue.increment(1),
        });

        // 참가 기록 추가
        transaction.set(_firestore.collection('prize_entries').doc(), {
          'prizeId': prizeId,
          'userId': user.uid,
          'entryDate': FieldValue.serverTimestamp(),
          'pointsUsed': requiredAdViews,
        });
      });
    } catch (e) {
      throw Exception('참가 실패: $e');
    }
  }

  // 사용자의 참가 여부 확인
  static Future<bool> hasUserParticipated(String prizeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final querySnapshot = await _firestore
          .collection('prize_entries')
          .where('prizeId', isEqualTo: prizeId)
          .where('userId', isEqualTo: user.uid)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}