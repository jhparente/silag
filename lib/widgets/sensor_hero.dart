// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated SILAG IoT sensor hero — mirrors the actual hardware drawn in
/// FloodHeightDiagram (sensor detail page):
///   • Vertical mounting pole
///   • Weatherproof ESP32 enclosure with blinking green LED
///   • Tilted solar panel at top
///   • Ultrasonic transducer head firing animated acoustic pulses
///   • Animated rising/falling water below
///   • Blue/teal radar-ring outer glow pulsing outward
///
/// The SILAG acronym logo is rendered with Image.asset beneath.
class SensorHero extends StatefulWidget {
  final double size;
  final String? logoAsset;
  final bool isDarkBackground;

  const SensorHero({
    super.key,
    this.size = 120,
    this.logoAsset,
    this.isDarkBackground = false,
  });

  @override
  State<SensorHero> createState() => _SensorHeroState();
}

class _SensorHeroState extends State<SensorHero>
    with TickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _ledCtrl;

  late final Animation<double> _waterLevel;
  late final Animation<double> _led;

  @override
  void initState() {
    super.initState();

    // Continuous ripple / acoustic pulse phase
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Water oscillates between 20 % and 68 % of the diagram height
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _waterLevel = Tween<double>(begin: 0.20, end: 0.68).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut),
    );

    // Slow green LED blink
    _ledCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _led = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ledCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _waveCtrl.dispose();
    _ledCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Animated sensor canvas ──
        SizedBox(
          width: s * 1.6,
          height: s * 1.5,
          child: AnimatedBuilder(
            animation: Listenable.merge([_rippleCtrl, _waveCtrl, _ledCtrl]),
            builder: (context, _) {
              return CustomPaint(
                painter: _SilagSensorPainter(
                  ripplePhase: _rippleCtrl.value,
                  waterFill: _waterLevel.value,
                  ledGlow: _led.value,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // ── SILAG logo acronym image ──
        Image.asset(
          widget.logoAsset ??
              (widget.isDarkBackground
                  ? 'icons/Light Mode SILAG transparent.png'
                  : 'icons/Transparent SILAG LOGO.png'),
          height: 52,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

/// Paints a faithful miniature of the real SILAG IoT node hardware.
class _SilagSensorPainter extends CustomPainter {
  final double ripplePhase; // 0..1 repeating
  final double waterFill;   // 0..1 fraction of diagram height
  final double ledGlow;     // 0..1

  _SilagSensorPainter({
    required this.ripplePhase,
    required this.waterFill,
    required this.ledGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Layout constants (matching the real diagram proportions)
    final double poleX = w * 0.50;
    final double groundY = h * 0.90;
    final double sensorY = h * 0.28; // underside of transducer
    final double topMargin = h * 0.04;

    // ── Outer radar-ring pulse ─────────────────────────────────────
    _drawRadarRings(canvas, poleX, sensorY - 10, w);

    // ── Water body ────────────────────────────────────────────────
    final double waterSurfaceY = groundY - waterFill * (groundY - sensorY - 20);
    _drawWater(canvas, size, waterSurfaceY, groundY);

    // ── Ground line ───────────────────────────────────────────────
    canvas.drawLine(
      Offset(w * 0.04, groundY),
      Offset(w * 0.96, groundY),
      Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 1.8,
    );

    // ── Acoustic echo pulses from sensor down to water ─────────────
    _drawAcousticPulses(canvas, poleX, sensorY, waterSurfaceY);

    // ── Pole & hardware ───────────────────────────────────────────
    _drawHardware(canvas, poleX, groundY, sensorY, topMargin);
  }

  // ── Radar rings ────────────────────────────────────────────────────
  void _drawRadarRings(Canvas canvas, double cx, double cy, double w) {
    final maxR = w * 0.46;
    for (int i = 0; i < 3; i++) {
      final double t = (ripplePhase + i * 0.33) % 1.0;
      final double radius = t * maxR;
      final double opacity = (1.0 - t) * 0.55;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF38BDF8).withOpacity(opacity),
      );
    }
  }

  // ── Acoustic downward echo pulses ───────────────────────────────────
  void _drawAcousticPulses(
      Canvas canvas, double x, double sensorY, double waterY) {
    if (waterY <= sensorY + 8) return;
    final dist = waterY - sensorY;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final double t = (ripplePhase + i * 0.33) % 1.0;
      final double arcY = sensorY + t * dist;
      final double arcW = 8.0 + t * 22.0;
      final double opacity = (1.0 - t).clamp(0.0, 0.75);
      paint.color = const Color(0xFF38BDF8).withOpacity(opacity);

      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, arcY - 4), width: arcW, height: 10),
        0.2,
        math.pi - 0.4,
        false,
        paint,
      );
    }
  }

  // ── Animated sinusoidal water ───────────────────────────────────────
  void _drawWater(Canvas canvas, Size size, double surfaceY, double groundY) {
    if (surfaceY >= groundY - 2) return;

    final waveAmp = math.min(5.0, (groundY - surfaceY) * 0.30);
    final path = Path()..moveTo(0, groundY);
    for (double x = 0; x <= size.width; x += 3.0) {
      final nx = x / size.width;
      final y = surfaceY +
          math.sin(nx * 4 * math.pi + ripplePhase * 2 * math.pi) * waveAmp +
          math.cos(nx * 2.5 * math.pi + ripplePhase * 2 * math.pi) *
              (waveAmp * 0.4);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, groundY);
    path.close();

    // Water fill
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2563EB).withOpacity(0.60),
            const Color(0xFF1E40AF).withOpacity(0.80),
          ],
        ).createShader(Rect.fromLTWH(0, surfaceY, size.width, groundY - surfaceY)),
    );

    // Wave crest highlight
    final crestPath = Path()..moveTo(0, surfaceY);
    for (double x = 0; x <= size.width; x += 3.0) {
      final nx = x / size.width;
      final y = surfaceY +
          math.sin(nx * 4 * math.pi + ripplePhase * 2 * math.pi) * waveAmp +
          math.cos(nx * 2.5 * math.pi + ripplePhase * 2 * math.pi) *
              (waveAmp * 0.4);
      crestPath.lineTo(x, y);
    }
    canvas.drawPath(
      crestPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF60A5FA).withOpacity(0.85),
    );
  }

  // ── SILAG Node hardware (pole + enclosure + solar panel + transducer) ──
  void _drawHardware(
      Canvas canvas, double x, double groundY, double sensorY, double topY) {
    // Base plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, groundY - 2), width: 28, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF94A3B8),
    );

    // Vertical pole
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2.5, sensorY, 5, groundY - sensorY),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFCBD5E1),
    );

    // Ultrasonic transducer head
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, sensorY - 3), width: 16, height: 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF64748B),
    );
    // Transducer horns
    canvas.drawCircle(Offset(x - 4, sensorY), 2.5, Paint()..color = const Color(0xFF94A3B8));
    canvas.drawCircle(Offset(x + 4, sensorY), 2.5, Paint()..color = const Color(0xFF94A3B8));

    // Weatherproof enclosure box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, sensorY - 16), width: 22, height: 18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFE2E8F0),
    );

    // Enclosure inner detail stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, sensorY - 16), width: 18, height: 5),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFCBD5E1),
    );

    // Green LED (blinking)
    final ledColor = Color.lerp(
      const Color(0xFF4ADE80).withOpacity(0.5),
      const Color(0xFF22C55E),
      ledGlow,
    )!;
    // Glow
    canvas.drawCircle(
      Offset(x + 5, sensorY - 22),
      5,
      Paint()
        ..color = const Color(0xFF22C55E).withOpacity(ledGlow * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(x + 5, sensorY - 22), 2, Paint()..color = ledColor);

    // Solar panel bracket arm
    final double bracketTopY = sensorY - 22;
    canvas.drawLine(
      Offset(x, sensorY - 20),
      Offset(x - 5, bracketTopY),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2,
    );

    // Tilted solar panel
    canvas.save();
    canvas.translate(x - 5, bracketTopY);
    canvas.rotate(-math.pi / 7);

    // Panel frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 38, height: 20),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );

    // PV cells
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 33, height: 15),
      Paint()..color = const Color(0xFF2563EB),
    );

    // PV cell grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(-16.5, 0), const Offset(16.5, 0), gridPaint);
    canvas.drawLine(const Offset(-5.5, -7.5), const Offset(-5.5, 7.5), gridPaint);
    canvas.drawLine(const Offset(5.5, -7.5), const Offset(5.5, 7.5), gridPaint);

    // PV shimmer highlight
    canvas.drawRect(
      const Rect.fromLTWH(-16, -7, 8, 14),
      Paint()..color = Colors.white.withOpacity(0.12),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SilagSensorPainter old) => true;
}
