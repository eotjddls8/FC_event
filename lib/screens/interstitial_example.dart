import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_helper.dart';

class InterstitialExample extends StatefulWidget {
  const InterstitialExample({super.key});

  @override
  State<InterstitialExample> createState() => _InterstitialExampleState();
}

class _InterstitialExampleState extends State<InterstitialExample> {
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _createInterstitialAd();
  }

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('✅ 전면 광고 로드 성공');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
          _interstitialAd!.setImmersiveMode(true);
          setState(() {});
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ 전면 광고 로드 실패: ${error.message}');
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            _createInterstitialAd();
          }
          setState(() {});
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      print('⚠️ 전면 광고가 아직 준비되지 않았습니다');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('광고가 아직 준비되지 않았습니다. 잠시 후 다시 시도해주세요.'),
        ),
      );
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('전면 광고가 표시되었습니다');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('전면 광고가 닫혔습니다');
        ad.dispose();
        _createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('전면 광고 표시 실패: ${error.message}');
        ad.dispose();
        _createInterstitialAd();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전면 광고 테스트'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fullscreen,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                '전면 광고',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '화면 전체를 덮는 광고입니다.\n자연스러운 전환 시점에 표시하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // 광고 상태 표시
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _interstitialAd != null
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _interstitialAd != null
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                child: Text(
                  _interstitialAd != null
                      ? '✅ 광고 준비 완료'
                      : '⏳ 광고 로딩 중...',
                  style: TextStyle(
                    color: _interstitialAd != null
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _showInterstitialAd,
                icon: const Icon(Icons.play_arrow),
                label: const Text('전면 광고 보기'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () {
                  _interstitialAd?.dispose();
                  _createInterstitialAd();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('광고 다시 로드'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}