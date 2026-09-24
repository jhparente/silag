import 'package:flutter/material.dart';

/// A self-contained radar-ping animation widget for sensor markers.
/// Each instance manages its own [AnimationController].
class SensorPulseMarker extends StatefulWidget {
  final Color color;
  const SensorPulseMarker({super.key, required this.color});

  @override
  State<SensorPulseMarker> createState() => _SensorPulseMarkerState();
}

class _SensorPulseMarkerState extends State<SensorPulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _PingRingPainter(progress: _anim.value, color: widget.color),
        size: const Size(90, 90),
      ),
    );
  }
}

/// Expanding ring: starts at 14 px and grows to 44 px, fading as it expands.
/// A solid bright inner dot stays fixed for visual anchor.
class _PingRingPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0 (eased)
  final Color color;
  _PingRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = 14.0 + progress * 30.0; // 14 -> 44 px
    final ringOpacity = (1.0 - progress).clamp(0.0, 1.0);

    // ---- Expanding fill ----
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = color.withOpacity(ringOpacity * 0.45)
        ..style = PaintingStyle.fill,
    );

    // ---- Crisp expanding border ----
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = color.withOpacity(ringOpacity * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ---- Solid inner dot (always visible anchor) ----
    canvas.drawCircle(
      center,
      9.0,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.fill,
    );
    // White outline on inner dot for contrast on light map
    canvas.drawCircle(
      center,
      9.0,
      Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PingRingPainter old) =>
      old.progress != progress || old.color != color;
}
