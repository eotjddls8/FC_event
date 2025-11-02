import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/prize_model.dart';
import '../services/prize_service.dart';
import '../theme/fifa_theme.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';  // ← 이 줄 추가
import 'package:cloud_firestore/cloud_firestore.dart';  // ← 이 줄 추가



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
  File? _selectedImage;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_selectedImage == null) return '';  // 빈 문자열 반환

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('prizes/$fileName.jpg');

    await ref.putFile(_selectedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartDate ? _startDate : _endDate),
      );

      if (pickedTime != null) {
        final newDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStartDate) {
            _startDate = newDateTime;
            // 시작일이 종료일보다 늦으면 종료일을 조정
            if (_startDate.isAfter(_endDate)) {
              _endDate = _startDate.add(Duration(days: 7));
            }
          } else {
            if (newDateTime.isAfter(_startDate)) {
              _endDate = newDateTime;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('종료일은 시작일보다 늦어야 합니다')),
              );
            }
          }
        });
      }
    }
  }

  Future<void> _createPrize() async {
    // 🔍 디버그 정보 출력
    final user = FirebaseAuth.instance.currentUser;
    print('=== 디버그 정보 ===');
    print('Firebase UID: ${user?.uid}');
    print('Firebase Email: ${user?.email}');

    // Firestore에서 직접 사용자 정보 확인
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      print('Firestore 문서 존재: ${userDoc.exists}');
      if (userDoc.exists) {
        final userData = userDoc.data();
        print('Firestore 데이터: $userData');
        print('isAdmin 값: ${userData?['isAdmin']}');
        print('role 값: ${userData?['role']}');
      }
    } catch (e) {
      print('Firestore 조회 오류: $e');
    }
    print('==================');

    if (!_formKey.currentState!.validate()) return;
    // ... 기존 코드 계속
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 이미지 업로드 (선택사항)
      String imageUrl = '';
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }

      // 상품 생성
      await PrizeService.createPrize(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        tier: _selectedTier,
        startDate: _startDate,
        endDate: _endDate,
        maxParticipants: int.parse(_maxParticipantsController.text),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('상품이 성공적으로 등록되었습니다'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
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
      appBar: AppBar(
        title: Text('상품 등록'),
        backgroundColor: FifaColors.primary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPrize,
            child: Text(
              '등록',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상품 이미지
              Text(
                '상품 이미지',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '이미지를 선택해주세요 (선택사항)',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // 상품 제목
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '상품 제목',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '상품 제목을 입력해주세요';
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

              // 상품 티어
              Text(
                '상품 티어',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<PrizeTier>(
                  value: _selectedTier,
                  isExpanded: true,
                  underline: SizedBox(),
                  onChanged: (PrizeTier? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTier = newValue;
                      });
                    }
                  },
                  items: PrizeTier.values.map((tier) {
                    return DropdownMenuItem<PrizeTier>(
                      value: tier,
                      child: Row(
                        children: [
                          Text(tier.emoji),
                          SizedBox(width: 8),
                          Text(tier.name.toUpperCase()),
                          SizedBox(width: 8),
                          Text('(광고 ${tier.requiredAdViews}회, ${tier.valueDisplay})'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 16),

              // 최대 참가자 수
              TextFormField(
                controller: _maxParticipantsController,
                decoration: InputDecoration(
                  labelText: '최대 참가자 수',
                  border: OutlineInputBorder(),
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
              SizedBox(height: 16),

              // 시작일
              Text(
                '시작일',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, true),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today),
                      SizedBox(width: 8),
                      Text(
                        '${_startDate.year}년 ${_startDate.month}월 ${_startDate.day}일 ${_startDate.hour.toString().padLeft(2, '0')}:${_startDate.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 종료일
              Text(
                '종료일',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, false),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today),
                      SizedBox(width: 8),
                      Text(
                        '${_endDate.year}년 ${_endDate.month}월 ${_endDate.day}일 ${_endDate.hour.toString().padLeft(2, '0')}:${_endDate.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),

              // 티어 정보 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택된 티어: ${_selectedTier.emoji} ${_selectedTier.name.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• 필요 광고 시청 횟수: ${_selectedTier.requiredAdViews}회'),
                    Text('• 상품 가치: ${_selectedTier.valueDisplay}'),
                    Text('• 사용자는 광고를 ${_selectedTier.requiredAdViews}번 시청한 후 응모할 수 있습니다'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}