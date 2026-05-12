import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/models/sensor_model.dart';

class RouteStep {
  final String instruction;
  final String? modifier;
  final String? type;
  final LatLng location;
  final double distance;

  RouteStep({
    required this.instruction,
    required this.modifier,
    required this.type,
    required this.location,
    required this.distance,
  });
}

class EvacuationMapPage extends StatefulWidget {
  final double destLatitude;
  final double destLongitude;
  final String destName;
  final List<EvacuationModel> otherSites;
  final List<SensorModel> sensors;

  const EvacuationMapPage({
    super.key,
    required this.destLatitude,
    required this.destLongitude,
    required this.destName,
    this.otherSites = const [],
    this.sensors = const [],
  });

  @override
  State<EvacuationMapPage> createState() => _EvacuationMapPageState();
}

class _EvacuationMapPageState extends State<EvacuationMapPage>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  List<LatLng> _routePoints = [];
  List<RouteStep> _steps = [];
  int _currentStepIndex = 0;
  
  String? _distanceText;
  String? _durationText;
  bool _isLoadingRoute = true;
  bool _isLoadingLocation = true;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<Position>? _positionStream;
  bool _isFollowing = true;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initLocationAndRoute();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndRoute() async {
    try {
      final position = await _getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      await _fetchRoute(
        from: _userLocation!,
        to: LatLng(widget.destLatitude, widget.destLongitude),
      );

      if (!mounted) return;
      _recenter();
      _startNavigation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _isLoadingRoute = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it in app settings.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _fetchRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    setState(() => _isLoadingRoute = true);

    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Route service unavailable.');
      }

      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        throw Exception('No route found between these locations.');
      }

      final route = routes[0];
      final geometry = route['geometry'];
      final coords = geometry['coordinates'] as List;

      final points = coords
          .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final distanceMeters = (route['distance'] as num).toDouble();
      final durationSecs = (route['duration'] as num).toDouble();

      final distanceKm = distanceMeters / 1000;
      final distStr = distanceKm < 1
          ? '${distanceMeters.round()} m'
          : '${distanceKm.toStringAsFixed(1)} km';

      final minutes = (durationSecs / 60).round();
      final durStr = minutes < 60 ? '$minutes min' : '${(minutes / 60).floor()}h ${minutes % 60}m';

      final legs = route['legs'] as List?;
      List<RouteStep> parsedSteps = [];
      if (legs != null && legs.isNotEmpty) {
        final stepsJson = legs[0]['steps'] as List?;
        if (stepsJson != null) {
          for (var s in stepsJson) {
            final maneuver = s['maneuver'];
            if (maneuver != null) {
              final loc = maneuver['location'] as List;
              parsedSteps.add(RouteStep(
                instruction: _getInstruction(s),
                modifier: maneuver['modifier'] as String?,
                type: maneuver['type'] as String?,
                location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
                distance: (s['distance'] as num).toDouble(),
              ));
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _steps = parsedSteps;
        _currentStepIndex = 0;
        _distanceText = distStr;
        _durationText = durStr;
        _isLoadingRoute = false;
      });
    } catch (e) {
      if (!mounted) return;
      final fallbackDist = _haversineKm(from, to);
      setState(() {
        _routePoints = [from, to];
        _steps = [];
        _distanceText = '~${fallbackDist.toStringAsFixed(1)} km (straight line)';
        _durationText = null;
        _isLoadingRoute = false;
        _errorMessage = null; 
      });
    }
  }

  void _startNavigation() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, 
      ),
    ).listen((Position position) {
      if (!mounted) return;
      final newLoc = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _userLocation = newLoc;
      });

      if (_isFollowing) {
        _mapController.move(newLoc, _mapController.camera.zoom > 16 ? _mapController.camera.zoom : 17.0);
      }

      _updateNavigation(newLoc);
    });
  }

  void _updateNavigation(LatLng currentLoc) {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return;

    final distToManeuver = _haversineKm(currentLoc, _steps[_currentStepIndex].location) * 1000;
    if (distToManeuver < 30) {
      if (_currentStepIndex < _steps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      }
    }

    if (_routePoints.isNotEmpty) {
      double minDist = double.infinity;
      for (int i = 0; i < _routePoints.length; i += 3) {
        final d = _haversineKm(currentLoc, _routePoints[i]) * 1000;
        if (d < minDist) minDist = d;
      }
      if (minDist > 100 && !_isRecalculating) {
        _recalculateRoute(currentLoc);
      }
    }
  }

  Future<void> _recalculateRoute(LatLng currentLoc) async {
    _isRecalculating = true;
    try {
      await _fetchRoute(from: currentLoc, to: LatLng(widget.destLatitude, widget.destLongitude));
    } catch (_) {
    } finally {
      _isRecalculating = false;
    }
  }

  String _getInstruction(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] ?? {};
    final type = maneuver['type'] as String?;
    final modifier = maneuver['modifier'] as String?;
    final name = step['name'] as String?;
    
    String action = 'Head';
    if (type == 'depart') return 'Head ${modifier ?? 'straight'} on ${name?.isNotEmpty == true ? name : 'this road'}';
    if (type == 'arrive') return 'You have reached your destination';
    
    if (modifier != null) {
      action = 'Turn $modifier';
      if (modifier == 'straight') action = 'Continue straight';
      if (modifier == 'uturn') action = 'Make a U-turn';
      if (modifier == 'slight right') action = 'Keep right';
      if (modifier == 'slight left') action = 'Keep left';
    }
    
    return '$action${name?.isNotEmpty == true ? ' onto $name' : ''}';
  }

  IconData _getModifierIcon(String? modifier, String? type) {
    if (type == 'depart') return Icons.trip_origin;
    if (type == 'arrive') return Icons.place;

    switch (modifier) {
      case 'uturn': return Icons.u_turn_left;
      case 'sharp right': return Icons.turn_right;
      case 'right': return Icons.turn_right;
      case 'slight right': return Icons.turn_right;
      case 'straight': return Icons.straight;
      case 'slight left': return Icons.turn_left;
      case 'left': return Icons.turn_left;
      case 'sharp left': return Icons.turn_left;
      default: return Icons.straight;
    }
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

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

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  void _recenter() {
    if (_userLocation == null) return;
    setState(() => _isFollowing = true);
    _mapController.move(_userLocation!, 17.0);
  }
  
  void _fitBounds() {
    if (_userLocation == null) return;
    setState(() => _isFollowing = false);
    final dest = LatLng(widget.destLatitude, widget.destLongitude);

    final allPoints = [_userLocation!, dest, ..._routePoints];
    double minLat = allPoints.map((p) => p.latitude).reduce(math.min);
    double maxLat = allPoints.map((p) => p.latitude).reduce(math.max);
    double minLon = allPoints.map((p) => p.longitude).reduce(math.min);
    double maxLon = allPoints.map((p) => p.longitude).reduce(math.max);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLon),
          LatLng(maxLat, maxLon),
        ),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dest = LatLng(widget.destLatitude, widget.destLongitude);
    final center = _userLocation ?? dest;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B40),
      body: _isLoadingLocation
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00C97A)),
                  SizedBox(height: 16),
                  Text(
                    'Getting your location...',
                    style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF101C45)),
                          child: const Text('Go Back'),
                        )
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Listener(
                      onPointerDown: (_) => setState(() => _isFollowing = false),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.silag.app',
                          ),
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: const Color(0xFF00C97A),
                                  strokeWidth: 6,
                                  borderColor: const Color(0xFF009B5E),
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // --- Destination (navigation target) ---
                              Marker(
                                point: dest,
                                width: 52,
                                height: 62,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                                      ),
                                      child: const Icon(Icons.place, color: Colors.white, size: 18),
                                    ),
                                    CustomPaint(
                                      size: const Size(12, 10),
                                      painter: _TrianglePainter(Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                              // --- Other evacuation sites ---
                              ...widget.otherSites
                                  .where((s) => s.latitude != 0.0 && s.longitude != 0.0)
                                  .map((s) => Marker(
                                        point: LatLng(s.latitude, s.longitude),
                                        width: 44,
                                        height: 54,
                                        child: Tooltip(
                                          message: s.name,
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00C97A),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 1.5),
                                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                ),
                                                child: const Icon(Icons.emergency_share, color: Colors.white, size: 14),
                                              ),
                                              CustomPaint(
                                                size: const Size(10, 8),
                                                painter: _TrianglePainter(const Color(0xFF00C97A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )),
                              // --- Sensor markers (color-coded by flood level) ---
                              ...widget.sensors
                                  .where((s) => s.latitude != null && s.longitude != null)
                                  .map((s) {
                                    final col = _sensorColor(s.waterLevel);
                                    return Marker(
                                      point: LatLng(s.latitude!, s.longitude!),
                                      width: 34,
                                      height: 34,
                                      child: Tooltip(
                                        message: '${s.name}\n${s.waterLevel.toStringAsFixed(2)} ft',
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: col.withOpacity(0.85),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                            boxShadow: [BoxShadow(color: col.withOpacity(0.5), blurRadius: 6)],
                                          ),
                                          child: const Icon(Icons.sensors, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    );
                                  }),
                              // --- User location ---
                              if (_userLocation != null)
                                Marker(
                                  point: _userLocation!,
                                  width: 44,
                                  height: 44,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (_, __) => Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4DBBFF).withOpacity(0.25),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF4DBBFF), width: 3),
                                        ),
                                        child: const Icon(Icons.navigation, color: Color(0xFF4DBBFF), size: 18),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_steps.isNotEmpty && _currentStepIndex < _steps.length)
                      Positioned(
                        top: 50,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C97A),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getModifierIcon(_steps[_currentStepIndex].modifier, _steps[_currentStepIndex].type),
                                color: Colors.white,
                                size: 42,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatDistance(_haversineKm(_userLocation!, _steps[_currentStepIndex].location)),
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                    ),
                                    Text(
                                      _steps[_currentStepIndex].instruction,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Poppins'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_isLoadingRoute)
                      Positioned(
                        top: 140,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101C45).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                SizedBox(width: 8),
                                Text('Calculating route...', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Poppins')),
                              ],
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 120,
                      right: 16,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'overview',
                            backgroundColor: const Color(0xFF101C45),
                            onPressed: _fitBounds,
                            child: const Icon(Icons.map, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            heroTag: 'recenter',
                            backgroundColor: _isFollowing ? const Color(0xFF00C97A) : const Color(0xFF101C45),
                            onPressed: _recenter,
                            child: Icon(Icons.my_location, color: _isFollowing ? Colors.white : const Color(0xFF00C97A)),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                        decoration: const BoxDecoration(
                          color: Color(0xFF101C45),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -2))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _distanceText ?? '-- km',
                                  style: const TextStyle(color: Color(0xFF00C97A), fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'To ${widget.destName}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Poppins'),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              child: const Text('Exit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
  bool shouldRepaint(_TrianglePainter oldDelegate) => oldDelegate.color != color;
}
