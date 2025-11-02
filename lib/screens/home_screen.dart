import 'package:flutter/material.dart';
import '../models/user.dart';
import 'dashboard_screen.dart';
import 'view_screen.dart';
import 'log_enhanced_screen.dart';
import 'ai_map_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      DashboardScreen(user: widget.user),
      ViewScreen(user: widget.user),
      LogEnhancedScreen(user: widget.user),
      AiMapScreen(user: widget.user),
      ProfileScreen(user: widget.user),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: '导图',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_module),
            label: '视图',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: '日志',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'AI地图',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
