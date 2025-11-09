// lib/screens/login_screen.dart - 이메일 인증 제거 + 오류 메시지 수정 버전

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import 'event_list_screen.dart';
import 'signup_screen.dart';
import 'main_navigation_screen.dart';
import '../widgets/google_sign_in_button.dart';

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

  void _showLoginError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('로그인 정보가 올바르지 않습니다.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      print('로그인 결과: $result');

      if (result['success'] == true && mounted) {
        // 로그인 성공
        final UserModel? user = result['user'];
        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigationScreen(currentUser: user),
            ),
          );
        }
      } else {
        _showLoginError();
      }

    } catch (e) {
      print('로그인 에러: $e');
      _showLoginError();
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
            Text(
              '로그인',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
                '피온 이벤트 알림',
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
                    _isLoading ? '로그인 중...' : '로그인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FifaColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),


              ///구글 계정 로그인
              GoogleSignInButton(
                  isLoading: _isLoading,
                  onPressed: () async {
                    if (_isLoading) return;
                    setState(() => _isLoading = true);

                    try {
                      // 1) Google 계정 선택 → Firebase 로그인 → 완성된 UserModel 반환
                      // 💡 NOTE: cred는 이제 완성된 UserModel 객체입니다.
                      final UserModel userModel = await _authService.signInWithGoogle();

                      // 2) 로그인 성공 시 메인으로 이동
                      if (userModel != null && mounted) {

                        // 💡 완성된 userModel 객체를 그대로 전달합니다.
                        // UserModel을 새로 생성하지 않아도 됩니다. (필수 필드 role 누락 방지)
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            // userModel을 MainNavigationScreen의 currentUser에 전달
                            builder: (context) => MainNavigationScreen(currentUser: userModel),
                          ),
                        );
                      } else {
                        // userModel이 null인 경우 (예: 로그인 취소/실패)
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      // AuthService에서 던진 Exception 메시지를 사용자에게 보여줍니다.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Google 로그인 오류: ${e.toString()}')),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
              ),


              SizedBox(height: 24),

              // 회원가입 버튼
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
                    style: TextStyle(
                      color: FifaColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
