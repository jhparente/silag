// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:silag/models/flood_level_template.dart';
import 'package:silag/models/sensor_model.dart';
import 'package:silag/pages/subpages/site_overview_map_page.dart';
import 'package:silag/models/hydrograph_model.dart';
import 'package:silag/services/sensor_service.dart';
import 'package:silag/widgets/flood_forecast_chart.dart';
import 'package:silag/widgets/flood_height_diagram.dart';

/// Full-screen IoT Sensor Detail page that replaces the modal bottom sheet.
/// Integrates physical ultrasonic ranging visualization, human reference comparison,
/// dynamic flood water alert templates, and hardware telemetry.
class SensorDetailPage extends StatefulWidget {
  final SensorModel sensor;
  final double? userLat;
  final double? userLng;

  const SensorDetailPage({
    super.key,
    required this.sensor,
    this.userLat,
    this.userLng,
  });

  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  late SensorModel _sensor;
  late Future<HydrographModel> _hydrographFuture;
  bool _isRefreshing = false;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _sensor = widget.sensor;
    _hydrographFuture = SensorService().fetchSensorHydrograph(widget.sensor.id);
    _userLat = widget.userLat;
    _userLng = widget.userLng;
    if (_userLat == null || _userLng == null) {
      _fetchUserLocation();
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        if (mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshSensorData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final updatedList = await SensorService().fetchSensors();
      final found = updatedList.firstWhere(
        (s) => s.id == _sensor.id,
        orElse: () => _sensor,
      );
      if (mounted) {
        setState(() {
          _sensor = found;
          _hydrographFuture = SensorService().fetchSensorHydrograph(found.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated telemetry for ${_sensor.name}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF101C45),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  double? get _distanceFromUser {
    if (_userLat == null ||
        _userLng == null ||
        _sensor.latitude == null ||
        _sensor.longitude == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _userLat!,
      _userLng!,
      _sensor.latitude!,
      _sensor.longitude!,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m away';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final activeWaterLevel = _sensor.waterLevel;
    final template = FloodLevelTemplate.fromWaterLevel(activeWaterLevel);

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1227),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              _sensor.name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _sensor.barangayName ?? _sensor.location,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white.withOpacity(0.65),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Telemetry',
            onPressed: _refreshSensorData,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: template.textColorDark.withOpacity(0.2),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── 1. HARDWARE STATUS HEADER STRIP ───────────────────────
              _buildIoTStatusStrip(template),

              // ── 2. ANIMATED FLOOD HEIGHT DIAGRAM (Live Sensor Reading) ──
              FloodHeightDiagram(
                waterLevelFt: activeWaterLevel,
                sensorName: _sensor.name,
                isActive: _sensor.isActive,
              ),

              const SizedBox(height: 14),

              // ── 3. FLOOD WATER ALERT DIRECTIVE & THRESHOLDS ───────────
              _buildFloodTemplateDirectiveCard(template, activeWaterLevel),

              const SizedBox(height: 14),

              // ── 4. GRAPHICAL FLOOD FORECAST & HYDROGRAPH ─────────────
              _buildGraphicalFloodForecastCard(template),

              const SizedBox(height: 14),

              // ── 5. IOT NODE HARDWARE & DIAGNOSTICS ───────────────────
              _buildIoTHardwareLinkCard(template),

              const SizedBox(height: 14),

              // ── 6. GEOSPATIAL & SITE POSITION CARD ────────────────────
              _buildGeospatialCard(),

              const SizedBox(height: 18),

              // ── 7. PRIMARY ACTION BUTTONS ─────────────────────────────
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. IoT Status Strip ──────────────────────────────────────
  Widget _buildIoTStatusStrip(FloodLevelTemplate template) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _sensor.isActive
                  ? const Color(0xFF16A34A).withOpacity(0.18)
                  : Colors.red.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _sensor.isActive
                    ? const Color(0xFF22C55E).withOpacity(0.4)
                    : Colors.red.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _sensor.isActive
                        ? const Color(0xFF22C55E)
                        : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _sensor.isActive ? 'ONLINE · LIVE NODE' : 'OFFLINE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _sensor.isActive
                        ? const Color(0xFF4ADE80)
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radio_rounded, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  'LoRa 433 MHz',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _sensor.lastReadingAt != null
                ? DateFormat('h:mm:ss a').format(_sensor.lastReadingAt!.toLocal())
                : 'No sync',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Compact Metric Tile Helper ────────────────────────────
  Widget _buildCompactMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1635),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10.5,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 5. IoT Node Hardware & Diagnostics Card ───────────────────
  Widget _buildIoTHardwareLinkCard(FloodLevelTemplate template) {
    final battery = _sensor.batteryLevel ?? 96;
    final rssi = _sensor.rssiValue ?? '-82 dBm';
    final signal = _sensor.signalStrength ?? 92;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111E44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.memory_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IoT Node Hardware & Telemetry',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ESP32 NodeMCU · LoRa 433 MHz SPI',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2x2 Compact Metric Grid
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Battery',
                  value: '$battery%',
                  subtitle: 'Solar Powered',
                  accentColor: const Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactMetricTile(
                  icon: Icons.network_check_rounded,
                  label: 'LoRa Signal',
                  value: rssi,
                  subtitle: '$signal% RSSI',
                  accentColor: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactMetricTile(
                  icon: Icons.swap_vert_rounded,
                  label: 'Trend',
                  value: _sensor.isRising ? 'Rising ↑' : 'Steady ↓',
                  subtitle: _sensor.isRising ? 'Increasing level' : 'Receding / Normal',
                  accentColor: _sensor.isRising
                      ? Colors.amberAccent
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactMetricTile(
                  icon: Icons.sensors_rounded,
                  label: 'Transducer',
                  value: 'Ultrasonic',
                  subtitle: '2.40m Mount Height',
                  accentColor: const Color(0xFFA78BFA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Detail rows for Node ID and Heartbeat
          _buildHardwareDetailRow(
            icon: Icons.tag_rounded,
            label: 'Sensor Node ID',
            value: _sensor.id.isEmpty ? 'N/A' : _sensor.id,
            action: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white60),
              tooltip: 'Copy ID',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _sensor.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sensor ID copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          _buildHardwareDetailRow(
            icon: Icons.timer_outlined,
            label: 'Telemetry Heartbeat',
            value: _sensor.lastReadingAt != null
                ? DateFormat('MMM d, y – h:mm a')
                    .format(_sensor.lastReadingAt!.toLocal())
                : 'No log record',
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1635),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 6),
            action,
          ],
        ],
      ),
    );
  }

  // ── 6. Graphical Flood Forecast & Hydrograph Card ────────────
  Widget _buildGraphicalFloodForecastCard(FloodLevelTemplate template) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111E44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: template.textColorDark.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: template.textColorDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Graphical Flood Forecast',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '12h Recorded Telemetry + 12h ML Projection',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          FutureBuilder<HydrographModel>(
            future: _hydrographFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF38BDF8),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.points.isEmpty) {
                return Container(
                  height: 140,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1635),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          size: 28, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text(
                        'No hydrograph curve available for this sensor yet.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FloodForecastChart(hydrograph: data),
                  if (data.predictedRiseFt != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF09122C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            data.predictedRiseFt! > 0
                                ? Icons.trending_up_rounded
                                : Icons.trending_flat_rounded,
                            size: 16,
                            color: data.predictedRiseFt! > 0
                                ? Colors.amberAccent
                                : Colors.greenAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.predictedRiseFt! > 0
                                  ? 'ML Projection: Anticipated rise of +${data.predictedRiseFt!.toStringAsFixed(2)} ft in next 12h'
                                  : 'ML Projection: Receding or steady within normal parameters',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 7. Flood Water Alert Template & Directive Card ──────────
  Widget _buildFloodTemplateDirectiveCard(
    FloodLevelTemplate template,
    double activeWaterLevel,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111E44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: template.textColorDark.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: template.backgroundColorDark.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: template.backgroundColorDark.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: template.textColorDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.fullBadge,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: template.textColorDark,
                      ),
                    ),
                    Text(
                      'Template Range: ${template.rangeDescription}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Advisory message
          Text(
            template.advisoryText,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withOpacity(0.9),
            ),
          ),

          const SizedBox(height: 16),

          // Threshold Comparative Bars
          const Text(
            'Configured Sensor Thresholds:',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),

          _buildThresholdBar(
            label: 'Warning Threshold',
            thresholdFt: _sensor.normalThresholdFt ?? 0.51,
            currentFt: activeWaterLevel,
            color: const Color(0xFFFACC15),
          ),
          const SizedBox(height: 8),
          _buildThresholdBar(
            label: 'Critical Threshold',
            thresholdFt: _sensor.criticalThresholdFt ?? 1.50,
            currentFt: activeWaterLevel,
            color: const Color(0xFFF87171),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdBar({
    required String label,
    required double thresholdFt,
    required double currentFt,
    required Color color,
  }) {
    final double ratio = (currentFt / thresholdFt).clamp(0.0, 1.5);
    final bool isBreached = currentFt >= thresholdFt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${thresholdFt.toStringAsFixed(2)} ft ${isBreached ? '• BREACHED' : '• CLEAR'}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isBreached ? color : Colors.white60,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (ratio / 1.5).clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
                isBreached ? color : Colors.white38),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── 7. Geospatial & Site Position Card ────────────────────────
  Widget _buildGeospatialCard() {
    final distance = _distanceFromUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111E44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4DBBFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF4DBBFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geospatial & Site Context',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Physical river / creek installation point',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildHardwareDetailRow(
            icon: Icons.home_work_outlined,
            label: 'Barangay Area',
            value: _sensor.barangayName ?? 'N/A',
          ),
          _buildHardwareDetailRow(
            icon: Icons.place_outlined,
            label: 'Channel Location',
            value: _sensor.location,
          ),
          if (_sensor.latitude != null && _sensor.longitude != null)
            _buildHardwareDetailRow(
              icon: Icons.gps_fixed_rounded,
              label: 'Coordinates',
              value:
                  '${_sensor.latitude!.toStringAsFixed(5)}, ${_sensor.longitude!.toStringAsFixed(5)}',
            ),
          if (distance != null)
            _buildHardwareDetailRow(
              icon: Icons.near_me_outlined,
              label: 'Distance from you',
              value: _formatDistance(distance),
              valueColor: const Color(0xFF38BDF8),
            ),
        ],
      ),
    );
  }

  // ── 8. Action Buttons ─────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteOverviewMapPage(
                      sites: const [],
                      sensors: [_sensor],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text(
                'View on Map',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF111E44),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh Telemetry',
              onPressed: _refreshSensorData,
            ),
          ),
        ],
      ),
    );
  }
}
