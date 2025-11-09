import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import '../widgets/banner_ad_widget.dart';
import 'event_write_screen.dart';
import 'event_detail_screen.dart';

// 🎯 필터 상태를 정의하는 Enum
enum FilterStatus { active, reward, ended }

class EventListScreen extends StatefulWidget {
  final UserModel? currentUser;

  const EventListScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _EventListScreenState createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  // 🎯 현재 선택된 필터 상태. null이면 '전체 보기'
  FilterStatus? _currentFilter;

  // 🎯 개선된 이벤트 정렬 (3단계 상태 기반)
  List<Event> sortEventsByStatus(List<Event> events) {
    List<Event> activeEvents = [];      // 진행 중
    List<Event> rewardEvents = [];      // 보상 기간
    List<Event> upcomingEvents = [];    // 시작 예정
    List<Event> endedEvents = [];       // 완전 종료

    for (Event event in events) {
      final status = event.status;

      if (status == EventStatus.active) {
        activeEvents.add(event);
      } else if (status == EventStatus.rewardPeriod) {
        rewardEvents.add(event);
      } else if (status == EventStatus.upcoming) {
        upcomingEvents.add(event);
      } else if (status == EventStatus.ended) {
        endedEvents.add(event);
      }
    }

    // 각 그룹 내 정렬: 진행/보상/예정은 마감일이 빠른 순, 종료는 최신 종료일 순
    activeEvents.sort((a, b) => a.endDate.compareTo(b.endDate));
    rewardEvents.sort((a, b) => a.rewardEndDate.compareTo(b.rewardEndDate));
    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));
    endedEvents.sort((a, b) => b.rewardEndDate.compareTo(a.rewardEndDate));

    // 최종 순서: 진행중 → 보상중 → 예정 → 종료
    return [...activeEvents, ...rewardEvents, ...upcomingEvents, ...endedEvents];
  }

  // 🎯 _buildEventSection을 리스트로 반환하고 null 처리 로직을 추가하여 SliverList에 사용하기 쉽게 변경
  List<Widget>? _buildEventSectionIfNotEmpty(List<Event>? events, String title, {bool isHighlighted = false, bool isCollapsed = false}) {
    if (events == null || events.isEmpty) {
      return null;
    }
    return [_buildEventSection(title: title, events: events, isHighlighted: isHighlighted, isCollapsed: isCollapsed)];
  }

// EventListScreen.dart 파일의 _EventListScreenState 클래스 내부

