// admin_prize_management_screen.dart (전체 수정된 코드)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ⭐ 1. 이 줄을 추가하세요!
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
  // ⭐ 상품 수정 로직 (추가)
  void _editPrize(PrizeModel prize) async {
    // AdminPrizeCreateScreen을 수정 모드로 재활용
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPrizeCreateScreen(prizeToEdit: prize), // 기존 데이터를 전달
      ),
    );
    if (result == true) {
      // StreamBuilder가 자동으로 갱신하므로 setState()는 불필요할 수 있습니다.
      // 하지만 상태 변경을 확실히 하려면 추가
      setState(() {});
    }
  }

  // ⭐ 상품 삭제 로직 (추가)
  void _deletePrize(PrizeModel prize) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('상품 삭제 확인'),
        content: Text('상품 "${prize.title}"을(를) 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PrizeService.deletePrize(prize.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ 상품이 삭제되었습니다.')),
        );
        // StreamBuilder가 자동으로 목록을 갱신합니다.
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 상품 삭제 실패: $e')),
        );
      }
    }
  }

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
                  onEdit: () => _editPrize(prize),     // ⭐ 수정 콜백 전달
                  onDelete: () => _deletePrize(prize), // ⭐ 삭제 콜백 전달
                  onUpdate: () => setState(() {}),
                )).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ⭐ '총 응모자' 카드 제거됨
  Widget _buildStatisticsCards(List<PrizeModel> prizes) {
    final activePrizes = prizes.where((p) => p.getCurrentStatus() == PrizeStatus.active).length;
    // final totalParticipants = prizes.fold<int>(0, (sum, p) => sum + p.currentParticipants); // ❌ 제거
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
                title: '추첨 완료',
                value: '${completedPrizes}개',
                icon: Icons.check_circle,
                color: Colors.purple,
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Container()), // ❌ '총 응모자' 카드 자리 비움
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
    // ... (이 위젯은 수정사항 없음) ...
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
  final VoidCallback onEdit;   // ⭐ 수정 콜백 추가
  final VoidCallback onDelete; // ⭐ 삭제 콜백 추가

  const AdminPrizeCard({
    Key? key,
    required this.prize,
    required this.onUpdate,
    required this.onEdit,   // ⭐ 수정 콜백 추가
    required this.onDelete, // ⭐ 삭제 콜백 추가
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

                SizedBox(width: 16),

                // 상품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          // ⭐ 수정/삭제 메뉴 추가
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit, color: Colors.blue),
                                  title: Text('수정'),
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete, color: Colors.red),
                                  title: Text('삭제'),
                                ),
                              ),
                            ],
                            icon: Icon(Icons.more_vert, color: Colors.grey[700]),
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
                          Icon(Icons.schedule, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          // ⭐ Expanded 적용 1
                          Expanded(
                            child: Text(
                              '~${prize.endDate.month}/${prize.endDate.day}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.people, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          // ⭐ Expanded 적용 2 (총 응모 횟수)
                          Expanded(
                            child: Text(
                              '총 응모: \n${prize.currentParticipants}회',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.monetization_on, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          // ⭐ Expanded 적용 3 (코인 정보)
                          Expanded(
                            child: Text(
                              '${prize.requiredCoins} 코인',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (prize.winnerId != null && prize.winnerId!.isNotEmpty) ...[ // ⭐ winnerId가 null이 아니고 비어있지 않은지 확인
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
                    Expanded( // 당첨자 ID가 길 경우를 대비
                      child: Text(
                        '당첨자: ${prize.winnerId}',
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 12),
            // ⭐ 버튼 Row 제거 (상세보기, 추첨하기)
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
                    onPressed: (status == PrizeStatus.expired && (prize.winnerId == null || prize.winnerId!.isEmpty))
                        ? () { // ⭐ 추첨 버튼 활성화 조건 변경
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('추첨 기능은 곧 구현될 예정입니다!')),
                      );
                    }
                        : null, // 그 외 비활성화
                    icon: Icon(Icons.emoji_events, size: 16),
                    label: Text('추첨하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (status == PrizeStatus.expired && (prize.winnerId == null || prize.winnerId!.isEmpty))
                          ? Colors.purple // 만료되고 당첨자가 없으면 활성화
                          : Colors.grey, // 그 외 비활성화
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ⭐ '응모자' 정보 제거
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
              // ⭐ 1단계에서 prize_model.dart에 추가한 requiredCoins 필드 사용
              Text('필요 코인: ${prize.requiredCoins} 코인'),
              Text('상품 가치: ${prize.tier.valueDisplay}'),
              SizedBox(height: 8),
              // ⭐ 2. DateFormat 오류 수정!
              Text('시작일: ${DateFormat('yyyy-MM-dd HH:mm').format(prize.startDate)}'),
              Text('종료일: ${DateFormat('yyyy-MM-dd HH:mm').format(prize.endDate)}'),
              SizedBox(height: 8),
              Text('총 응모 횟수: ${prize.currentParticipants}회'), // ⭐ 추가
              // Text('응모자: ${prize.currentParticipants}/${prize.maxParticipants}명'), // ❌ 제거
              //Text('최대 인원: ${prize.maxParticipants}명'), // ❌ 대신 '최대 인원' 표시
              Text('상태: ${prize.getCurrentStatus().displayName}'),
              if (prize.winnerId != null && prize.winnerId!.isNotEmpty) ...[ // ⭐ winnerId null 체크 강화
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