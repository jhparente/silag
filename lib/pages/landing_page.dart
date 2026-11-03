// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../widgets/sensor_hero.dart';
import 'login.dart';
import 'signup.dart';

/// The first screen shown on fresh install or upon logout.
/// A vertically scrollable landing page presenting what SILAG is, how it works,
/// and how to stay safe, with Log In and Sign Up buttons pinned at the bottom.
class LandingPage extends StatefulWidget {
  final String? initialErrorMessage;

  const LandingPage({super.key, this.initialErrorMessage});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();

    // Show optional error banner (e.g., session expired / account banned)
    if (widget.initialErrorMessage != null &&
        widget.initialErrorMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialErrorMessage!,
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      });
    }
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  void _goToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Signup()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ── Scrollable Body ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Hero Banner with SensorHero
                    _buildTopHero(context),

                    // Main Informational Sections
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionCard(
                            icon: Icons.water_drop_rounded,
                            iconColor: const Color(0xFF2563EB),
                            badgeText: 'COMMUNITY IOT NETWORK',
                            title: 'What is SILAG?',
                            body:
                                'SILAG — Smart Inundation-Level Alert Gateway — is a community-driven '
                                'flood monitoring system deployed across flood-prone waterways and vulnerable communities. '
                                'Real-time IoT sensors track water levels 24/7 so you are always informed.',
                            chips: const [
                              '📡 24/7 IoT Sensors',
                              '👥 Community-Driven',
                              '⚡ Real-Time Alerts',
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildSectionCard(
                            icon: Icons.sensors_rounded,
                            iconColor: const Color(0xFF0EA5E9),
                            badgeText: 'LIVE TELEMETRY',
                            title: 'How It Works',
                            body:
                                'Physical flood sensors stream water-level data wirelessly to our servers. '
                                'The app shows live readings, historical trends, and color-coded alerts so you know exactly when to act.',
                            customWidget: _buildAlertLevelRow(),
                          ),
                          const SizedBox(height: 16),

                          _buildSectionCard(
                            icon: Icons.shield_rounded,
                            iconColor: const Color(0xFF10B981),
                            badgeText: 'EARLY WARNING & SAFETY',
                            title: 'Stay Safe, Stay Ready',
                            body:
                                'SILAG sends you instant push notifications when water levels rise. '
                                'Report flooding, mark yourself safe during emergencies, and coordinate '
                                'with your barangay — all from this app.',
                            chips: const [
                              '🔔 Instant Push Alerts',
                              '📸 Citizen Flood Reports',
                              '📍 Evacuation Site Maps',
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pinned Bottom Action Buttons ──
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  // ── Top Hero Banner ─────────────────────────────────────────────────────────
  Widget _buildTopHero(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1227), Color(0xFF1E3A8A)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101C45).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Network badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'COMMUNITY IOT FLOOD NETWORK',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Animated IoT hardware & water oscillation
          const SensorHero(
            size: 68,
            logoAsset: 'icons/Light Mode SILAG transparent.png',
            isDarkBackground: true,
          ),
          const SizedBox(height: 8),

          const Text(
            'Early Flood Warning & Community Safety',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF93C5FD),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Section Card ───────────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required String title,
    required String body,
    List<String>? chips,
    Widget? customWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101C45).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Icon and Badge
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101C45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Body text
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.55,
              color: Colors.grey[700],
            ),
          ),

          // Optional highlight chips
          if (chips != null && chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.map((chip) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Optional custom widget (e.g. alert levels)
          if (customWidget != null) ...[
            const SizedBox(height: 14),
            customWidget,
          ],
        ],
      ),
    );
  }

  // ── Color Alert Levels Row (All 8 Sensor Thresholds) ───────────────────────
  Widget _buildAlertLevelRow() {
    final thresholds = [
      {'label': 'Safe', 'range': '< 1 ft', 'color': const Color(0xFF00E676)},
      {'label': 'L1 Low', 'range': '1–2 ft', 'color': const Color(0xFFFFC107)},
      {'label': 'L2 High', 'range': '2–3 ft', 'color': const Color(0xFFFF9800)},
      {'label': 'L3 Critical', 'range': '3–4 ft', 'color': const Color(0xFFF44336)},
      {'label': 'L4 Severe', 'range': '4–5 ft', 'color': const Color(0xFFB71C1C)},
      {'label': 'L5 Extreme', 'range': '5–6 ft', 'color': const Color(0xFF9C27B0)},
      {'label': 'L6 Dangerous', 'range': '6–7 ft', 'color': const Color(0xFF311B92)},
      {'label': 'L7 Catastrophic', 'range': '7+ ft', 'color': const Color(0xFF121212)},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '8 SENSOR ALERT THRESHOLDS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                'Sensor Color Codes',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 1: Safe, L1 Low, L2 High, L3 Critical
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _buildAlertBadge(
                  thresholds[i]['label'] as String,
                  thresholds[i]['range'] as String,
                  thresholds[i]['color'] as Color,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: L4 Severe, L5 Extreme, L6 Dangerous, L7 Catastrophic
          Row(
            children: [
              for (int i = 4; i < 8; i++) ...[
                if (i > 4) const SizedBox(width: 6),
                _buildAlertBadge(
                  thresholds[i]['label'] as String,
                  thresholds[i]['range'] as String,
                  thresholds[i]['color'] as Color,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBadge(String label, String range, Color color) {
    final bool isDark = color.computeLuminance() < 0.15;
    final Color textColor = isDark ? const Color(0xFF0F172A) : color;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              range,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Buttons ───────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset > 0 ? bottomInset + 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101C45).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary: Log In
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _goToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF101C45),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary: Sign Up
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _goToSignup,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF101C45),
                side: const BorderSide(color: Color(0xFF101C45), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
