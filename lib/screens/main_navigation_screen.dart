import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import 'event_list_screen.dart';
import 'ad_reward_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel? currentUser; // null이면 비회원

  const MainNavigationScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    print('MainNavigationScreen - currentUser: ${widget.currentUser?.name ?? "비회원"} (${widget.currentUser?.role ?? "guest"})');

    if (widget.currentUser != null) {
      // 로그인한 사용자: 모든 기능 접근 가능
      _screens = [
        EventListScreen(currentUser: widget.currentUser),
        AdRewardScreen(currentUser: widget.currentUser),
        SettingsScreen(currentUser: widget.currentUser),
        //HomeScreen(),
      ];
      _navItems = [
        BottomNavigationBarItem(
          icon: Icon(Icons.sports_soccer),
          label: 'FC 이벤트',
        ),
         BottomNavigationBarItem(
           icon: Icon(Icons.card_giftcard),
           label: '광고 보상',
         ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '설정',
        ),
      ];
    } else {
      // 비회원: 이벤트 보기 + 로그인 화면만
      _screens = [
        EventListScreen(currentUser: null), // 비회원도 이벤트 목록 볼 수 있음
        AdRewardScreen(currentUser: null),
        LoginScreen(), // 로그인 화면
      ];
      _navItems = [
        BottomNavigationBarItem(
          icon: Icon(Icons.sports_soccer),
          label: 'FC 이벤트',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.card_giftcard),
          label: '추첨 보상',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.login),
          label: '로그인',
        ),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: FifaColors.primary,
        unselectedItemColor: FifaColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
        ),
        elevation: 8,
        items: _navItems,
      ),
    );
  }
}