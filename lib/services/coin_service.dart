import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'time_validation_service.dart';

/// 코인 획득, 차감, 검증을 담당하는 서비스
///
/// 광고 시청 보상, 일일 제한 체크, 서버 검증 등
/// 모든 코인 관련 비즈니스 로직을 처리합니다.
class CoinService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🎯 상수 설정
  static const int maxDailyAds = 10; // 일일 최대 광고 시청 횟수
  static const int baseCoinsPerAd = 1; // 광고당 기본 코인
  static const int bonus5thView = 2; // 5번째 시청 보너스
  static const int bonus10thView = 4; // 10번째 시청 보너스

  /// 사용자의 일일 광고 시청 가능 여부를 확인합니다
  ///
  /// [userId]: 사용자 ID
  /// Returns:
  /// - canWatch: 시청 가능 여부
  /// - remainingAds: 남은 광고 횟수
  /// - todayCount: 오늘 시청한 횟수
  static Future<DailyLimitResult> checkDailyLimit(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return DailyLimitResult(
          canWatch: false,
          remainingAds: 0,
          todayCount: 0,
          errorMessage: '사용자 정보를 찾을 수 없습니다',
        );
      }

      final userData = userDoc.data()!;
      final serverTime = await TimeValidationService.getServerTime();
      final todayString = TimeValidationService.formatDate(serverTime);
      final lastAdDate = userData['lastAdDate'] ?? '';

      int todayCount = 0;
      if (lastAdDate == todayString) {
        todayCount = (userData['dailyAdCount'] ?? 0).toInt();
      }

      final canWatch = todayCount < maxDailyAds;
      final remainingAds = canWatch ? maxDailyAds - todayCount : 0;

      return DailyLimitResult(
        canWatch: canWatch,
        remainingAds: remainingAds,
        todayCount: todayCount,
      );
    } catch (e) {
      print('⚠️ 일일 제한 체크 실패: $e');
      return DailyLimitResult(
        canWatch: false,
        remainingAds: 0,
        todayCount: 0,
        errorMessage: '일일 제한 확인 중 오류가 발생했습니다',
      );
    }
  }

  /// 광고 시청 후 코인을 지급합니다 (서버 검증 포함)
  ///
  /// [userId]: 사용자 ID
  /// [deviceId]: 기기 ID (중복 방지용)
  /// [consecutiveAds]: 연속 시청 횟수 (보너스 계산용)
  ///
  /// Returns: 지급된 코인 개수와 성공 여부
  static Future<CoinRewardResult> giveCoins({
    required String userId,
    required String deviceId,
    int consecutiveAds = 0,
  }) async {
    try {
      // 1️⃣ 시간 검증
      final timeValidation = await TimeValidationService.validateTime();
      if (!timeValidation.isValid) {
        return CoinRewardResult(
          success: false,
          coinsEarned: 0,
          errorType: CoinRewardError.timeValidationFailed,
          errorMessage: timeValidation.message ?? '시간 검증 실패',
        );
      }

      // 2️⃣ 일일 제한 체크
      final limitCheck = await checkDailyLimit(userId);
      if (!limitCheck.canWatch) {
        return CoinRewardResult(
          success: false,
          coinsEarned: 0,
          errorType: CoinRewardError.dailyLimitReached,
          errorMessage: '오늘의 광고 시청 횟수를 모두 사용했습니다',
          todayCount: limitCheck.todayCount,
        );
      }

      // 3️⃣ 서버 시간 기준 날짜
      final serverTime = await TimeValidationService.getServerTime();
      final todayString = TimeValidationService.formatDate(serverTime);

      // 4️⃣ Firestore Transaction으로 코인 지급
      final result = await _firestore.runTransaction<CoinRewardResult>((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('사용자 문서가 존재하지 않습니다');
        }

        final userData = userDoc.data()!;
        final lastAdDate = userData['lastAdDate'] ?? '';
        int currentDailyCount = 0;

        // 같은 날짜인지 확인
        if (lastAdDate == todayString) {
          currentDailyCount = (userData['dailyAdCount'] ?? 0).toInt();
        }

        // 다시 한번 일일 제한 체크 (동시성 문제 방지)
        if (currentDailyCount >= maxDailyAds) {
          return CoinRewardResult(
            success: false,
            coinsEarned: 0,
            errorType: CoinRewardError.dailyLimitReached,
            errorMessage: '오늘의 광고 시청 횟수를 모두 사용했습니다',
            todayCount: currentDailyCount,
          );
        }

        // ✅ 보너스 계산 (Transaction 내부에서 currentDailyCount 사용)
        int bonusCoins = 0;
        int bonusMultiplier = 1;

        // 5번째 시청: +2 보너스
        if (currentDailyCount + 1 == 5) {
          bonusCoins = bonus5thView;
          bonusMultiplier = 2; // UI 표시용
        }
        // 10번째 시청: +4 보너스
        else if (currentDailyCount + 1 == 10) {
          bonusCoins = bonus10thView;
          bonusMultiplier = 3; // UI 표시용
        }

        final coinsToGive = baseCoinsPerAd + bonusCoins;

        // 코인 지급 및 카운트 증가
        transaction.update(userRef, {
          'coins': FieldValue.increment(coinsToGive),
          'dailyAdCount': currentDailyCount + 1,
          'lastAdDate': todayString,
          'lastAdWatchedAt': FieldValue.serverTimestamp(),
          'totalAdsWatched': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 광고 시청 로그 기록
        final adLogRef = _firestore.collection('ad_watch_logs').doc();
        transaction.set(adLogRef, {
          'userId': userId,
          'deviceId': deviceId,
          'coinsEarned': coinsToGive,
          'bonusMultiplier': bonusMultiplier,
          'consecutiveAds': consecutiveAds,
          'watchedAt': FieldValue.serverTimestamp(),
          'date': todayString,
        });

        return CoinRewardResult(
          success: true,
          coinsEarned: coinsToGive,
          bonusMultiplier: bonusMultiplier,
          newDailyCount: currentDailyCount + 1,
          remainingAds: maxDailyAds - (currentDailyCount + 1),
          todayCount: currentDailyCount + 1,
        );
      });

      return result;
    } catch (e) {
      print('⚠️ 코인 지급 실패: $e');
      return CoinRewardResult(
        success: false,
        coinsEarned: 0,
        errorType: CoinRewardError.transactionFailed,
        errorMessage: '코인 지급 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 현재 시청 횟수에 따른 보너스 코인을 계산합니다
  ///
  /// - 5번째: +2 코인 (총 3코인)
  /// - 10번째: +4 코인 (총 5코인)
  /// - 그 외: 0 (총 1코인)
  static int calculateBonusCoins(int viewCount) {
    if (viewCount == 6) {
      return bonus5thView;
    } else if (viewCount == 10) {
      return bonus10thView;
    }
    return 0;
  }

  /// 시청 횟수에 따른 보너스 메시지를 반환합니다
  static String getBonusDescription(int viewCount) {
    if (viewCount == 6) {
      return '🎉 6회 달성! +2 보너스!';
    } else if (viewCount == 10) {
      return '🔥 10회 달성! +4 보너스!';
    }
    return '';
  }

  /// 사용자의 현재 코인 잔액을 가져옵니다
  static Future<int> getCurrentCoins(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return (userDoc.data()!['coins'] ?? 0).toInt();
      }
      return 0;
    } catch (e) {
      print('⚠️ 코인 조회 실패: $e');
      return 0;
    }
  }

  /// 코인을 차감합니다 (추첨 응모 등에 사용)
  ///
  /// 이 메소드는 직접 호출하지 말고 lottery_participation_service에서 트랜잭션으로 처리하세요
  @Deprecated('Use transaction in lottery_participation_service instead')
  static Future<bool> deductCoins({
    required String userId,
    required int amount,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        return false;
      }

      final currentCoins = (userDoc.data()!['coins'] ?? 0).toInt();
      if (currentCoins < amount) {
        return false; // 잔액 부족
      }

      await userRef.update({
        'coins': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('⚠️ 코인 차감 실패: $e');
      return false;
    }
  }
}

/// 일일 광고 시청 제한 체크 결과
class DailyLimitResult {
  final bool canWatch;
  final int remainingAds;
  final int todayCount;
  final String? errorMessage;

  DailyLimitResult({
    required this.canWatch,
    required this.remainingAds,
    required this.todayCount,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

/// 코인 지급 결과
class CoinRewardResult {
  final bool success;
  final int coinsEarned;
  final int? bonusMultiplier;
  final int? newDailyCount;
  final int? remainingAds;
  final int? todayCount;
  final CoinRewardError? errorType;
  final String? errorMessage;

  CoinRewardResult({
    required this.success,
    required this.coinsEarned,
    this.bonusMultiplier,
    this.newDailyCount,
    this.remainingAds,
    this.todayCount,
    this.errorType,
    this.errorMessage,
  });

  bool get hasError => !success;
  bool get hasBonus => bonusMultiplier != null && bonusMultiplier! > 1;
}

/// 코인 지급 실패 유형
enum CoinRewardError {
  /// 시간 검증 실패
  timeValidationFailed,

  /// 일일 제한 도달
  dailyLimitReached,

  /// 트랜잭션 실패
  transactionFailed,

  /// 사용자를 찾을 수 없음
  userNotFound,

  /// 잔액 부족 (차감 시)
  insufficientBalance,
}