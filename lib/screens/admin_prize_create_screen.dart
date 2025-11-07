import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prize_model.dart';
import '../services/prize_service.dart';
import '../theme/fifa_theme.dart';

class AdminPrizeCreateScreen extends StatefulWidget {
  @override
  _AdminPrizeCreateScreenState createState() => _AdminPrizeCreateScreenState();
}

class _AdminPrizeCreateScreenState extends State<AdminPrizeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  PrizeTier _selectedTier = PrizeTier.bronze;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.add, color: Colors.white),
            SizedBox(width: 8),
            Text('새 상품 등록'),
          ],
        ),
        backgroundColor: FifaColors.primary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 티어 선택 카드 (시각적 개선)
              Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상품 티어',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PrizeTier.values.map((tier) {
                            final isSelected = _selectedTier == tier;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedTier = tier),
                              child: Container(
                                margin: EdgeInsets.only(right: 12),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? _getTierColor(tier) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? _getTierColor(tier) : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      tier.emoji,
                                      style: TextStyle(fontSize: 24),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      tier.name.toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${tier.requiredAdViews}회',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 상품명
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '상품명',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '상품명을 입력해주세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // 상품 설명
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: '상품 설명',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '상품 설명을 입력해주세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // 최대 참가자 수
              TextFormField(
                controller: _maxParticipantsController,
                decoration: InputDecoration(
                  labelText: '최대 참가자 수',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '최대 참가자 수를 입력해주세요';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return '올바른 숫자를 입력해주세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // 시작일
              Card(
                child: ListTile(
                  leading: Icon(Icons.calendar_today, color: FifaColors.primary),
                  title: Text('시작일'),
                  subtitle: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'),
                  onTap: () => _selectStartDate(),
                ),
              ),
              SizedBox(height: 8),

              // 종료일
              Card(
                child: ListTile(
                  leading: Icon(Icons.calendar_today_outlined, color: FifaColors.primary),
                  title: Text('종료일'),
                  subtitle: Text('${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}'),
                  onTap: () => _selectEndDate(),
                ),
              ),
              SizedBox(height: 32),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createPrize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FifaColors.primary,
                  ),
                  child: _isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('등록 중...', style: TextStyle(color: Colors.white)),
                    ],
                  )
                      : Text(
                    '상품 등록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  // 티어별 색상 함수
  Color _getTierColor(PrizeTier tier) {
    switch (tier) {
      case PrizeTier.bronze:
        return Colors.orange;
      case PrizeTier.silver:
        return Colors.grey;
      case PrizeTier.gold:
        return Colors.amber;
      case PrizeTier.diamond:
        return Colors.purple;
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _startDate.add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createPrize() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 상품 생성 (이미지 URL 없이)
      await PrizeService.createPrize(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: '', // 항상 빈 문자열
        tier: _selectedTier,
        startDate: _startDate,
        endDate: _endDate,
        maxParticipants: int.parse(_maxParticipantsController.text),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('상품이 성공적으로 등록되었습니다'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('오류가 발생했습니다: $e')),
            ],
          ),
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }
}