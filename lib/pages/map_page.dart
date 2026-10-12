import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:silag/models/evacuation_model.dart';
import 'package:silag/models/sensor_model.dart';
import 'package:silag/services/evacuation_service.dart';
import 'package:silag/services/sensor_service.dart';
import 'package:silag/widgets/sensor_pulse_marker.dart';
import 'package:silag/pages/subpages/sensor_detail_page.dart';
import 'package:silag/pages/subpages/evacuation_map_page.dart';

class MapPage extends StatefulWidget {
  final List<EvacuationModel>? initialSites;
  final List<SensorModel>? initialSensors;

  const MapPage({
    super.key,
    this.initialSites,
    this.initialSensors,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final SensorService _sensorService = SensorService();
  final EvacuationService _evacuationService = EvacuationService();

  List<SensorModel> _sensors = [];
  List<EvacuationModel> _sites = [];
  bool _isLoading = true;

  LatLng? _userLocation;
  bool _loadingLocation = true;
  bool _showLegend = false;
  bool _showEvacuationSites = true;
  String? _selectedSensorId;
  double _currentZoom = 14.0;

  // ── Per-severity toggles for IoT Flood Sensors ───────────────
  bool _showCriticalSensors = true; // >= 3.0 ft (Critical / Severe)
  bool _showHighSensors = true;     // 2.0 - 2.99 ft (High Alert)
  bool _showLowSensors = true;      // 1.0 - 1.99 ft (Low Alert)
  bool _showSafeSensors = true;     // < 1.0 ft (Normal / Baseline)

  int get _criticalCount => _sensors.where((s) => s.waterLevel >= 3.0).length;
  int get _highCount => _sensors.where((s) => s.waterLevel >= 2.0 && s.waterLevel < 3.0).length;
  int get _lowCount => _sensors.where((s) => s.waterLevel >= 1.0 && s.waterLevel < 2.0).length;
  int get _safeCount => _sensors.where((s) => s.waterLevel < 1.0).length;

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

  // Default centre: Valenzuela City, Philippines
  static const _defaultCenter = LatLng(14.7008, 120.9841);

  @override
  void initState() {
    super.initState();
    _sensors = widget.initialSensors ?? [];
    _sites = widget.initialSites ?? [];

    _loadData();
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _sensorService.fetchSensors(),
        _evacuationService.fetchEvacuationCenters(),
      ]);

      if (mounted) {
        setState(() {
          _sensors = results[0] as List<SensorModel>;
          _sites = results[1] as List<EvacuationModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      // 1. Try fast last known position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          _loadingLocation = false;
        });
      }

      final svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _loadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  static Color _sensorColor(double wl) {
    if (wl >= 7.0) return const Color(0xFF121212); // Catastrophic (Black)
    if (wl >= 6.0) return const Color(0xFF311B92); // Dangerous (Deep Purple)
    if (wl >= 5.0) return const Color(0xFF9C27B0); // Extreme (Purple)
    if (wl >= 4.0) return const Color(0xFFB71C1C); // Severe (Dark Red)
    if (wl >= 3.0) return const Color(0xFFF44336); // Critical (Red)
    if (wl >= 2.0) return const Color(0xFFFF9800); // High (Orange)
    if (wl >= 1.0) return const Color(0xFFFFC107); // Low (Yellow)
    return const Color(0xFF00C97A);                // Normal / Safe (Green)
  }

  void _fitAll() {
    final pts = <LatLng>[
      ?_userLocation,
      if (_showEvacuationSites)
        ..._sites
            .where((s) => s.latitude != 0 && s.longitude != 0)
            .map((s) => LatLng(s.latitude, s.longitude)),
      ..._sensors
          .where((s) => s.latitude != null && s.longitude != null && _isSensorVisible(s))
          .map((s) => LatLng(s.latitude!, s.longitude!)),
    ];
    if (pts.isEmpty) {
      if (_userLocation != null) {
        _mapController.move(_userLocation!, 14);
      } else {
        _mapController.move(_defaultCenter, 14);
      }
      return;
    }
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

  void _showSiteModal(EvacuationModel site) {
    double? distMeters;
    if (_userLocation != null && site.latitude != 0 && site.longitude != 0) {
      distMeters = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        site.latitude,
        site.longitude,
      );
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C97A).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emergency_share, color: Color(0xFF00C97A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101C45),
                          ),
                        ),
                        if (site.address.isNotEmpty)
                          Text(
                            site.address,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: site.isFull
                          ? Colors.red.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      site.isFull ? 'FULL' : 'AVAILABLE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: site.isFull ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (distMeters != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        distMeters < 1000
                            ? '${distMeters.toStringAsFixed(0)} m from your location'
                            : '${(distMeters / 1000).toStringAsFixed(2)} km from your location',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              if (site.maxCapacity > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Capacity: ${site.currentOccupancyIndividual} / ${site.maxCapacity} individuals',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvacuationMapPage(
                          destLatitude: site.latitude,
                          destLongitude: site.longitude,
                          destName: site.name,
                          otherSites: _sites,
                          sensors: _sensors,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions, color: Colors.white),
                  label: const Text(
                    'Get Evacuation Route',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101C45),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSensorModal(SensorModel sensor) {
    setState(() => _selectedSensorId = sensor.id);
    double? distMeters;
    if (_userLocation != null && sensor.latitude != null && sensor.longitude != null) {
      distMeters = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        sensor.latitude!,
        sensor.longitude!,
      );
    }

    final col = _sensorColor(sensor.waterLevel);
    String statusLabel;
    if (sensor.waterLevel >= 7.0) {
      statusLabel = 'Catastrophic';
    } else if (sensor.waterLevel >= 6.0) {
      statusLabel = 'Dangerous';
    } else if (sensor.waterLevel >= 5.0) {
      statusLabel = 'Extreme';
    } else if (sensor.waterLevel >= 4.0) {
      statusLabel = 'Severe';
    } else if (sensor.waterLevel >= 3.0) {
      statusLabel = 'Critical';
    } else if (sensor.waterLevel >= 2.0) {
      statusLabel = 'High Alert';
    } else if (sensor.waterLevel >= 1.0) {
      statusLabel = 'Low Alert';
    } else {
      statusLabel = 'Safe / Normal';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sensors, color: col, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sensor.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101C45),
                          ),
                        ),
                        if (sensor.barangayName != null && sensor.barangayName!.isNotEmpty)
                          Text(
                            'Brgy. ${sensor.barangayName}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          )
                        else if (sensor.location.isNotEmpty)
                          Text(
                            sensor.location,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: col,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Water Level',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sensor.waterLevel.toStringAsFixed(2)} ft',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: col,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                    Column(
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF101C45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (distMeters != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        distMeters < 1000
                            ? '${distMeters.toStringAsFixed(0)} m from your location'
                            : '${(distMeters / 1000).toStringAsFixed(2)} km from your location',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SensorDetailPage(
                          sensor: sensor,
                          userLat: _userLocation?.latitude,
                          userLng: _userLocation?.longitude,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
                  label: const Text(
                    'View Sensor Analytics & History',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101C45),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _selectedSensorId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF101C45)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF101C45),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, color: Color(0xFF101C45), size: 22),
            SizedBox(width: 8),
            Text(
              'Interactive Map',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101C45),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showLegend ? Icons.layers_rounded : Icons.layers_outlined,
              color: _showLegend ? const Color(0xFF2563EB) : const Color(0xFF101C45),
            ),
            tooltip: 'Map Layers & Legend',
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF101C45)),
            tooltip: 'Refresh',
            onPressed: _loadData,
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
              onPositionChanged: (camera, hasGesture) {
                if ((_currentZoom - camera.zoom).abs() > 0.25) {
                  setState(() => _currentZoom = camera.zoom);
                }
              },
              onTap: (tapPosition, point) {
                if (_selectedSensorId != null) {
                  setState(() => _selectedSensorId = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.silag.app',
              ),

              // Proximity circle markers (100m ring)
              CircleLayer(
                circles: _sensors
                    .where((s) =>
                        s.latitude != null &&
                        s.longitude != null &&
                        _isSensorVisible(s))
                    .map<CircleMarker>((s) {
                      final col = _sensorColor(s.waterLevel);
                      final isSelected = _selectedSensorId == s.id;
                      return CircleMarker(
                        point: LatLng(s.latitude!, s.longitude!),
                        color: col.withValues(alpha: isSelected ? 0.16 : 0.08),
                        borderStrokeWidth: isSelected ? 1.8 : 1.2,
                        borderColor: col.withValues(alpha: isSelected ? 0.60 : 0.35),
                        useRadiusInMeter: true,
                        radius: 100,
                      );
                    })
                    .toList(),
              ),

              // Animated Radar-pulse markers on each visible sensor
              MarkerLayer(
                markers: _sensors
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

              // Pin Markers
              MarkerLayer(
                markers: [
                  // Evacuation site markers
                  if (_showEvacuationSites)
                    ..._sites
                        .where((s) => s.latitude != 0 && s.longitude != 0)
                        .map((s) => Marker(
                              point: LatLng(s.latitude, s.longitude),
                              width: 50,
                              height: 62,
                              child: GestureDetector(
                                onTap: () => _showSiteModal(s),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C97A),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00C97A).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.emergency_share, color: Colors.white, size: 16),
                                    ),
                                    CustomPaint(
                                      size: const Size(12, 10),
                                      painter: _TrianglePainter(const Color(0xFF00C97A)),
                                    ),
                                  ],
                                ),
                              ),
                            )),

                  // Sensor Pin Markers
                  ..._sensors
                      .where((s) => s.latitude != null && s.longitude != null && _isSensorVisible(s))
                      .map((s) {
                        final col = _sensorColor(s.waterLevel);
                        final isSelected = _selectedSensorId == s.id;
                        final double markerSize = isSelected ? 42.0 : 36.0;

                        return Marker(
                          point: LatLng(s.latitude!, s.longitude!),
                          width: markerSize,
                          height: markerSize,
                          child: GestureDetector(
                            onTap: () => _showSensorModal(s),
                            child: Container(
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF101C45) : Colors.white,
                                  width: isSelected ? 2.5 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: col.withValues(alpha: 0.45),
                                    blurRadius: isSelected ? 8 : 5,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.sensors,
                                  color: Colors.white,
                                  size: isSelected ? 18 : 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                  // User location Pin
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 42,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                        ),
                        child: const Icon(Icons.my_location, color: Color(0xFF2563EB), size: 18),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Floating Map Controls (Right Side)
          Positioned(
            right: 14,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My Location',
                  onTap: () {
                    if (_userLocation != null) {
                      _mapController.move(_userLocation!, 15);
                    } else {
                      _fetchUserLocation().then((_) {
                        if (_userLocation != null) {
                          _mapController.move(_userLocation!, 15);
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                _buildFloatingMapButton(
                  icon: Icons.crop_free_rounded,
                  tooltip: 'Fit All Nodes',
                  onTap: _fitAll,
                ),
              ],
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
                        count: _sites.length,
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
                        iconColor: const Color(0xFF00C97A),
                        value: _showSafeSensors,
                        onChanged: (val) => setState(() => _showSafeSensors = val),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                      ),

                      // ── User Location ───────────────────────────
                      _legendItem(const Color(0xFF2563EB), Icons.my_location, 'Your Location'),
                    ],
                  ),
                ),
              ),
            ),

          // Loading location indicator
          if (_loadingLocation)
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Locating your position…',
                    style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 12),
                  ),
                ),
              ),
            ),

          if (_isLoading)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
                  ],
                ),
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF101C45)),
                ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 11),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontFamily: 'Poppins',
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Icon(icon, color: const Color(0xFF101C45), size: 21),
          ),
        ),
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
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
