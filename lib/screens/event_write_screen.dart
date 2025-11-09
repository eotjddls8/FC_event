import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';

class EventWriteScreen extends StatefulWidget {
  final UserModel currentUser;
  final Event? editEvent;

  const EventWriteScreen({
    Key? key,
    required this.currentUser,
    this.editEvent,
  }) : super(key: key);

  @override
  _EventWriteScreenState createState() => _EventWriteScreenState();
}

class _EventWriteScreenState extends State<EventWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  DateTime? _selectedRewardEndDate; // 🎯 보상 종료 날짜 추가
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.editEvent != null) {
      _titleController.text = widget.editEvent!.title;
      _contentController.text = widget.editEvent!.content;
      _selectedStartDate = widget.editEvent!.startDate;
      _selectedEndDate = widget.editEvent!.endDate;
      _selectedRewardEndDate = widget.editEvent!.rewardEndDate;
    } else {
      // 기본값 설정
      _selectedStartDate = DateTime.now();
      _selectedEndDate = DateTime.now().add(Duration(days: 7));
      _selectedRewardEndDate = DateTime.now().add(Duration(days: 14));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 🗓️ 날짜 선택기
  Future<void> _selectDate({
    required BuildContext context,
    required String dateType,
  }) async {
    DateTime initialDate;
    String helpText;

    switch (dateType) {
      case 'start':
        initialDate = _selectedStartDate ?? DateTime.now();
        helpText = '이벤트 시작 날짜';
        break;
      case 'end':
        initialDate = _selectedEndDate ?? DateTime.now().add(Duration(days: 7));
        helpText = '이벤트 종료 날짜';
        break;
      case 'reward':
        initialDate = _selectedRewardEndDate ?? DateTime.now().add(Duration(days: 14));
        helpText = '보상 수령 마감 날짜';
        break;
      default:
        return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: helpText,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: FifaColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        switch (dateType) {
          case 'start':
            _selectedStartDate = picked;
            // 연쇄적으로 날짜 조정
            if (_selectedEndDate != null && picked.isAfter(_selectedEndDate!)) {
              _selectedEndDate = picked.add(Duration(days: 7));
            }
            if (_selectedRewardEndDate != null && _selectedEndDate != null &&
                _selectedEndDate!.isAfter(_selectedRewardEndDate!)) {
              _selectedRewardEndDate = _selectedEndDate!.add(Duration(days: 7));
            }
            break;
          case 'end':
            _selectedEndDate = picked;
            // 시작일보다 빠르면 조정
            if (_selectedStartDate != null && picked.isBefore(_selectedStartDate!)) {
              _selectedStartDate = picked.subtract(Duration(days: 1));
            }
            // 보상 종료일보다 늦으면 조정
            if (_selectedRewardEndDate != null && picked.isAfter(_selectedRewardEndDate!)) {
              _selectedRewardEndDate = picked.add(Duration(days: 7));
            }
            break;
          case 'reward':
            _selectedRewardEndDate = picked;
            // 종료일보다 빠르면 조정
            if (_selectedEndDate != null && picked.isBefore(_selectedEndDate!)) {
              _selectedEndDate = picked.subtract(Duration(days: 1));
              if (_selectedStartDate != null && _selectedEndDate!.isBefore(_selectedStartDate!)) {
                _selectedStartDate = _selectedEndDate!.subtract(Duration(days: 1));
              }
            }
            break;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '날짜를 선택하세요';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStartDate == null || _selectedEndDate == null || _selectedRewardEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모든 날짜를 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'author': widget.currentUser.email,
        'startDate': Timestamp.fromDate(_selectedStartDate!),
        'endDate': Timestamp.fromDate(_selectedEndDate!),
        'rewardEndDate': Timestamp.fromDate(_selectedRewardEndDate!), // 🎯 추가
        'likes': widget.editEvent?.likes ?? 0,
        'likedUsers': widget.editEvent?.likedUsers ?? [],
      };

      if (widget.editEvent != null) {
        eventData['createdAt'] = Timestamp.fromDate(widget.editEvent!.createdAt);
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.editEvent!.id)
            .update(eventData);
      } else {
        eventData['createdAt'] = Timestamp.fromDate(DateTime.now());
        await FirebaseFirestore.instance.collection('events').add(eventData);
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.editEvent != null ? '이벤트 수정' : '새 이벤트 만들기',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 입력
              _buildInputSection(
                icon: Icons.title_rounded,
                title: '이벤트 제목',
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: '매력적인 이벤트 제목을 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '제목을 입력해주세요';
                    }
                    return null;
                  },
                ),
              ),

              // 내용 입력
              _buildInputSection(
                icon: Icons.description_rounded,
                title: '이벤트 내용',
                child: TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: '이벤트 상세 내용을 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  maxLines: 6,
                  maxLength: 500,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '내용을 입력해주세요';
                    }
                    return null;
                  },
                ),
              ),

              // 🎯 3단계 날짜 선택 섹션
              _buildInputSection(
                icon: Icons.calendar_month_rounded,
                title: '이벤트 기간 설정',
                child: Column(
                  children: [
                    // 시작 날짜
                    _buildDateSelector(
                      label: '이벤트 시작',
                      date: _selectedStartDate,
                      color: Color(0xFF2196F3),
                      icon: Icons.play_arrow_rounded,
                      onTap: () => _selectDate(context: context, dateType: 'start'),
                    ),
                    SizedBox(height: 12),

                    // 종료 날짜
                    _buildDateSelector(
                      label: '이벤트 종료',
                      date: _selectedEndDate,
                      color: Color(0xFFF44336),
                      icon: Icons.stop_rounded,
                      onTap: () => _selectDate(context: context, dateType: 'end'),
                    ),
                    SizedBox(height: 12),

                    // 보상 종료 날짜
                    _buildDateSelector(
                      label: '보상 수령 마감',
                      date: _selectedRewardEndDate,
                      color: Color(0xFFFFC107),
                      icon: Icons.card_giftcard_rounded,
                      onTap: () => _selectDate(context: context, dateType: 'reward'),
                    ),
                  ],
                ),
              ),

              // 기간 미리보기
              if (_selectedStartDate != null &&
                  _selectedEndDate != null &&
                  _selectedRewardEndDate != null)
                _buildPeriodPreview(),

              SizedBox(height: 32),

              // 저장 버튼
              Container(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FifaColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.editEvent != null ? '수정 완료' : '이벤트 생성',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: FifaColors.primary),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: date != null ? Colors.black87 : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_today_rounded, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodPreview() {
    final eventDuration = _selectedEndDate!.difference(_selectedStartDate!).inDays + 1;
    final rewardDuration = _selectedRewardEndDate!.difference(_selectedEndDate!).inDays;
    final totalDuration = _selectedRewardEndDate!.difference(_selectedStartDate!).inDays + 1;

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFFFF9C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 20, color: FifaColors.primary),
              SizedBox(width: 8),
              Text(
                '이벤트 기간 요약',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FifaColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildPeriodRow('이벤트 진행', eventDuration, Color(0xFF2196F3)),
          SizedBox(height: 8),
          _buildPeriodRow('보상 수령', rewardDuration, Color(0xFFFFC107)),
          SizedBox(height: 8),
          Divider(color: Colors.grey[400]),
          SizedBox(height: 8),
          _buildPeriodRow('전체 기간', totalDuration, Colors.grey[700]!),
        ],
      ),
    );
  }

  Widget _buildPeriodRow(String label, int days, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        Text(
          '$days일',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}