// admin_prize_create_screen.dart (전체 코드)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/prize_model.dart';
import '../services/prize_service.dart';
import '../theme/fifa_theme.dart';

class AdminPrizeCreateScreen extends StatefulWidget {
  final PrizeModel? prizeToEdit; // ⭐ 편집할 상품 데이터 (옵션)

  const AdminPrizeCreateScreen({Key? key, this.prizeToEdit}) : super(key: key);

  @override
  _AdminPrizeCreateScreenState createState() => _AdminPrizeCreateScreenState();
}

class _AdminPrizeCreateScreenState extends State<AdminPrizeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requiredCoinsController = TextEditingController(); // ⭐ 이름 변경 (maxParticipants -> requiredCoins)
  //final _maxParticipantsController = TextEditingController();

  PrizeTier _selectedTier = PrizeTier.bronze;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));
  bool _isLoading = false;

  // ⭐ 편집 모드인지 확인하는 변수
  bool get _isEditing => widget.prizeToEdit != null;

  @override
  void initState() {
    super.initState();
    // ⭐ 편집 모드 시 기존 데이터로 컨트롤러 초기화
    if (_isEditing) {
      final prize = widget.prizeToEdit!;
      _titleController.text = prize.title;
      _descriptionController.text = prize.description;
      _requiredCoinsController.text = prize.requiredCoins.toString();
     // _maxParticipantsController.text = prize.maxParticipants.toString();
      _selectedTier = prize.tier;
      _startDate = prize.startDate;
      _endDate = prize.endDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requiredCoinsController.dispose();
    //_maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ⭐ 등록/수정 함수 (수정됨)
  Future<void> _createOrUpdatePrize() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String title = _titleController.text.trim();
      final String description = _descriptionController.text.trim();
      final int requiredCoins = int.parse(_requiredCoinsController.text.trim());
      //final int maxParticipants = int.parse(_maxParticipantsController.text.trim());

      if (_isEditing) {
        // --- 수정 ---
        await PrizeService.updatePrize(
          prizeId: widget.prizeToEdit!.id,
          title: title,
          description: description,
          tier: _selectedTier,
          startDate: _startDate,
          endDate: _endDate,
          //maxParticipants: maxParticipants,
          requiredCoins: requiredCoins,
          // imageUrl은 이 폼에서 수정하지 않는다고 가정
        );
        _showSnackbar('상품이 성공적으로 수정되었습니다', Colors.green);

      } else {
        // --- 새로 등록 ---
        await PrizeService.createPrize(
          title: title,
          description: description,
          tier: _selectedTier,
          requiredCoins: requiredCoins, // ⭐ requiredCoins 전달
          //maxParticipants: maxParticipants,
          startDate: _startDate,
          endDate: _endDate,
          imageUrl: '', // 이미지 URL이 있다면 추가 (현재 폼에는 없음)
        );
        _showSnackbar('상품이 성공적으로 등록되었습니다', Colors.green);
      }

      Navigator.pop(context, true); // true를 반환하여 목록 화면이 갱신되도록 함
    } catch (e) {
      _showSnackbar('오류가 발생했습니다: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '상품 수정' : '상품 등록'), // ⭐ 제목 변경
        backgroundColor: FifaColors.primary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildTextFormField(
              controller: _titleController,
              label: '상품명',
              icon: Icons.card_giftcard,
            ),
            SizedBox(height: 16),
            _buildTextFormField(
              controller: _descriptionController,
              label: '설명',
              icon: Icons.description,
              maxLines: 3,
            ),
            SizedBox(height: 16),
            _buildTextFormField(
              controller: _requiredCoinsController,
              label: '필요 코인',
              icon: Icons.monetization_on,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            // _buildTextFormField(
            //   controller: _maxParticipantsController,
            //   label: '최대 참가 인원',
            //   icon: Icons.people,
            //   keyboardType: TextInputType.number,
            // ),
            // SizedBox(height: 16),
            _buildTierDropdown(),
            SizedBox(height: 16),
            _buildDatePicker(
              label: '시작일',
              date: _startDate,
              onPressed: () => _selectDate(context, true),
            ),
            SizedBox(height: 16),
            _buildDatePicker(
              label: '종료일',
              date: _endDate,
              onPressed: () => _selectDate(context, false),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _createOrUpdatePrize,
              style: ElevatedButton.styleFrom(
                backgroundColor: FifaColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isEditing ? '수정 완료' : '등록하기', // ⭐ 버튼 텍스트 변경
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: FifaColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label을(를) 입력해주세요.';
        }
        if (keyboardType == TextInputType.number && int.tryParse(value) == null) {
          return '유효한 숫자를 입력해주세요.';
        }
        return null;
      },
    );
  }

  Widget _buildTierDropdown() {
    return DropdownButtonFormField<PrizeTier>(
      value: _selectedTier,
      decoration: InputDecoration(
        labelText: '상품 티어',
        prefixIcon: Icon(Icons.star, color: FifaColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      items: PrizeTier.values.map((tier) {
        return DropdownMenuItem(
          value: tier,
          child: Text(tier.valueDisplay),
        );
      }).toList(),
      onChanged: (PrizeTier? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedTier = newValue;
          });
        }
      },
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today, color: FifaColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        child: Text(
          DateFormat('yyyy년 MM월 dd일').format(date),
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}