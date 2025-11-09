import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/fifa_theme.dart';
import 'event_list_screen.dart' as event;
import 'board_list_screen.dart' as board;
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
      event.EventListScreen(currentUser: widget.currentUser),  // 개선된 이벤트 리스트
      board.EventListScreen(currentUser: widget.currentUser),
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
          child: Container(
            height: 60,
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
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_outlined, size: 24),
                  activeIcon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FifaColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.event, size: 24),
                  ),
                  label: '이벤트',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.forum_outlined, size: 24),
                  activeIcon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FifaColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.forum, size: 24),
                  ),
                  label: '게시판',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard_outlined, size: 24),
                  activeIcon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FifaColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.card_giftcard, size: 24),
                  ),
                  label: '경품',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.monetization_on_outlined, size: 24),
                  activeIcon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FifaColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.monetization_on, size: 24),
                  ),
                  label: '코인',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined, size: 24),
                  activeIcon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FifaColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.settings, size: 24),
                  ),
                  label: '설정',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}