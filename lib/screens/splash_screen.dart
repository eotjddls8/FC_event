import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_frequency_service.dart'; // 🎯 광고 빈도 서비스 추가
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // 광고 관련
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  bool _shouldShowAd = false; // 🎯 오늘 광고를 봐야 하는지
  bool _isMinimumTimeElapsed = false;
  String _loadingStatus = '앱을 준비하는 중...';

  @override
  void initState() {
    super.initState();

    // 상태바 숨기기 (풀스크린)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // 애니메이션 초기화
    _initializeAnimations();

    // 동시에 시작: 애니메이션 + 광고 체크 + 최소 대기시간
    _animationController.forward();
    _checkAndLoadAd(); // 🎯 광고 필요성 체크 후 로딩
    _startMinimumTimer();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.7, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.4, 1.0, curve: Curves.easeOutBack),
    ));
  }

  // 🎯 광고 필요성 체크 후 로딩
  Future<void> _checkAndLoadAd() async {
    setState(() {
      _loadingStatus = '설정을 확인하는 중...';
    });

    // 오늘 광고를 봐야 하는지 체크
    _shouldShowAd = await AdFrequencyService.shouldShowInterstitialAd();

    if (_shouldShowAd) {
      print('오늘 첫 실행 - 광고 로딩 시작');
      _loadInterstitialAd();
    } else {
      print('오늘 이미 광고 봤음 - 광고 스킵');
      setState(() {
        _loadingStatus = '준비 완료!';
        _isInterstitialAdLoaded = false; // 광고 로딩 안함
      });
      _checkReadyToNavigate();
    }
  }
  // 🎯 광고 프리로딩 (필요한 경우에만)
  void _loadInterstitialAd() {
    setState(() {
      _loadingStatus = '광고를 준비하는 중...';
    });

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // 테스트 광고 ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('전면 광고 로딩 완료');
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;

          setState(() {
            _loadingStatus = '광고 준비 완료!';
          });

          // 광고 이벤트 설정
          _interstitialAd!.setImmersiveMode(true);
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (InterstitialAd ad) {
              print('전면 광고 표시됨');
              // 🎯 광고 시청 기록
              AdFrequencyService.recordInterstitialAdShown();
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              print('전면 광고 닫힘 - 메인 화면으로 이동');
              ad.dispose();
              _navigateToMainApp();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              print('전면 광고 표시 실패: $error');
              ad.dispose();
              _navigateToMainApp();
            },
          );

          // 모든 준비가 끝나면 화면 전환 체크
          _checkReadyToNavigate();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('전면 광고 로딩 실패: $error');
          _isInterstitialAdLoaded = false;

          setState(() {
            _loadingStatus = '준비 완료!';
          });

          // 광고 실패해도 계속 진행
          _checkReadyToNavigate();
        },
      ),
    );
  }

  // ⏱️ 최소 대기 시간 (사용자 경험을 위해)
  void _startMinimumTimer() {
    Future.delayed(Duration(milliseconds: 2000), () {
      _isMinimumTimeElapsed = true;
      _checkReadyToNavigate();
    });
  }

  // ✅ 모든 준비가 완료되었는지 체크
  void _checkReadyToNavigate() {
    if (_isMinimumTimeElapsed) {
      // 최소 시간이 지났으면 진행
      if (_shouldShowAd && _isInterstitialAdLoaded) {
        // 오늘 첫 실행이고 광고가 준비되었으면 광고 표시
        _showInterstitialAd();
      } else {
        // 광고를 보지 않거나 광고가 없으면 바로 메인으로
        Future.delayed(Duration(milliseconds: 500), () {
          _navigateToMainApp();
        });
      }
    }
  }

  // 📱 전면 광고 표시
  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      print('전면 광고 표시 시작');
      _interstitialAd!.show();
    } else {
      _navigateToMainApp();
    }
  }

  // 🏠 메인 앱으로 이동
  void _navigateToMainApp() {
    // 상태바 복원
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => AuthWrapper(),
          transitionDuration: Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _interstitialAd?.dispose(); // 광고 리소스 해제
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF1976D2),
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 메인 콘텐츠
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 섹션
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: Offset(0, 15),
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_soccer,
                                    size: 70,
                                    color: Color(0xFF1976D2),
                                  ),
                                  // 반짝이는 효과
                                  Positioned(
                                    top: 25,
                                    right: 25,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 40),

                  // 앱 타이틀 섹션
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [Colors.white, Colors.white70],
                            ).createShader(bounds),
                            child: Text(
                              'FIFA EVENTS',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 12),

                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '축구 이벤트의 모든 것',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 60),

                  // 로딩 섹션 (상태에 따라 변경)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // 광고 상태에 따른 다른 인디케이터
                        Container(
                          width: 50,
                          height: 50,
                          child: !_shouldShowAd
                              ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 50,
                                color: Colors.green,
                              ),
                              Icon(
                                Icons.check,
                                size: 30,
                                color: Colors.white,
                              ),
                            ],
                          )
                              : _isInterstitialAdLoaded
                              ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: 50,
                                color: Colors.orange,
                              ),
                              Icon(
                                Icons.play_arrow,
                                size: 30,
                                color: Colors.white,
                              ),
                            ],
                          )
                              : CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                        ),

                        SizedBox(height: 20),

                        // 동적 로딩 텍스트
                        Text(
                          _loadingStatus,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),

                        // 광고 상태별 추가 메시지
                        if (!_shouldShowAd)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '오늘은 광고 없이 바로 시작!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (_shouldShowAd && _isInterstitialAdLoaded)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '광고 후 앱이 시작됩니다',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 하단 정보
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '© 2024 FIFA Events Team',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        letterSpacing: 0.5,
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