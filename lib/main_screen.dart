import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/map_page.dart';
import 'pages/safety.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

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
    const MapPage(),
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

      if (type == 'account_banned') {
        AuthService().logout().then((_) {
          ApiClient.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/landing',
            (_) => false,
            arguments: 'Account is banned. Contact the admin.',
          );
        });
        return;
      }

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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    // In landscape: ultra-compact navbar height and icons to preserve screen visibility
    final navHeight = isLandscape ? 38.0 : 70.0;
    final iconSize = isLandscape ? 18.0 : 35.0;
    final mapIconSize = isLandscape ? 17.0 : 32.0;
    final bottomMargin = isLandscape ? 4.0 : 16.0;

    // In landscape: neat 240px wide pill centered horizontally
    final hMargin = isLandscape
        ? math.max(16.0, (screenWidth - 240.0) / 2)
        : 80.0;

    return Scaffold(
      body: _pages[_currentIndex],
      extendBody: true,
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(
            hMargin, 0, hMargin, bottomPadding + bottomMargin),
        height: navHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isLandscape ? 0.25 : 0.4),
              blurRadius: isLandscape ? 6 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              iconSize: iconSize,
              isLandscape: isLandscape,
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.health_and_safety_outlined,
              iconSize: iconSize,
              isLandscape: isLandscape,
            ),
            _buildNavItem(
              index: 2,
              icon: _currentIndex == 2 ? Icons.map_rounded : Icons.map_outlined,
              iconSize: mapIconSize,
              isLandscape: isLandscape,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required double iconSize,
    required bool isLandscape,
  }) {
    final isSelected = _currentIndex == index;

    return Container(
      width: isLandscape ? 36.0 : null,
      height: isLandscape ? 28.0 : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: isSelected ? const Color(0xFF162455) : Colors.transparent,
      ),
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        color: isSelected ? Colors.white : const Color(0xFF162455),
        padding: isLandscape ? EdgeInsets.zero : const EdgeInsets.all(8),
        constraints: isLandscape ? const BoxConstraints() : null,
        onPressed: () => _onItemTapped(index),
      ),
    );
  }
}

