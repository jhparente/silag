// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:silag/models/flood_level_template.dart';

/// Interactive diagram replicating the physical IoT sensor mounting, ultrasonic
/// water surface ranging, human height comparison, and animated wave ripples.
/// Matches the official reference design and video specifications.
class FloodHeightDiagram extends StatefulWidget {
  /// The current flood depth in feet
  final double waterLevelFt;

  /// Optional sensor name / location to display in header
  final String? sensorName;

  /// Optional active status
  final bool isActive;

  /// Callback when user taps or scrubs to test levels
  final ValueChanged<double>? onWaterLevelChanged;

  /// Optional custom title (e.g. 'Personal Alert Threshold')
  final String? title;

  /// Optional custom subtitle (e.g. 'SMS Alert Threshold')
  final String? subtitle;

  /// Optional custom margin
  final EdgeInsetsGeometry? margin;

  /// Optional custom boxShadow override
  final List<BoxShadow>? boxShadow;

  /// Whether this diagram represents a Personal Alert Threshold rather than a live sensor
  final bool isThresholdMode;

  /// Whether to animate the water level rising from 0 on initial load
  final bool animateOnLoad;

  const FloodHeightDiagram({
    super.key,
    required this.waterLevelFt,
    this.sensorName,
    this.isActive = true,
    this.onWaterLevelChanged,
    this.title,
    this.subtitle,
    this.margin,
    this.boxShadow,
    this.isThresholdMode = false,
    this.animateOnLoad = true,
  });

  @override
  State<FloodHeightDiagram> createState() => _FloodHeightDiagramState();
}

