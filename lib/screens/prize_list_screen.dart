import 'package:flutter/material.dart';
import '../models/prize_model.dart';
import '../models/user_model.dart';
import '../services/prize_service.dart';
import '../services/rewarded_ad_service.dart';
import '../theme/fifa_theme.dart';
import 'login_screen.dart';

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
                  Text('상품 목록 로드 실패'),
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

// 🎨 이미지 없는 깔끔한 상품 카드
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
              // 🎯 티어별 아이콘 카드 (이미지 대신)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getTierColor(prize.tier).withOpacity(0.8),
                      _getTierColor(prize.tier),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Stack(
                  children: [
                    // 중앙 아이콘
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            prize.tier.emoji,
                            style: TextStyle(fontSize: 48),
                          ),
                          SizedBox(height: 4),
                          Text(
                            prize.tier.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
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

                    // 완료/만료 오버레이
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
              ),

              // 상품 정보
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상품명
                    Text(
                      prize.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.grey : null,
                      ),
                    ),
                    SizedBox(height: 8),

                    // 상품 설명
                    Text(
                      prize.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isExpired ? Colors.grey : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),

                    // 하단 정보 행
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 필요 응모 수
                        Row(
                          children: [
                            Icon(Icons.confirmation_number, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '${prize.tier.requiredAdViews}회 응모',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        // 참가자 정보
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '${prize.currentParticipants}/${prize.maxParticipants}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        // 마감일
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '${prize.endDate.month}/${prize.endDate.day}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
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

  // 🎨 티어별 색상
  Color _getTierColor(PrizeTier tier) {
    switch (tier) {
      case PrizeTier.bronze:
        return Colors.orange;
      case PrizeTier.silver:
        return Colors.grey;
      case PrizeTier.gold:
        return Colors.amber;
      case PrizeTier.diamond:
        return Colors.purple;
    }
  }

  // 🎨 상태별 색상
  Color _getStatusColor(PrizeStatus status) {
    switch (status) {
      case PrizeStatus.upcoming:
        return Colors.blue;
      case PrizeStatus.active:
        return Colors.green;
      case PrizeStatus.expired:
        return Colors.red;
      case PrizeStatus.completed:
        return Colors.grey;
    }
  }
}

// 상품 상세 화면도 동일하게 수정
class PrizeDetailScreen extends StatelessWidget {
  final PrizeModel prize;
  final UserModel? currentUser;

  const PrizeDetailScreen({
    Key? key,
    required this.prize,
    this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = prize.getCurrentStatus();
    final canParticipate = status == PrizeStatus.active && currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('상품 상세'),
        backgroundColor: FifaColors.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 티어별 아이콘 헤더 (이미지 대신)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getTierColor(prize.tier).withOpacity(0.8),
                    _getTierColor(prize.tier),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      prize.tier.emoji,
                      style: TextStyle(fontSize: 72),
                    ),
                    SizedBox(height: 8),
                    Text(
                      prize.tier.name.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${prize.tier.requiredAdViews}회 응모 필요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 상품 정보
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품명
                  Text(
                    prize.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  // 상태 배지
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // 상품 설명
                  Text(
                    '상품 설명',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    prize.description,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 24),

                  // 참가 정보 카드들
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.people, size: 32, color: FifaColors.primary),
                                SizedBox(height: 8),
                                Text(
                                  '${prize.currentParticipants}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text('현재 참가자', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.group, size: 32, color: FifaColors.primary),
                                SizedBox(height: 8),
                                Text(
                                  '${prize.maxParticipants}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text('최대 참가자', style: TextStyle(fontSize: 12)),
                              ],
                            ),
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
      ),

      // 하단 참가 버튼
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        child: canParticipate
            ? ElevatedButton(
          onPressed: () => _participateInPrize(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: FifaColors.primary,
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            '추첨 참가하기 (${prize.tier.requiredAdViews}회 응모)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        )
            : Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              currentUser == null ? '로그인이 필요합니다' : '참가 불가',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTierColor(PrizeTier tier) {
    switch (tier) {
      case PrizeTier.bronze:
        return Colors.orange;
      case PrizeTier.silver:
        return Colors.grey;
      case PrizeTier.gold:
        return Colors.amber;
      case PrizeTier.diamond:
        return Colors.purple;
    }
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
        return Colors.grey;
    }
  }

  void _participateInPrize(BuildContext context) {
    // 참가 로직 구현
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('추첨 참가'),
        content: Text('${prize.tier.requiredAdViews}회 응모하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 실제 참가 로직 실행
            },
            child: Text('참가'),
          ),
        ],
      ),
    );
  }
}