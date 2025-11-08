import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/user_model.dart';
import '../services/rewarded_ad_service.dart';
import '../services/auth_service.dart';
import '../theme/fifa_theme.dart';
import 'login_screen.dart';
import '../services/prize_service.dart';
import '../models/prize_model.dart';
import 'prize_list_screen.dart';
import 'admin_prize_management_screen.dart';
import '../services/admob_service.dart';

class AdRewardScreen extends StatefulWidget {
  final UserModel? currentUser;

  const AdRewardScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _AdRewardScreenState createState() => _AdRewardScreenState();
}

class _AdRewardScreenState extends State<AdRewardScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Firebase에서 가져올 실제 데이터
  int _userCoins = 0;
  int _todayAdsWatched = 0;
  int _maxDailyAds = 5;
  bool _isLoading = true;
  bool _isProcessing = false; // 코인 지급 처리 중
  String _userId = '';

  // 광고 시스템
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    _initializeAds();
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
      _isAdLoaded = false;

      await RewardedAd.load(
        adUnitId: AdMobService.rewardedAdUnitId, // 테스트 광고 ID
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
          // ========== num → int 변환 ==========
          _userCoins = (userData['coins'] ?? 0).toInt();

          final lastAdDate = userData['lastAdDate'] ?? '';
          if (lastAdDate == serverDateString) {
            _todayAdsWatched = (userData['dailyAdCount'] ?? 0).toInt();
          } else {
            _todayAdsWatched = 0;
          }

          _isLoading = false;
        });
      } else {
        await _createUserDocument();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 서버 시간 검증 시스템
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

      final serverTime = timestamp.toDate();
      return serverTime;
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

      final serverDateString = _formatDate(serverTime);
      final clientDateString = _formatDate(clientTime);

      if (serverDateString != clientDateString) {
        _showSecurityError(
            '날짜 불일치 감지',
            '서버 날짜와 기기 날짜가 다릅니다.\n기기 시간을 자동으로 설정해주세요.'
        );
        return false;
      }

      final timeDifference = serverTime.difference(clientTime).abs();
      if (timeDifference.inMinutes > 5) {
        _showSecurityError(
            '시간 차이 감지',
            '서버와 기기 시간 차이가 ${timeDifference.inMinutes}분입니다.\n기기 시간을 동기화해주세요.'
        );
        return false;
      }

      return true;

    } catch (e) {
      _showSecurityError('시간 검증 실패', '시간 검증 중 오류가 발생했습니다.');
      return false;
    }
  }

  void _showSecurityError(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(Icons.security, color: Colors.red[700], size: 40),
          title: Text(
            '🚨 $title',
            style: TextStyle(color: Colors.red[700]),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '보안을 위해 코인 지급이 중단됩니다.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인', style: TextStyle(color: Colors.red[700])),
            ),
          ],
        );
      },
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

  Future<void> _refreshUserData() async {
    if (widget.currentUser != null) {
      await _loadUserDataFromFirebase();
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _authService.signOut();
  }

  // 완전한 코인 지급 시스템
  Future<void> _earnCoins() async {
    if (_isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미 처리 중입니다. 잠시만 기다려주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_todayAdsWatched >= _maxDailyAds) {
      _showDailyLimitDialog();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('광고가 준비되지 않았습니다. 잠시 후 다시 시도해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );

        await _loadRewardedAd();

        setState(() {
          _isProcessing = false;
        });
        return;
      }

      await _showRewardedAdAndGiveCoins();

    } catch (e) {
      print('코인 획득 과정 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('광고 표시 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
          print('🎉 보상 획득! ${reward.amount} ${reward.type}');
          await _giveCoinsToUser();
        },
      );
    } catch (e) {
      print('광고 표시 중 오류: $e');
    }
  }

  Future<void> _giveCoinsToUser() async {
    try {
      final serverTime = await _getServerTime();
      final todayString = _formatDate(serverTime);

      final isTimeValid = await _validateTime();
      if (!isTimeValid) {
        return;
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(_userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('사용자 문서가 존재하지 않습니다');
        }

        final userData = userDoc.data()!;
        final currentCoins = (userData['coins'] ?? 0).toInt(); // ========== num → int 변환 ==========
        final lastAdDate = userData['lastAdDate'] ?? '';
        final currentDailyCount = (lastAdDate == todayString)
            ? (userData['dailyAdCount'] ?? 0).toInt() // ========== num → int 변환 ==========
            : 0;

        if (currentDailyCount >= _maxDailyAds) {
          throw Exception('일일 광고 시청 한도 초과');
        }

        transaction.update(userRef, {
          'coins': currentCoins + 1,
          'dailyAdCount': currentDailyCount + 1,
          'lastAdDate': todayString,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(_firestore.collection('ad_views').doc(), {
          'userId': _userId,
          'userName': widget.currentUser?.name ?? 'Unknown',
          'adType': 'rewarded',
          'coinsEarned': 1,
          'viewedAt': FieldValue.serverTimestamp(),
          'serverDate': todayString,
        });

        print('💰 코인 지급 완료: ${currentCoins} + 1 = ${currentCoins + 1}');
      });

      setState(() {
        _userCoins += 1;
        _todayAdsWatched += 1;
      });

      _showCoinEarnedDialog();

    } catch (e) {
      print('코인 지급 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('코인 지급 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCoinEarnedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text('🎉 코인 획득!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.green[600], size: 50),
                  SizedBox(height: 16),
                  Text(
                    '+1 코인 획득!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '현재 보유: $_userCoins 코인',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '오늘 시청: $_todayAdsWatched/$_maxDailyAds',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showDailyLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📺 일일 한도 달성'),
        content: Text('오늘 광고 시청 한도($_maxDailyAds회)에 도달했습니다.\n내일 다시 도전해보세요!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  // ========== 5단계: 실제 추첨 응모 시스템 ==========
  Future<void> _participateInLottery(String prizeId, Map<String, dynamic> prizeData) async {
    final int requiredCoins = (prizeData['requiredCoins'] ?? 1).toInt(); // ========== num → int 변환 ==========
    final String prizeName = prizeData['name'] ?? '상품';

    if (_userCoins < requiredCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('코인이 부족합니다. $requiredCoins개가 필요합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🎯 추첨 응모'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$prizeName에 응모하시겠습니까?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '코인 $requiredCoins개가 차감됩니다',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
            ),
            child: Text('응모하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 서버 시간 검증
      final isTimeValid = await _validateTime();
      if (!isTimeValid) return;

      final serverTime = await _getServerTime();

      // Firebase Transaction으로 안전한 코인 차감 + 응모 등록
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(_userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('사용자 문서가 존재하지 않습니다');
        }

        final userData = userDoc.data()!;
        final int currentCoins = (userData['coins'] ?? 0).toInt(); // ========== num → int 변환 ==========

        if (currentCoins < requiredCoins) {
          throw Exception('코인이 부족합니다');
        }

        // 코인 차감
        transaction.update(userRef, {
          'coins': currentCoins - requiredCoins,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 추첨 응모 기록
        transaction.set(_firestore.collection('lottery_participants').doc(), {
          'userId': _userId,
          'userName': widget.currentUser?.name ?? 'Unknown',
          'prizeId': prizeId,
          'prizeName': prizeName,
          'coinsSpent': requiredCoins,
          'participatedAt': FieldValue.serverTimestamp(),
          'serverTime': Timestamp.fromDate(serverTime),
          'status': 'pending', // 대기중 (당첨 발표 전)
        });

        print('🎯 추첨 응모 완료: $prizeName ($requiredCoins 코인)');
      });

      // UI 업데이트 (이제 타입 오류 없음!)
      setState(() {
        _userCoins -= requiredCoins;
      });

      // 성공 메시지
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.how_to_vote, color: Colors.green[600], size: 30),
              SizedBox(width: 10),
              Text('🎉 응모 완료!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.celebration, color: Colors.green[600], size: 50),
                    SizedBox(height: 16),
                    Text(
                      '$prizeName',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '추첨 응모가 완료되었습니다!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '남은 코인: $_userCoins개',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: Text('확인'),
            ),
          ],
        ),
      );

    } catch (e) {
      print('추첨 응모 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('추첨 응모 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        title: Row(
          children: [
            Icon(Icons.casino, color: Colors.white),
            SizedBox(width: 8),
            Text('추첨 이벤트'),
          ],
        ),
        backgroundColor: Colors.blue[600],
        actions: [
          if (widget.currentUser != null) ...[
            IconButton(
              onPressed: _refreshUserData,
              icon: Icon(Icons.refresh, color: Colors.white),
              tooltip: '데이터 새로고침',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _logout(context);
                } else if (value == 'admin_prizes') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminPrizeManagementScreen(currentUser: widget.currentUser!),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(widget.currentUser!.isAdmin ? Icons.admin_panel_settings : Icons.person),
                      SizedBox(width: 8),
                      Text('${widget.currentUser!.name}'),
                    ],
                  ),
                ),
                if (widget.currentUser!.isAdmin) ...[
                  PopupMenuItem(
                    value: 'admin_prizes',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('상품 관리'),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('로그아웃'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Text(
                '로그인',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue[600]),
            SizedBox(height: 16),
            Text(
              'Firebase 데이터 로딩 중...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshUserData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 정보 카드
              if (widget.currentUser != null)
                _buildUserInfoCard(),

              SizedBox(height: 20),

              // 코인 받기 카드
              _buildCoinEarnCard(),

              SizedBox(height: 30),

              // ========== 5단계: 실제 추첨 상품 목록 ==========
              _buildRealLotteryItemsList(),

              // 로그인이 필요한 경우 표시
              if (widget.currentUser == null) ...[
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.lock, color: Colors.grey, size: 48),
                      SizedBox(height: 16),
                      Text(
                        '로그인이 필요합니다',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '추첨 이벤트에 참여하려면 먼저 로그인해주세요',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },
                        child: Text('로그인하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ========== 5단계 완료 상태 표시 ==========
              if (widget.currentUser != null) ...[
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.celebration, color: Colors.purple[600], size: 20),
                      SizedBox(width: 8),
                      Text(
                        '🎉 5단계: 추첨 이벤트 시스템 완전 완성! ✅',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    String userName = widget.currentUser?.name ?? '사용자';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue[100],
              child: Text(
                userName.isNotEmpty ? userName[0] : 'U',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.verified_user, color: Colors.blue[400], size: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.monetization_on, color: Colors.amber[600], size: 20),
                      const SizedBox(width: 5),
                      Text(
                        '$_userCoins 코인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '(실시간)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinEarnCard() {
    final canWatchAd = _todayAdsWatched < _maxDailyAds && _isAdLoaded && !_isProcessing;

    return Card(
      elevation: 4,
      color: canWatchAd ? Colors.green[50] : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isProcessing ? Icons.hourglass_empty : Icons.play_circle_filled,
                  color: canWatchAd ? Colors.green[600] : Colors.grey,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '광고 시청 완료 시 코인 1개가 지급됩니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: canWatchAd ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 시청: $_todayAdsWatched/$_maxDailyAds',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _isAdLoaded ? '광고 준비 완료' : '광고 로딩 중...',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isAdLoaded ? Colors.green[600] : Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: canWatchAd ? _earnCoins : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canWatchAd ? Colors.green[600] : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                      '코인 받기',
                      style: TextStyle(fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),

            if (_todayAdsWatched >= _maxDailyAds)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '오늘 광고 시청 횟수를 모두 사용했습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            if (!_isAdLoaded && _todayAdsWatched < _maxDailyAds)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '광고 로딩 중... 잠시만 기다려주세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========== 5단계: 실제 Firebase 상품 데이터 표시 ==========
  Widget _buildRealLotteryItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '추첨 상품',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '실시간 연동',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // ========== 실제 Firebase 데이터 스트림 ==========
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('prizes')
              .where('status', isEqualTo: 'active')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.blue[600]),
                    SizedBox(height: 16),
                    Text(
                      'Firebase에서 상품 목록을 불러오는 중...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.error, size: 50, color: Colors.red[400]),
                      SizedBox(height: 10),
                      Text(
                        '상품 목록 로드 실패',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '오류: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(
                          '현재 진행 중인 추첨 상품이 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.currentUser?.isAdmin == true)
                          Text(
                            '관리자 메뉴에서 상품을 추가해보세요!',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // ========== 실제 상품 목록 표시 ==========
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildRealPrizeCard(doc.id, data);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ========== 5단계: 실제 상품 카드 위젯 ==========
  Widget _buildRealPrizeCard(String prizeId, Map<String, dynamic> data) {
    final tier = data['tier'] ?? 'Bronze';
    final prizeName = data['name'] ?? '상품';
    final description = data['description'] ?? '';
    final int requiredCoins = (data['requiredCoins'] ?? 1).toInt(); // ========== num → int 변환 ==========
    final endDate = data['endDate']?.toDate() ?? DateTime.now().add(Duration(days: 30));
    final int maxParticipants = (data['maxParticipants'] ?? 100).toInt(); // ========== num → int 변환 ==========
    final int currentParticipants = (data['currentParticipants'] ?? 0).toInt(); // ========== num → int 변환 ==========

    final isExpired = endDate.isBefore(DateTime.now());
    final isFull = currentParticipants >= maxParticipants;
    final canParticipate = !isExpired && !isFull && _userCoins >= requiredCoins;

    Color tierColor;
    IconData tierIcon;

    switch (tier.toLowerCase()) {
      case 'diamond':
        tierColor = Colors.purple;
        tierIcon = Icons.diamond;
        break;
      case 'gold':
        tierColor = Colors.amber;
        tierIcon = Icons.star;
        break;
      case 'silver':
        tierColor = Colors.grey;
        tierIcon = Icons.star_half;
        break;
      default: // bronze
        tierColor = Colors.brown;
        tierIcon = Icons.star_border;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tierIcon, color: tierColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red[100]
                        : isFull
                        ? Colors.orange[100]
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired
                        ? '마감'
                        : isFull
                        ? '정원초과'
                        : '진행중',
                    style: TextStyle(
                      color: isExpired
                          ? Colors.red[700]
                          : isFull
                          ? Colors.orange[700]
                          : Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prizeName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // 추가 정보 표시
            Row(
              children: [
                Icon(Icons.people, color: Colors.grey[600], size: 16),
                SizedBox(width: 4),
                Text(
                  '응모자: $currentParticipants/$maxParticipants',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.schedule, color: Colors.grey[600], size: 16),
                SizedBox(width: 4),
                Text(
                  '마감: ${_formatDate(endDate)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.amber[600], size: 18),
                const SizedBox(width: 4),
                Text(
                  '필요 코인: $requiredCoins개',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // 상태 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: canParticipate
                        ? Colors.green[100]
                        : _userCoins < requiredCoins
                        ? Colors.red[100]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    canParticipate
                        ? '응모 가능'
                        : _userCoins < requiredCoins
                        ? '코인 부족'
                        : isExpired
                        ? '마감됨'
                        : '정원초과',
                    style: TextStyle(
                      fontSize: 10,
                      color: canParticipate
                          ? Colors.green[700]
                          : _userCoins < requiredCoins
                          ? Colors.red[700]
                          : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: canParticipate
                      ? () => _participateInLottery(prizeId, data)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tierColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('응모하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}