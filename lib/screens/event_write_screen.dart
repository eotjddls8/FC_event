import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';

class EventWriteScreen extends StatefulWidget {
  final UserModel currentUser;
  final Event? editEvent; // 수정할 이벤트 (null이면 새 이벤트)

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // 수정 모드인 경우 기존 데이터 로드
    if (widget.editEvent != null) {
      _titleController.text = widget.editEvent!.title;
      _contentController.text = widget.editEvent!.content;
      _selectedStartDate = widget.editEvent!.startDate;
      _selectedEndDate = widget.editEvent!.endDate;
    } else {
      // 새 이벤트인 경우 기본값 설정
      _selectedStartDate = DateTime.now();
      _selectedEndDate = DateTime.now().add(Duration(days: 7));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 🗓️ 날짜 선택기 (25년 전부터 미래까지)
  Future<void> _selectDate({
    required BuildContext context,
    required bool isStartDate,
  }) async {
    final DateTime initialDate = isStartDate
        ? (_selectedStartDate ?? DateTime.now())
        : (_selectedEndDate ?? DateTime.now().add(Duration(days: 7)));

    final DateTime firstDate = DateTime(1999, 1, 1); // 25년 전
    final DateTime lastDate = DateTime(2099, 12, 31); // 먼 미래까지

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isStartDate ? '시작 날짜 선택' : '종료 날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: FifaColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
          // 시작 날짜가 종료 날짜보다 늦으면 종료 날짜를 시작 날짜 + 1일로 설정
          if (_selectedEndDate != null && picked.isAfter(_selectedEndDate!)) {
            _selectedEndDate = picked.add(Duration(days: 1));
          }
        } else {
          _selectedEndDate = picked;
          // 종료 날짜가 시작 날짜보다 빠르면 시작 날짜를 종료 날짜 - 1일로 설정
          if (_selectedStartDate != null && picked.isBefore(_selectedStartDate!)) {
            _selectedStartDate = picked.subtract(Duration(days: 1));
          }
        }
      });
    }
  }

  // 📅 날짜 표시 포맷
  String _formatDate(DateTime? date) {
    if (date == null) return '날짜를 선택하세요';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // 💾 이벤트 저장
  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시작 날짜와 종료 날짜를 모두 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedStartDate!.isAfter(_selectedEndDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시작 날짜는 종료 날짜보다 빠르거나 같아야 합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final eventData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'author': widget.currentUser.email,
        'startDate': Timestamp.fromDate(_selectedStartDate!),
        'endDate': Timestamp.fromDate(_selectedEndDate!),
        'likes': widget.editEvent?.likes ?? 0,
        'likedUsers': widget.editEvent?.likedUsers ?? [],
      };

      if (widget.editEvent != null) {
        // 수정 모드
        eventData['createdAt'] = Timestamp.fromDate(widget.editEvent!.createdAt);
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.editEvent!.id)
            .update(eventData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이벤트가 수정되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 생성 모드
        eventData['createdAt'] = Timestamp.fromDate(DateTime.now());
        await FirebaseFirestore.instance
            .collection('events')
            .add(eventData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이벤트가 생성되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      print('이벤트 저장 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.editEvent != null ? '이벤트 수정' : '이벤트 작성',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: FifaColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 저장 버튼
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: Text(
              '저장',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: FifaColors.primary),
            SizedBox(height: 16),
            Text('저장 중...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📝 제목 입력
              _buildSectionTitle('이벤트 제목', Icons.title),
              SizedBox(height: 8),
              _buildInputCard(
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: '예: FIFA 월드컵 예측 이벤트',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '제목을 입력해주세요';
                    }
                    if (value.trim().length < 2) {
                      return '제목은 2자 이상 입력해주세요';
                    }
                    return null;
                  },
                  maxLength: 50,
                  style: TextStyle(fontSize: 16),
                ),
              ),

              SizedBox(height: 24),

              // 📄 내용 입력
              _buildSectionTitle('이벤트 내용', Icons.description),
              SizedBox(height: 8),
              _buildInputCard(
                child: TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: '이벤트에 대한 자세한 설명을 입력하세요...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '내용을 입력해주세요';
                    }
                    if (value.trim().length < 3) {
                      return '내용은 3자 이상 입력해주세요';
                    }
                    return null;
                  },
                  maxLines: 5,
                  maxLength: 500,
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ),

              SizedBox(height: 24),

              // 📅 시작 날짜
              _buildSectionTitle('시작 날짜', Icons.event),
              SizedBox(height: 8),
              _buildInputCard(
                child: InkWell(
                  onTap: () => _selectDate(context: context, isStartDate: true),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시작 날짜',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatDate(_selectedStartDate),
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedStartDate != null
                                    ? Colors.black87
                                    : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: FifaColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // 📅 종료 날짜
              _buildSectionTitle('종료 날짜', Icons.event_busy),
              SizedBox(height: 8),
              _buildInputCard(
                child: InkWell(
                  onTap: () => _selectDate(context: context, isStartDate: false),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '종료 날짜',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatDate(_selectedEndDate),
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedEndDate != null
                                    ? Colors.black87
                                    : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: FifaColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              // 📊 이벤트 미리보기
              if (_selectedStartDate != null && _selectedEndDate != null)
                _buildPreviewCard(),

              SizedBox(height: 32),

              // 💾 저장 버튼 (하단)
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FifaColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    widget.editEvent != null ? '수정 완료' : '이벤트 생성',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 섹션 제목 위젯
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: FifaColors.primary, size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: FifaColors.primary,
          ),
        ),
      ],
    );
  }

  // 🎨 입력 카드 위젯
  Widget _buildInputCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // 📊 미리보기 카드
  Widget _buildPreviewCard() {
    final now = DateTime.now();
    final startDate = _selectedStartDate!;
    final endDate = _selectedEndDate!;
    final duration = endDate.difference(startDate).inDays + 1;

    String status;
    Color statusColor;

    if (now.isBefore(startDate)) {
      final daysUntilStart = startDate.difference(now).inDays;
      status = 'D-${daysUntilStart}일 후 시작';
      statusColor = Colors.blue;
    } else if (now.isAfter(endDate)) {
      status = '종료됨';
      statusColor = Colors.grey;
    } else {
      final daysLeft = endDate.difference(now).inDays;
      status = 'D-${daysLeft}일 남음';
      statusColor = daysLeft <= 3 ? Colors.red : Colors.green;
    }

    return _buildInputCard(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: FifaColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  '이벤트 미리보기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FifaColors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '이벤트 기간: ${duration}일',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${_formatDate(startDate)} ~ ${_formatDate(endDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}