class _FloodHeightDiagramState extends State<FloodHeightDiagram>
    with TickerProviderStateMixin {
  late AnimationController _rippleCtrl;
  late AnimationController _waterLevelAnimCtrl;
  late Animation<double> _waterLevelAnim;

  double _displayedWaterLevel = 0.0;

  @override
  void initState() {
    super.initState();

    final bool shouldAnimate =
        widget.animateOnLoad && widget.waterLevelFt > 0.02;
    _displayedWaterLevel = shouldAnimate ? 0.0 : widget.waterLevelFt;

    // Continuous wave ripple animation (approx 2.4 seconds per cycle)
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Smooth transition when water level changes or rises on open
    _waterLevelAnimCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: shouldAnimate ? 1300 : 700),
    );

    _waterLevelAnim = Tween<double>(
      begin: _displayedWaterLevel,
      end: widget.waterLevelFt,
    ).animate(
      CurvedAnimation(
        parent: _waterLevelAnimCtrl,
        curve: shouldAnimate ? Curves.easeOutCubic : Curves.easeInOutCubic,
      ),
    )..addListener(() {
        setState(() {
          _displayedWaterLevel = _waterLevelAnim.value;
        });
      });

    if (shouldAnimate) {
      // Allow the page route transition to complete before starting water rise
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _waterLevelAnimCtrl.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant FloodHeightDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.waterLevelFt - widget.waterLevelFt).abs() > 0.001) {
      _waterLevelAnimCtrl.duration = const Duration(milliseconds: 800);
      _waterLevelAnim = Tween<double>(
        begin: _displayedWaterLevel,
        end: widget.waterLevelFt,
      ).animate(
        CurvedAnimation(
            parent: _waterLevelAnimCtrl, curve: Curves.easeInOutCubic),
      );
      _waterLevelAnimCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _waterLevelAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final template = FloodLevelTemplate.fromWaterLevel(_displayedWaterLevel);
    final waterLevelMeters = _displayedWaterLevel * 0.3048;
    final airGapMeters = (2.40 - waterLevelMeters).clamp(0.0, 2.40);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1128),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: template.textColorDark.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: widget.boxShadow ??
            (widget.isThresholdMode
                ? null
                : [
                    BoxShadow(
                      color: template.backgroundColorDark.withOpacity(0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HEADER (SILAG · Flood height + Badge) ─────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    template.backgroundColorDark.withOpacity(0.55),
                    const Color(0xFF0A1128).withOpacity(0.0),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title ??
                                  (widget.sensorName != null &&
                                          widget.sensorName!.isNotEmpty
                                      ? 'SILAG · ${widget.sensorName}'
                                      : (widget.isThresholdMode
                                          ? 'Personal Alert Threshold'
                                          : 'SILAG · Flood height')),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: widget.isThresholdMode
                                        ? (_displayedWaterLevel > 0
                                            ? const Color(0xFF22C55E)
                                            : Colors.amber)
                                        : (widget.isActive
                                            ? const Color(0xFF22C55E)
                                            : Colors.amber),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (widget.isThresholdMode
                                                ? (_displayedWaterLevel > 0
                                                    ? const Color(0xFF22C55E)
                                                    : Colors.amber)
                                                : (widget.isActive
                                                    ? const Color(0xFF22C55E)
                                                    : Colors.amber))
                                            .withOpacity(0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.subtitle ??
                                        (widget.isThresholdMode
                                            ? (_displayedWaterLevel > 0
                                                ? 'Active SMS Alert · ${_displayedWaterLevel.toStringAsFixed(0)} ft'
                                                : 'Alerts Inactive (0 ft)')
                                            : (widget.isActive
                                                ? 'Active Ultrasonic Node · Moving Ripples'
                                                : 'Node Offline · Cached Reading')),
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Metric equivalent
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          '${waterLevelMeters.toStringAsFixed(2)} m',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Template Alert Level Badge ──────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: template.backgroundColorDark.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: template.textColorDark.withOpacity(0.9),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: template.textColorDark.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForLevel(template.level),
                          size: 16,
                          color: template.textColorDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isThresholdMode
                              ? (_displayedWaterLevel == 0
                                  ? '0 ft · Alerts Inactive'
                                  : '${_displayedWaterLevel.toStringAsFixed(0)} ft · ${template.name}')
                              : '${_displayedWaterLevel.toStringAsFixed(2)} ft · ${template.name}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: template.textColorDark,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (template.level > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: template.textColorDark.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Level ${template.level}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: template.textColorDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── DIAGRAM CANVAS (CustomPainter with animated wave) ─────
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (context, _) {
                return SizedBox(
                  height: 310,
                  child: CustomPaint(
                    painter: _FloodDiagramPainter(
                      waterLevelFt: _displayedWaterLevel,
                      wavePhase: _rippleCtrl.value,
                      template: template,
                    ),
                    size: const Size(double.infinity, 310),
                  ),
                );
              },
            ),

            // ── BOTTOM REFERENCE FOOTER (Air Gap & Heights) ───────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1635),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isThresholdMode) ...[
                    Row(
                      children: [
                        Icon(
                          _displayedWaterLevel > 0
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          size: 16,
                          color: template.textColorDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _displayedWaterLevel > 0
                              ? 'SMS triggers at ${_displayedWaterLevel.toStringAsFixed(0)} ft'
                              : 'SMS Alerts: Disabled (0 ft)',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${waterLevelMeters.toStringAsFixed(2)} m depth',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reference heights: person 1.70 m (5.58 ft). You will receive an SMS alert whenever flood water in your barangay reaches this threshold.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.sensors_outlined,
                          size: 16,
                          color: template.textColorDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${airGapMeters.toStringAsFixed(2)} m below sensor',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(airGapMeters / 0.3048).toStringAsFixed(2)} ft gap',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reference heights: person 1.70 m · sensor 2.40 m. Sensor height is measured from the ground to its underside.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLevel(int level) {
    switch (level) {
      case 7:
        return Icons.dangerous_rounded;
      case 6:
      case 5:
        return Icons.warning_rounded;
      case 4:
      case 3:
        return Icons.notification_important_rounded;
      case 2:
        return Icons.trending_up_rounded;
      case 1:
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }
}

/// CustomPainter rendering the complete physical IoT mounting structure,
/// human reference silhouette, vertical measuring scale, ultrasonic pulse beam,
/// and animated ripple water surface.
class _FloodDiagramPainter extends CustomPainter {
  final double waterLevelFt;
  final double wavePhase;
  final FloodLevelTemplate template;

  _FloodDiagramPainter({
    required this.waterLevelFt,
    required this.wavePhase,
    required this.template,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double maxScaleFt = 8.0; // Ruler goes from 0 ft to 7.87 ft (2.40 m)
    const double sensorMountFt = 7.874; // 2.40 m in feet
    const double personHeightFt = 5.577; // 1.70 m in feet

    final double topMargin = 38.0;
    final double bottomMargin = 28.0;
    final double groundY = size.height - bottomMargin;
    final double availableH = groundY - topMargin;

    // Y coordinates
    final double sensorUndersideY =
        groundY - (sensorMountFt / maxScaleFt) * availableH;
    final double personHeadTopY =
        groundY - (personHeightFt / maxScaleFt) * availableH;
    final double waterSurfaceY =
        groundY - (waterLevelFt.clamp(0.0, maxScaleFt) / maxScaleFt) * availableH;

    // X coordinates
    final double poleX = size.width * 0.22;
    final double personX = size.width * 0.64;
    final double rulerX = size.width * 0.90;

    // ── 1. Background subtle ambient glow ─────────────────────────
    final bgGlowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.4),
        radius: 0.9,
        colors: [
          template.backgroundColorDark.withOpacity(0.35),
          const Color(0xFF0A1128).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgGlowPaint);

    // ── 2. Horizontal measurement grid guidelines ─────────────────
    final gridLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    for (int ft = 1; ft <= 7; ft++) {
      final y = groundY - (ft / maxScaleFt) * availableH;
      canvas.drawLine(Offset(poleX - 20, y), Offset(rulerX, y), gridLinePaint);
    }

    // ── 3. Sensor Underside / Face Guideline (Dashed Line) ─────────
    _drawDashedLine(
      canvas,
      Offset(poleX, sensorUndersideY),
      Offset(rulerX, sensorUndersideY),
      Colors.white.withOpacity(0.35),
      dashWidth: 4.0,
      dashSpace: 4.0,
    );

    // Text: "Sensor face · 2.40 m"
    _drawText(
      canvas,
      text: 'Sensor face · 2.40 m',
      offset: Offset(poleX + 10, sensorUndersideY - 14),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.75),
      ),
    );

    // ── 4. Ultrasonic Acoustic Pulse Rings (radiating down) ───────
    _drawUltrasonicPulse(canvas, poleX, sensorUndersideY, waterSurfaceY);

    // ── 5. Ground Line ────────────────────────────────────────────
    final groundPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(10, groundY), Offset(size.width - 10, groundY), groundPaint);

    // Ground Text Labels
    _drawText(
      canvas,
      text: 'Ground · 0 ft',
      offset: Offset(18, groundY + 7),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: Colors.white.withOpacity(0.6),
        fontWeight: FontWeight.w500,
      ),
    );
    _drawText(
      canvas,
      text: 'Height above ground',
      offset: Offset(personX - 40, groundY + 7),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10,
        color: Colors.white.withOpacity(0.45),
      ),
    );

    // ── 6. Draw SILAG Node Pole & Solar Panel Structure ───────────
    _drawSilagNodeHardware(canvas, poleX, groundY, sensorUndersideY);

    // ── 7. Draw Person Silhouette (1.70 m tall) ───────────────────
    _drawPersonSilhouette(canvas, personX, groundY, personHeadTopY);

    // ── 8. Draw Animated Water Body & Moving Ripples ──────────────
    _drawAnimatedWater(
      canvas,
      size,
      waterSurfaceY: waterSurfaceY,
      groundY: groundY,
      waterLevelFt: waterLevelFt,
    );

    // ── 9. Draw Height Ruler (Right side) ─────────────────────────
    _drawHeightRuler(
      canvas,
      rulerX: rulerX,
      groundY: groundY,
      availableH: availableH,
      maxScaleFt: maxScaleFt,
    );
  }

  /// Draws active ultrasonic echo pulse arcs between sensor underside and water surface
  void _drawUltrasonicPulse(
    Canvas canvas,
    double poleX,
    double sensorUndersideY,
    double waterSurfaceY,
  ) {
    if (waterSurfaceY <= sensorUndersideY + 10) return;

    final double distance = waterSurfaceY - sensorUndersideY;
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw 3 animated acoustic wavefront arcs
    for (int i = 0; i < 3; i++) {
      final double progress = (wavePhase + (i * 0.33)) % 1.0;
      final double arcY = sensorUndersideY + progress * distance;
      final double arcWidth = 10.0 + progress * 24.0;
      final double opacity = (1.0 - progress).clamp(0.0, 0.7);

      pulsePaint.color = template.textColorDark.withOpacity(opacity);

      final rect = Rect.fromCenter(
        center: Offset(poleX, arcY - 4),
        width: arcWidth,
        height: 12,
      );
      canvas.drawArc(rect, 0.2, math.pi - 0.4, false, pulsePaint);
    }
  }

  /// Draws the SILAG node pole, base plate, solar panel, enclosure, and transceiver
  void _drawSilagNodeHardware(
    Canvas canvas,
    double x,
    double groundY,
    double sensorY,
  ) {
    // Base plate at ground
    final basePlatePaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, groundY - 2), width: 28, height: 4),
        const Radius.circular(2),
      ),
      basePlatePaint,
    );

    // Vertical mounting mast / pole
    final polePaint = Paint()..color = const Color(0xFFCBD5E1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2.5, sensorY, 5, groundY - sensorY),
        const Radius.circular(1.5),
      ),
      polePaint,
    );

    // Ultrasonic Transducer Head (pointing downwards at sensorY)
    final transducerPaint = Paint()..color = const Color(0xFF64748B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, sensorY - 3), width: 14, height: 6),
        const Radius.circular(2),
      ),
      transducerPaint,
    );
    // Transceiver horns
    final hornPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawCircle(Offset(x - 3.5, sensorY - 0.5), 2.2, hornPaint);
    canvas.drawCircle(Offset(x + 3.5, sensorY - 0.5), 2.2, hornPaint);

    // Weatherproof IoT Enclosure Box (ESP32 + LoRa radio)
    final enclosurePaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, sensorY - 14), width: 18, height: 16),
        const Radius.circular(3),
      ),
      enclosurePaint,
    );
    // Subtle status LED
    final ledPaint = Paint()..color = const Color(0xFF22C55E);
    canvas.drawCircle(Offset(x + 4, sensorY - 17), 1.5, ledPaint);

    // Solar Panel Bracket & Tilted Panel at top
    final double bracketTopY = sensorY - 24;
    canvas.drawLine(
      Offset(x, sensorY - 22),
      Offset(x - 4, bracketTopY),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2,
    );

    // Tilted Solar Panel
    canvas.save();
    canvas.translate(x - 4, bracketTopY);
    canvas.rotate(-math.pi / 7); // ~25° tilt towards the sun

    // Panel frame
    final panelFramePaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 34, height: 18),
        const Radius.circular(2),
      ),
      panelFramePaint,
    );

    // Photovoltaic cells
    final pvCellPaint = Paint()..color = const Color(0xFF2563EB);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 14),
      pvCellPaint,
    );

    // PV Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(-15, 0), const Offset(15, 0), gridPaint);
    canvas.drawLine(const Offset(-5, -7), const Offset(-5, 7), gridPaint);
    canvas.drawLine(const Offset(5, -7), const Offset(5, 7), gridPaint);

    canvas.restore();

    // Top Label: "SILAG node"
    _drawText(
      canvas,
      text: 'SILAG node',
      offset: Offset(x - 26, bracketTopY - 24),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }

  /// Draws a clean anatomical person silhouette representing 1.70 m reference height
  void _drawPersonSilhouette(
    Canvas canvas,
    double x,
    double groundY,
    double headTopY,
  ) {
    final double totalH = groundY - headTopY;
    final double headRadius = totalH * 0.082; // ~8% of height
    final double headCenterY = headTopY + headRadius;

    final personPaint = Paint()..color = Colors.white.withOpacity(0.92);

    // Head
    canvas.drawCircle(Offset(x, headCenterY), headRadius, personPaint);

    // Torso, shoulders, arms & legs path
    final path = Path();
    final double neckY = headCenterY + headRadius + 2.0;
    final double shoulderW = totalH * 0.16;
    final double waistY = neckY + totalH * 0.34;
    final double hipY = waistY + totalH * 0.10;
    final double crotchY = hipY + totalH * 0.05;

    // Shoulders
    path.moveTo(x - shoulderW / 2, neckY + 4);
    path.lineTo(x + shoulderW / 2, neckY + 4);

    // Right arm & torso side
    path.lineTo(x + shoulderW / 2 + 2, waistY);
    path.lineTo(x + shoulderW * 0.35, waistY + 6);
    path.lineTo(x + shoulderW * 0.32, hipY);

    // Right leg down to ground
    path.lineTo(x + 9, groundY);
    path.lineTo(x + 2.5, groundY);

    // Crotch
    path.lineTo(x, crotchY);

    // Left leg down to ground
    path.lineTo(x - 2.5, groundY);
    path.lineTo(x - 9, groundY);

    // Left hip, torso side & arm
    path.lineTo(x - shoulderW * 0.32, hipY);
    path.lineTo(x - shoulderW * 0.35, waistY + 6);
    path.lineTo(x - shoulderW / 2 - 2, waistY);
    path.close();

    canvas.drawPath(path, personPaint);

    // Top Label: "Person · 1.70 m"
    _drawText(
      canvas,
      text: 'Person · 1.70 m',
      offset: Offset(x - 36, headTopY - 18),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }

  /// Draws moving sinusoidal wave water fluid body and surface ripple highlights
  void _drawAnimatedWater(
    Canvas canvas,
    Size size, {
    required double waterSurfaceY,
    required double groundY,
    required double waterLevelFt,
  }) {
    if (waterLevelFt <= 0.01) {
      // Very slight baseline moisture sheen at ground
      final flatPaint = Paint()
        ..color = template.waterCrestColor.withOpacity(0.35)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), flatPaint);
      return;
    }

    final double width = size.width;
    final double waveAmp = math.min(5.0, (groundY - waterSurfaceY) * 0.35);

    // Path 1: Primary Wave Body
    final waterPath = Path();
    waterPath.moveTo(0, groundY);

    // Start on the left at the wave height
    for (double x = 0; x <= width; x += 3.0) {
      final double normalizedX = x / width;
      final double y = waterSurfaceY +
          math.sin(normalizedX * 4 * math.pi + wavePhase * 2 * math.pi) * waveAmp +
          math.cos(normalizedX * 2.5 * math.pi + wavePhase * 2 * math.pi) * (waveAmp * 0.4);
      if (x == 0) {
        waterPath.lineTo(0, y);
      } else {
        waterPath.lineTo(x, y);
      }
    }

    waterPath.lineTo(width, groundY);
    waterPath.close();

    // Fill water with vertical gradient (translucent so human & pole remain visible)
    final waterFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          template.waterColor.withOpacity(0.70),
          template.waterDeepColor.withOpacity(0.88),
        ],
      ).createShader(Rect.fromLTRB(0, waterSurfaceY - waveAmp, width, groundY));
    canvas.drawPath(waterPath, waterFillPaint);

    // Path 2: Surface Crest Highlight Line (Glow wave)
    final crestPath = Path();
    for (double x = 0; x <= width; x += 3.0) {
      final double normalizedX = x / width;
      final double y = waterSurfaceY +
          math.sin(normalizedX * 4 * math.pi + wavePhase * 2 * math.pi) * waveAmp +
          math.cos(normalizedX * 2.5 * math.pi + wavePhase * 2 * math.pi) * (waveAmp * 0.4);
      if (x == 0) {
        crestPath.moveTo(0, y);
      } else {
        crestPath.lineTo(x, y);
      }
    }

    final crestPaint = Paint()
      ..color = template.waterCrestColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(crestPath, crestPaint);

    // Subtle Secondary ripple line (offset for 3D water ripple effect)
    final secondaryCrestPath = Path();
    for (double x = 0; x <= width; x += 3.0) {
      final double normalizedX = x / width;
      final double y = waterSurfaceY + 4.0 +
          math.sin(normalizedX * 3.5 * math.pi + (wavePhase + 0.35) * 2 * math.pi) *
              (waveAmp * 0.7);
      if (x == 0) {
        secondaryCrestPath.moveTo(0, y);
      } else {
        secondaryCrestPath.lineTo(x, y);
      }
    }
    final secondaryPaint = Paint()
      ..color = template.waterCrestColor.withOpacity(0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(secondaryCrestPath, secondaryPaint);
  }

  /// Draws the vertical measurement ruler with tick marks from 0 ft up to 7 ft
  void _drawHeightRuler(
    Canvas canvas, {
    required double rulerX,
    required double groundY,
    required double availableH,
    required double maxScaleFt,
  }) {
    final rulerPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.2;

    // Vertical line
    canvas.drawLine(
      Offset(rulerX, groundY),
      Offset(rulerX, groundY - availableH),
      rulerPaint,
    );

    // Ticks & Labels for each foot
    for (int ft = 1; ft <= 7; ft++) {
      final double y = groundY - (ft / maxScaleFt) * availableH;
      // Tick mark
      canvas.drawLine(
        Offset(rulerX - 5, y),
        Offset(rulerX + 4, y),
        rulerPaint,
      );

      // Label: "1 ft", "2 ft", ..., "7 ft"
      _drawText(
        canvas,
        text: '$ft ft',
        offset: Offset(rulerX + 8, y - 6),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9.5,
          color: Colors.white.withOpacity(0.65),
          fontWeight: FontWeight.w500,
        ),
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Color color, {
    double dashWidth = 5.0,
    double dashSpace = 4.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final double max = (p2 - p1).distance;
    final Offset dir = (p2 - p1) / max;
    double current = 0.0;
    while (current < max) {
      final double len = math.min(dashWidth, max - current);
      canvas.drawLine(p1 + dir * current, p1 + dir * (current + len), paint);
      current += dashWidth + dashSpace;
    }
  }

  void _drawText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required TextStyle style,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FloodDiagramPainter oldDelegate) {
    return oldDelegate.waterLevelFt != waterLevelFt ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.template != template;
  }
}
