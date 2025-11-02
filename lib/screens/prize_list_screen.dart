import 'package:flutter/material.dart';
import '../models/prize_model.dart';
import '../models/user_model.dart';
import '../services/prize_service.dart';
import '../services/rewarded_ad_service.dart';
import '../theme/fifa_theme.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';  // ← 이 줄 추가
import 'admin_prize_management_screen.dart';  // ← 이 줄 추가



class PrizeListScreen extends StatefulWidget {
  final UserModel? currentUser;

  const PrizeListScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _PrizeListScreenState createState() => _PrizeListScreenState();
}

class _PrizeListScreenState extends State<PrizeListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.card_giftcard, color: Colors.white),
            SizedBox(width: 8),
            Text('상품 추첨'),
          ],
        ),
        backgroundColor: FifaColors.primary,
      ),
      body: StreamBuilder<List<PrizeModel>>(
        stream: PrizeService.getPrizesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('오류가 발생했습니다'),
                  Text('${snapshot.error}'),
                ],
              ),
            );
          }

          final prizes = snapshot.data ?? [];

          if (prizes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '등록된 상품이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: prizes.length,
            itemBuilder: (context, index) {
              final prize = prizes[index];
              return PrizeCard(
                prize: prize,
                currentUser: widget.currentUser,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrizeDetailScreen(
                        prize: prize,
                        currentUser: widget.currentUser,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// 상품 카드 위젯
class PrizeCard extends StatelessWidget {
  final PrizeModel prize;
  final UserModel? currentUser;
  final VoidCallback onTap;

  const PrizeCard({
    Key? key,
    required this.prize,
    required this.currentUser,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = prize.getCurrentStatus();
    final isExpired = status == PrizeStatus.expired || status == PrizeStatus.completed;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isExpired ? Colors.grey.withOpacity(0.3) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상품 이미지
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: prize.imageUrl.isNotEmpty
                          ? Image.network(
                        prize.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey[600]),
                          );
                        },
                      )
                          : Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.image, size: 48, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  // 상태 배지
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 티어 배지
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(prize.tier.emoji, style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text(
                            prize.tier.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpired)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Text(
                            status == PrizeStatus.completed ? '추첨 완료' : '기간 만료',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // 상품 정보
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prize.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.grey : FifaColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      prize.description,
                      style: TextStyle(
                        color: isExpired ? Colors.grey : FifaColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '필요 광고: ${prize.tier.requiredAdViews}회',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired ? Colors.grey : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '상품 가치: ${prize.tier.valueDisplay}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired ? Colors.grey : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${prize.currentParticipants}/${prize.maxParticipants}명 응모',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired ? Colors.grey : FifaColors.textSecondary,
                              ),
                            ),
                            Text(
                              '~${prize.endDate.month}/${prize.endDate.day} ${prize.endDate.hour.toString().padLeft(2, '0')}:${prize.endDate.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired ? Colors.grey : FifaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(PrizeStatus status) {
    switch (status) {
      case PrizeStatus.upcoming:
        return Colors.blue;
      case PrizeStatus.active:
        return Colors.green;
      case PrizeStatus.expired:
        return Colors.red;
      case PrizeStatus.completed:
        return Colors.purple;
    }
  }
}

// 상품 상세 화면
class PrizeDetailScreen extends StatefulWidget {
  final PrizeModel prize;
  final UserModel? currentUser;

  const PrizeDetailScreen({
    Key? key,
    required this.prize,
    required this.currentUser,
  }) : super(key: key);

  @override
  _PrizeDetailScreenState createState() => _PrizeDetailScreenState();
}

class _PrizeDetailScreenState extends State<PrizeDetailScreen> {
  bool _isLoading = false;
  int _currentAdViews = 0;
  bool _hasAlreadyParticipated = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    if (widget.currentUser == null) return;

    try {
      // 사용자의 응모 이력 확인 (실제로는 PrizeService에 메서드 추가 필요)
      // 현재는 임시로 false로 설정
      setState(() {
        _hasAlreadyParticipated = false;
        _currentAdViews = 0; // 실제로는 오늘 시청한 광고 수 확인
      });
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  Future<void> _watchAdForPrize() async {
    if (widget.currentUser == null) {
      _showLoginDialog();
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

    setState(() {
      _isLoading = true;
    });

    try {
      bool rewardEarned = await RewardedAdService.showRewardedAd();

      if (rewardEarned) {
        // 광고 시청 이력 추가
        await PrizeService.addAdViewHistory(
          userId: FirebaseAuth.instance.currentUser!.uid,
          adType: 'prize_entry',
          pointsEarned: 0,
          prizeId: widget.prize.id,
        );

        setState(() {
          _currentAdViews++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('광고 시청 완료! (${_currentAdViews}/${widget.prize.tier.requiredAdViews})'),
            backgroundColor: Colors.green,
          ),
        );

        // 필요한 광고를 모두 시청했으면 응모 가능 알림
        if (_currentAdViews >= widget.prize.tier.requiredAdViews) {
          _showParticipationDialog();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _participateInPrize() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await PrizeService.participateInPrize(widget.prize.id);

      setState(() {
        _hasAlreadyParticipated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('응모가 완료되었습니다! 행운을 빕니다 🍀'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('로그인 필요'),
        content: Text('상품 응모를 위해 로그인이 필요합니다.'),
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

  void _showParticipationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.yellow),
            SizedBox(width: 8),
            Text('응모 가능!'),
          ],
        ),
        content: Text('필요한 광고를 모두 시청했습니다.\n지금 응모하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _participateInPrize();
            },
            child: Text('응모하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.prize.getCurrentStatus();
    final isExpired = status == PrizeStatus.expired || status == PrizeStatus.completed;
    final canParticipate = widget.prize.canParticipate() && widget.currentUser != null;
    final remainingAds = widget.prize.tier.requiredAdViews - _currentAdViews;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.card_giftcard, color: Colors.white),
            SizedBox(width: 8),
            Text('상품 추첨'),
          ],
        ),
        backgroundColor: FifaColors.primary,
        actions: [
          if (widget.currentUser?.isAdmin == true) ...[
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminPrizeManagementScreen(currentUser: widget.currentUser!),
                  ),
                );
              },
              icon: Icon(Icons.settings),
              tooltip: '상품 관리',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: widget.prize.imageUrl.isNotEmpty
                      ? Image.network(
                    widget.prize.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported, size: 64),
                      );
                    },
                  )
                      : Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: 64),
                  ),
                ),
                if (isExpired)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Text(
                          status == PrizeStatus.completed ? '추첨 완료' : '기간 만료',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 티어와 상태
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: FifaColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FifaColors.primary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.prize.tier.emoji),
                            SizedBox(width: 4),
                            Text(
                              widget.prize.tier.name.toUpperCase(),
                              style: TextStyle(
                                color: FifaColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          status.displayName,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // 상품 제목
                  Text(
                    widget.prize.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: FifaColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),

                  // 상품 설명
                  Text(
                    widget.prize.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: FifaColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24),

                  // 상품 정보 카드들
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.play_circle_filled,
                          title: '필요 광고',
                          value: '${widget.prize.tier.requiredAdViews}회',
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.card_giftcard,
                          title: '상품 가치',
                          value: widget.prize.tier.valueDisplay,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.people,
                          title: '응모 현황',
                          value: '${widget.prize.currentParticipants}/${widget.prize.maxParticipants}명',
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.schedule,
                          title: '종료일',
                          value: '${widget.prize.endDate.month}/${widget.prize.endDate.day} ${widget.prize.endDate.hour.toString().padLeft(2, '0')}:${widget.prize.endDate.minute.toString().padLeft(2, '0')}',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  // 응모 상태에 따른 버튼
                  if (widget.currentUser == null) ...[
                    _buildActionButton(
                      onPressed: _showLoginDialog,
                      text: '로그인하고 응모하기',
                      icon: Icons.login,
                      color: FifaColors.primary,
                    ),
                  ] else if (_hasAlreadyParticipated) ...[
                    _buildActionButton(
                      onPressed: null,
                      text: '이미 응모한 상품입니다',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ] else if (isExpired) ...[
                    _buildActionButton(
                      onPressed: null,
                      text: status == PrizeStatus.completed ? '추첨이 완료되었습니다' : '응모 기간이 만료되었습니다',
                      icon: Icons.lock,
                      color: Colors.grey,
                    ),
                  ] else if (!canParticipate) ...[
                    _buildActionButton(
                      onPressed: null,
                      text: '정원이 초과되었습니다',
                      icon: Icons.lock,
                      color: Colors.grey,
                    ),
                  ] else if (remainingAds > 0) ...[
                    _buildActionButton(
                      onPressed: _watchAdForPrize,
                      text: '광고 시청하기 ($remainingAds회 남음)',
                      icon: Icons.play_arrow,
                      color: Colors.orange,
                    ),
                  ] else ...[
                    _buildActionButton(
                      onPressed: _participateInPrize,
                      text: '응모하기',
                      icon: Icons.star,
                      color: Colors.green,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(PrizeStatus status) {
    switch (status) {
      case PrizeStatus.upcoming:
        return Colors.blue;
      case PrizeStatus.active:
        return Colors.green;
      case PrizeStatus.expired:
        return Colors.red;
      case PrizeStatus.completed:
        return Colors.purple;
    }
  }
}