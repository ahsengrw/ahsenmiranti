import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/welcome_screen.dart';
import 'home_view.dart';
import 'tracking_view.dart';
import 'history_view.dart';
import 'profile_view.dart';

class CustomerDashboard extends StatefulWidget {
  final int initialIndex;
  const CustomerDashboard({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  late int _currentIndex;

  final List<Widget> _views = [
    const HomeView(),
    const TrackingView(),
    const HistoryView(),
    const ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _views[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w300),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Order'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Track'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
