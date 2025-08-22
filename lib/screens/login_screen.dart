import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import 'event_list_screen.dart';
import 'signup_screen.dart'; // 추가
import 'main_navigation_screen.dart'; // 🎯 이 줄 추가!



class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // signIn 메서드에서 UserModel을 반환받음
      final user = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      print('로그인 결과: $user'); // 디버그

      // 로그인 성공 시 화면 전환
      if (user != null && mounted) {
        print('화면 전환 시도'); // 디버그
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(currentUser: user),
          ),
        );
      } else {
        print('사용자 정보 없음'); // 디버그
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      }

    } catch (e) {
      print('로그인 에러: $e');
      if (mounted) {
        String errorMessage = '로그인 실패';
        if (e.toString().contains('user-not-found')) {
          errorMessage = '등록되지 않은 이메일입니다';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = '비밀번호가 틀렸습니다';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = '올바르지 않은 이메일 형식입니다';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = '너무 많은 시도입니다. 잠시 후 다시 시도해주세요';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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

  void _setTestAccount(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.sports_soccer, color: FifaColors.accent),
            SizedBox(width: 8),
            Text('로그인',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,  // 👈 이 줄 추가!
              ),),
          ],
        ),
        backgroundColor: FifaColors.primary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40),

              // FIFA 로고
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FifaColors.primary, FifaColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FifaColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sports_soccer,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              Text(
                'FC 이벤트 알림',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: FifaColors.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '최신 이벤트 소식을 받아보세요!',
                style: TextStyle(
                  fontSize: 16,
                  color: FifaColors.textSecondary,
                ),
              ),

              SizedBox(height: 40),

              // 이메일 입력
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  if (!value.contains('@')) {
                    return '올바른 이메일 형식이 아닙니다';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // 비밀번호 입력
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: FifaColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock, color: FifaColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: FifaColors.primary,
                    ),
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
                  return null;
                },
              ),
              SizedBox(height: 24),

              // 로그인 버튼
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signIn,
                  icon: _isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.login, color: Colors.white),
                  label: Text(
                    _isLoading ? '로그인 중...' : 'FIFA 로그인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,color: Colors.white,),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FifaColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              // 회원가입 버튼 추가
              Container(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignUpScreen()),
                    );
                  },
                  icon: Icon(Icons.person_add, color: FifaColors.secondary),
                  label: Text(
                    '새 계정 만들기',
                    style: TextStyle(color: FifaColors.secondary, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: FifaColors.secondary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32),

              // 구분선
              // Row(
              //   children: [
              //     Expanded(child: Divider()),
              //     Padding(
              //       padding: EdgeInsets.symmetric(horizontal: 16),
              //       child: Text(
              //         '또는',
              //         style: TextStyle(color: FifaColors.textSecondary),
              //       ),
              //     ),
              //     Expanded(child: Divider()),
              //   ],
              // ),
              //
              // SizedBox(height: 16),
              // Text(
              //   '테스트 계정으로 빠른 로그인',
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     color: FifaColors.textPrimary,
              //   ),
              // ),
              // SizedBox(height: 12),
              //
              // Row(
              //   children: [
              //     Expanded(
              //       child: OutlinedButton.icon(
              //         onPressed: () => _setTestAccount('admin@test.com', '123456'),
              //         icon: Icon(Icons.admin_panel_settings, size: 16),
              //         label: Text('관리자'),
              //         style: OutlinedButton.styleFrom(
              //           padding: EdgeInsets.symmetric(vertical: 8),
              //           side: BorderSide(color: FifaColors.primary),
              //         ),
              //       ),
              //     ),
              //     SizedBox(width: 8),
              //     Expanded(
              //       child: OutlinedButton.icon(
              //         onPressed: () => _setTestAccount('user@test.com', '123456'),
              //         icon: Icon(Icons.person, size: 16),
              //         label: Text('일반 사용자'),
              //         style: OutlinedButton.styleFrom(
              //           padding: EdgeInsets.symmetric(vertical: 8),
              //           side: BorderSide(color: FifaColors.primary),
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}