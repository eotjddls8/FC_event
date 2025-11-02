import 'package:flutter/material.dart';
import '../models/prize_model.dart';
import '../models/user_model.dart';
import '../services/prize_service.dart';
import '../theme/fifa_theme.dart';
import 'admin_prize_create_screen.dart';

class AdminPrizeManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const AdminPrizeManagementScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _AdminPrizeManagementScreenState createState() => _AdminPrizeManagementScreenState();
}

class _AdminPrizeManagementScreenState extends State<AdminPrizeManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 8),
            Text('상품 관리'),
          ],
        ),
        backgroundColor: FifaColors.primary,
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminPrizeCreateScreen(),
                ),
              );
              if (result == true) {
                setState(() {}); // 상품 목록 새로고침
              }
            },
            icon: Icon(Icons.add),
            tooltip: '상품 등록',
          ),
        ],
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
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminPrizeCreateScreen(),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.add),
                    label: Text('상품 등록하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FifaColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 통계 카드들
                _buildStatisticsCards(prizes),
                SizedBox(height: 24),

                // 상품 목록
                Text(
                  '상품 목록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: FifaColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),

                ...prizes.map((prize) => AdminPrizeCard(
                  prize: prize,
                  onUpdate: () => setState(() {}),
                )).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards(List<PrizeModel> prizes) {
    final activePrizes = prizes.where((p) => p.getCurrentStatus() == PrizeStatus.active).length;
    final totalParticipants = prizes.fold<int>(0, (sum, p) => sum + p.currentParticipants);
    final completedPrizes = prizes.where((p) => p.getCurrentStatus() == PrizeStatus.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 통계',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: FifaColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '전체 상품',
                value: '${prizes.length}개',
                icon: Icons.card_giftcard,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: '진행 중',
                value: '${activePrizes}개',
                icon: Icons.play_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '총 응모자',
                value: '${totalParticipants}명',
                icon: Icons.people,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: '추첨 완료',
                value: '${completedPrizes}개',
                icon: Icons.check_circle,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
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
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 관리자용 상품 카드
class AdminPrizeCard extends StatelessWidget {
  final PrizeModel prize;
  final VoidCallback onUpdate;

  const AdminPrizeCard({
    Key? key,
    required this.prize,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = prize.getCurrentStatus();

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상품 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    child: prize.imageUrl.isNotEmpty
                        ? Image.network(
                      prize.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.image, color: Colors.grey[600]),
                        );
                      },
                    )
                        : Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.image, color: Colors.grey[600]),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // 상품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              prize.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getStatusColor(status)),
                            ),
                            child: Text(
                              status.displayName,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${prize.tier.emoji} ${prize.tier.name.toUpperCase()} • ${prize.tier.valueDisplay}',
                        style: TextStyle(
                          color: FifaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            '${prize.currentParticipants}/${prize.maxParticipants}명',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.schedule, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            '~${prize.endDate.month}/${prize.endDate.day}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (prize.winnerId != null) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      '당첨자: ${prize.winnerId}',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPrizeDetails(context),
                    icon: Icon(Icons.info, size: 16),
                    label: Text('상세보기'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: FifaColors.primary),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('추첨 기능은 곧 구현될 예정입니다!')),
                      );
                    },
                    icon: Icon(Icons.emoji_events, size: 16),
                    label: Text('추첨하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPrizeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prize.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prize.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    prize.imageUrl,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported, size: 48),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
              ],
              Text('설명: ${prize.description}'),
              SizedBox(height: 8),
              Text('티어: ${prize.tier.emoji} ${prize.tier.name.toUpperCase()}'),
              Text('필요 광고: ${prize.tier.requiredAdViews}회'),
              Text('상품 가치: ${prize.tier.valueDisplay}'),
              SizedBox(height: 8),
              Text('시작일: ${prize.startDate.year}-${prize.startDate.month.toString().padLeft(2, '0')}-${prize.startDate.day.toString().padLeft(2, '0')} ${prize.startDate.hour.toString().padLeft(2, '0')}:${prize.startDate.minute.toString().padLeft(2, '0')}'),
              Text('종료일: ${prize.endDate.year}-${prize.endDate.month.toString().padLeft(2, '0')}-${prize.endDate.day.toString().padLeft(2, '0')} ${prize.endDate.hour.toString().padLeft(2, '0')}:${prize.endDate.minute.toString().padLeft(2, '0')}'),
              SizedBox(height: 8),
              Text('응모자: ${prize.currentParticipants}/${prize.maxParticipants}명'),
              Text('상태: ${prize.getCurrentStatus().displayName}'),
              if (prize.winnerId != null) ...[
                SizedBox(height: 8),
                Text('당첨자: ${prize.winnerId}', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기'),
          ),
        ],
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