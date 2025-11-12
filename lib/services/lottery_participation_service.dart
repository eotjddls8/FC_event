import 'package:cloud_firestore/cloud_firestore.dart';
import 'time_validation_service.dart';

/// 추첨 응모 및 관리를 담당하는 서비스
///
/// 코인 차감, 참가자 등록, 중복 체크 등
/// 모든 추첨 관련 비즈니스 로직을 처리합니다.
class LotteryParticipationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 추첨에 응모합니다 (Transaction 처리)
  ///
  /// [userId]: 사용자 ID
  /// [userName]: 사용자 이름
  /// [userEmail]: 사용자 이메일
  /// [prizeId]: 상품 ID
  /// [prizeName]: 상품 이름
  /// [requiredCoins]: 필요한 코인
  /// [deviceId]: 기기 ID
  ///
  /// Returns: 응모 결과
  static Future<ParticipationResult> participate({
    required String userId,
    required String userName,
    required String userEmail,
    required String prizeId,
    required String prizeName,
    required int requiredCoins,
    required String deviceId,
  }) async {
    try {
      // 1️⃣ 시간 검증
      final timeValidation = await TimeValidationService.validateTime();
      if (!timeValidation.isValid) {
        return ParticipationResult(
          success: false,
          errorType: ParticipationError.timeValidationFailed,
          errorMessage: timeValidation.message ?? '시간 검증 실패',
        );
      }

      // 2️⃣ 상품 존재 여부 확인
      final prizeDoc = await _firestore.collection('prizes').doc(prizeId).get();
      if (!prizeDoc.exists) {
        return ParticipationResult(
          success: false,
          errorType: ParticipationError.prizeNotFound,
          errorMessage: '상품을 찾을 수 없습니다',
        );
      }

      // 3️⃣ 상품 응모 가능 여부 체크 (마감일, 최대 인원 등)
      final prizeData = prizeDoc.data()!;
      final validationResult = _validatePrize(prizeData);
      if (!validationResult.isValid) {
        return ParticipationResult(
          success: false,
          errorType: ParticipationError.prizeNotAvailable,
          errorMessage: validationResult.message ?? '응모할 수 없는 상품입니다',
        );
      }

      // 4️⃣ Transaction으로 응모 처리
      final result = await _firestore.runTransaction<ParticipationResult>((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final prizeRef = _firestore.collection('prizes').doc(prizeId);
        final participantRef = prizeRef.collection('participants').doc(); // 자동 생성 ID

        // 사용자 문서 가져오기
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('사용자 문서가 존재하지 않습니다');
        }

        final userData = userDoc.data()!;
        final int currentCoins = (userData['coins'] ?? 0).toInt();

        // 코인 부족 체크
        if (currentCoins < requiredCoins) {
          return ParticipationResult(
            success: false,
            errorType: ParticipationError.insufficientCoins,
            errorMessage: '코인이 부족합니다 (필요: $requiredCoins, 보유: $currentCoins)',
            requiredCoins: requiredCoins,
            currentCoins: currentCoins,
          );
        }

        // 상품 문서 다시 가져오기 (동시성 체크)
        final latestPrizeDoc = await transaction.get(prizeRef);
        if (!latestPrizeDoc.exists) {
          throw Exception('상품이 삭제되었습니다');
        }

        final latestPrizeData = latestPrizeDoc.data()!;
        final currentParticipants = (latestPrizeData['currentParticipants'] ?? 0).toInt();
        final maxParticipants = (latestPrizeData['maxParticipants'] ?? 999999).toInt();

        // 최대 인원 체크
        if (currentParticipants >= maxParticipants) {
          return ParticipationResult(
            success: false,
            errorType: ParticipationError.maxParticipantsReached,
            errorMessage: '최대 응모 인원에 도달했습니다',
          );
        }

        // ✅ 1. 코인 차감 (유저 문서 업데이트)
        transaction.update(userRef, {
          'coins': FieldValue.increment(-requiredCoins),
          'totalCoinsSpent': FieldValue.increment(requiredCoins),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // ✅ 2. 추첨 응모 기록 (Subcollection: prizes/{prizeId}/participants/{participantId})
        transaction.set(participantRef, {
          'userId': userId,
          'userName': userName,
          'email': userEmail,
          'coinsSpent': requiredCoins,
          'deviceId': deviceId,
          'participatedAt': FieldValue.serverTimestamp(),
          'status': 'pending', // pending, winner, loser
        });

        // ✅ 3. 상품 참가자 수 증가 (prize 문서 업데이트)
        transaction.update(prizeRef, {
          'currentParticipants': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('🎯 추첨 응모 완료: $prizeName ($requiredCoins 코인) - Subcollection 방식');

        return ParticipationResult(
          success: true,
          prizeId: prizeId,
          prizeName: prizeName,
          coinsSpent: requiredCoins,
          remainingCoins: currentCoins - requiredCoins,
          newParticipantCount: currentParticipants + 1,
        );
      });

      return result;
    } catch (e) {
      print('⚠️ 추첨 응모 실패: $e');
      return ParticipationResult(
        success: false,
        errorType: ParticipationError.transactionFailed,
        errorMessage: '응모 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 상품이 응모 가능한 상태인지 검증합니다
  static _PrizeValidationResult _validatePrize(Map<String, dynamic> prizeData) {
    try {
      // 상품 상태 체크
      final status = prizeData['status'] ?? '';
      if (status != 'active') {
        return _PrizeValidationResult(
          isValid: false,
          message: '현재 응모할 수 없는 상품입니다',
        );
      }

      // 마감일 체크
      final deadline = prizeData['deadline'];
      if (deadline != null && deadline is Timestamp) {
        final deadlineDate = deadline.toDate();
        if (DateTime.now().isAfter(deadlineDate)) {
          return _PrizeValidationResult(
            isValid: false,
            message: '응모 기간이 종료되었습니다',
          );
        }
      }

      // 최대 인원 체크
      final currentParticipants = (prizeData['currentParticipants'] ?? 0).toInt();
      final maxParticipants = (prizeData['maxParticipants'] ?? 999999).toInt();
      if (currentParticipants >= maxParticipants) {
        return _PrizeValidationResult(
          isValid: false,
          message: '최대 응모 인원에 도달했습니다',
        );
      }

      return _PrizeValidationResult(isValid: true);
    } catch (e) {
      return _PrizeValidationResult(
        isValid: false,
        message: '상품 정보를 확인할 수 없습니다',
      );
    }
  }

  /// 사용자가 특정 상품에 응모한 횟수를 가져옵니다
  ///
  /// [prizeId]: 상품 ID
  /// [userId]: 사용자 ID
  /// Returns: 응모 횟수
  static Future<int> getUserEntryCount(String prizeId, String userId) async {
    try {
      final participantsSnapshot = await _firestore
          .collection('prizes')
          .doc(prizeId)
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();

      return participantsSnapshot.docs.length;
    } catch (e) {
      print('⚠️ 응모 횟수 조회 실패: $e');
      return 0;
    }
  }

  /// 사용자의 모든 응모 내역을 가져옵니다
  ///
  /// [userId]: 사용자 ID
  /// [limit]: 가져올 최대 개수 (기본 20개)
  /// Returns: 응모 내역 리스트
  static Future<List<ParticipationHistory>> getUserParticipationHistory({
    required String userId,
    int limit = 20,
  }) async {
    try {
      // 모든 상품의 participants 서브컬렉션을 검색
      // 이 방식은 비효율적이므로, 실제로는 별도의 user_participations 컬렉션을 만드는 것이 좋습니다
      // 하지만 현재 구조에 맞춰서 작성합니다

      final prizesSnapshot = await _firestore.collection('prizes').get();
      List<ParticipationHistory> allParticipations = [];

      for (var prizeDoc in prizesSnapshot.docs) {
        final participantsSnapshot = await prizeDoc.reference
            .collection('participants')
            .where('userId', isEqualTo: userId)
            .orderBy('participatedAt', descending: true)
            .limit(limit)
            .get();

        for (var participantDoc in participantsSnapshot.docs) {
          final data = participantDoc.data();
          allParticipations.add(ParticipationHistory(
            prizeId: prizeDoc.id,
            prizeName: prizeDoc.data()['name'] ?? 'Unknown',
            coinsSpent: (data['coinsSpent'] ?? 0).toInt(),
            participatedAt: (data['participatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: data['status'] ?? 'pending',
          ));
        }
      }

      // 최신순 정렬
      allParticipations.sort((a, b) => b.participatedAt.compareTo(a.participatedAt));

      return allParticipations.take(limit).toList();
    } catch (e) {
      print('⚠️ 응모 내역 조회 실패: $e');
      return [];
    }
  }

  /// 특정 상품의 모든 참가자 목록을 가져옵니다 (관리자용)
  ///
  /// [prizeId]: 상품 ID
  /// Returns: 참가자 리스트
  static Future<List<Participant>> getPrizeParticipants(String prizeId) async {
    try {
      final participantsSnapshot = await _firestore
          .collection('prizes')
          .doc(prizeId)
          .collection('participants')
          .orderBy('participatedAt', descending: true)
          .get();

      return participantsSnapshot.docs.map((doc) {
        final data = doc.data();
        return Participant(
          id: doc.id,
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? 'Unknown',
          email: data['email'] ?? '',
          coinsSpent: (data['coinsSpent'] ?? 0).toInt(),
          deviceId: data['deviceId'] ?? '',
          participatedAt: (data['participatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'pending',
        );
      }).toList();
    } catch (e) {
      print('⚠️ 참가자 목록 조회 실패: $e');
      return [];
    }
  }
}

/// 상품 검증 결과 (내부용)
class _PrizeValidationResult {
  final bool isValid;
  final String? message;

  _PrizeValidationResult({
    required this.isValid,
    this.message,
  });
}

/// 추첨 응모 결과
class ParticipationResult {
  final bool success;
  final String? prizeId;
  final String? prizeName;
  final int? coinsSpent;
  final int? remainingCoins;
  final int? newParticipantCount;
  final int? requiredCoins;
  final int? currentCoins;
  final ParticipationError? errorType;
  final String? errorMessage;

  ParticipationResult({
    required this.success,
    this.prizeId,
    this.prizeName,
    this.coinsSpent,
    this.remainingCoins,
    this.newParticipantCount,
    this.requiredCoins,
    this.currentCoins,
    this.errorType,
    this.errorMessage,
  });

  bool get hasError => !success;
}

/// 추첨 응모 실패 유형
enum ParticipationError {
  /// 시간 검증 실패
  timeValidationFailed,

  /// 상품을 찾을 수 없음
  prizeNotFound,

  /// 상품이 응모 불가능 상태
  prizeNotAvailable,

  /// 코인 부족
  insufficientCoins,

  /// 최대 인원 도달
  maxParticipantsReached,

  /// 트랜잭션 실패
  transactionFailed,
}

/// 응모 내역
class ParticipationHistory {
  final String prizeId;
  final String prizeName;
  final int coinsSpent;
  final DateTime participatedAt;
  final String status; // pending, winner, loser

  ParticipationHistory({
    required this.prizeId,
    required this.prizeName,
    required this.coinsSpent,
    required this.participatedAt,
    required this.status,
  });

  bool get isWinner => status == 'winner';
  bool get isPending => status == 'pending';
  bool get isLoser => status == 'loser';
}

/// 참가자 정보
class Participant {
  final String id;
  final String userId;
  final String userName;
  final String email;
  final int coinsSpent;
  final String deviceId;
  final DateTime participatedAt;
  final String status;

  Participant({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.coinsSpent,
    required this.deviceId,
    required this.participatedAt,
    required this.status,
  });

  bool get isWinner => status == 'winner';
  bool get isPending => status == 'pending';
  bool get isLoser => status == 'loser';
}