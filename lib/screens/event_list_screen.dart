import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';  // post.dart에서 event.dart로 변경
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/fifa_theme.dart';
import '../widgets/banner_ad_widget.dart';  // 추가
import 'event_write_screen.dart';  // post_write_screen.dart에서 변경
import 'event_detail_screen.dart';  // post_detail_screen.dart에서 변경
import 'login_screen.dart';
import 'simple_ad_test_screen.dart';

class EventListScreen extends StatelessWidget {
  final UserModel? currentUser;
  final AuthService _authService = AuthService();

  EventListScreen({this.currentUser});

  Future<void> _logout(BuildContext context) async {
    await _authService.signOut();
  }

  // 이벤트 정렬 함수 수정 (3단계 정렬)
  List<Event> sortEventsByDeadline(List<Event> events) {
    final now = DateTime.now();
    final ongoingEvents = <Event>[];    // 진행 중
    final upcomingEvents = <Event>[];   // 시작 예정
    final expiredEvents = <Event>[];    // 종료됨

    // 이벤트를 3단계로 분리
    for (final event in events) {
      if (event.endDate.isBefore(now)) {
        // 종료된 이벤트
        expiredEvents.add(event);
      } else if (event.startDate.isAfter(now)) {
        // 아직 시작되지 않은 이벤트
        upcomingEvents.add(event);
      } else {
        // 진행 중인 이벤트 (startDate <= now < endDate)
        ongoingEvents.add(event);
      }
    }

    // 1. 진행 중 이벤트: 마감일 가까운 순으로 정렬 (오름차순)
    ongoingEvents.sort((a, b) => a.endDate.compareTo(b.endDate));

    // 2. 시작 예정 이벤트: 시작일 가까운 순으로 정렬 (오름차순)
    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));

    // 3. 종료된 이벤트: 최근 종료된 순으로 정렬 (내림차순)
    expiredEvents.sort((a, b) => b.endDate.compareTo(a.endDate));

    // 진행 중 → 시작 예정 → 종료됨 순서로 배치
    return [...ongoingEvents, ...upcomingEvents, ...expiredEvents];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.sports_soccer, color: FifaColors.accent),
            SizedBox(width: 8),
            Text('FIFA 이벤트'),
          ],
        ),
        backgroundColor: FifaColors.primary,
        actions: [
          // 비회원도 광고 테스트는 볼 수 있음
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SimpleAdTestScreen(),
                ),
              );
            },
            icon: Icon(Icons.ads_click),
            tooltip: '광고 테스트',
          ),
          if (currentUser != null) ...[
            // 로그인한 사용자만 프로필 메뉴 표시
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _logout(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(currentUser!.isAdmin ? Icons.admin_panel_settings : Icons.person),
                      SizedBox(width: 8),
                      Text('${currentUser!.name} (${currentUser!.role})'),
                    ],
                  ),
                ),
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
            // 비회원은 로그인 버튼 표시
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .snapshots(), // orderBy 제거 - 클라이언트에서 정렬할 것임
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('오류가 발생했습니다: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(FifaColors.primary),
                  ),
                  SizedBox(height: 16),
                  Text('FIFA 이벤트 로딩 중...'),
                ],
              ),
            );
          }

          final events = snapshot.data!.docs
              .map((doc) => Event.fromFirestore(doc))
              .toList();

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: FifaColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sports_soccer,
                      size: 60,
                      color: FifaColors.primary,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    '등록된 FIFA 이벤트가 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FifaColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    currentUser?.isAdmin == true
                        ? '첫 번째 이벤트를 추가해보세요!'
                        : '관리자가 이벤트를 추가할 때까지 기다려주세요.',
                    style: TextStyle(color: FifaColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // 🎯 여기서 이벤트 정렬!
          final sortedEvents = sortEventsByDeadline(events);

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: sortedEvents.length,
            itemBuilder: (context, index) {
              final event = sortedEvents[index];
              return _buildEventCard(context, event);
            },
          );
        },
      ),
      floatingActionButton: currentUser?.isAdmin == true
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventWriteScreen(currentUser: currentUser!),
            ),
          );
        },
        icon: Icon(Icons.add),
        label: Text('이벤트 추가'),
        backgroundColor: FifaColors.secondary,
      )
          : null,
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) {
    final now = DateTime.now();
    final isExpired = event.endDate.isBefore(now);
    final isUpcoming = event.startDate.isAfter(now);
    final isOngoing = !isExpired && !isUpcoming;

    // 상태에 따른 색상 설정
    Color cardBorderColor;
    Color statusBadgeColor;
    String statusText;

    if (isExpired) {
      cardBorderColor = Colors.grey[300]!;
      statusBadgeColor = Colors.grey[400]!;
      statusText = '종료됨';
    } else if (isUpcoming) {
      cardBorderColor = Colors.blue[300]!;
      statusBadgeColor = Colors.blue[600]!;
      statusText = '시작 예정';
    } else {
      cardBorderColor = event.statusColor;
      statusBadgeColor = event.statusColor;
      statusText = event.statusText;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorderColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpired
                ? Colors.grey.withOpacity(0.1)
                : cardBorderColor.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: currentUser != null ? () {
          // 로그인한 사용자만 이벤트 상세 접근 가능
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                event: event,
                currentUser: currentUser,
              ),
            ),
          );
        } : () {
          // 비회원은 로그인 유도
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('이벤트 참여를 위해 로그인해주세요'),
              action: SnackBarAction(
                label: '로그인',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 배지와 제목
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBadgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // 남은 일수 표시 추가
                  if (!isExpired) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUpcoming ? Colors.blue[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _calculateRemainingDays(event.startDate, event.endDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isUpcoming ? Colors.blue[700] : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  if (currentUser?.isAdmin == true)
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEvent(context, event),
                    ),
                ],
              ),

              SizedBox(height: 12),

              // 제목
              Text(
                event.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isExpired ? Colors.grey[600] : FifaColors.textPrimary,
                ),
              ),

              SizedBox(height: 8),

              // 내용 미리보기
              Text(
                event.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isExpired ? Colors.grey[500] : FifaColors.textSecondary,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 12),

              // 기간 정보
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.grey[50] : FifaColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: isExpired ? Colors.grey[400] : FifaColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatDate(event.startDate)} ~ ${_formatDate(event.endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? Colors.grey[500] : FifaColors.textSecondary,
                        ),
                      ),
                    ),
                    // 좋아요 수 - 클릭 가능 (로그인한 사용자만)
                    InkWell(
                      onTap: currentUser != null ? () {
                        // 좋아요 기능 (회원만)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('좋아요 기능은 개발 중입니다')),
                        );
                      } : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            color: isExpired ? Colors.grey[400] : Colors.red,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            event.likes.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired ? Colors.grey[500] : FifaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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

  // 남은 일수 계산 함수 수정 (시작 예정 이벤트 포함)
  String _calculateRemainingDays(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();

    if (endDate.isBefore(now)) {
      // 종료된 이벤트
      return '종료됨';
    } else if (startDate.isAfter(now)) {
      // 시작 예정 이벤트
      final daysToStart = startDate.difference(now).inDays;
      if (daysToStart == 0) {
        return '오늘 시작';
      } else if (daysToStart == 1) {
        return '내일 시작';
      } else {
        return '$daysToStart일 후 시작';
      }
    } else {
      // 진행 중 이벤트
      final daysToEnd = endDate.difference(now).inDays;
      if (daysToEnd == 0) {
        return '오늘 마감';
      } else if (daysToEnd == 1) {
        return '내일 마감';
      } else {
        return '$daysToEnd일 남음';
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}';
  }

  Future<void> _deleteEvent(BuildContext context, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('이벤트 삭제'),
        content: Text('정말로 이 이벤트를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(event.id)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이벤트가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }
}