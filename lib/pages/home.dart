// ignore_for_file: deprecated_member_use of withOpacity
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:silag/models/notification_model.dart';
import 'package:silag/pages/profile_page.dart';
import 'package:silag/pages/subpages/notifications_page.dart';
import 'package:silag/services/api_config.dart';
import 'package:silag/services/api_client.dart';
import 'package:silag/services/notification_service.dart';
import 'package:silag/services/sensor_service.dart';
import 'package:silag/services/weather_service.dart';
import 'package:silag/models/weather_model.dart';
import 'package:silag/models/sensor_model.dart';
import 'package:silag/models/hydrograph_model.dart';
import 'package:silag/widgets/flood_forecast_chart.dart';
import 'package:silag/widgets/skeleton_loader.dart';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _weatherService = WeatherService();
  final _sensorService = SensorService();
  final _notifService = NotificationService();

  late Future<WeatherModel> _weatherFuture;
  late Future<List<SensorModel>> _sensorsFuture;
  late Future<HydrographModel> _hydrographFuture;
  List<NotificationModel> _notifications = [];
  int get _unreadCount => _notifications.where((n) => !n.isReadLocally).length;

  /// Barangay name fetched from the logged-in user's profile.
  String? _barangayName;

  /// Auto-refresh interval — sensors reload every 30 seconds automatically.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _weatherService.fetchWeather();
    _sensorsFuture = _sensorService.fetchSensors();
    _hydrographFuture = _sensorService.fetchGlobalHydrograph();
    _startAutoRefresh();
    _loadNotifications();
    _loadBarangay();
  }

  Future<void> _loadNotifications() async {
    try {
      final list = await _notifService.fetchNotifications();
      if (mounted) setState(() => _notifications = list);
    } catch (_) {}
  }

  /// Fetches the user profile and extracts the barangay name via the
  /// joined `barangays(name)` relation returned by the backend.
  Future<void> _loadBarangay() async {
    try {
      const storage = FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id');
      if (userId == null) return;

      final response = await ApiClient().get(
        ApiConfig.uri('users/$userId/profile'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'success') {
          final data = body['data'] as Map<String, dynamic>;

          // The backend joins barangays(name) as a nested object.
          String? name;
          final barangaysRel = data['barangays'];
          if (barangaysRel is Map) {
            name = barangaysRel['name']?.toString();
          }
          // Fallback: just show the barangay_id if the join is absent
          name ??= data['barangay_id']?.toString();

          if (mounted && name != null) {
            setState(() => _barangayName = 'Brgy. $name');
          }
        }
      }
    } catch (_) {
      // Silently ignore — header will keep the default placeholder.
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _sensorsFuture = _sensorService.fetchSensors();
          _hydrographFuture = _sensorService.fetchGlobalHydrograph();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      // Force a fresh fetch from the network on pull-to-refresh
      _weatherFuture = _weatherService.fetchWeather(forceRefresh: true);
      _sensorsFuture = _sensorService.fetchSensors();
      _hydrographFuture = _sensorService.fetchGlobalHydrograph();
    });
    await Future.wait([_weatherFuture, _sensorsFuture, _hydrographFuture]);
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, MMMM, d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: appBar(formattedDate),

      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 40),
          child: Column(
            children: [
              // --- WEATHER SECTION ---
              FutureBuilder<WeatherModel>(
                future: _weatherFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const WeatherCardSkeleton();
                  }
                  if (snapshot.hasError) {
                    return _buildErrorCard();
                  }
                  // display the weather card if data is available
                  final weather = snapshot.data!;
                  return _buildWeatherCard(weather);
                },
              ),

              const SizedBox(height: 40),

              // --- SENSOR SECTION ---
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  "Sensor Status",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101C45),
                  ),
                ),
              ),
              const SizedBox(height: 5),

              FutureBuilder<List<SensorModel>>(
                future: _sensorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const SensorCardSkeleton(),
                        const SizedBox(height: 8),
                        const SensorCardSkeleton(),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildErrorCard();
                  }

                  final sensors = snapshot.data!;
                  return Column(
                    children: sensors
                        .map((sensor) => _buildSensorCard(sensor))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: 40),

              // --- FLOOD FORECAST SECTION ---
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Graphical Flood Forecast",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101C45),
                  ),
                ),
              ),
              const SizedBox(height: 5),

              FutureBuilder<HydrographModel>(
                future: _hydrographFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 250,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  return FloodForecastChart(hydrograph: snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the flood level color based on water level in feet.
  /// Matches the 7-level table:
  ///   < 1 ft  : Safe        (green)
  ///   ≥ 1 ft  : Low         (#FFC107  Advisory)
  ///   ≥ 2 ft  : High        (#FF9800  Warning)
  ///   ≥ 3 ft  : Critical    (#F44336)
  ///   ≥ 4 ft  : Severe      (#B71C1C)
  ///   ≥ 5 ft  : Extreme     (#9C27B0)
  ///   ≥ 6 ft  : Dangerous   (#311B92)
  ///   ≥ 7 ft  : Catastrophic(#121212)
  Color _sensorPrimaryColor(SensorModel sensor) {
    return _colorFromLevel(sensor.waterLevel);
  }

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

  static String _statusLabelFromLevel(double wl) {
    if (wl >= 7.0) return 'Catastrophic';
    if (wl >= 6.0) return 'Dangerous';
    if (wl >= 5.0) return 'Extreme';
    if (wl >= 4.0) return 'Severe';
    if (wl >= 3.0) return 'Critical';
    if (wl >= 2.0) return 'High';
    if (wl >= 1.0) return 'Low';
    return 'Safe';
  }

  void _showSensorDetails(SensorModel sensor) {
    final statusColor = _sensorPrimaryColor(sensor);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
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
                          child: Icon(
                            Icons.sensors,
                            color: statusColor,
                            size: 24,
                          ),
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
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                    const SizedBox(height: 18),
                    _buildSensorDetailTile(
                      label: 'Sensor ID',
                      value: sensor.id.isEmpty ? 'N/A' : sensor.id,
                    ),
                    _buildSensorDetailTileWithColor(
                      label: 'Sensor Active',
                      value: sensor.isActive ? 'Active' : 'Inactive',
                      valueColor: sensor.isActive ? Colors.greenAccent : Colors.redAccent,
                    ),
                    _buildSensorDetailTile(
                      label: 'Status',
                      value: sensor.status,
                    ),
                    _buildSensorDetailTile(
                      label: 'Current Water Level',
                      value: '${sensor.waterLevel.toStringAsFixed(2)} ft',
                    ),
                    _buildSensorDetailTile(
                      label: 'Warning Threshold',
                      value: '${(sensor.normalThresholdFt ?? 0.51).toStringAsFixed(2)} ft',
                    ),
                    _buildSensorDetailTile(
                      label: 'Critical Threshold',
                      value: '${(sensor.criticalThresholdFt ?? 1.50).toStringAsFixed(2)} ft',
                    ),
                    _buildSensorDetailTile(
                      label: 'Last Updated',
                      value: sensor.lastReadingAt != null
                          ? DateFormat('MMM d, y - h:mm a').format(sensor.lastReadingAt!.toLocal())
                          : 'No data',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor.withOpacity(0.18),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSensorDetailTile({
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDetailTileWithColor({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sensor Card
  Widget _buildSensorCard(SensorModel sensor) {
    final wl = sensor.waterLevel;
    final statusColor = _colorFromLevel(wl);
    final floodDescription = _statusLabelFromLevel(wl);

    IconData statusIcon;
    double glowIntensity;
    double fillPercentage;

    // Icon, glow & ring fill mapped to 7-level system
    if (wl >= 7.0) {
      statusIcon = Icons.warning_rounded;
      glowIntensity = 0.45;
      fillPercentage = 0.05;
    } else if (wl >= 6.0) {
      statusIcon = Icons.warning_rounded;
      glowIntensity = 0.40;
      fillPercentage = 0.10;
    } else if (wl >= 5.0) {
      statusIcon = Icons.flood;
      glowIntensity = 0.35;
      fillPercentage = 0.15;
    } else if (wl >= 4.0) {
      statusIcon = Icons.flood;
      glowIntensity = 0.30;
      fillPercentage = 0.20;
    } else if (wl >= 3.0) {
      statusIcon = Icons.flood;
      glowIntensity = 0.25;
      fillPercentage = 0.30;
    } else if (wl >= 2.0) {
      statusIcon = Icons.warning_amber_rounded;
      glowIntensity = 0.20;
      fillPercentage = 0.50;
    } else if (wl >= 1.0) {
      statusIcon = Icons.water;
      glowIntensity = 0.15;
      fillPercentage = 0.70;
    } else {
      statusIcon = Icons.house_outlined;
      glowIntensity = 0.05;
      fillPercentage = 1.0;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSensorDetails(sensor),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF16224A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(glowIntensity),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // ── Active / Inactive status dot ──
                        Container(
                          width: 9,
                          height: 9,
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
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sensor.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 35),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  floodDescription,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  ' (${wl.toStringAsFixed(2)} ft)',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sensor.status,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
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

              // Sensor Progress Bar
              NeonSensorRing(
                color: statusColor,
                percentage: fillPercentage,
                size: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Weather Card
  Widget _buildWeatherCard(WeatherModel weather) {
    // Always build slots relative to the current local time so the widget
    // stays accurate no matter when the weather data was fetched.
    final now = DateTime.now(); // device local time (Philippines UTC+8)
    final hourly = weather.hourly;

    final List<_HourlySlot> slots = [];

    for (int offset = 0; offset <= 4; offset++) {
      final targetTime = now.add(Duration(hours: offset));
      final isNow = offset == 0;

      if (hourly.isEmpty) {
        // No hourly data — show placeholders with correct local times
        slots.add(_HourlySlot(
          label: isNow ? 'Now' : _formatHour(targetTime),
          iconCode: weather.iconCode,
          rainChance: (weather.rainChance * 100).round(),
          isNow: isNow,
        ));
      } else {
        // Find the hourly entry whose time is closest to targetTime.
        // WeatherAPI returns local-time strings e.g. "2026-05-11 18:00",
        // parsed by DateTime.tryParse as local DateTime — so we compare hours directly.
        HourlyWeatherEntry best = hourly[0];
        int bestDiff = (hourly[0].time.hour - targetTime.hour).abs();

        for (final entry in hourly) {
          final diff = (entry.time.hour - targetTime.hour).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            best = entry;
          }
        }

        slots.add(_HourlySlot(
          label: isNow ? 'Now' : _formatHour(targetTime),
          // "Now" always uses the current conditions icon (same as main card)
          // so both icons always match. Future slots use the forecast entry.
          iconCode: isNow ? weather.iconCode : best.iconCode,
          rainChance: isNow ? (weather.rainChance * 100).round() : best.rainChance,
          isNow: isNow,
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A), // Main Navy Background
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16224A).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // A. TOP: Icon & Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Local weather icon based on condition
              Expanded(
                child: Center(
                  child: _buildWeatherIcon(weather.iconCode, size: 100),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${weather.temp.round()}\u00b0C',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weather.description,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // B. MIDDLE: Stats Container
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F162F), // Darker Inner Blue
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherDetail('Humidity', '${weather.humidity}%'),
                _buildVerticalDivider(),
                _buildWeatherDetail('Wind', '${weather.windSpeed.toStringAsFixed(1)} km/h'),
                _buildVerticalDivider(),
                _buildWeatherDetail(
                  'Rain',
                  '${(weather.rainChance * 100).round()}%',
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // C. BOTTOM: Dynamic Hourly Forecast
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: slots.map((slot) => _buildHourlyItem(slot)).toList(),
          ),
        ],
      ),
    );
  }

  /// Formats a DateTime as a 12-hour hour label e.g. "3 AM", "2 PM".
  /// Uses device local time (Philippines UTC+8).
  String _formatHour(DateTime dt) {
    // dt from hourly list has no timezone info — treat it as local time directly
    final h = dt.toLocal().hour;
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  /// Returns the local asset path for a given weather icon/condition code.
  /// Supports both OWM-style codes ("01d") and WeatherAPI icon URL strings.
  Widget _buildWeatherIcon(String iconCode, {double size = 40}) {
    final asset = _iconAssetFromCode(iconCode);
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        _iconCodeToIcon(iconCode),
        color: Colors.lightBlueAccent,
        size: size * 0.8,
      ),
    );
  }

  /// Maps a weather icon code to one of our local icon assets.
  /// Automatically switches to night variants (moon, cloudy moon) between 6 PM – 6 AM.
  String _iconAssetFromCode(String code) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 18 || hour < 6; // 6 PM → 6 AM = night

    // WeatherAPI icon URLs look like "//cdn.weatherapi.com/weather/64x64/day/113.png"
    if (code.contains('/')) {
      final match = RegExp(r'/(\d+)\.png').firstMatch(code);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '') ?? 0;
        return _iconFromWeatherApiCode(num, isNight: isNight);
      }
    }

    // OWM codes: "01d", "02d", "09n", etc.
    // Strip the trailing d/n — we use real-time hour for day/night instead.
    final c = code.replaceAll(RegExp(r'[dn]$'), '');
    switch (c) {
      case '01':
        return isNight ? 'icons/moon (2).png' : 'icons/sun (1).png';
      case '02':
        return isNight ? 'icons/cloudy moon.png' : 'icons/sun with cloud.png';
      case '03':
      case '04':
        return isNight ? 'icons/cloudy moon.png' : 'icons/cloudy.png';
      case '09':
      case '11':
        return 'icons/heavy rain.png'; // same day/night
      case '10':
        return 'icons/rainy.png';
      case '13':
      case '50':
        return isNight ? 'icons/cloudy moon.png' : 'icons/cloudy.png';
      default:
        return isNight ? 'icons/moon (2).png' : 'icons/sun with cloud.png';
    }
  }

  /// WeatherAPI numeric condition codes → local icon (day/night aware).
  String _iconFromWeatherApiCode(int code, {required bool isNight}) {
    if (code == 113) {
      return isNight ? 'icons/moon (2).png' : 'icons/sun (1).png';
    }
    if (code == 116) {
      return isNight ? 'icons/cloudy moon.png' : 'icons/sun with cloud.png';
    }
    if (code == 119 || code == 122) {
      return isNight ? 'icons/cloudy moon.png' : 'icons/cloudy.png';
    }
    if (code >= 176 && code <= 185) return 'icons/rainy.png';
    if (code >= 200 && code <= 232) return 'icons/heavy rain.png';
    if (code >= 293 && code <= 321) return 'icons/rainy.png';
    if (code >= 353 && code <= 395) return 'icons/heavy rain.png';
    // Default fallback
    return isNight ? 'icons/moon (2).png' : 'icons/sun with cloud.png';
  }

  /// Material icon fallback for error cases.
  IconData _iconCodeToIcon(String code) {
    if (code.contains('113') || code.contains('01')) return Icons.wb_sunny;
    if (code.contains('116') || code.contains('02')) return Icons.wb_cloudy;
    if (code.contains('09') || code.contains('11') ||
        code.contains('rain') || code.contains('thunder')) {
      return Icons.water_drop;
    }
    if (code.contains('cloud') || code.contains('03') || code.contains('04')) {
      return Icons.cloud;
    }
    return Icons.wb_cloudy;
  }

  // HELPER: Single Weather Detail (Humidity, Wind, Rain)
  Widget _buildWeatherDetail(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // Vertical Line Divider for Weather Details
  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: const Color.fromARGB(31, 227, 213, 213),
    );
  }

  // Hourly Forecast Item — driven by real API data
  Widget _buildHourlyItem(_HourlySlot slot) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: slot.isNow ? const Color(0xFF4A90E2) : const Color(0xFF1D284B),
        borderRadius: BorderRadius.circular(15),
        boxShadow: slot.isNow
            ? [
                BoxShadow(
                  color: const Color(0xFF4A90E2).withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slot.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          // Local weather icon
          _buildWeatherIcon(slot.iconCode, size: 32),
          const SizedBox(height: 4),
          // Rain chance percentage
          Text(
            '${slot.rainChance}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 10,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  // HELPER: Error Card
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFE65100), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to connect',
                  style: TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check your internet or wait for the server to come online.',
                  style: TextStyle(
                    color: Color(0xFF795548),
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Notification Panel — navigate to dedicated full page
  void _openNotificationPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          notifications: _notifications,
          onNotificationsRead: () {
            // Sync isReadLocally state back to _notifications list
            // (already mutated in-place by NotificationsPage)
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }


  // App Bar Widget
  AppBar appBar(String formattedDate) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      toolbarHeight: 80.0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _barangayName ?? 'Loading...',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF101C45),
            ),
          ),
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF101C45),
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            // --- Notification Bell ---
            GestureDetector(
              onTap: _openNotificationPanel,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    alignment: Alignment.center,
                    height: 35,
                    width: 35,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCCCCC).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Color(0xFF101C45), size: 20),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _unreadCount > 9 ? '9+' : '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // --- Profile Button ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              child: Container(
                alignment: Alignment.center,
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCCCCC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(1),
                child: const Icon(Icons.person, color: Color(0xFF101C45), size: 20),
              ),
            ),
            const SizedBox(width: 15),
          ],
        ),
      ],
    );
  }
}

class NeonSensorRing extends StatelessWidget {
  final Color color;
  final double percentage;
  final double size;

  const NeonSensorRing({
    super.key,
    required this.color,
    required this.percentage,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _NeonRingPainter(color: color, percentage: percentage),
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  final Color color;
  final double percentage;

  _NeonRingPainter({required this.color, required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = (size.width / 2) - 4; // Padding for glow

    // 1. Draw Background Track (Faint circle)
    Paint trackPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw The Neon Glow (Blurry Arc)
    Paint glowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6); // The Glow

    // We rotate -90 degrees (-pi/2) so it starts at the top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at Top
      2 * math.pi * percentage, // Sweep amount
      false,
      glowPaint,
    );

    // 3. Draw The Solid Arc (The bright line in the center)
    Paint solidPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          3 // Slightly thinner than the glow to look sharp
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      solidPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


/// Data holder for a single hourly forecast slot in the weather card strip.
class _HourlySlot {
  final String label;     // "Now", "3 AM", "5 PM", etc.
  final String iconCode;  // OWM icon code e.g. "04d"
  final int rainChance;   // 0-100 %
  final bool isNow;

  const _HourlySlot({
    required this.label,
    required this.iconCode,
    required this.rainChance,
    required this.isNow,
  });
}


