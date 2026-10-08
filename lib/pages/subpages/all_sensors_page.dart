// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:silag/models/sensor_model.dart';

// ─────────────────────────────────────────────────────────────
// Sensor filter mode
// ─────────────────────────────────────────────────────────────
enum _SensorFilter { closest, barangay, all }

class AllSensorsPage extends StatefulWidget {
  final List<SensorModel> sensors;
  final double? userLat;
  final double? userLng;
  final String? userBarangayId;

  const AllSensorsPage({
    super.key,
    required this.sensors,
    this.userLat,
    this.userLng,
    this.userBarangayId,
  });

  @override
  State<AllSensorsPage> createState() => _AllSensorsPageState();
}

class _AllSensorsPageState extends State<AllSensorsPage> {
  _SensorFilter _filter = _SensorFilter.closest;
  String _selectedSubBarangay = 'All';
  bool _isFetchingLocation = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.userLat;
    _lng = widget.userLng;
    if (_lat == null || _lng == null) _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────
  double? _distanceTo(SensorModel s) {
    if (_lat == null ||
        _lng == null ||
        s.latitude == null ||
        s.longitude == null) return null;
    return Geolocator.distanceBetween(_lat!, _lng!, s.latitude!, s.longitude!);
  }

  String _formatDist(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  List<SensorModel> get _displayedSensors {
    final all = [...widget.sensors];

    switch (_filter) {
      case _SensorFilter.closest:
        if (_lat != null && _lng != null) {
          all.sort((a, b) {
            final da = _distanceTo(a) ?? double.infinity;
            final db = _distanceTo(b) ?? double.infinity;
            return da.compareTo(db);
          });
          final within =
              all.where((s) {
                final d = _distanceTo(s);
                return d != null && d <= 500;
              }).toList();
          return within;
        }
        return [];

      case _SensorFilter.barangay:
        if (_lat != null && _lng != null) {
          all.sort((a, b) {
            final da = _distanceTo(a) ?? double.infinity;
            final db = _distanceTo(b) ?? double.infinity;
            return da.compareTo(db);
          });
        }
        if (widget.userBarangayId == null) return [];
        return all.where((s) => s.barangayId == widget.userBarangayId).toList();

      case _SensorFilter.all:
        var filtered = all;
        if (_selectedSubBarangay != 'All') {
          filtered = all.where((s) => s.barangayName == _selectedSubBarangay).toList();
        }
        if (_lat != null && _lng != null) {
          filtered.sort((a, b) {
            final da = _distanceTo(a) ?? double.infinity;
            final db = _distanceTo(b) ?? double.infinity;
            return da.compareTo(db);
          });
        }
        return filtered;
    }
  }

  // ── Colour helpers ────────────────────────────────────────
  static Color _colorFromLevel(double wl) {
    if (wl >= 7.0) return const Color(0xFF121212);
    if (wl >= 6.0) return const Color(0xFF311B92);
    if (wl >= 5.0) return const Color(0xFF9C27B0);
    if (wl >= 4.0) return const Color(0xFFB71C1C);
    if (wl >= 3.0) return const Color(0xFFF44336);
    if (wl >= 2.0) return const Color(0xFFFF9800);
    if (wl >= 1.0) return const Color(0xFFFFC107);
    return Colors.greenAccent;
  }

  static String _statusLabel(double wl) {
    if (wl >= 7.0) return 'Catastrophic';
    if (wl >= 6.0) return 'Dangerous';
    if (wl >= 5.0) return 'Extreme';
    if (wl >= 4.0) return 'Severe';
    if (wl >= 3.0) return 'Critical';
    if (wl >= 2.0) return 'High';
    if (wl >= 1.0) return 'Low';
    return 'Safe';
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sensors = _displayedSensors;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF101C45), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'All Sensors',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFF101C45),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterChips(),
                if (_filter == _SensorFilter.all) ...[
                  const SizedBox(height: 12),
                  _buildSubFilterDropdown(),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  _filterSubtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFF6B7BA4),
                  ),
                ),
                const Spacer(),
                Text(
                  '${sensors.length} sensor${sensors.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF101C45),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sensors.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: sensors.length,
                    itemBuilder: (ctx, i) => _buildSensorCard(sensors[i]),
                  ),
          ),
        ],
      ),
    );
  }

  String get _filterSubtitle {
    switch (_filter) {
      case _SensorFilter.closest:
        return 'Sensors within 500 m of your location';
      case _SensorFilter.barangay:
        return 'Sensors in your barangay';
      case _SensorFilter.all:
        if (_selectedSubBarangay == 'All') {
          return 'All sensors, sorted by distance';
        }
        return 'Sensors in $_selectedSubBarangay';
    }
  }

  // ── Filter chips ─────────────────────────────────────────
  Widget _buildFilterChips() {
    final items = [
      (_SensorFilter.closest, Icons.near_me_rounded, 'Closest'),
      (_SensorFilter.barangay, Icons.location_city_rounded, 'My Barangay'),
      (_SensorFilter.all, Icons.sensors_rounded, 'All'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final filter = item.$1;
          final icon   = item.$2;
          final label  = item.$3;
          final isSelected = _filter == filter;
          final isLoading  =
              isSelected && filter == _SensorFilter.closest && _isFetchingLocation;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _filter = filter);
                if ((filter == _SensorFilter.closest ||
                        filter == _SensorFilter.all) &&
                    (_lat == null || _lng == null)) {
                  _fetchLocation();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF101C45)
                      : const Color(0xFFEEF1FA),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF101C45)
                        : const Color(0xFFCED4E6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else if (isSelected) ...[
                      const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ] else ...[
                      Icon(icon, size: 14, color: const Color(0xFF6B7BA4)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF101C45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubFilterDropdown() {
    final availableBarangays = widget.sensors
        .map((s) => s.barangayName)
        .where((b) => b != null && b.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final options = ['All', ...availableBarangays];
    
    // Ensure selected sub barangay is valid
    if (!options.contains(_selectedSubBarangay)) {
      _selectedSubBarangay = 'All';
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCED4E6),
          width: 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubBarangay,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7BA4), size: 18),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF101C45),
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedSubBarangay = newValue);
            }
          },
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'All' ? 'All Barangays' : value),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.sensors_off_rounded,
              size: 52,
              color: Color(0xFFCED4E6),
            ),
            SizedBox(height: 12),
            Text(
              'No sensors found.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFA1A9BE),
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try adjusting your filter or check back later.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFA1A9BE),
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sensor Card ───────────────────────────────────────────
  Widget _buildSensorCard(SensorModel sensor) {
    final wl          = sensor.waterLevel;
    final statusColor = _colorFromLevel(wl);
    final label       = _statusLabel(wl);
    final dist        = _distanceTo(sensor);

    IconData icon;
    double fill, glow;
    if (wl >= 7.0)      { icon = Icons.warning_rounded;       glow = 0.45; fill = 0.05; }
    else if (wl >= 6.0) { icon = Icons.warning_rounded;       glow = 0.40; fill = 0.10; }
    else if (wl >= 5.0) { icon = Icons.flood;                 glow = 0.35; fill = 0.15; }
    else if (wl >= 4.0) { icon = Icons.flood;                 glow = 0.30; fill = 0.20; }
    else if (wl >= 3.0) { icon = Icons.flood;                 glow = 0.25; fill = 0.30; }
    else if (wl >= 2.0) { icon = Icons.warning_amber_rounded; glow = 0.20; fill = 0.50; }
    else if (wl >= 1.0) { icon = Icons.water;                 glow = 0.15; fill = 0.70; }
    else                { icon = Icons.house_outlined;         glow = 0.05; fill = 1.0; }

    return GestureDetector(
      onTap: () => _showSensorDetail(sensor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16224A),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(glow),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sensor.location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sensor.isActive
                              ? const Color(0xFF00E676)
                              : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: sensor.isActive
                                  ? const Color(0xFF00E676).withOpacity(0.7)
                                  : Colors.redAccent.withOpacity(0.5),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sensor.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (dist != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.near_me_rounded,
                            size: 11,
                            color: Colors.lightBlueAccent.withOpacity(0.8)),
                        const SizedBox(width: 3),
                        Text(
                          _formatDist(dist),
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '  ${wl.toStringAsFixed(2)} ft',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            sensor.status,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _NeonRingWidget(
              color: statusColor,
              percentage: fill,
              size: 48,
            ),
          ],
        ),
      ),
    );
  }

  // ── Sensor detail bottom sheet ────────────────────────────
  void _showSensorDetail(SensorModel sensor) {
    final statusColor = _colorFromLevel(sensor.waterLevel);
    final dist        = _distanceTo(sensor);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF101C45),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.sensors,
                            color: statusColor, size: 22),
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
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              sensor.location,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailTile(
                      'Sensor ID', sensor.id.isEmpty ? 'N/A' : sensor.id),
                  _detailTileColored(
                    'Sensor Active',
                    sensor.isActive ? 'Active' : 'Inactive',
                    sensor.isActive ? Colors.greenAccent : Colors.redAccent,
                  ),
                  _detailTile('Status', sensor.status),
                  _detailTile('Water Level',
                      '${sensor.waterLevel.toStringAsFixed(2)} ft'),
                  _detailTile('Warning Threshold',
                      '${(sensor.normalThresholdFt ?? 0.51).toStringAsFixed(2)} ft'),
                  _detailTile('Critical Threshold',
                      '${(sensor.criticalThresholdFt ?? 1.50).toStringAsFixed(2)} ft'),
                  if (dist != null)
                    _detailTile('Distance from You', _formatDist(dist)),
                  _detailTile(
                    'Last Updated',
                    sensor.lastReadingAt != null
                        ? DateFormat('MMM d, y – h:mm a')
                            .format(sensor.lastReadingAt!.toLocal())
                        : 'No data',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor.withOpacity(0.18),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Poppins')),
          ),
          Expanded(
            flex: 5,
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Widget _detailTileColored(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Poppins')),
          ),
          Expanded(
            flex: 5,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}

// ─── Mini neon ring ───────────────────────────────────────────
class _NeonRingWidget extends StatelessWidget {
  final Color color;
  final double percentage;
  final double size;

  const _NeonRingWidget({
    required this.color,
    required this.percentage,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NeonPainter(color: color, percentage: percentage),
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final Color color;
  final double percentage;

  _NeonPainter({required this.color, required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
