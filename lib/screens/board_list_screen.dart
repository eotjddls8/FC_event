import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/fifa_theme.dart';
import '../widgets/banner_ad_widget.dart';
import 'event_write_screen.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';

class EventListScreen extends StatelessWidget {
  final UserModel? currentUser;
  final AuthService _authService = AuthService();

  EventListScreen({this.currentUser});

  Future<void> _logout(BuildContext context) async {
    await _authService.signOut();
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
          if (currentUser != null) ...[
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
                      Text('${currentUser!.name}'),
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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .orderBy('startDate', descending: false)
                  .snapshots(),
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

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(context, events[index]);
                  },
                );
              },
            ),
          ),
          // 배너 광고 추가
          BannerAdWidget(currentUser: currentUser),
        ],
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
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.statusColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: event.statusColor.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(
                event: event,
                currentUser: currentUser,
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
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: event.statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.statusText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (currentUser?.isAdmin == true)
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEvent(context, event),
                    ),
                ],
              ),

              SizedBox(height: 12),

              Text(
                event.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FifaColors.textPrimary,
                ),
              ),

              SizedBox(height: 8),

              Text(
                event.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: FifaColors.textSecondary,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 12),

              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FifaColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: FifaColors.textSecondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatDate(event.startDate)} ~ ${_formatDate(event.endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: FifaColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(Icons.favorite, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      event.likes.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: FifaColors.textSecondary,
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