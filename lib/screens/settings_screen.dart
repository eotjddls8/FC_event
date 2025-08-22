import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // 🎯 Platform.isAndroid, Platform.isIOS 사용을 위해 추가
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/fifa_theme.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel? currentUser;

  const SettingsScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final InAppReview inAppReview = InAppReview.instance;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _darkMode = false;
  String _language = '한국어';

  // 문의용 정보
  final String _supportEmail = 'eotjddls903@gmail.com';
  final String _adminContact = 'admin@pionevents.com';
  final String _appVersion = '1.0.0';

  // 🎯 앱 평가하기 함수
  Future<void> _rateApp() async {
    try {
      // 먼저 인앱 리뷰 시도 (더 자연스러움)
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        // 인앱 리뷰가 안되면 스토어로 이동
        await inAppReview.openStoreListing();
      }
    } catch (e) {
      // 실패 시 직접 스토어 URL 열기
      await _openStoreDirectly();
    }
  }

  // 🎯 스토어 직접 열기
  Future<void> _openStoreDirectly() async {
    const String androidPackageName = 'com.jonglee.pionevent';
    const String iOSAppId = '123456789'; // 실제 앱 ID로 변경 필요

    try {
      if (Platform.isAndroid) {
        // Google Play Store
        final Uri playStoreUri = Uri.parse('market://details?id=$androidPackageName');
        final Uri playStoreWebUri = Uri.parse('https://play.google.com/store/apps/details?id=$androidPackageName');

        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri);
        } else {
          await launchUrl(playStoreWebUri);
        }
      } else if (Platform.isIOS) {
        // Apple App Store
        final Uri appStoreUri = Uri.parse('itms-apps://itunes.apple.com/app/id$iOSAppId');
        final Uri appStoreWebUri = Uri.parse('https://apps.apple.com/app/id$iOSAppId');

        if (await canLaunchUrl(appStoreUri)) {
          await launchUrl(appStoreUri);
        } else {
          await launchUrl(appStoreWebUri);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('스토어를 열 수 없습니다. 나중에 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🎯 기타 유용한 링크들
  Future<void> _openWebsite(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw '링크를 열 수 없습니다';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('링크를 열 수 없습니다: $e')),
      );
    }
  }

  // 🔧 로그아웃 함수
  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(currentUser: null),
          ),
              (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그아웃 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🗑️ 회원 탈퇴 함수
  Future<void> _deleteAccount() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      // 1. Firestore에서 사용자 데이터 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // 2. 사용자가 작성한 이벤트들 삭제 (관리자인 경우)
      if (widget.currentUser?.isAdmin == true) {
        final userEvents = await FirebaseFirestore.instance
            .collection('events')
            .where('author', isEqualTo: widget.currentUser!.email)
            .get();

        for (var doc in userEvents.docs) {
          await doc.reference.delete();
        }
      }

      // 3. Firebase Auth에서 계정 삭제
      await user.delete();

      // 4. 성공 메시지와 함께 초기 화면으로 이동
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(currentUser: null),
          ),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원 탈퇴가 완료되었습니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('회원 탈퇴 에러: $e');
      String errorMessage = '회원 탈퇴 중 오류가 발생했습니다';

      if (e.toString().contains('requires-recent-login')) {
        errorMessage = '보안을 위해 다시 로그인 후 탈퇴해주세요';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ⚠️ 탈퇴 확인 다이얼로그
  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 바깥 터치로 닫기 방지
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 탈퇴하시겠습니까?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('⚠️ 탈퇴 시 다음 데이터가 삭제됩니다:'),
            SizedBox(height: 8),
            Text('• 계정 정보 (이메일, 이름 등)'),
            Text('• 이벤트 참여 기록'),
            Text('• 좋아요 기록'),
            if (widget.currentUser?.isAdmin == true)
              Text('• 작성한 모든 이벤트', style: TextStyle(color: Colors.red)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '❗ 삭제된 데이터는 복구할 수 없습니다',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('탈퇴하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 최종 확인 다이얼로그
      final finalConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('최종 확인', style: TextStyle(color: Colors.red)),
          content: Text(
            '진짜로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('아니요'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('네, 탈퇴합니다'),
            ),
          ],
        ),
      );

      if (finalConfirmed == true) {
        _deleteAccount();
      }
    }
  }

  // 📋 클립보드 복사 함수
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label이(가) 복사되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🎨 설정 섹션 빌더
  Widget _buildSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 제목
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: FifaColors.primary, size: 20),
                  SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FifaColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // 섹션 내용
          Container(
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
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // 🔗 설정 리스트 아이템
  Widget _buildListTile({
    required String title,
    String? subtitle,
    IconData? leading,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: leading != null
          ? Icon(leading, color: iconColor ?? Colors.grey[600])
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor ?? Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      )
          : null,
      trailing: trailing ??
          (onTap != null ? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '설정',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: FifaColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 🧑‍💼 사용자 정보 섹션
            if (widget.currentUser != null)
              _buildSection(
                title: '계정 정보',
                icon: Icons.person,
                children: [
                  _buildListTile(
                    leading: Icons.account_circle,
                    title: '이름',
                    subtitle: widget.currentUser!.name,
                  ),
                  Divider(height: 1),
                  _buildListTile(
                    leading: Icons.email,
                    title: '이메일',
                    subtitle: widget.currentUser!.email,
                    trailing: IconButton(
                      icon: Icon(Icons.copy, size: 18),
                      onPressed: () => _copyToClipboard(
                        widget.currentUser!.email,
                        '이메일',
                      ),
                    ),
                  ),
                  Divider(height: 1),
                  _buildListTile(
                    leading: Icons.shield,
                    title: '권한',
                    subtitle: widget.currentUser!.role == 'admin' ? '관리자' : '일반 사용자',
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.currentUser!.role == 'admin'
                            ? Colors.orange
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.currentUser!.role == 'admin' ? 'ADMIN' : 'USER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1),
                  // 로그아웃을 권한 밑으로 이동
                  _buildListTile(
                    leading: Icons.logout,
                    title: '로그아웃',
                    subtitle: '현재 계정에서 로그아웃합니다',
                    titleColor: Colors.orange,
                    iconColor: Colors.orange,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('로그아웃'),
                          content: Text('정말로 로그아웃하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('로그아웃', style: TextStyle(color: Colors.orange)),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        _logout();
                      }
                    },
                  ),
                ],
              )
            else
            // 비회원 로그인 유도
              _buildSection(
                title: '계정',
                icon: Icons.login,
                children: [
                  _buildListTile(
                    leading: Icons.login,
                    title: '로그인',
                    subtitle: '더 많은 기능을 이용하려면 로그인하세요',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
                ],
              ),

            // 🔔 알림 설정 - 주석처리
            /*
            _buildSection(
              title: '알림 설정',
              icon: Icons.notifications,
              children: [
                _buildListTile(
                  leading: Icons.notifications_active,
                  title: '푸시 알림',
                  subtitle: '새로운 이벤트 알림을 받습니다',
                  trailing: Switch(
                    value: _pushNotifications,
                    onChanged: (value) {
                      setState(() {
                        _pushNotifications = value;
                      });
                    },
                    activeColor: FifaColors.primary,
                  ),
                ),
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.email_outlined,
                  title: '이메일 알림',
                  subtitle: '이벤트 정보를 이메일로 받습니다',
                  trailing: Switch(
                    value: _emailNotifications,
                    onChanged: (value) {
                      setState(() {
                        _emailNotifications = value;
                      });
                    },
                    activeColor: FifaColors.primary,
                  ),
                ),
              ],
            ),
            */

            // 🎨 앱 설정 - 주석처리
            /*
            _buildSection(
              title: '앱 설정',
              icon: Icons.settings,
              children: [
                _buildListTile(
                  leading: Icons.dark_mode,
                  title: '다크 모드',
                  subtitle: '어두운 테마를 사용합니다',
                  trailing: Switch(
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() {
                        _darkMode = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('다크 모드는 준비 중입니다')),
                      );
                    },
                    activeColor: FifaColors.primary,
                  ),
                ),
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.language,
                  title: '언어',
                  subtitle: _language,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('언어 설정은 준비 중입니다')),
                    );
                  },
                ),
              ],
            ),
            */

            // 📞 고객 지원
            _buildSection(
              title: '고객 지원',
              icon: Icons.help_outline,
              children: [
                _buildListTile(
                  leading: Icons.mail_outline,
                  title: '문의 이메일',
                  subtitle: _supportEmail,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, size: 18),
                        onPressed: () => _copyToClipboard(_supportEmail, '문의 이메일'),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _copyToClipboard(_supportEmail, '문의 이메일'),
                ),
                // Divider(height: 1),
                // _buildListTile(
                //   leading: Icons.admin_panel_settings,
                //   title: '관리자 문의',
                //   subtitle: _adminContact,
                //   trailing: Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       IconButton(
                //         icon: Icon(Icons.copy, size: 18),
                //         onPressed: () => _copyToClipboard(_adminContact, '관리자 이메일'),
                //       ),
                //       Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                //     ],
                //   ),
                //   onTap: () => _copyToClipboard(_adminContact, '관리자 이메일'),
                // ),
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.bug_report,
                  title: '버그 신고',
                  subtitle: '앱 사용 중 문제점을 신고해주세요',
                  onTap: () {
                    _copyToClipboard(_supportEmail, '버그 신고 이메일');
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   SnackBar(content: Text('이메일 주소가 복사되었습니다. ')),
                    // );
                  },
                ),
                // 앱 평가하기 - 주석처리
                /*
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.star_rate,
                  title: '앱 평가하기',
                  subtitle: '앱스토어에서 평가를 남겨주세요',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _rateApp(), // 🎯 실제 함수 연결!
                ),
                */
              ],
            ),

            // ℹ️ 앱 정보
            _buildSection(
              title: '앱 정보',
              icon: Icons.info_outline,
              children: [
                _buildListTile(
                  leading: Icons.sports_soccer,
                  title: '피온 이벤트 알림',
                  subtitle: '버전 $_appVersion',
                ),
                // 업데이트 확인 - 주석처리
                /*
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.update,
                  title: '업데이트 확인',
                  subtitle: '최신 버전인지 확인합니다',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('최신 버전입니다!')),
                    );
                  },
                ),
                */
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.privacy_tip,
                  title: '개인정보 처리방침',
                  subtitle: '개인정보 보호 정책을 확인하세요',
                  onTap: () => _openWebsite('https://plip.kr/pcc/3e76264e-029f-48f9-8bde-f151fbd16712/privacy/1.html'),
                ),
                // 이용약관 - 주석처리
                /*
                Divider(height: 1),
                _buildListTile(
                  leading: Icons.gavel,
                  title: '이용약관',
                  subtitle: '서비스 이용약관을 확인하세요',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('이용약관 페이지는 준비 중입니다')),
                    );
                  },
                ),
                */
              ],
            ),

            // 🚪 회원 탈퇴 (로그인 사용자만)
            if (widget.currentUser != null)
              _buildSection(
                title: '계정 관리',
                icon: Icons.manage_accounts,
                children: [
                  _buildListTile(
                    leading: Icons.delete_forever,
                    title: '회원 탈퇴',
                    subtitle: '계정과 모든 데이터를 영구 삭제합니다',
                    titleColor: Colors.red,
                    iconColor: Colors.red,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '위험',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),

            // 하단 여백
            SizedBox(height: 32),

            // 저작권 정보
            Text(
              '© 2024 피온 이벤트 알림\nMade with ❤️ for PION fans',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}