import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prize_model.dart';

class PrizeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prizesCollection = 'prizes';

  // 🔧 단순화된 쿼리 (인덱스 불필요)
  static Stream<List<PrizeModel>> getPrizesStream() {
    return _firestore
        .collection(_prizesCollection)
        .snapshots()  // 모든 WHERE 조건과 ORDER BY 제거
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return <PrizeModel>[];
      }

      try {
        final prizes = snapshot.docs
            .map((doc) => PrizeModel.fromFirestore(doc.data(), doc.id))
            .toList();

        // 클라이언트에서 정렬 및 필터링 (인덱스 불필요)
        prizes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return prizes;
      } catch (e) {
        print('Prize 데이터 파싱 오류: $e');
        return <PrizeModel>[];
      }
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
    //required int maxParticipants,
    required int requiredCoins,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('사용자 인증이 필요합니다');
      }

      // 관리자 권한 체크
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null || userData['role'] != 'admin') {  // isAdmin 대신 role 사용
        throw Exception('관리자 권한이 필요합니다');
      }

      final prizeData = {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'tier': tier.name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        //'maxParticipants': maxParticipants,
        'requiredCoins': requiredCoins,
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
      if (userData == null || userData['role'] != 'admin') {  // isAdmin 대신 role 사용
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
    //int? maxParticipants,
    int? requiredCoins,
    String? status,
    String? winnerId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('인증이 필요합니다');

      // 관리자 권한 체크
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null || userData['role'] != 'admin') {  // isAdmin 대신 role 사용
        throw Exception('관리자 권한이 필요합니다');
      }

      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (tier != null) updateData['tier'] = tier.name;
      if (startDate != null) updateData['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updateData['endDate'] = Timestamp.fromDate(endDate);
     //if (maxParticipants != null) updateData['maxParticipants'] = maxParticipants;
      if (requiredCoins != null) updateData['requiredCoins'] = requiredCoins;
      if (status != null) updateData['status'] = status;
      if (winnerId != null) updateData['winnerId'] = winnerId;

      updateData['updatedAt'] = FieldValue.serverTimestamp(); // 수정 시간 기록

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
      final currentPoints = userData?['coins'] ?? 0;  // points 대신 coins 사용

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
          'coins': FieldValue.increment(-requiredAdViews),  // points 대신 coins 사용
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

  // 특정 상품에 대한 사용자의 총 응모 횟수를 가져옵니다.
  static Future<int> getUserEntryCount(String prizeId, String userId) async {
    try {
      // ⭐ 변경: 'prize_entries' 컬렉션 대신 'prizes/{prizeId}/participants' 서브컬렉션 조회
      final querySnapshot = await _firestore
          .collection('prizes')
          .doc(prizeId)
          .collection('participants') // ⭐ 서브컬렉션 지정
          .where('userId', isEqualTo: userId) // ⭐ userId로 필터링
          .count() // Firestore SDK의 count() 기능을 사용합니다.
          .get();

      return querySnapshot.count ?? 0;
    } catch (e) {
      print('❌ 사용자 응모 횟수 가져오기 실패: $e');
      return 0;
    }
  }

}