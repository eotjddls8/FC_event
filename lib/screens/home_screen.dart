import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_helper.dart';
import 'interstitial_example.dart';
import 'rewarded_example.dart';
import '../models/user_model.dart'; // 이 줄 추가


class HomeScreen extends StatefulWidget {
  final UserModel? currentUser; // 이 줄 추가


  const HomeScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
          });
          print('✅ 배너 광고 로드 성공');
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ 배너 광고 로드 실패: ${error.message}');
          _isBannerAdReady = false;
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Firebase + AdMob Demo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 배너 광고 영역
            if (_isBannerAdReady)
              Container(
                alignment: Alignment.center,
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),

            // 메인 콘텐츠
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      size: 80,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'AdMob 광고 테스트',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '다양한 광고 형식을 테스트해보세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 전면 광고 버튼
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InterstitialExample(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('전면 광고 테스트'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 보상형 광고 버튼
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RewardedExample(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('보상형 광고 테스트'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 배너 광고 재로드 버튼
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isBannerAdReady = false;
                        });
                        _bannerAd?.dispose();
                        _loadBannerAd();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('배너 광고 새로고침'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}