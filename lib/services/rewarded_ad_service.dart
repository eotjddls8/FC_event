import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'admob_service.dart';

class RewardedAdService {
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;

  // 보상형 광고 로드
  static Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: AdMobService.rewardedAdUnitId,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          print('🎥 보상형 광고 로드 완료!');
        },
        onAdFailedToLoad: (error) {
          print('❌ 보상형 광고 로드 실패: $error');
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  // 보상형 광고 표시
  static Future<bool> showRewardedAd() async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      print('⚠️ 보상형 광고가 준비되지 않음');
      return false;
    }

    bool rewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        print('🎬 보상형 광고 표시됨');
      },
      onAdDismissedFullScreenContent: (ad) {
        print('🎬 보상형 광고 닫힘');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        // 다음 광고 미리 로드
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('❌ 보상형 광고 표시 실패: $error');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print('🎁 보상 획득: ${reward.amount} ${reward.type}');
        rewardEarned = true;
      },
    );

    return rewardEarned;
  }

  // 광고 준비 상태 확인
  static bool get isReady => _isRewardedAdReady;

  // 초기화
  static Future<void> initialize() async {
    await loadRewardedAd();
  }

  // 리소스 정리
  static void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
  }
}