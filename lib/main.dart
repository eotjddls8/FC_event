// main.dart - 이것만 실행해보세요!
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();
  print('🔥 Firebase 초기화 완료');

  // AdMob 초기화
  MobileAds.instance.initialize();
  print('🎯 AdMob 초기화 완료');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  BannerAd? myBanner;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();

    // 광고 생성 및 로드
    myBanner = BannerAd(
      // ⚠️ 중요: Android 테스트 배너 ID (하드코딩)
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          print('✅✅✅ 광고 로드 성공!!! ✅✅✅');
          setState(() {
            isLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('❌❌❌ 광고 실패: ${error.message}');
          print('Error code: ${error.code}');
          print('Error domain: ${error.domain}');
          ad.dispose();
        },
        onAdOpened: (Ad ad) => print('광고 열림'),
        onAdClosed: (Ad ad) => print('광고 닫힘'),
      ),
    );

    print('📢 광고 로드 시작...');
    myBanner!.load();
  }

  @override
  void dispose() {
    myBanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('초간단 광고 테스트'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // 광고 공간
          Container(
            alignment: Alignment.center,
            width: double.infinity,
            height: 100,
            color: Colors.yellow[100],
            child: isLoaded && myBanner != null
                ? Container(
              width: myBanner!.size.width.toDouble(),
              height: myBanner!.size.height.toDouble(),
              child: AdWidget(ad: myBanner!),
            )
                : Text(
              '광고 로딩 중...',
              style: TextStyle(fontSize: 20),
            ),
          ),

          // 상태 표시
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLoaded ? Icons.check_circle : Icons.error,
                    size: 100,
                    color: isLoaded ? Colors.green : Colors.red,
                  ),
                  SizedBox(height: 20),
                  Text(
                    isLoaded
                        ? '광고가 표시되고 있습니다!'
                        : '광고 로딩 실패',
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isLoaded = false;
                      });
                      myBanner?.dispose();

                      // 새 광고 생성
                      myBanner = BannerAd(
                        adUnitId: 'ca-app-pub-3940256099942544/6300978111',
                        size: AdSize.banner,
                        request: AdRequest(),
                        listener: BannerAdListener(
                          onAdLoaded: (Ad ad) {
                            print('✅ 재로드 성공!');
                            setState(() {
                              isLoaded = true;
                            });
                          },
                          onAdFailedToLoad: (Ad ad, LoadAdError error) {
                            print('❌ 재로드 실패: ${error.message}');
                            ad.dispose();
                          },
                        ),
                      );
                      myBanner!.load();
                    },
                    child: Text('광고 다시 로드'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}