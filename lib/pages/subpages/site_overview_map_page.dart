import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/models/sensor_model.dart';
import 'package:silag/widgets/sensor_pulse_marker.dart';
import 'package:silag/pages/subpages/sensor_detail_page.dart';

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

  // ── Per-severity toggles for IoT Flood Sensors ───────────────
  bool _showCriticalSensors = true; // >= 3.0 ft
  bool _showHighSensors = true;     // 2.0 - 2.99 ft
  bool _showLowSensors = true;      // 1.0 - 1.99 ft
  bool _showSafeSensors = true;     // < 1.0 ft

  int get _criticalCount => widget.sensors.where((s) => s.waterLevel >= 3.0).length;
  int get _highCount => widget.sensors.where((s) => s.waterLevel >= 2.0 && s.waterLevel < 3.0).length;
  int get _lowCount => widget.sensors.where((s) => s.waterLevel >= 1.0 && s.waterLevel < 2.0).length;
  int get _safeCount => widget.sensors.where((s) => s.waterLevel < 1.0).length;

  bool _isSensorVisible(SensorModel s) {
    final wl = s.waterLevel;
    if (wl >= 3.0) return _showCriticalSensors;
    if (wl >= 2.0) return _showHighSensors;
    if (wl >= 1.0) return _showLowSensors;
    return _showSafeSensors;
  }

  bool get _allSensorsVisible =>
      _showCriticalSensors && _showHighSensors && _showLowSensors && _showSafeSensors;

  void _toggleAllSensors(bool enable) {
    setState(() {
      _showCriticalSensors = enable;
      _showHighSensors = enable;
      _showLowSensors = enable;
      _showSafeSensors = enable;
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
    if (wl >= 7.0) return const Color(0xFF121212);
    if (wl >= 6.0) return const Color(0xFF311B92);
    if (wl >= 5.0) return const Color(0xFF9C27B0);
    if (wl >= 4.0) return const Color(0xFFB71C1C);
    if (wl >= 3.0) return const Color(0xFFF44336);
    if (wl >= 2.0) return const Color(0xFFFF9800);
    if (wl >= 1.0) return const Color(0xFFFFC107);
    return Colors.greenAccent;
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
                  // Sensor markers — color-coded
                  ...widget.sensors
                      .where((s) => s.latitude != null && s.longitude != null && _isSensorVisible(s))
                      .map((s) {
                        final col = _sensorColor(s.waterLevel);
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
                              message: '${s.name}\n${s.waterLevel.toStringAsFixed(2)} ft (Tap to view)',
                              preferBelow: false,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 6)
                                  ],
                                ),
                                child: const Icon(Icons.sensors, color: Colors.white, size: 16),
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

          // Map Legend with Interactive Layer & Severity Toggles
          if (_showLegend)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                width: 260,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with close button
                      Row(
                        children: [
                          const Icon(Icons.layers_rounded, color: Color(0xFF101C45), size: 15),
                          const SizedBox(width: 6),
                          const Text(
                            'MAP LAYERS & SEVERITY',
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

                      // ── IoT Flood Sensors Header with Quick Toggle ──
                      Row(
                        children: [
                          const Text(
                            'IOT FLOOD SENSORS',
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
                      const SizedBox(height: 4),

                      // ── Per-Severity Toggles ───────────────────
                      _buildLayerToggleRow(
                        title: 'Critical (3+ ft)',
                        count: _criticalCount,
                        icon: Icons.sensors,
                        iconColor: const Color(0xFFF44336),
                        value: _showCriticalSensors,
                        onChanged: (val) => setState(() => _showCriticalSensors = val),
                      ),
                      _buildLayerToggleRow(
                        title: 'High Alert (2–3 ft)',
                        count: _highCount,
                        icon: Icons.sensors,
                        iconColor: const Color(0xFFFF9800),
                        value: _showHighSensors,
                        onChanged: (val) => setState(() => _showHighSensors = val),
                      ),
                      _buildLayerToggleRow(
                        title: 'Low Alert (1–2 ft)',
                        count: _lowCount,
                        icon: Icons.sensors,
                        iconColor: const Color(0xFFFFC107),
                        value: _showLowSensors,
                        onChanged: (val) => setState(() => _showLowSensors = val),
                      ),
                      _buildLayerToggleRow(
                        title: 'Safe / Normal (<1 ft)',
                        count: _safeCount,
                        icon: Icons.sensors,
                        iconColor: Colors.greenAccent,
                        value: _showSafeSensors,
                        onChanged: (val) => setState(() => _showSafeSensors = val),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                      ),

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
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: value ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: value,
                activeThumbColor: iconColor,
                activeTrackColor: iconColor.withValues(alpha: 0.35),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onChanged,
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
