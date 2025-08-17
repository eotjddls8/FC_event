import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_helper.dart';

class RewardedExample extends StatefulWidget {
  const RewardedExample({super.key});

  @override
  State<RewardedExample> createState() => _RewardedExampleState();
}

class _RewardedExampleState extends State<RewardedExample> {
  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _createRewardedAd();
  }

  void _createRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('✅ 보상형 광고 로드 성공');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
          setState(() {});
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ 보상형 광고 로드 실패: ${error.message}');
          _rewardedAd = null;
          _numRewardedLoadAttempts += 1;
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            _createRewardedAd();
          }
          setState(() {});
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) {
      print('⚠️ 보상형 광고가 아직 준비되지 않았습니다');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('광고가 아직 준비되지 않았습니다. 잠시 후 다시 시도해주세요.'),
        ),
      );
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('보상형 광고가 표시되었습니다');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('보상형 광고가 닫혔습니다');
        ad.dispose();
        _createRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('보상형 광고 표시 실패: ${error.message}');
        ad.dispose();
        _createRewardedAd();
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('🎁 보상 획득: ${reward.amount} ${reward.type}');
        setState(() {
          _coins += reward.amount.toInt();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${reward.amount} 코인을 획득했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
    _rewardedAd = null;
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보상형 광고 테스트'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 코인 표시
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amber,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      size: 60,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$_coins',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const Text(
                      '코인',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                '보상형 광고',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '광고를 끝까지 시청하면\n보상을 받을 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),

              // 광고 상태 표시
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _rewardedAd != null
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _rewardedAd != null
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                child: Text(
                  _rewardedAd != null
                      ? '✅ 광고 준비 완료'
                      : '⏳ 광고 로딩 중...',
                  style: TextStyle(
                    color: _rewardedAd != null
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _showRewardedAd,
                icon: const Icon(Icons.card_giftcard),
                label: const Text('광고 보고 코인 받기'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: Colors.amber,
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () {
                  _rewardedAd?.dispose();
                  _createRewardedAd();
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