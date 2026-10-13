import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/models/sensor_model.dart';
import 'package:silag/widgets/sensor_pulse_marker.dart';
import 'package:silag/pages/subpages/sensor_detail_page.dart';
import 'package:silag/models/flood_level_template.dart';

class SiteOverviewMapPage extends StatefulWidget {
  final List<EvacuationModel> sites;
  final List<SensorModel> sensors;

  const SiteOverviewMapPage({
    super.key,
    required this.sites,
    required this.sensors,
  });

  @override
  State<SiteOverviewMapPage> createState() => _SiteOverviewMapPageState();
}

class _SiteOverviewMapPageState extends State<SiteOverviewMapPage> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _loadingLocation = true;
  bool _showEvacuationSites = true;
  bool _showLegend = false;

  // ── 7 Alert Threshold Toggles for IoT Flood Sensors (+ Baseline) ────────
  bool _showLevel7 = true; // >= 7.00 ft (Critical)
  bool _showLevel6 = true; // 6.00 - 6.99 ft (Severe)
  bool _showLevel5 = true; // 5.00 - 5.99 ft (Serious)
  bool _showLevel4 = true; // 4.00 - 4.99 ft (Alert)
  bool _showLevel3 = true; // 3.00 - 3.99 ft (Warning)
  bool _showLevel2 = true; // 2.00 - 2.99 ft (Rising)
  bool _showLevel1 = true; // 1.00 - 1.99 ft (Advisory)
  bool _showLevel0 = true; // < 1.00 ft (Normal / Baseline)

  int get _level7Count => widget.sensors.where((s) => s.waterLevel >= 7.0).length;
  int get _level6Count => widget.sensors.where((s) => s.waterLevel >= 6.0 && s.waterLevel < 7.0).length;
  int get _level5Count => widget.sensors.where((s) => s.waterLevel >= 5.0 && s.waterLevel < 6.0).length;
  int get _level4Count => widget.sensors.where((s) => s.waterLevel >= 4.0 && s.waterLevel < 5.0).length;
  int get _level3Count => widget.sensors.where((s) => s.waterLevel >= 3.0 && s.waterLevel < 4.0).length;
  int get _level2Count => widget.sensors.where((s) => s.waterLevel >= 2.0 && s.waterLevel < 3.0).length;
  int get _level1Count => widget.sensors.where((s) => s.waterLevel >= 1.0 && s.waterLevel < 2.0).length;
  int get _level0Count => widget.sensors.where((s) => s.waterLevel < 1.0).length;

  bool _isSensorVisible(SensorModel s) {
    final wl = s.waterLevel;
    if (wl >= 7.0) return _showLevel7;
    if (wl >= 6.0) return _showLevel6;
    if (wl >= 5.0) return _showLevel5;
    if (wl >= 4.0) return _showLevel4;
    if (wl >= 3.0) return _showLevel3;
    if (wl >= 2.0) return _showLevel2;
    if (wl >= 1.0) return _showLevel1;
    return _showLevel0;
  }

  bool get _allSensorsVisible =>
      _showLevel7 &&
      _showLevel6 &&
      _showLevel5 &&
      _showLevel4 &&
      _showLevel3 &&
      _showLevel2 &&
      _showLevel1 &&
      _showLevel0;

  void _toggleAllSensors(bool enable) {
    setState(() {
      _showLevel7 = enable;
      _showLevel6 = enable;
      _showLevel5 = enable;
      _showLevel4 = enable;
      _showLevel3 = enable;
      _showLevel2 = enable;
      _showLevel1 = enable;
      _showLevel0 = enable;
    });
  }

  // Default centre: Barangay Dalandanan, Valenzuela
  static const _defaultCenter = LatLng(14.7008, 120.9841);

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLocation() async {
    try {
      final svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  static Color _sensorColor(double wl) {
    if (wl >= 7.0) return FloodLevelTemplate.level7.waterColor; // Level 7: Catastrophic (0xFF121212)
    if (wl >= 6.0) return FloodLevelTemplate.level6.waterColor; // Level 6: Dangerous (0xFF311B92)
    if (wl >= 5.0) return FloodLevelTemplate.level5.waterColor; // Level 5: Extreme (0xFF9C27B0)
    if (wl >= 4.0) return FloodLevelTemplate.level4.waterColor; // Level 4: Severe (0xFFB71C1C)
    if (wl >= 3.0) return FloodLevelTemplate.level3.waterColor; // Level 3: Critical (0xFFF44336)
    if (wl >= 2.0) return FloodLevelTemplate.level2.waterColor; // Level 2: High (0xFFFF9800)
    if (wl >= 1.0) return FloodLevelTemplate.level1.waterColor; // Level 1: Low (0xFFFFC107)
    return FloodLevelTemplate.level0.waterColor;                 // Safe / Normal Baseline (< 1.00 ft, 0xFF00E676)
  }

  void _fitAll() {
    final pts = <LatLng>[
      ?_userLocation,
      if (_showEvacuationSites)
        ...widget.sites
            .where((s) => s.latitude != 0 && s.longitude != 0)
            .map((s) => LatLng(s.latitude, s.longitude)),
      ...widget.sensors
          .where((s) => s.latitude != null && s.longitude != null && _isSensorVisible(s))
          .map((s) => LatLng(s.latitude!, s.longitude!)),
    ];
    if (pts.isEmpty) return;
    double minLat = pts.map((p) => p.latitude).reduce(math.min);
    double maxLat = pts.map((p) => p.latitude).reduce(math.max);
    double minLon = pts.map((p) => p.longitude).reduce(math.min);
    double maxLon = pts.map((p) => p.longitude).reduce(math.max);

    if (minLat == maxLat && minLon == maxLon) {
      _mapController.move(pts.first, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)),
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Evacuation Sites & Sensors',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _showLegend ? Icons.layers_rounded : Icons.layers_outlined,
              color: const Color(0xFF101C45),
            ),
            tooltip: 'Map Layers & Legend',
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Fit all',
            onPressed: _fitAll,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _defaultCenter,
              initialZoom: 14,
              onMapReady: () => Future.delayed(const Duration(milliseconds: 300), _fitAll),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.silag.app',
              ),
              // Static 100m boundary — visible when zoomed in close enough
              CircleLayer(
                circles: widget.sensors
                    .where((s) => s.latitude != null && s.longitude != null && _isSensorVisible(s))
                    .map<CircleMarker>((s) {
                      final col = _sensorColor(s.waterLevel);
                      return CircleMarker(
                        point: LatLng(s.latitude!, s.longitude!),
                        color: col.withValues(alpha: 0.10),
                        borderStrokeWidth: 1.2,
                        borderColor: col.withValues(alpha: 0.40),
                        useRadiusInMeter: true,
                        radius: 100,
                      );
                    })
                    .toList(),
              ),
              // Radar-ping markers — signal effect on each visible sensor
              MarkerLayer(
                markers: widget.sensors
                    .where((s) =>
                        s.latitude != null &&
                        s.longitude != null &&
                        _isSensorVisible(s))
                    .map((s) => Marker(
                          point: LatLng(s.latitude!, s.longitude!),
                          width: 80,
                          height: 80,
                          child: SensorPulseMarker(
                            color: _sensorColor(s.waterLevel),
                          ),
                        ))
                    .toList(),
              ),
              MarkerLayer(
                markers: [
                  // Evacuation sites — teal pin
                  if (_showEvacuationSites)
                    ...widget.sites
                        .where((s) => s.latitude != 0 && s.longitude != 0)
                        .map((s) => Marker(
                              point: LatLng(s.latitude, s.longitude),
                              width: 50,
                              height: 62,
                              child: Tooltip(
                                message: s.name,
                                preferBelow: false,
                                child: Column(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C97A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                            color: const Color(0xFF00C97A).withValues(alpha: 0.5),
                                            blurRadius: 8),
                                      ],
                                    ),
                                    child: const Icon(Icons.emergency_share, color: Colors.white, size: 16),
                                  ),
                                  CustomPaint(
                                    size: const Size(12, 10),
                                    painter: _TrianglePainter(const Color(0xFF00C97A)),
                                  ),
                                ]),
                              ),
                            )),
                  // Sensor markers — color-coded by the 7 flood thresholds
                  ...widget.sensors
                      .where((s) => s.latitude != null && s.longitude != null && _isSensorVisible(s))
                      .map((s) {
                        final col = _sensorColor(s.waterLevel);
                        final template = s.floodTemplate;
                        return Marker(
                          point: LatLng(s.latitude!, s.longitude!),
                          width: 36,
                          height: 36,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SensorDetailPage(
                                    sensor: s,
                                    userLat: _userLocation?.latitude,
                                    userLng: _userLocation?.longitude,
                                  ),
                                ),
                              );
                            },
                            child: Tooltip(
                              message: '${s.name}\n${s.waterLevel.toStringAsFixed(2)} ft · ${template.name} (Tap to view)',
                              preferBelow: false,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.8),
                                  boxShadow: [
                                    BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 6)
                                  ],
                                ),
                                child: Center(
                                  child: template.level > 0
                                      ? Text(
                                          'L${template.level}',
                                          style: TextStyle(
                                            color: template.level == 1 ? const Color(0xFF101C45) : Colors.white,
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        )
                                      : const Icon(Icons.sensors, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  // User location
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4DBBFF).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4DBBFF), width: 2.5),
                        ),
                        child: const Icon(Icons.my_location, color: Color(0xFF4DBBFF), size: 18),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Floating Quick-Filter Threshold Strip
          Positioned(
            left: 12,
            right: 68,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuickThresholdChip(
                      label: 'Safe',
                      sublabel: '<1ft',
                      color: FloodLevelTemplate.level0.waterColor,
                      count: _level0Count,
                      isActive: _showLevel0,
                      onTap: () => setState(() => _showLevel0 = !_showLevel0),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L1 Low',
                      sublabel: '1–2ft',
                      color: FloodLevelTemplate.level1.waterColor,
                      count: _level1Count,
                      isActive: _showLevel1,
                      onTap: () => setState(() => _showLevel1 = !_showLevel1),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L2 High',
                      sublabel: '2–3ft',
                      color: FloodLevelTemplate.level2.waterColor,
                      count: _level2Count,
                      isActive: _showLevel2,
                      onTap: () => setState(() => _showLevel2 = !_showLevel2),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L3 Critical',
                      sublabel: '3–4ft',
                      color: FloodLevelTemplate.level3.waterColor,
                      count: _level3Count,
                      isActive: _showLevel3,
                      onTap: () => setState(() => _showLevel3 = !_showLevel3),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L4 Severe',
                      sublabel: '4–5ft',
                      color: FloodLevelTemplate.level4.waterColor,
                      count: _level4Count,
                      isActive: _showLevel4,
                      onTap: () => setState(() => _showLevel4 = !_showLevel4),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L5 Extreme',
                      sublabel: '5–6ft',
                      color: FloodLevelTemplate.level5.waterColor,
                      count: _level5Count,
                      isActive: _showLevel5,
                      onTap: () => setState(() => _showLevel5 = !_showLevel5),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L6 Dangerous',
                      sublabel: '6–7ft',
                      color: FloodLevelTemplate.level6.waterColor,
                      count: _level6Count,
                      isActive: _showLevel6,
                      onTap: () => setState(() => _showLevel6 = !_showLevel6),
                    ),
                    const SizedBox(width: 6),
                    _buildQuickThresholdChip(
                      label: 'L7 Catastrophic',
                      sublabel: '7ft+',
                      color: FloodLevelTemplate.level7.waterColor,
                      count: _level7Count,
                      isActive: _showLevel7,
                      onTap: () => setState(() => _showLevel7 = !_showLevel7),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsed quick button
          if (!_showLegend)
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _showLegend = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_rounded, size: 15, color: Color(0xFF101C45)),
                        const SizedBox(width: 6),
                        const Text(
                          'Legend & Severity',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF101C45),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _miniColorDot(FloodLevelTemplate.level0.waterColor),
                            _miniColorDot(FloodLevelTemplate.level1.waterColor),
                            _miniColorDot(FloodLevelTemplate.level2.waterColor),
                            _miniColorDot(FloodLevelTemplate.level3.waterColor),
                            _miniColorDot(FloodLevelTemplate.level4.waterColor),
                            _miniColorDot(FloodLevelTemplate.level5.waterColor),
                            _miniColorDot(FloodLevelTemplate.level6.waterColor),
                            _miniColorDot(FloodLevelTemplate.level7.waterColor),
                          ],
                        ),
                        if (!_showEvacuationSites || !_allSensorsVisible) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF9800),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Map Legend with Interactive Layer & 7 Threshold Toggles
          if (_showLegend)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                width: 285,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with close button
                      Row(
                        children: [
                          const Icon(Icons.layers_rounded, color: Color(0xFF101C45), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'LEGEND & SEVERITY',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Color(0xFF101C45),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => setState(() => _showLegend = false),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Evacuation Centers Section ──────────────
                      _buildLayerToggleRow(
                        title: 'Evacuation Centers',
                        count: widget.sites.length,
                        icon: Icons.emergency_share,
                        iconColor: const Color(0xFF00C97A),
                        value: _showEvacuationSites,
                        onChanged: (val) => setState(() => _showEvacuationSites = val),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                      ),

                      // ── 7 Alert Thresholds Header with Quick Toggle ──
                      Row(
                        children: [
                          const Text(
                            '7 FLOOD ALERT THRESHOLDS',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _toggleAllSensors(!_allSensorsVisible),
                            child: Text(
                              _allSensorsVisible ? 'Hide All' : 'Show All',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Continuous Spectrum Gradient Bar
                      Container(
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: [
                              FloodLevelTemplate.level0.waterColor,
                              FloodLevelTemplate.level1.waterColor,
                              FloodLevelTemplate.level2.waterColor,
                              FloodLevelTemplate.level3.waterColor,
                              FloodLevelTemplate.level4.waterColor,
                              FloodLevelTemplate.level5.waterColor,
                              FloodLevelTemplate.level6.waterColor,
                              FloodLevelTemplate.level7.waterColor,
                            ],
                          ),
                        ),
                      ),

                      // ── 7 Thresholds (Highest Severity First) ───
                      _buildThresholdToggleRow(
                        level: 7,
                        title: 'Level 7: Catastrophic',
                        range: '≥ 7.00 ft (Catastrophic submergence)',
                        count: _level7Count,
                        color: FloodLevelTemplate.level7.waterColor,
                        value: _showLevel7,
                        onChanged: (val) => setState(() => _showLevel7 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 6,
                        title: 'Level 6: Dangerous',
                        range: '6.00 – 6.99 ft (Emergency)',
                        count: _level6Count,
                        color: FloodLevelTemplate.level6.waterColor,
                        value: _showLevel6,
                        onChanged: (val) => setState(() => _showLevel6 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 5,
                        title: 'Level 5: Extreme',
                        range: '5.00 – 5.99 ft (Mandatory Evac)',
                        count: _level5Count,
                        color: FloodLevelTemplate.level5.waterColor,
                        value: _showLevel5,
                        onChanged: (val) => setState(() => _showLevel5 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 4,
                        title: 'Level 4: Severe',
                        range: '4.00 – 4.99 ft (Preemptive Evac)',
                        count: _level4Count,
                        color: FloodLevelTemplate.level4.waterColor,
                        value: _showLevel4,
                        onChanged: (val) => setState(() => _showLevel4 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 3,
                        title: 'Level 3: Critical',
                        range: '3.00 – 3.99 ft (Waist depth)',
                        count: _level3Count,
                        color: FloodLevelTemplate.level3.waterColor,
                        value: _showLevel3,
                        onChanged: (val) => setState(() => _showLevel3 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 2,
                        title: 'Level 2: High',
                        range: '2.00 – 2.99 ft (Knee depth)',
                        count: _level2Count,
                        color: FloodLevelTemplate.level2.waterColor,
                        value: _showLevel2,
                        onChanged: (val) => setState(() => _showLevel2 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 1,
                        title: 'Level 1: Low',
                        range: '1.00 – 1.99 ft (Ankle depth)',
                        count: _level1Count,
                        color: FloodLevelTemplate.level1.waterColor,
                        value: _showLevel1,
                        onChanged: (val) => setState(() => _showLevel1 = val),
                      ),
                      _buildThresholdToggleRow(
                        level: 0,
                        title: 'Safe / Baseline',
                        range: '< 1.00 ft (Ankle clearance)',
                        count: _level0Count,
                        color: FloodLevelTemplate.level0.waterColor,
                        value: _showLevel0,
                        onChanged: (val) => setState(() => _showLevel0 = val),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                      ),

                      // ── User Location ───────────────────────────
                      _legendItem(const Color(0xFF4DBBFF), Icons.my_location, 'Your Location'),
                    ],
                  ),
                ),
              ),
            ),

          if (_loadingLocation)
            const Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text('Getting location…',
                    style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Poppins')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniColorDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildQuickThresholdChip({
    required String label,
    required String sublabel,
    required Color color,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.14) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : const Color(0xFFCBD5E1),
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isActive ? color : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdToggleRow({
    required int level,
    required String title,
    required String range,
    required int count,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? color : Colors.grey[400],
                shape: BoxShape.circle,
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  level > 0 ? '$level' : '0',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: value ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($count)',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: value ? color : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    range,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: value ? const Color(0xFF64748B) : const Color(0xFFA0AEC0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 38,
              height: 24,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: value,
                  activeThumbColor: color,
                  activeTrackColor: color.withValues(alpha: 0.35),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerToggleRow({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? iconColor : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 11),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: value ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 38,
              height: 24,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: value,
                  activeThumbColor: iconColor,
                  activeTrackColor: iconColor.withValues(alpha: 0.35),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF334155), fontFamily: 'Poppins', fontSize: 11)),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
