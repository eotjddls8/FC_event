import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('회원가입 시도: ${_emailController.text.trim()}');

      UserModel? user = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      print('회원가입 결과 - user: $user');

      // 회원가입 성공 처리 (user가 null이 아니면 성공)
      if (user != null && mounted) {
        // Firebase Auth에서 자동 로그인되므로 로그아웃 처리
        try {
          await _authService.signOut();
          print('자동 로그인 해제 완료');
        } catch (signOutError) {
          print('로그아웃 중 오류 (무시 가능): $signOutError');
        }

        // 회원가입 성공 알림 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('회원가입이 완료되었습니다! 로그인해주세요.'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 잠시 대기 후 로그인 화면으로 돌아가기
        await Future.delayed(Duration(milliseconds: 1000));

        if (mounted) {
          Navigator.pop(context); // 로그인 화면으로 돌아가기
        }
      } else if (mounted) {
        // user가 null인 경우 (예상치 못한 상황)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Text('회원가입 처리 중 문제가 발생했습니다. 로그인을 시도해보세요.'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('회원가입 중 예외 발생: $e');

      if (mounted) {
        String errorMessage = '회원가입 실패';
        Color backgroundColor = Colors.red;
        IconData iconData = Icons.error;

        // 특정 오류 메시지 확인
        String errorString = e.toString().toLowerCase();

        if (errorString.contains('email-already-in-use') ||
            errorString.contains('이미 사용 중인 이메일')) {
          errorMessage = '이미 사용 중인 이메일입니다';
        } else if (errorString.contains('weak-password') ||
            errorString.contains('너무 약합니다')) {
          errorMessage = '비밀번호가 너무 약합니다 (6자 이상)';
        } else if (errorString.contains('invalid-email') ||
            errorString.contains('이메일 형식')) {
          errorMessage = '올바르지 않은 이메일 형식입니다';
        } else if (errorString.contains('network-request-failed')) {
          errorMessage = '네트워크 연결을 확인해주세요';
        } else {
          // 기타 모든 오류는 일반적인 안내로 처리
          errorMessage = '회원가입 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(iconData, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: backgroundColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.sports_soccer, color: FifaColors.accent),
            SizedBox(width: 8),
            Text('회원가입'),
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
              SizedBox(height: 20),

              // 헤더
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: FifaColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sports_soccer,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'FC 이벤트 알림',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: FifaColors.primary,
                      ),
                    ),
                    Text(
                      '회원가입하고 이벤트 소식을 받아보세요!',
                      style: TextStyle(
                        color: FifaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),

              // 이름
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: FifaColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.person, color: FifaColors.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력해주세요';
                  }
                  if (value.trim().length < 2) {
                    return '이름은 2자 이상이어야 합니다';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // 이메일
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: FifaColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.email, color: FifaColors.primary),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return '올바른 이메일 형식이 아닙니다';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // 비밀번호
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: FifaColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock, color: FifaColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '비밀번호를 입력해주세요';
                  }
                  if (value.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // 비밀번호 확인
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: FifaColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: FifaColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '비밀번호 확인을 입력해주세요';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다';
                  }
                  return null;
                },
              ),

              SizedBox(height: 32),

              // 회원가입 버튼
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signUp,
                  icon: _isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.person_add),
                  label: Text(
                    _isLoading ? '가입 중...' : '회원가입',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FifaColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // 로그인 페이지로 이동
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    '이미 계정이 있으신가요? 로그인하기',
                    style: TextStyle(color: FifaColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}