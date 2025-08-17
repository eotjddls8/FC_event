import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ⚠️ 배포 전 교체 필수:
/// 테스트 단위 ID → 실제 배너 광고 단위 ID
String get _testBannerUnitId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/9214589741' // Android 테스트 배너(앵커/적응형 포함)
    : 'ca-app-pub-3940256099942544/2934735716'; // iOS 테스트 배너

class SimpleAdTestScreen extends StatefulWidget {
  const SimpleAdTestScreen({super.key});

  @override
  State<SimpleAdTestScreen> createState() => _SimpleAdTestScreenState();
}

class _SimpleAdTestScreenState extends State<SimpleAdTestScreen> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize; // Anchored Adaptive 크기 캐싱

  @override
  void initState() {
    super.initState();
    _prepareAndLoad(); // 처음 진입 시 1회 로드
  }

  Future<void> _prepareAndLoad() async {
    setState(() {
      _isLoaded = false;
      _bannerAd?.dispose();
      _bannerAd = null;
      _adSize = null;
    });

    // 1) 화면 너비 기반 Anchored Adaptive 사이즈 얻기
    // MediaQuery는 build context가 필요하므로, post-frame 콜백에서 안전하게 호출
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final widthDp = MediaQuery.sizeOf(context).width.truncate();
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(widthDp);

      if (!mounted) return;
      if (size == null) {
        debugPrint('[Ad] Anchored size = null (너비 계산 실패).');
        return;
      }
      setState(() => _adSize = size);

      // 2) 배너 로드
      final ad = BannerAd(
        adUnitId: _testBannerUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('[Ad] Loaded: $ad');
            if (!mounted) return;
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint('[Ad] Failed: $err');
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          },
          onAdOpened: (ad) => debugPrint('[Ad] Opened overlay'),
          onAdClosed: (ad) => debugPrint('[Ad] Closed overlay'),
          onAdImpression: (ad) => debugPrint('[Ad] Impression'),
          onAdClicked: (ad) => debugPrint('[Ad] Clicked'),
          onAdWillDismissScreen: (ad) => debugPrint('[Ad] Will dismiss (iOS)'),
        ),
      );

      ad.load();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;

    return Scaffold(
      appBar: AppBar(
        title: const Text('앵커 적응형 배너 테스트'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            onPressed: _prepareAndLoad, // 수동 새로 요청 (UI 테스트용)
            icon: const Icon(Icons.refresh),
            tooltip: '광고 다시 로드',
          ),
        ],
      ),
      body: Column(
        children: [
          // 본문 (임의 콘텐츠)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLoaded ? Icons.check_circle : Icons.hourglass_empty,
                    size: 80,
                    color: _isLoaded ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLoaded ? '✅ 광고 로드 완료' : '⏳ 광고 로딩 중...',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '앵커 적응형(Anchored Adaptive) 배너는\n'
                        '현재 화면 방향과 너비에 맞춰 자동으로 사이즈를 선택합니다.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // 하단 앵커 배너
          SafeArea(
            top: false,
            child: (_isLoaded && ad != null && _adSize != null)
                ? Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: _adSize!.width.toDouble(),
                height: _adSize!.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            )
                : Container(
              height: 50,
              alignment: Alignment.center,
              color: Colors.grey[200],
              child: const Text('광고 로딩 중...'),
            ),
          ),
        ],
      ),
    );
  }
}
