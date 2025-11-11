import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'dart:math';
import '../models/user_model.dart';
import '../services/rewarded_ad_service.dart';
import '../services/auth_service.dart';
import '../theme/fifa_theme.dart';
import 'login_screen.dart';
import '../services/prize_service.dart';
import '../models/prize_model.dart';
import 'admin_prize_management_screen.dart';
import '../services/admob_service.dart';
import '../services/fraud_prevention_service.dart';
import '../utils/device_info_helper.dart';

class AdRewardScreen extends StatefulWidget {
  final UserModel? currentUser;

  const AdRewardScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _AdRewardScreenState createState() => _AdRewardScreenState();
}

class _AdRewardScreenState extends State<AdRewardScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🎯 개선된 애니메이션 컨트롤러들
  late AnimationController _coinAnimationController;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _coinScaleAnimation;
  late Animation<double> _coinOpacityAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  // 사용자 데이터
  int _userCoins = 0;
  int _todayAdsWatched = 0;
  int _maxDailyAds = 20; // 🎯 20회로 증가
  bool _isLoading = true;
  bool _isProcessing = false;
  String _userId = '';

  // 🎯 개선된 광고 시스템
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  int _consecutiveAds = 0; // 연속 시청 횟수 (보너스용)
  DateTime? _lastAdWatchTime;

  // 🎯 보너스 시스템
  bool _showBonusAnimation = false;
  int _bonusMultiplier = 1;
  String _bonusReason = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeUserData();
    _initializeAds();
  }

  void _initializeAnimations() {
    // 코인 획득 애니메이션
    _coinAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _coinScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _coinAnimationController,
      curve: Curves.elasticOut,
    ));

    _coinOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _coinAnimationController,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // 버튼 펄스 애니메이션
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 진행률 바 애니메이션
    _progressController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // 펄스 애니메이션 반복 시작
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeAds() async {
    try {
      await AdMobService.initialize();
      await _loadRewardedAd();
      print('✅ 광고 시스템 초기화 완료');
    } catch (e) {
      print('❌ 광고 시스템 초기화 실패: $e');
    }
  }

  Future<void> _loadRewardedAd() async {
    try {
      _rewardedAd?.dispose();
      _rewardedAd = null;
      setState(() {
        _isAdLoaded = false;
      });

      await RewardedAd.load(
        adUnitId: AdMobService.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('✅ 리워드 광고 로드 성공');
            setState(() {
              _rewardedAd = ad;
              _isAdLoaded = true;
            });
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('❌ 리워드 광고 로드 실패: $error');
            setState(() {
              _rewardedAd = null;
              _isAdLoaded = false;
            });
            // 3초 후 재시도
            Timer(Duration(seconds: 3), _loadRewardedAd);
          },
        ),
      );
    } catch (e) {
      print('❌ 광고 로드 중 오류: $e');
      setState(() {
        _isAdLoaded = false;
      });
    }
  }

  Future<void> _initializeUserData() async {
    final user = _auth.currentUser;
    if (user != null && widget.currentUser != null) {
      _userId = user.uid;
      await _loadUserDataFromFirebase();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserDataFromFirebase() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final serverTime = await _getServerTime();
      final userDoc = await _firestore.collection('users').doc(_userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final serverDateString = _formatDate(serverTime);

        setState(() {
          _userCoins = (userData['coins'] ?? 0).toInt();

          final lastAdDate = userData['lastAdDate'] ?? '';
          if (lastAdDate == serverDateString) {
            _todayAdsWatched = (userData['dailyAdCount'] ?? 0).toInt();
          } else {
            _todayAdsWatched = 0;
          }

          _isLoading = false;
        });

        // 진행률 애니메이션 시작
        _progressController.forward();
      } else {
        await _createUserDocument();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<DateTime> _getServerTime() async {
    try {
      final tempDocRef = _firestore.collection('temp').doc();
      await tempDocRef.set({
        'timestamp': FieldValue.serverTimestamp(),
        'purpose': 'time_validation',
      });

      final docSnapshot = await tempDocRef.get();
      final timestamp = docSnapshot.data()!['timestamp'] as Timestamp;
      await tempDocRef.delete();

      return timestamp.toDate();
    } catch (e) {
      print('서버 시간 획득 실패: $e');
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _validateTime() async {
    try {
      final serverTime = await _getServerTime();
      final clientTime = DateTime.now();
      final timeDifference = serverTime.difference(clientTime).abs();

      if (timeDifference.inMinutes > 5) {
        _showSecurityDialog(
          '시간 동기화 필요',
          '정확한 보상을 위해 기기 시간을 자동 설정으로 변경해주세요.',
          Icons.schedule,
          Colors.orange,
        );
        return false;
      }

      return true;
    } catch (e) {
      _showSecurityDialog(
        '시간 검증 실패',
        '네트워크 상태를 확인하고 다시 시도해주세요.',
        Icons.wifi_off,
        Colors.red,
      );
      return false;
    }
  }

  void _showSecurityDialog(String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _createUserDocument() async {
    try {
      final serverTime = await _getServerTime();
      final todayString = _formatDate(serverTime);

      await _firestore.collection('users').doc(_userId).set({
        'name': widget.currentUser?.name ?? 'Anonymous',
        'email': widget.currentUser?.email ?? '',
        'isAdmin': widget.currentUser?.isAdmin ?? false,
        'coins': 0,
        'dailyAdCount': 0,
        'lastAdDate': todayString,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // 🎯 추가 통계 필드들
        'totalCoinsEarned': 0,
        'totalAdsWatched': 0,
        'consecutiveDays': 1,
        'lastLoginDate': todayString,
      }, SetOptions(merge: true));

      setState(() {
        _userCoins = 0;
        _todayAdsWatched = 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error creating user document: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🎯 개선된 코인 획득 시스템 (보너스 포함)
  Future<void> _earnCoins() async {
    if (_isProcessing) {
      _showSnackBar('이미 처리 중입니다. 잠시만 기다려주세요.', Colors.orange);
      return;
    }

    if (_todayAdsWatched >= _maxDailyAds) {
      _showDailyLimitDialog();
      return;
    }

    // 쿨다운 체크 (30초)
    if (_lastAdWatchTime != null &&
        DateTime.now().difference(_lastAdWatchTime!).inSeconds < 30) {
      final remainingTime = 30 - DateTime.now().difference(_lastAdWatchTime!).inSeconds;
      _showSnackBar('$remainingTime초 후에 다시 시청할 수 있습니다.', Colors.blue);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final isTimeValid = await _validateTime();
      if (!isTimeValid) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      if (!_isAdLoaded || _rewardedAd == null) {
        _showSnackBar('광고가 준비 중입니다. 잠시 후 다시 시도해주세요.', Colors.orange);
        await _loadRewardedAd();
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      await _showRewardedAdAndGiveCoins();

    } catch (e) {
      print('코인 획득 과정 오류: $e');
      _showSnackBar('오류가 발생했습니다. 다시 시도해주세요.', Colors.red);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showRewardedAdAndGiveCoins() async {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('📺 광고 전체 화면 표시');
        HapticFeedback.lightImpact();
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('📱 광고 종료');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('❌ 광고 표시 실패: $error');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        _showSnackBar('광고 표시 중 오류가 발생했습니다.', Colors.red);
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
          print('🎉 보상 획득! ${reward.amount} ${reward.type}');
          HapticFeedback.heavyImpact();
          await _giveCoinsToUser();
        },
      );
    } catch (e) {
      print('광고 표시 중 오류: $e');
    }
  }

  // 🎯 개선된 코인 지급 시스템 (보너스 로직 포함)
  Future<void> _giveCoinsToUser() async {
    try {
      final serverTime = await _getServerTime();
      final todayString = _formatDate(serverTime);

      final isTimeValid = await _validateTime();
      if (!isTimeValid) return;

      // 🎯 보너스 계산 로직
      int baseCoins = 1;
      _bonusMultiplier = 1;
      _bonusReason = '';

      // 연속 시청 보너스 (5회마다 2배)
      if ((_todayAdsWatched + 1) % 5 == 0) {
        _bonusMultiplier = 2;
        _bonusReason = '연속 시청 보너스!';
      }

      // 랜덤 럭키 보너스 (5% 확률로 3배, 1% 확률로 5배)
      final random = Random();
      final luckyChance = random.nextDouble();
      if (luckyChance < 0.03) {
        _bonusMultiplier = 5;
        _bonusReason = '🍀 슈퍼 럭키 보너스!';
      } else if (luckyChance < 0.2) {
        _bonusMultiplier = 2;
        _bonusReason = '🍀 럭키 보너스!';
      }


      final finalCoins = baseCoins * _bonusMultiplier;
      _showBonusAnimation = _bonusMultiplier > 1;

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(_userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('사용자 문서가 존재하지 않습니다');
        }

        final userData = userDoc.data()!;
        final currentCoins = (userData['coins'] ?? 0).toInt();
        final totalCoinsEarned = (userData['totalCoinsEarned'] ?? 0).toInt();
        final totalAdsWatched = (userData['totalAdsWatched'] ?? 0).toInt();
        final lastAdDate = userData['lastAdDate'] ?? '';
        final currentDailyCount = (lastAdDate == todayString)
            ? (userData['dailyAdCount'] ?? 0).toInt()
            : 0;

        if (currentDailyCount >= _maxDailyAds) {
          throw Exception('일일 광고 시청 한도 초과');
        }

        // 사용자 데이터 업데이트
        transaction.update(userRef, {
          'coins': currentCoins + finalCoins,
          'totalCoinsEarned': totalCoinsEarned + finalCoins,
          'totalAdsWatched': totalAdsWatched + 1,
          'dailyAdCount': currentDailyCount + 1,
          'lastAdDate': todayString,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 🎯 상세한 시청 기록 저장
        transaction.set(_firestore.collection('ad_views').doc(), {
          'userId': _userId,
          'userName': widget.currentUser?.name ?? 'Unknown',
          'adType': 'rewarded',
          'baseCoins': baseCoins,
          'bonusMultiplier': _bonusMultiplier,
          'finalCoins': finalCoins,
          'bonusReason': _bonusReason,
          'viewedAt': FieldValue.serverTimestamp(),
          'serverDate': todayString,
          'deviceTime': Timestamp.fromDate(DateTime.now()),
          'dailyCount': currentDailyCount + 1,
        });

        print('💰 코인 지급 완료: +$finalCoins (${_bonusMultiplier}x 보너스)');
      });

      setState(() {
        _userCoins += finalCoins;
        _todayAdsWatched += 1;
        _lastAdWatchTime = DateTime.now();
      });

      await _showCoinEarnedAnimation(finalCoins);

    } catch (e) {
      print('코인 지급 실패: $e');
      _showSnackBar('코인 지급 중 오류가 발생했습니다.', Colors.red);
    }
  }

  // 🎯 향상된 코인 획득 애니메이션
  Future<void> _showCoinEarnedAnimation(int coinsEarned) async {
    // 애니메이션 시작
    await _coinAnimationController.forward();

    // 성공 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCoinEarnedDialog(coinsEarned),
    );

    // 3초 후 자동 닫기
    Timer(Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  Widget _buildCoinEarnedDialog(int coinsEarned) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade400,
              Colors.orange.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎯 애니메이션된 코인 아이콘
            AnimatedBuilder(
              animation: _coinAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _coinScaleAnimation.value,
                  child: Opacity(
                    opacity: _coinOpacityAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.monetization_on,
                        color: Colors.amber.shade700,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 20),

            Text(
              '🎉 코인 획득!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            Text(
              '+$coinsEarned 코인',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (_showBonusAnimation && _bonusReason.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _bonusReason,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            SizedBox(height: 16),

            Text(
              '현재 보유: $_userCoins 코인',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),

            SizedBox(height: 8),

            Text(
              '오늘 시청: $_todayAdsWatched/$_maxDailyAds',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDailyLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange.shade600, size: 28),
            SizedBox(width: 12),
            Text(
              '일일 한도 달성',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                color: Colors.orange.shade600,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                '오늘 광고 시청을 모두 완료했습니다!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '내일 다시 도전해서 더 많은 코인을 모아보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _refreshUserData() async {
    if (widget.currentUser != null) {
      await _loadUserDataFromFirebase();
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _coinAnimationController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: _buildModernAppBar(),
      body: _isLoading ? _buildLoadingWidget() : _buildMainContent(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade600,
              Colors.purple.shade500,
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.monetization_on, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),
          Text(
            '추첨 이벤트',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: _buildAppBarActions(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (widget.currentUser != null) ...[
        IconButton(
          onPressed: _refreshUserData,
          icon: Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: '새로고침',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.account_circle, color: Colors.white, size: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) async {
            if (value == 'logout') {
              await _authService.signOut();
            } else if (value == 'admin_prizes') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminPrizeManagementScreen(
                    currentUser: widget.currentUser!,
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.currentUser!.name.isNotEmpty
                            ? widget.currentUser!.name[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser!.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.currentUser!.isAdmin ? '관리자' : '일반 사용자',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.grey.shade700),
                  SizedBox(width: 12),
                  Text('프로필'),
                ],
              ),
            ),
            if (widget.currentUser!.isAdmin) ...[
              PopupMenuItem(
                value: 'admin_prizes',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('상품 관리'),
                  ],
                ),
              ),
            ],
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red.shade600),
                  SizedBox(width: 12),
                  Text('로그아웃'),
                ],
              ),
            ),
          ],
        ),
      ] else ...[
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          },
          icon: Icon(Icons.login, color: Colors.white),
          label: Text(
            '로그인',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 8),
      ],
    ];
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          SizedBox(height: 24),
          Text(
            '데이터를 불러오는 중...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _refreshUserData,
      color: Colors.blue.shade600,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          children: [

            // ⭐ 1. [추가] 비회원일 때 로그인 안내를 맨 위에 표시
            if (widget.currentUser == null) ...[
              _buildLoginPrompt(),
              SizedBox(height: 20),
            ],

            // 사용자 정보 카드
            if (widget.currentUser != null) _buildUserInfoCard(),

            if (widget.currentUser != null) SizedBox(height: 20),

            // 코인 받기 카드
            if (widget.currentUser != null) _buildCoinEarnCard(),

            SizedBox(height: 30),

            // 상품 목록
            _buildPrizesList(),


          ],
        ),
      ),
    );
  }

  // 다음 메시지에서 나머지 위젯들과 상품 목록을 계속 구현하겠습니다!

  Widget _buildUserInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.currentUser?.name ?? '사용자',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(width: 8),
                    if (widget.currentUser?.isAdmin == true)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: Colors.amber.shade600,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '$_userCoins',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '코인',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '오늘 $_todayAdsWatched/$_maxDailyAds',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinEarnCard() {
    final canWatchAd = _todayAdsWatched < _maxDailyAds &&
        _isAdLoaded &&
        !_isProcessing &&
        widget.currentUser != null;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: canWatchAd ? _pulseAnimation.value : 0,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: canWatchAd
                    ? [Colors.green.shade400, Colors.teal.shade500]
                    : [Colors.grey.shade300, Colors.grey.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: canWatchAd
                      ? Colors.green.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isProcessing ? Icons.hourglass_empty : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '광고 시청하고 코인 받기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '기본 1코인 + 보너스 확률!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // 진행률 바
                if (widget.currentUser != null) ...[
                  Row(
                    children: [
                      Text(
                        '오늘의 진행률',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '$_todayAdsWatched / $_maxDailyAds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      final progress = (_todayAdsWatched / _maxDailyAds).clamp(0.0, 0.0);
                      return Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progress * _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                ],

                // 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: canWatchAd ? _earnCoins : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: canWatchAd ? Colors.green.shade700 : Colors.grey.shade500,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: _isProcessing
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                      ),
                    )
                        : Icon(
                      canWatchAd ? Icons.play_arrow_rounded : Icons.block,
                      size: 24,
                    ),
                    label: Text(
                      _isProcessing
                          ? '처리 중...'
                          : !canWatchAd && widget.currentUser == null
                          ? '로그인 필요'
                          : !canWatchAd && _todayAdsWatched >= _maxDailyAds
                          ? '오늘 한도 달성'
                          : !_isAdLoaded
                          ? '광고 로딩 중...'
                          : '광고 시청하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                if (widget.currentUser != null) ...[
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBonusInfo(String title, String multiplier, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            multiplier,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '🏆 이벤트 상품',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '실시간 업데이트',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('prizes')
              .where('status', isEqualTo: 'active')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard('상품 목록을 불러오는 중...');
            }

            if (snapshot.hasError) {
              return _buildErrorCard('상품 목록을 불러올 수 없습니다.');
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyCard();
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildPrizeCard(doc.id, data);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              '현재 진행 중인 이벤트가 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '새로운 이벤트가 곧 시작됩니다!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            if (widget.currentUser?.isAdmin == true) ...[
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminPrizeManagementScreen(
                        currentUser: widget.currentUser!,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.add),
                label: Text('상품 추가하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeCard(String prizeId, Map<String, dynamic> data) {
    // 상품 정보 파싱
    final prizeName = data['title'] ?? '상품';
    final description = data['description'] ?? '';
    final tier = data['tier'] ?? 'Bronze';
    final int requiredCoins = (data['requiredCoins'] ?? 1).toInt();
    final endDate = data['endDate']?.toDate() ?? DateTime.now().add(Duration(days: 30));
    final int maxParticipants = (data['maxParticipants'] ?? 100).toInt();
    final int currentParticipants = (data['currentParticipants'] ?? 0).toInt();

    // 상태 계산
    final isExpired = endDate.isBefore(DateTime.now());
    final isFull = currentParticipants >= maxParticipants;
    final hasEnoughCoins = _userCoins >= requiredCoins;
    final canParticipate = !isExpired && !isFull && hasEnoughCoins && widget.currentUser != null;

    // 티어별 색상 및 아이콘
    Color tierColor;
    IconData tierIcon;
    Color gradientStart, gradientEnd;

    switch (tier.toLowerCase()) {
      case 'diamond':
        tierColor = Colors.purple.shade600;
        tierIcon = Icons.diamond;
        gradientStart = Colors.purple.shade400;
        gradientEnd = Colors.pink.shade400;
        break;
      case 'gold':
        tierColor = Colors.amber.shade600;
        tierIcon = Icons.star;
        gradientStart = Colors.amber.shade400;
        gradientEnd = Colors.orange.shade400;
        break;
      case 'silver':
        tierColor = Colors.grey.shade600;
        tierIcon = Icons.star_half;
        gradientStart = Colors.grey.shade400;
        gradientEnd = Colors.blueGrey.shade400;
        break;
      default: // bronze
        tierColor = Colors.brown.shade600;
        tierIcon = Icons.star_border;
        gradientStart = Colors.brown.shade400;
        gradientEnd = Colors.orange.shade300;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tierColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Column(
            children: [
              // 헤더 (그라데이션 배경)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [gradientStart, gradientEnd],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tierIcon, color: Colors.white, size: 24),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tier.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? Colors.red.shade600
                                      : isFull
                                      ? Colors.orange.shade600
                                      : Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isExpired
                                      ? '마감'
                                      : isFull
                                      ? '정원초과'
                                      : '진행중',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            prizeName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 내용
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

// 1. 총 응모 횟수 및 내 응모 횟수 표시
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        // ⭐ 배경색 적용 및 디자인 개선
                        color: Colors.blue.shade50, // 밝은 파란색 배경
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: PrizeEntryInfo(
                        prize: PrizeModel.fromFirestore(data, prizeId), // PrizeModel 객체 전달
                        userId: _userId,
                      ),
                    ),

                    SizedBox(height: 16),

                    // 통계 정보
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            Icons.schedule,
                            '마감일',
                            '${endDate.month}/${endDate.day}',
                            Colors.orange.shade600,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            Icons.monetization_on,
                            '필요 코인',
                            '$requiredCoins개',
                            Colors.amber.shade600,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // 응모 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: canParticipate
                            ? () => _participateInLottery(prizeId, data)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canParticipate ? tierColor : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          elevation: canParticipate ? 8 : 0,
                          shadowColor: tierColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: Icon(
                          canParticipate
                              ? Icons.how_to_vote_rounded
                              : widget.currentUser == null
                              ? Icons.login
                              : !hasEnoughCoins
                              ? Icons.monetization_on
                              : Icons.block,
                          size: 20,
                        ),
                        label: Text(
                          widget.currentUser == null
                              ? '로그인 필요'
                              : !hasEnoughCoins
                              ? '코인 부족 (${requiredCoins - _userCoins}개 더 필요)'
                              : isExpired
                              ? '마감됨'
                              : isFull
                              ? '정원초과'
                              : '응모하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    if (!canParticipate && widget.currentUser != null && !hasEnoughCoins) ...[
                      SizedBox(height: 8),
                      Text(
                        '💡 광고를 ${((requiredCoins - _userCoins) / 1).ceil()}번 더 시청하면 응모 가능합니다!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      margin: EdgeInsets.only(top: 32),
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.login, color: Colors.white, size: 32),
          ),
          SizedBox(height: 16),
          Text(
            '로그인하고 더 많은 혜택을!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '광고 시청으로 코인을 모으고\n다양한 상품에 응모해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              icon: Icon(Icons.login, size: 20),
              label: Text(
                '로그인하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: Colors.blue.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 응모하기 함수 (Subcollection 구조 적용)
  Future<void> _participateInLottery(String prizeId, Map<String, dynamic> prizeData) async {
    final int requiredCoins = (prizeData['requiredCoins'] ?? 1).toInt();
    final String prizeName = prizeData['name'] ?? '상품';

    if (_userCoins < requiredCoins) {
      _showSnackBar('코인이 부족합니다. $requiredCoins개가 필요합니다.', Colors.red);
      return;
    }

    // 🔒 부정 방지 체크
    try {
      final fraudService = FraudPreventionService();
      final deviceId = await DeviceInfoHelper.getDeviceId(); // Device ID를 미리 가져옴

      final fraudCheck = await fraudService.performFraudCheck(
        userId: _userId,
        deviceId: deviceId, // FraudPreventionService에서 prizes/{prizeId}/participants/{deviceId}로 사용됨
        eventId: prizeId,
      );

      if (!fraudCheck['allowed']) {
        _showSnackBar(fraudCheck['reason'], Colors.red);
        return;
      }
    } catch (e) {
      print('부정 방지 체크 실패: $e');
      // 부정 방지 체크 실패 시 응모를 허용하지 않는 것이 안전합니다.
      _showSnackBar('응모 전 보안 검증에 실패했습니다.', Colors.red);
      return;
    }

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.how_to_vote, color: Colors.blue.shade600, size: 28),
            SizedBox(width: 12),
            Text(
              '추첨 응모',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"$prizeName"',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '이 상품에 응모하시겠습니까?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber.shade600, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '$requiredCoins 코인이 차감됩니다',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('응모하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final isTimeValid = await _validateTime();
      if (!isTimeValid) return;

      // 트랜잭션 시작
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(_userId);
        final prizeRef = _firestore.collection('prizes').doc(prizeId); // ⭐ prize 문서 참조
        // userId를 참가자 문서 ID로 사용 (참가자 조회 시 유저 ID로 바로 접근 가능)
        final participantRef = prizeRef.collection('participants').doc();

        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('사용자 문서가 존재하지 않습니다');
        }

        final userData = userDoc.data()!;
        final int currentCoins = (userData['coins'] ?? 0).toInt();

        if (currentCoins < requiredCoins) {
          throw Exception('코인이 부족합니다');
        }

        final deviceId = await DeviceInfoHelper.getDeviceId();

        // 1. 코인 차감 (유저 문서 업데이트)
        transaction.update(userRef, {
          'coins': FieldValue.increment(-requiredCoins),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. 추첨 응모 기록 (Subcollection 방식 - prizes/{prizeId}/participants/{userId} 에 저장)
        transaction.set(participantRef, {
          'userId': _userId,
          'userName': widget.currentUser?.name ?? 'Unknown',
          'email': widget.currentUser?.email ?? '',
          'coinsSpent': requiredCoins,
          'deviceId': deviceId,
          'participatedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        // 3. 상품 참가자 수 증가 (prize 문서 업데이트)
        transaction.update(prizeRef, {
          'currentParticipants': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('🎯 추첨 응모 완료: $prizeName ($requiredCoins 코인) - Subcollection 방식');
      }); // 트랜잭션 종료

      setState(() {
        _userCoins -= requiredCoins;
      });

      // 성공 애니메이션 및 다이얼로그
      HapticFeedback.heavyImpact();
      _showSuccessDialog(prizeName, requiredCoins);

    } catch (e) {
      print('추첨 응모 실패: $e');
      _showSnackBar('응모 중 오류가 발생했습니다.', Colors.red);
    }
  }

  void _showSuccessDialog(String prizeName, int coinsSpent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade400, Colors.teal.shade500],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.celebration,
                  color: Colors.green.shade600,
                  size: 50,
                ),
              ),
              SizedBox(height: 20),
              Text(
                '🎉 응모 완료!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                prizeName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '사용 코인: $coinsSpent개',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '남은 코인: $_userCoins개',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 3초 후 자동 닫기
    Timer(Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }
}


// 응모 정보(총 응모, 내 응모)를 비동기로 표시하는 위젯
class PrizeEntryInfo extends StatelessWidget {
  final PrizeModel prize;
  final String userId;

  const PrizeEntryInfo({
    Key? key,
    required this.prize,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. 사용자 응모 횟수를 비동기로 가져옵니다.
    return FutureBuilder<int>(
      future: PrizeService.getUserEntryCount(prize.id, userId),
      builder: (context, snapshot) {
        // 데이터가 로딩 중이거나 오류가 나도 0으로 표시 (사용자 경험 개선)
        final myEntries = snapshot.data ?? 0;

        // 2. 총 응모 수와 내 응모 수를 표시합니다.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, size: 16, color: FifaColors.textSecondary),
                SizedBox(width: 4),
                // prize.currentParticipants는 PrizeService의 transaction에서 증가시킨 총 응모 횟수입니다.
                Text(
                  '총 응모: ${prize.currentParticipants}회',
                  style: TextStyle(
                    fontSize: 14,
                    color: FifaColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: myEntries > 0 ? Colors.amber : FifaColors.textSecondary),
                SizedBox(width: 4),
                // 내 응모 횟수 (응모했을 경우 텍스트를 강조)
                Text(
                  '내 응모: ${myEntries}회',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: myEntries > 0 ? FontWeight.bold : FontWeight.normal,
                    color: myEntries > 0 ? Colors.amber : FifaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}