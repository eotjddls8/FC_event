import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../models/user_model.dart';

class BannerAdWidget extends StatefulWidget {
  final UserModel? currentUser;

  BannerAdWidget({this.currentUser});

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // 관리자는 광고 안 보여줌
    if (!AdMobService.shouldShowAds(widget.currentUser?.role)) {
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
          });
          print('배너 광고 로드 성공! 🎯');
        },
        onAdFailedToLoad: (ad, error) {
          print('배너 광고 로드 실패: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 관리자거나 광고가 준비되지 않으면 빈 위젯
    if (!AdMobService.shouldShowAds(widget.currentUser?.role) ||
        !_isBannerAdReady) {
      return SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}