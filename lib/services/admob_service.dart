// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'dart:io';
//
// class AdMobService {
//   // 배너 광고 ID
//   static String get bannerAdUnitId {
//     if (Platform.isAndroid) {
//       return 'ca-app-pub-5878607330599253/8771455548'; // 실제 Android ID
//     } else if (Platform.isIOS) {
//       return 'ca-app-pub-5878607330599253/2930318963'; // 실제 iOS ID
//     } else {
//       throw UnsupportedError('Unsupported platform');
//     }
//   }
//
//   // 보상형 동영상 광고 ID
//   static String get rewardedAdUnitId {
//     if (Platform.isAndroid) {
//       return 'ca-app-pub-3940256099942544/5224354917'; // 테스트 ID로 임시 변경
//       // return 'ca-app-pub-5878607330599253/3892896903'; // 실제 Android ID
//     } else if (Platform.isIOS) {
//       return 'ca-app-pub-5878607330599253/1617237298'; // 실제 iOS ID
//     } else {
//       throw UnsupportedError('Unsupported platform');
//     }
//   }
//
//   // 네이티브 광고 ID
//   static String get nativeAdUnitId {
//     if (Platform.isAndroid) {
//       return 'ca-app-pub-5878607330599253/1112457379'; // 실제 Android ID
//     } else if (Platform.isIOS) {
//       return 'ca-app-pub-5878607330599253/7991073955'; // 실제 iOS ID
//     } else {
//       throw UnsupportedError('Unsupported platform');
//     }
//   }
//
//   // AdMob 초기화
//   static Future<void> initialize() async {
//     await MobileAds.instance.initialize();
//   }
//
//   // 관리자는 광고 제외
//   static bool shouldShowAds(String? userRole) {
//     return userRole != 'admin';
//   }
// }


import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdMobService {
  // 배너 광고 ID (테스트 ID 사용)
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // 테스트 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // 테스트 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 보상형 동영상 광고 ID (테스트 ID 사용)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // 테스트 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // 테스트 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // 네이티브 광고 ID (테스트 ID 사용)
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110'; // 테스트 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511'; // 테스트 ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // AdMob 초기화
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    print('🎯 AdMob 초기화 완료 (테스트 모드)');
  }

  // 관리자는 광고 제외
  static bool shouldShowAds(String? userRole) {
    return userRole != 'admin';
  }
}