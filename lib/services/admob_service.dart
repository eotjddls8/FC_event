import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdMobService {
  // 배너 광고 ID
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // 테스트 ID (안드로이드용 실제 ID로 나중에 교체)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5878607330599253/5755307752'; // 🎯 실제 iOS 배너 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 전면 광고 ID
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // 테스트 ID (안드로이드용 실제 ID로 나중에 교체)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5878607330599253/4350742659'; // 🎯 실제 iOS 전면 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 보상형 동영상 광고 ID (이벤트 추첨권용)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // 테스트 ID (안드로이드용 실제 ID로 나중에 교체)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5878607330599253/1724579310'; // 🎯 실제 iOS 보상형 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 네이티브 광고 ID
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110'; // 테스트 ID (안드로이드용 실제 ID로 나중에 교체)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511'; // 테스트 ID (iOS 네이티브는 제공받지 않아서 테스트 ID 유지)
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // AdMob 초기화
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    print('🎯 AdMob 초기화 완료 (iOS 실제 광고 ID 적용)');
  }

  // 관리자는 광고 제외
  static bool shouldShowAds(String? userRole) {
    return userRole != 'admin';
  }

  // 🎁 이벤트용 보상형 광고 로드 및 표시
  static Future<bool> showRewardedAdForEvent({
    required Function() onRewardEarned,
    required Function() onAdFailedToShow,
  }) async {
    try {
      RewardedAd? rewardedAd;

      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('🎯 보상형 광고 로드 완료');
            rewardedAd = ad;

            // 광고 콜백 설정
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (RewardedAd ad) =>
                  print('🎬 보상형 광고 표시 시작'),
              onAdDismissedFullScreenContent: (RewardedAd ad) {
                print('🎬 보상형 광고 종료');
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
                print('❌ 보상형 광고 표시 실패: $error');
                ad.dispose();
                onAdFailedToShow();
              },
            );

            // 광고 표시
            ad.show(
              onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
                print('🎁 보상 획득! ${reward.type}: ${reward.amount}');
                onRewardEarned();
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('❌ 보상형 광고 로드 실패: $error');
            onAdFailedToShow();
          },
        ),
      );

      return true;
    } catch (e) {
      print('❌ 보상형 광고 오류: $e');
      onAdFailedToShow();
      return false;
    }
  }

  // 📊 광고 시청 제한 체크 (하루 최대 5회)
  static bool canWatchMoreAds(int todayWatchCount) {
    const maxAdsPerDay = 5;
    return todayWatchCount < maxAdsPerDay;
  }
}