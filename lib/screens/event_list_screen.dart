import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import '../widgets/banner_ad_widget.dart';
import 'event_write_screen.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatefulWidget {
  final UserModel? currentUser;

  const EventListScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _EventListScreenState createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {

  // 🎯 개선된 이벤트 정렬 (3단계 상태 기반)
  List<Event> sortEventsByStatus(List<Event> events) {
    List<Event> activeEvents = [];      // 진행 중
    List<Event> rewardEvents = [];      // 보상 기간
    List<Event> upcomingEvents = [];    // 시작 예정
    List<Event> endedEvents = [];       // 완전 종료

    for (Event event in events) {
      switch (event.status) {
        case EventStatus.active:
          activeEvents.add(event);
          break;
        case EventStatus.rewardPeriod:
          rewardEvents.add(event);
          break;
        case EventStatus.upcoming:
          upcomingEvents.add(event);
          break;
        case EventStatus.ended:
          endedEvents.add(event);
          break;
      }
    }

    // 각 그룹 내 정렬
    activeEvents.sort((a, b) => a.endDate.compareTo(b.endDate));
    rewardEvents.sort((a, b) => a.rewardEndDate.compareTo(b.rewardEndDate));
    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));
    endedEvents.sort((a, b) => b.rewardEndDate.compareTo(a.rewardEndDate));

    // 최종 순서: 진행중 → 보상중 → 예정 → 종료
    return [...activeEvents, ...rewardEvents, ...upcomingEvents, ...endedEvents];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // 🎯 모던한 앱바
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'FC 이벤트',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(
                color: Colors.grey[200],
                height: 1,
              ),
            ),
          ),

          // 배너 광고
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: BannerAdWidget(),
            ),
          ),

          // 🎯 이벤트 상태별 섹션
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorWidget();
                }

                if (!snapshot.hasData) {
                  return _buildLoadingWidget();
                }

                List<Event> events = snapshot.data!.docs
                    .map((doc) => Event.fromFirestore(doc))
                    .toList();

                if (events.isEmpty) {
                  return _buildEmptyWidget();
                }

                events = sortEventsByStatus(events);

                // 상태별로 그룹화
                Map<EventStatus, List<Event>> groupedEvents = {};
                for (var event in events) {
                  groupedEvents.putIfAbsent(event.status, () => []);
                  groupedEvents[event.status]!.add(event);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 진행 중 이벤트
                    if (groupedEvents[EventStatus.active]?.isNotEmpty ?? false)
                      _buildEventSection(
                        title: '🔥 진행 중',
                        events: groupedEvents[EventStatus.active]!,
                        isHighlighted: true,
                      ),

                    // 보상 수령 기간 이벤트
                    if (groupedEvents[EventStatus.rewardPeriod]?.isNotEmpty ?? false)
                      _buildEventSection(
                        title: '🎁 보상 수령 가능',
                        events: groupedEvents[EventStatus.rewardPeriod]!,
                        isHighlighted: true,
                      ),

                    // 시작 예정 이벤트
                    if (groupedEvents[EventStatus.upcoming]?.isNotEmpty ?? false)
                      _buildEventSection(
                        title: '📅 시작 예정',
                        events: groupedEvents[EventStatus.upcoming]!,
                      ),

                    // 종료된 이벤트
                    if (groupedEvents[EventStatus.ended]?.isNotEmpty ?? false)
                      _buildEventSection(
                        title: '✅ 종료됨',
                        events: groupedEvents[EventStatus.ended]!,
                        isCollapsed: true,
                      ),

                    SizedBox(height: 100), // FAB 공간
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // 🎯 관리자용 이벤트 추가 버튼 (개선된 디자인)
      floatingActionButton: (widget.currentUser?.isAdmin == true)
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventWriteScreen(
                currentUser: widget.currentUser!,
              ),
            ),
          );
        },
        icon: Icon(Icons.add_rounded),
        label: Text('새 이벤트'),
        backgroundColor: FifaColors.primary,
      )
          : null,
    );
  }

  // 🎯 섹션별 이벤트 표시
  Widget _buildEventSection({
    required String title,
    required List<Event> events,
    bool isHighlighted = false,
    bool isCollapsed = false,
  }) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? FifaColors.primary : Colors.grey[700],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? FifaColors.primary.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${events.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isHighlighted ? FifaColors.primary : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 이벤트 카드들
          if (!isCollapsed || events.length <= 2)
            ...events.map((event) => _buildEventCard(event))
          else
            ...[
              ...events.take(2).map((event) => _buildEventCard(event)),
              _buildShowMoreButton(events.length - 2),
            ],
        ],
      ),
    );
  }

  // 🎯 개선된 이벤트 카드 디자인
  Widget _buildEventCard(Event event) {
    final bool isEnded = event.status == EventStatus.ended;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isEnded ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnded ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(
                  event: event,
                  currentUser: widget.currentUser,
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEnded ? Colors.grey[300]! : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 제목과 상태
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상태 아이콘
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: event.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        event.statusIcon,
                        color: event.statusColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),

                    // 제목과 내용
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isEnded ? Colors.grey : Colors.black87,
                              decoration: isEnded ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            event.content,
                            style: TextStyle(
                              fontSize: 13,
                              color: isEnded ? Colors.grey[400] : Colors.grey[600],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // 상태 배지
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: event.statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.statusText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // 하단: 기간 정보
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildDateInfo(
                        icon: Icons.play_arrow_rounded,
                        date: event.startDate,
                        color: Color(0xFF2196F3),
                      ),
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF2196F3),
                                Color(0xFFF44336),
                                Color(0xFFFFC107),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      _buildDateInfo(
                        icon: Icons.stop_rounded,
                        date: event.endDate,
                        color: Color(0xFFF44336),
                      ),
                      SizedBox(width: 8),
                      _buildDateInfo(
                        icon: Icons.card_giftcard_rounded,
                        date: event.rewardEndDate,
                        color: Color(0xFFFFC107),
                      ),
                    ],
                  ),
                ),

                // 관리자 액션
                if (widget.currentUser?.isAdmin == true)
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventWriteScreen(
                                  currentUser: widget.currentUser!,
                                  editEvent: event,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.edit_rounded, size: 16),
                          label: Text('수정'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _deleteEvent(event),
                          icon: Icon(Icons.delete_rounded, size: 16),
                          label: Text('삭제'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateInfo({
    required IconData icon,
    required DateTime date,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 4),
        Text(
          '${date.month}.${date.day}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildShowMoreButton(int count) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO: 더보기 기능 구현
          },
          child: Container(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                '+ $count개 더보기',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(
          color: FifaColors.primary,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              '이벤트를 불러올 수 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      height: 400,
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '진행 중인 이벤트가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '곧 새로운 이벤트가 시작됩니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('이벤트 삭제'),
        content: Text('${event.title} 이벤트를 삭제하시겠습니까?'),
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
          SnackBar(
            content: Text('이벤트가 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}