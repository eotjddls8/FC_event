import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';  // 새로 추가
import '../models/user_model.dart';
import '../services/rewarded_ad_service.dart';
import '../services/auth_service.dart';
import '../theme/fifa_theme.dart';
import 'login_screen.dart';
import '../services/prize_service.dart';  // 새로 추가
import '../models/prize_model.dart';      // 새로 추가
import 'prize_list_screen.dart';  // ← 이 줄 추가
import 'admin_prize_management_screen.dart';  // ← 이 줄 추가



class AdRewardScreen extends StatefulWidget {
  final UserModel? currentUser;

  const AdRewardScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _AdRewardScreenState createState() => _AdRewardScreenState();
}

class _AdRewardScreenState extends State<AdRewardScreen> {
  final AuthService _authService = AuthService();
  int _userPoints = 150;
  int _todayAdsWatched = 3;
  int _weeklyAdsWatched = 15;
  int _maxDailyAds = 5;

  @override
  void initState() {
    super.initState();
    RewardedAdService.initialize();
  }

  Future<void> _logout(BuildContext context) async {
    await _authService.signOut();
  }

  Future<void> _showRewardedAd() async {
    if (widget.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    if (_todayAdsWatched >= _maxDailyAds) {
      _showDailyLimitDialog();
      return;
    }

    if (!RewardedAdService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('광고를 준비 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool rewardEarned = await RewardedAdService.showRewardedAd();

    if (rewardEarned) {
      // 광고 시청 이력 추가 (수정된 부분)
      await PrizeService.addAdViewHistory(
        userId: FirebaseAuth.instance.currentUser!.uid,  // uid 수정
        adType: 'reward',
        pointsEarned: 10,
      );

      setState(() {
        _userPoints += 10;
        _todayAdsWatched++;
        _weeklyAdsWatched++;
      });
      _showRewardDialog();
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('로그인 필요'),
        content: Text('광고 보상을 받으려면 로그인이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
            child: Text('로그인'),
          ),
        ],
      ),
    );
  }

  void _showDailyLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('일일 한도 초과'),
        content: Text('오늘의 광고 시청 한도($_maxDailyAds회)에 도달했습니다.\n내일 다시 시도해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showRewardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.yellow, size: 24),
            SizedBox(width: 8),
            Text('보상 획득!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, color: Colors.orange, size: 48),
            SizedBox(height: 16),
            Text(
              '+10 포인트 획득!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text('현재 보유 포인트: $_userPoints P'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.card_giftcard, color: FifaColors.accent),
            SizedBox(width: 8),
            Text('광고 보상'),
          ],
        ),
        backgroundColor: Colors.orange,
        actions: [
          if (widget.currentUser != null) ...[
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
                // 관리자 전용 메뉴 추가
                if (widget.currentUser!.isAdmin) ...[
                  PopupMenuItem(
                    value: 'admin_prizes',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.orange),
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.currentUser != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.currentUser!.name}님',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '보유 포인트',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_userPoints P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'FIFA 회원',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],

            // 일반 광고 시청 카드
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.orange, size: 48),
                  SizedBox(height: 16),
                  Text(
                    '광고 보고 포인트 받기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: FifaColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '광고를 끝까지 시청하면 10 포인트를 드려요!',
                    style: TextStyle(
                      color: FifaColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _todayAdsWatched >= _maxDailyAds ? null : _showRewardedAd,
                      icon: Icon(Icons.play_arrow),
                      label: Text(
                        _todayAdsWatched >= _maxDailyAds ? '오늘 한도 완료' : '광고 시청하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _todayAdsWatched >= _maxDailyAds ? Colors.grey : Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 상품 추첨 카드 (새로 추가)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [FifaColors.primary, FifaColors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: FifaColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.yellow, size: 32),
                      SizedBox(width: 8),
                      Text(
                        '🎁 상품 추첨',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '광고를 시청하고 다양한 상품에 응모하세요!\n🥉 Bronze부터 💎 Diamond까지 다양한 상품이 기다려요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrizeListScreen(currentUser: widget.currentUser),
                          ),
                        );
                      },
                      icon: Icon(Icons.card_giftcard, color: FifaColors.primary),
                      label: Text(
                        '상품 보러가기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: FifaColors.primary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                      '광고 보상을 받으려면 먼저 로그인해주세요',
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
                        backgroundColor: FifaColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 상품 티어 안내 (새로 추가)
            if (widget.currentUser != null) ...[
              SizedBox(height: 24),
              Text(
                '🎯 상품 티어 안내',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FifaColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              ...PrizeTier.values.map((tier) {
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(tier.emoji, style: TextStyle(fontSize: 20)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '광고 ${tier.requiredAdViews}회 시청 • ${tier.valueDisplay}',
                              style: TextStyle(
                                color: FifaColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}