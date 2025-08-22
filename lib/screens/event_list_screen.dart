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
import 'simple_ad_test_screen.dart';
import 'main_navigation_screen.dart'; // 🎯 로그아웃용 import

class EventListScreen extends StatefulWidget {
  final UserModel? currentUser;

  const EventListScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _EventListScreenState createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final AuthService _authService = AuthService();

  // 🔧 완전한 로그아웃 함수
  Future<void> _logout() async {
    try {
      print('로그아웃 시도 중...');

      // Firebase 세션 종료
      await _authService.signOut();
      print('Firebase 로그아웃 완료');

      // 모든 화면을 제거하고 비회원 상태로 돌아가기
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(currentUser: null), // 비회원 상태
          ),
              (route) => false, // 모든 이전 화면 제거
        );

        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('로그아웃 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 이벤트 정렬 함수
  List<Event> sortEventsByDeadline(List<Event> events) {
    final now = DateTime.now();

    // 3개 그룹으로 분리
    List<Event> ongoingEvents = [];  // 진행 중
    List<Event> upcomingEvents = []; // 시작 예정
    List<Event> endedEvents = [];    // 종료됨

    for (Event event in events) {
      if (event.status == EventStatus.upcoming) {
        upcomingEvents.add(event);
      } else if (event.status == EventStatus.ended) {
        endedEvents.add(event);
      } else {
        ongoingEvents.add(event);
      }
    }

    // 각 그룹 내에서 정렬
    ongoingEvents.sort((a, b) => a.endDate.compareTo(b.endDate));        // 마감일 가까운 순
    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));   // 시작일 가까운 순
    endedEvents.sort((a, b) => b.endDate.compareTo(a.endDate));          // 최근 종료 순

    // 최종 순서: 진행중 → 예정 → 종료
    return [...ongoingEvents, ...upcomingEvents, ...endedEvents];
  }

  // 남은 일수 계산 (Event 모델의 statusText 사용)
  String calculateRemainingDays(Event event) {
    return event.statusText;
  }

  // 이벤트 상태 확인 (Event 모델의 status 사용)
  String getEventStatus(Event event) {
    switch (event.status) {
      case EventStatus.upcoming:
        return "upcoming";
      case EventStatus.ended:
        return "ended";
      case EventStatus.active:
        return "ongoing";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'FC 이벤트',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: FifaColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // 로그인/프로필 메뉴
          if (widget.currentUser != null)
          // 로그인된 상태: 프로필 메뉴
            PopupMenuButton<String>(
              icon: Icon(Icons.account_circle, color: Colors.white, size: 28),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout(); // 🎯 로그아웃 함수 호출
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: FifaColors.primary),
                      SizedBox(width: 8),
                      Text('${widget.currentUser!.name} (${widget.currentUser!.role})'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('로그아웃', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            )
          else
          // 비회원 상태: 로그인 버튼
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              icon: Icon(Icons.login, color: Colors.white),
              label: Text('로그인', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 배너 광고
          BannerAdWidget(),

          // 이벤트 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('오류가 발생했습니다', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 8),
                        Text(snapshot.error.toString(), style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: FifaColors.primary),
                        SizedBox(height: 16),
                        Text('이벤트를 불러오는 중...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_soccer, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('등록된 이벤트가 없습니다', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final events = snapshot.data!.docs.map((doc) => Event.fromFirestore(doc)).toList();
                final sortedEvents = sortEventsByDeadline(events);

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: sortedEvents.length,
                  itemBuilder: (context, index) {
                    final event = sortedEvents[index];
                    final status = getEventStatus(event);
                    final remainingDays = calculateRemainingDays(event);

                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Card(
                        elevation: status == 'ended' ? 2 : 6,
                        shadowColor: status == 'ongoing' ? Colors.red.withOpacity(0.3) :
                        status == 'upcoming' ? Colors.blue.withOpacity(0.3) :
                        Colors.grey.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: event.statusColor,
                            width: status == 'ended' ? 1 : 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: status == 'ended'
                                ? null
                                : BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  event.statusColor.withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                if (widget.currentUser == null) {
                                  // 비회원: 로그인 유도
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
                                } else {
                                  // 로그인된 사용자: 상세화면으로
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EventDetailScreen(
                                        event: event,
                                        currentUser: widget.currentUser!,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 상단: 제목과 상태 배지
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            event.title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'ended' ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        // 상태 배지
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: event.statusColor,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            remainingDays,
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

                                    // 설명
                                    Text(
                                      event.content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: status == 'ended' ? Colors.grey : Colors.grey[600],
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    SizedBox(height: 12),

                                    // 하단: 보상과 액션
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // 보상 정보 (좋아요 수로 대체)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.favorite,
                                              size: 16,
                                              color: status == 'ended' ? Colors.grey : Colors.red,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '${event.likes}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: status == 'ended' ? Colors.grey : Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // 액션 버튼들
                                        Row(
                                          children: [
                                            // 관리자 삭제 버튼
                                            if (widget.currentUser?.isAdmin == true)
                                              IconButton(
                                                onPressed: () async {
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

                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('이벤트가 삭제되었습니다')),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('삭제 중 오류가 발생했습니다')),
                                                      );
                                                    }
                                                  }
                                                },
                                                icon: Icon(Icons.delete, color: Colors.red),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 관리자용 이벤트 추가 버튼
      floatingActionButton: (widget.currentUser?.isAdmin == true)
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventWriteScreen(currentUser: widget.currentUser!),
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
}