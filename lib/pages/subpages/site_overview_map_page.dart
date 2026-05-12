import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/models/sensor_model.dart';

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

  // Default centre: Barangay Dalandanan, Valenzuela
  static const _defaultCenter = LatLng(14.7008, 120.9841);

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
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
      if (_userLocation != null) _userLocation!,
      ...widget.sites
          .where((s) => s.latitude != 0 && s.longitude != 0)
          .map((s) => LatLng(s.latitude, s.longitude)),
      ...widget.sensors
          .where((s) => s.latitude != null && s.longitude != null)
          .map((s) => LatLng(s.latitude!, s.longitude!)),
    ];
    if (pts.isEmpty) return;
    double minLat = pts.map((p) => p.latitude).reduce(math.min);
    double maxLat = pts.map((p) => p.latitude).reduce(math.max);
    double minLon = pts.map((p) => p.longitude).reduce(math.min);
    double maxLon = pts.map((p) => p.longitude).reduce(math.max);
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
      backgroundColor: const Color(0xFF0D1B40),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101C45),
        foregroundColor: Colors.white,
        title: const Text('Evacuation Sites & Sensors',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
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
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.silag.app',
              ),
              MarkerLayer(
                markers: [
                  // Evacuation sites — teal pin
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
                                      BoxShadow(color: const Color(0xFF00C97A).withOpacity(0.5), blurRadius: 8),
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
                      .where((s) => s.latitude != null && s.longitude != null)
                      .map((s) {
                        final col = _sensorColor(s.waterLevel);
                        return Marker(
                          point: LatLng(s.latitude!, s.longitude!),
                          width: 36,
                          height: 36,
                          child: Tooltip(
                            message: '${s.name}\n${s.waterLevel.toStringAsFixed(2)} ft',
                            preferBelow: false,
                            child: Container(
                              decoration: BoxDecoration(
                                color: col.withOpacity(0.9),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [BoxShadow(color: col.withOpacity(0.5), blurRadius: 6)],
                              ),
                              child: const Icon(Icons.sensors, color: Colors.white, size: 16),
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
                          color: const Color(0xFF4DBBFF).withOpacity(0.25),
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

          // Legend
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101C45).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendItem(const Color(0xFF00C97A), Icons.emergency_share, 'Evacuation Site'),
                  const SizedBox(height: 6),
                  _legendItem(Colors.greenAccent, Icons.sensors, 'Sensor – Safe'),
                  const SizedBox(height: 4),
                  _legendItem(const Color(0xFFFFC107), Icons.sensors, 'Sensor – Low'),
                  const SizedBox(height: 4),
                  _legendItem(const Color(0xFFFF9800), Icons.sensors, 'Sensor – High'),
                  const SizedBox(height: 4),
                  _legendItem(const Color(0xFFF44336), Icons.sensors, 'Sensor – Critical'),
                ],
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
                    style: TextStyle(color: Colors.white54, fontFamily: 'Poppins')),
              ),
            ),
        ],
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
            color: color.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 11)),
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