// 🎯 이벤트 상태에 따라 D-Day 정보(텍스트, 색상)를 계산하는 헬퍼 함수 (수정)
  Map<String, dynamic> _getDdayInfo(Event event) {
    // Event 모델의 daysRemaining을 바로 사용 (0이면 오늘 마감)
    final days = event.daysRemaining;
    Color ddayColor;
    String ddayText;

    switch (event.status) {
      case EventStatus.upcoming:
        ddayColor = Color(0xFF2196F3); // 파랑
        if (days <= 0) ddayText = '오늘 시작!';
        else ddayText = 'D-$days';
        break;

      case EventStatus.rewardPeriod:
        ddayColor = Color(0xFFFFC107); // 노랑
        if (days <= 0) ddayText = '보상 마감!';
        else ddayText = '보상 D-$days';
        break;

      case EventStatus.active:
      // 색상은 Event 모델에서 계산된 statusColor를 사용
        ddayColor = event.statusColor;
        if (days <= 0) ddayText = 'D-DAY';
        else ddayText = 'D-$days';
        break;

      case EventStatus.ended:
        ddayColor = Colors.grey[400]!;
        ddayText = '종료';
        break;
    }

    return {
      'text': ddayText,
      'color': ddayColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 StreamBuilder를 최상단으로 이동하여 이벤트 데이터를 먼저 가져옴
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: _buildErrorWidget());
        }

        if (!snapshot.hasData) {
          return Scaffold(body: _buildLoadingWidget());
        }

        List<Event> events = snapshot.data!.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList();

        // 1. 상태에 따라 정렬
        events = sortEventsByStatus(events);

        // 2. 상태별로 그룹화
        Map<EventStatus, List<Event>> groupedEvents = {};
        for (var event in events) {
          groupedEvents.putIfAbsent(event.status, () => []).add(event);
        }

        return Scaffold(
          backgroundColor: Color(0xFFF5F7FA),
          body: CustomScrollView(
            slivers: [
              // 💡 SliverAppBar에 '설정' 디자인과 Sticky 필터 적용
              SliverAppBar(
                // 💡 고객님의 요청 AppBar 디자인 적용
                title: Row(
                  children: [
                    Icon(Icons.sports_soccer, color: Colors.white),
                    SizedBox(width: 8),
                    Text('피온 이벤트',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue[600],
                iconTheme: IconThemeData(color: Colors.white), // 아이콘 색상을 흰색으로 통일

                // 스크롤 동작 설정
                pinned: true, // 앱바의 bottom 부분이 화면 상단에 고정됨 (필터 고정)
                elevation: 0,

                // 🎯 필터 세그먼트를 AppBar의 Bottom으로 이동 (Sticky Header)
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(60.0), // 필터 높이
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildFilterSegment(groupedEvents), // 그룹화된 데이터 전달
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

              if (events.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyWidget())
              else
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      // 진행 중 이벤트 (필터: All or Active)
                      if (_currentFilter == null || _currentFilter == FilterStatus.active)
                        ...?_buildEventSectionIfNotEmpty(groupedEvents[EventStatus.active], '🔥 진행 중', isHighlighted: true),

                      // 보상 수령 기간 이벤트 (필터: All or Reward)
                      if (_currentFilter == null || _currentFilter == FilterStatus.reward)
                        ...?_buildEventSectionIfNotEmpty(groupedEvents[EventStatus.rewardPeriod], '🎁 보상 수령 가능', isHighlighted: true),

                      // 시작 예정 이벤트 (필터: All only)
                      if (_currentFilter == null)
                        ...?_buildEventSectionIfNotEmpty(groupedEvents[EventStatus.upcoming], '📅 시작 예정'),

                      // 종료된 이벤트 (필터: All or Ended)
                      if (_currentFilter == null || _currentFilter == FilterStatus.ended)
                        ...?_buildEventSectionIfNotEmpty(groupedEvents[EventStatus.ended], '✅ 종료됨', isCollapsed: true),

                      SizedBox(height: 100), // FAB 공간
                    ],
                  ),
                ),
            ],
          ),

          // 🎯 관리자용 이벤트 추가 버튼 (Hero Tag 추가)
          floatingActionButton: (widget.currentUser?.isAdmin == true)
              ? FloatingActionButton.extended(
            // 🐛 Hero 애니메이션 충돌 방지를 위해 고유한 heroTag 추가
            heroTag: 'eventListFAB',
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
      },
    );
  }

  // 🎯 필터 세그먼트 위젯 (Sticky Header)
  Widget _buildFilterSegment(Map<EventStatus, List<Event>> groupedEvents) {
    // 필터 카운트 로직 (각 필터는 해당 상태만 카운트)
    final activeCount = groupedEvents[EventStatus.active]?.length ?? 0;
    final rewardCount = groupedEvents[EventStatus.rewardPeriod]?.length ?? 0;
    final endedCount = groupedEvents[EventStatus.ended]?.length ?? 0;

    // 필터 컬러 정의
    final Color activeColor = Color(0xFF2196F3); // 파랑
    final Color rewardColor = Color(0xFFFFC107); // 노랑
    final Color endedColor = Color(0xFF616161); // 회색

    return Row(
      children: [
        _buildFilterItem(
          title: '진행',
          status: FilterStatus.active,
          count: activeCount,
          color: activeColor,
          isCurrentFilter: _currentFilter == FilterStatus.active,
        ),
        SizedBox(width: 8),
        _buildFilterItem(
          title: '보상',
          status: FilterStatus.reward,
          count: rewardCount,
          color: rewardColor,
          isCurrentFilter: _currentFilter == FilterStatus.reward,
        ),
        SizedBox(width: 8),
        _buildFilterItem(
          title: '종료',
          status: FilterStatus.ended,
          count: endedCount,
          color: endedColor,
          isCurrentFilter: _currentFilter == FilterStatus.ended,
        ),
      ],
    );
  }

  // 🎯 필터 세그먼트 아이템 (버튼처럼 보이도록 수정)
  Widget _buildFilterItem({
    required String title,
    required FilterStatus status,
    required int count,
    required Color color,
    required bool isCurrentFilter,
  }) {
    // 선택된 상태에서는 색상을 진하게, 미선택 상태에서는 투명도를 높여 배경색을 사용
    final Color bgColor = isCurrentFilter ? color : color.withOpacity(0.1);
    final Color textColor = isCurrentFilter ? Colors.white : color;

    return Expanded(
      child: Material( // 🎯 Material 위젯을 사용하여 InkWell 효과와 배경색 처리
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        elevation: isCurrentFilter ? 2 : 0, // 선택 시 살짝 떠 보이게
        shadowColor: color.withOpacity(0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              // 현재 필터와 같으면 필터를 해제하여 '전체 보기' 상태(null)로 전환
              // 다르면 새 필터 설정
              _currentFilter = isCurrentFilter ? null : status;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final ddayInfo = _getDdayInfo(event); // D-Day 정보 가져오기

    // 💡 테두리 및 그림자 색상 결정 로직 (변경 없음)
    final Color effectiveBorderColor = isEnded ? Colors.grey[300]! : event.statusColor;
    final double effectiveBorderWidth = isEnded ? 1.0 : 3.0;
    final bool isHighlighted = event.status == EventStatus.active || event.status == EventStatus.rewardPeriod;


    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isHighlighted ? 4 : 1,
        shadowColor: isHighlighted ? effectiveBorderColor.withOpacity(0.3) : Colors.black.withOpacity(0.05),
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
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 제목과 상태
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 상태 아이콘
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

                    // 2. 중앙: 제목과 내용 (D-Day 삭제)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🎯 제목만 남음 (이전 D-Day 텍스트 제거)
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isEnded ? Colors.grey : Colors.black87,
                              decoration: isEnded ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 4),

                          // 2-3. 내용
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

                    // 3. 🎯 우측 상단 상태 배지 (최종 D-Day 강조 영역)
                    if (!isEnded) // 종료된 이벤트가 아닐 때만 D-Day 강조 표시
                      Container(
                        // 💡 D-Day 강조를 위한 디자인 변경
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 패딩 키움
                        decoration: BoxDecoration(
                          color: ddayInfo['color'], // D-Day 색상을 배경색으로 사용
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [ // 💡 그림자 추가로 눈에 더 잘 띄게 강조

                          ],
                        ),
                        child: Text(
                          ddayInfo['text'], // D-Day 텍스트 표시 (예: D-6, 보상 D-3)
                          style: TextStyle(
                            color: Colors.white, // 흰색 텍스트로 대비 강조
                            fontSize: 14, // 폰트 크기
                            fontWeight: FontWeight.w900, // 가장 굵게
                          ),
                        ),
                      )
                    else // 종료된 이벤트는 '종료됨' 상태 배지를 작게 표시
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[400]!,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '종료됨',
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

                // 하단: 기간 정보 (변경 없음)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildDateInfo(
                        icon: Icons.play_arrow_rounded,
                        date: event.startDate,
                        color: Color(0xFF2196F3),
                      ),
                      // 버전 1 (진행률 바) 사용
                      Expanded(
                        child: _buildProgressBar(event),
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

                // 관리자 액션 (변경 없음)
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

// 🎨 이벤트 기간(시작~종료일)만 100%로 표시하는 진행 바
  Widget _buildProgressBar(Event event) {
    final now = DateTime.now();
    final isUpcoming = event.status == EventStatus.upcoming;
    final isReward = event.status == EventStatus.rewardPeriod;
    final isEnded = event.status == EventStatus.ended;

    // 전체 기간 = 시작일 ~ 종료일만 (100%)
    final totalDuration = event.endDate.difference(event.startDate).inDays;

    // 진행률 계산 (0.0 ~ 1.0)
    double progress = 0.0;
    if (totalDuration > 0) {
      final elapsed = now.difference(event.startDate).inDays;
      progress = (elapsed / totalDuration).clamp(0.0, 1.0);
    }

    // 진행 예정 이벤트는 0%
    if (isUpcoming) {
      progress = 0.0;
    }
    // 보상 기간이나 종료된 경우는 100% 채움
    else if (isReward || isEnded) {
      progress = 1.0;
    }


    // 현재 상태에 따른 색상
    Color activeColor;
    if (isEnded) {
      activeColor = Colors.grey[400]!; // 완전 종료
    } else if (isReward) {
      activeColor = Color(0xFFFFC107); // 보상 기간: 노랑
    } else if (isUpcoming) {
      activeColor = Colors.grey[400]!; // 시작 예정
    } else if (event.status == EventStatus.active) {
      // D-Day 정보에서 계산된 색상을 사용하도록 단순화할 수 있으나, 현재 로직을 유지합니다.
      final remaining = event.endDate.difference(now).inDays;
      if (remaining <= 1) {
        activeColor = Color(0xFFF44336); // 1일 이하: 빨강
      } else if (remaining <= 3) {
        activeColor = Color(0xFFFF9800); // 3일 이하: 주황
      } else if (remaining <= 7) {
        activeColor = Color(0xFFFFC107); // 7일 이하: 노랑
      } else {
        activeColor = Color(0xFF2196F3); // 7일 이상: 파랑
      }
    } else {
      activeColor = Color(0xFF2196F3); // 기본값 (다른 상태가 있을 경우 대비)
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      height: 4,
      child: Stack(
        children: [
          // 배경 (회색)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 현재 진행 상황 (색상 바)
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
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