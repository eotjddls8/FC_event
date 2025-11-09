import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import 'event_list_screen.dart';
//import 'board_list_screen.dart';
import 'prize_list_screen.dart';
import 'ad_reward_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel? currentUser;

  const MainNavigationScreen({
    Key? key,
    this.currentUser,
  }) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // 🎯 개선된 스크린 사용
    _screens = [
      EventListScreen(currentUser: widget.currentUser),  // 개선된 이벤트 리스트
      //BoardListScreen(currentUser: widget.currentUser),
      PrizeListScreen(currentUser: widget.currentUser),
      AdRewardScreen(currentUser: widget.currentUser),
      SettingsScreen(currentUser: widget.currentUser),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: FifaColors.primary,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 11,
            ),
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.event_outlined, size: 22),
                activeIcon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FifaColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.event, size: 22),
                ),
                label: '이벤트',
              ),

              BottomNavigationBarItem(
                icon: Icon(Icons.card_giftcard_outlined, size: 22),
                activeIcon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FifaColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.card_giftcard, size: 22),
                ),
                label: '경품',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.monetization_on_outlined, size: 22),
                activeIcon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FifaColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.monetization_on, size: 22),
                ),
                label: '코인',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined, size: 22),
                activeIcon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FifaColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings, size: 22),
                ),
                label: '설정',
              ),
            ],
          ),
        ),
      ),
    );
  }
}