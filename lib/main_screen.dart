import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/report.dart';
import 'pages/safety.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SafetyPage(),
    const ReportPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      
      final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      final type = message.data['type'];

      if (title.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, fontFamily: 'Poppins')),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins')),
                ],
              ],
            ),
            backgroundColor: type == 'evacuation_accepted'
                ? Colors.green.shade700
                : type == 'report_accepted'
                    ? const Color(0xFF1565C0)   // blue — report published
                    : const Color(0xFF162455),  // default navy
            duration: const Duration(seconds: 7),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      extendBody: true,
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(80, 0, 80, 30),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: _currentIndex == 0
                    ? Color(0xFF162455)
                    : Colors.transparent,
              ),
              child: IconButton(
                icon: const Icon(Icons.home_outlined, size: 35),
                color: _currentIndex == 0
                    ? Colors.white
                    : const Color(0xFF162455),
                onPressed: () => _onItemTapped(0),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: _currentIndex == 1
                    ? Color(0xFF162455)
                    : Colors.transparent,
              ),
              child: IconButton(
                icon: const Icon(Icons.health_and_safety_outlined, size: 35),
                color: _currentIndex == 1 ? Colors.white : Color(0xFF162455),
                onPressed: () => _onItemTapped(1),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: _currentIndex == 2
                    ? Color(0xFF162455)
                    : Colors.transparent,
              ),
              child: IconButton(
                icon: const Icon(Icons.warning_amber_rounded, size: 35),
                color: _currentIndex == 2 ? Colors.white : Color(0xFF162455),
                onPressed: () => _onItemTapped(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
