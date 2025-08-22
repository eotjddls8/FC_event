import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import '../services/rewarded_ad_service.dart';
import '../services/admob_service.dart';
import 'event_write_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  final UserModel? currentUser;

  EventDetailScreen({required this.event, this.currentUser});

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late int _likes;
  late List<String> _likedUsers;

  @override
  void initState() {
    super.initState();
    _likes = widget.event.likes;
    _likedUsers = List<String>.from(widget.event.likedUsers);
  }

  bool get _hasUserLiked {
    if (widget.currentUser == null) return false;
    return _likedUsers.contains(widget.currentUser!.email);
  }

  bool get _canLike {
    return widget.currentUser != null && !_hasUserLiked;
  }

  Future<void> _toggleLike() async {
    if (!_canLike) return;

    try {
      final userEmail = widget.currentUser!.email;
      final newLikes = _likes + 1;
      final updatedLikedUsers = [..._likedUsers, userEmail];

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({
        'likes': newLikes,
        'likedUsers': updatedLikedUsers,
      });

      setState(() {
        _likes = newLikes;
        _likedUsers = updatedLikedUsers;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _editEvent() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventWriteScreen(
          currentUser: widget.currentUser!,
          editEvent: widget.event,
        ),
      ),
    );
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('이벤트 삭제'),
          ],
        ),
        content: Text('정말로 이 FIFA 이벤트를 삭제하시겠습니까?\n삭제된 이벤트는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event.id)
            .delete();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('FIFA 이벤트가 삭제되었습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.event.statusColor, widget.event.statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.event.statusColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            widget.event.status == EventStatus.active ? Icons.sports_soccer :
            widget.event.status == EventStatus.upcoming ? Icons.schedule :
            Icons.event_busy,
            size: 48,
            color: Colors.white,
          ),
          SizedBox(height: 12),
          Text(
            widget.event.statusText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          if (widget.event.status == EventStatus.active) ...[
            Text(
              '이벤트 진행 중!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ] else if (widget.event.status == EventStatus.upcoming) ...[
            Text(
              '곧 시작됩니다',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ] else ...[
            Text(
              '이벤트가 종료되었습니다',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: FifaColors.primary),
              SizedBox(width: 8),
              Text(
                '이벤트 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FifaColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          _buildInfoRow(Icons.play_arrow, '시작일', _formatDate(widget.event.startDate)),
          _buildInfoRow(Icons.stop, '종료일', _formatDate(widget.event.endDate)),
          _buildInfoRow(Icons.person, '작성자', widget.event.author),
          _buildInfoRow(Icons.access_time, '등록일',
              '${_formatDate(widget.event.createdAt)} ${_formatTime(widget.event.createdAt)}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FifaColors.primary),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: FifaColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: FifaColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton() {
    if (widget.currentUser == null) {
      return Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(Icons.favorite_border, color: Colors.grey),
          label: Text('로그인 후 좋아요 가능 ($_likes)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    } else if (_hasUserLiked) {
      return Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(Icons.favorite, color: Colors.white),
          label: Text('좋아요 완료! ($_likes)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _toggleLike,
          icon: Icon(Icons.favorite_border),
          label: Text('이 이벤트가 좋아요! ($_likes)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FifaColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  /* 광고 관련 추첨 버튼 및 메서드들 주석처리
  Widget _buildLotteryButton() {
    // 비로그인이거나 관리자는 추첨 참여 불가
    if (widget.currentUser == null) {
      // 일반 사용자 - 추첨 참여 가능
      return Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: RewardedAdService.isReady ? _participateInLottery : null,
          icon: RewardedAdService.isReady
              ? Icon(Icons.card_giftcard)
              : SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: Text(
            RewardedAdService.isReady
                ? '🎁 광고 보고 추첨 참여하기'
                : '광고 로딩 중...',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: RewardedAdService.isReady ? FifaColors.accent : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (widget.currentUser!.isAdmin) {
      return Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(Icons.admin_panel_settings, color: Colors.grey),
          label: Text('관리자는 추첨 참여 불가'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // 이벤트가 종료되었으면 추첨 불가
    if (widget.event.status == EventStatus.ended) {
      return Container(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: Icon(Icons.event_busy, color: Colors.grey),
          label: Text('종료된 이벤트'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // 일반 사용자 - 추첨 참여 가능
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _participateInLottery,
        icon: Icon(Icons.card_giftcard),
        label: Text('🎁 광고 보고 추첨 참여하기'),
        style: ElevatedButton.styleFrom(
          backgroundColor: FifaColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // 추첨 참여 메서드
  Future<void> _participateInLottery() async {
    // 관리자는 광고 안 봄
    if (!AdMobService.shouldShowAds(widget.currentUser?.role)) {
      _showLotteryResult();
      return;
    }

    // 광고 준비 확인
    if (!RewardedAdService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('광고가 준비 중입니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    try {
      // 광고 시청 확인 다이얼로그
      final shouldWatch = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.video_collection, color: FifaColors.accent),
              SizedBox(width: 8),
              Text('추첨 참여'),
            ],
          ),
          content: Text('추첨에 참여하려면 광고를 시청해야 합니다.\n광고를 시청하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: FifaColors.accent),
              child: Text('광고 시청', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldWatch != true) return;

      // 광고 시청
      final rewardEarned = await RewardedAdService.showRewardedAd();

      if (rewardEarned) {
        // 광고 시청 완료 - 추첨 진행
        _showLotteryResult();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('광고를 끝까지 시청해야 추첨에 참여할 수 있습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // 추첨 결과 표시
  void _showLotteryResult() {
    // 간단한 추첨 로직 (10% 확률로 당첨)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    final isWinner = random < 10; // 10% 확률

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isWinner ? Icons.celebration : Icons.sentiment_dissatisfied,
              color: isWinner ? FifaColors.accent : Colors.grey,
            ),
            SizedBox(width: 8),
            Text(isWinner ? '🎉 당첨!' : '😢 아쉽네요'),
          ],
        ),
        content: Text(
          isWinner
              ? '축하합니다! FIFA 이벤트에 당첨되었습니다!'
              : '아쉽게도 당첨되지 않았습니다. 다음 기회에 도전해보세요!',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isWinner ? FifaColors.accent : FifaColors.primary,
            ),
            child: Text('확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.sports_soccer, color: FifaColors.accent),
            SizedBox(width: 8),
            Text('이벤트 내용',  style: TextStyle(
              color: Colors.white,      // 빨간색

            ),),
          ],
        ),
        backgroundColor: FifaColors.primary,
        actions: [
          if (widget.currentUser?.isAdmin == true) ...[
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _editEvent,
              tooltip: '수정',
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteEvent,
              tooltip: '삭제',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 카드
            _buildStatusCard(),

            SizedBox(height: 24),

            // 제목
            Text(
              widget.event.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FifaColors.textPrimary,
              ),
            ),

            SizedBox(height: 16),

            // 이벤트 정보
            _buildEventInfo(),

            SizedBox(height: 24),

            // 내용
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: FifaColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '이벤트 내용',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: FifaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    widget.event.content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: FifaColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 좋아요 버튼
            _buildLikeButton(),

            /* 추첨 버튼 주석처리
            SizedBox(height: 16),

            // 추첨 버튼
            _buildLotteryButton(),
            */

            SizedBox(height: 16),

            // 사용자 상태 표시
            if (widget.currentUser != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FifaColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.currentUser!.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      size: 16,
                      color: FifaColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${widget.currentUser!.name}님으로 로그인 중 (${widget.currentUser!.isAdmin ? '관리자' : '일반 사용자'})',
                      style: TextStyle(
                        fontSize: 12,
                        color: FifaColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}