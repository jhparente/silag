// ignore_for_file: deprecated_member_use of withOpacity
import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:silag/pages/profile_page.dart';
import 'package:silag/services/sensor_service.dart';
import 'package:silag/services/weather_service.dart';
import 'package:silag/models/weather_model.dart';
import 'package:silag/models/sensor_model.dart';
import 'dart:math' as math; // Required for the drawing math

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _weatherService = WeatherService();
  final _sensorService = SensorService();

  late Future<WeatherModel> _weatherFuture;
  late Future<List<SensorModel>> _sensorsFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _weatherService.fetchWeather();
    _sensorsFuture = _sensorService.fetchSensors();
  }

  Future<void> _refreshData() async {
    setState(() {
      _weatherFuture = _weatherService.fetchWeather();
      _sensorsFuture = _sensorService.fetchSensors();
    });
    // Wait for both futures to complete so the RefreshIndicator stops spinning
    await Future.wait([_weatherFuture, _sensorsFuture]);
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // --- WEATHER SECTION ---
              FutureBuilder<WeatherModel>(
                future: _weatherFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingSkeleton(height: 400);
                  }
                  if (snapshot.hasError) {
                    return _buildErrorCard(snapshot.error.toString());
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
                        _buildLoadingSkeleton(height: 100),
                        const SizedBox(height: 15),
                        _buildLoadingSkeleton(height: 100),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildErrorCard('Failed to load the sensors');
                  }

                  final sensors = snapshot.data!;
                  return Column(
                    children: sensors
                        .map((sensor) => _buildSensorCard(sensor))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Color _sensorPrimaryColor(SensorModel sensor) {
    if (sensor.type == SensorType.ultrasonic) {
      if (sensor.waterLevel >= 3.0) return Colors.redAccent;
      if (sensor.waterLevel >= 2.0) return Colors.orangeAccent;
      if (sensor.waterLevel >= 1.0) return Colors.yellowAccent;
      return Colors.greenAccent;
    }

    return sensor.isRising ? Colors.redAccent : Colors.greenAccent;
  }

  void _showSensorDetails(SensorModel sensor) {
    final isUltrasonic = sensor.type == SensorType.ultrasonic;
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
                            isUltrasonic ? Icons.flood : Icons.sensors,
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
                    _buildSensorDetailTile(
                      label: 'Sensor Type',
                      value: isUltrasonic ? 'Ultrasonic' : 'Float',
                    ),
                    _buildSensorDetailTile(
                      label: 'Status',
                      value: sensor.status,
                    ),
                    if (isUltrasonic)
                      _buildSensorDetailTile(
                        label: 'Current Water Level',
                        value: '${sensor.waterLevel.toStringAsFixed(2)} m',
                      )
                    else
                      _buildSensorDetailTile(
                        label: 'Float Trend',
                        value: sensor.isRising ? 'Rising' : 'Stable',
                      ),
                    _buildSensorDetailTile(
                      label: 'Last Refreshed',
                      value: DateFormat(
                        'MMM d, y - h:mm a',
                      ).format(DateTime.now()),
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

  // Sensor Card
  Widget _buildSensorCard(SensorModel sensor) {
    Color statusColor;
    IconData statusIcon;
    String displayStatus;
    String displayValue;
    String floodDescription = 'Normal';
    double glowIntensity = 0.1;
    double fillPercentage = 1.0; // Default fill percentage

    if (sensor.type == SensorType.ultrasonic) {
      displayValue = '${sensor.waterLevel}m';
      displayStatus = sensor.status;

      if (sensor.waterLevel >= 3.0) {
        statusColor = Colors.redAccent;
        statusIcon = Icons.flood;
        floodDescription = 'Waist Level';
        glowIntensity = 0.3;
        fillPercentage = 0.25; // Small arc for critical/high
      } else if (sensor.waterLevel >= 2.0) {
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.warning_amber_rounded;
        floodDescription = 'Knee Level';
        glowIntensity = 0.2;
        fillPercentage = 0.60; // Partial arc for warning
      } else if (sensor.waterLevel >= 1.0) {
        statusColor = Colors.yellowAccent;
        statusIcon = Icons.water;
        floodDescription = 'Ankle Level';
        glowIntensity = 0.1;
        fillPercentage = 0.75; // Mostly full for alert
      } else {
        statusColor = Colors.greenAccent;
        statusIcon = Icons.house_outlined;
        floodDescription = 'No Flood';
        glowIntensity = 0.05;
        fillPercentage = 1.0; // Full circle for safe
      }
    } else if (sensor.type == SensorType.float) {
      displayValue = sensor.isRising ? 'Rising' : 'Stable';
      displayStatus = sensor.status;

      if (sensor.isRising) {
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_amber_rounded;
        glowIntensity = 0.2;
        fillPercentage = 0.50; // Half circle for rising
      } else {
        statusColor = Colors.greenAccent;
        statusIcon = Icons.house_outlined;
        glowIntensity = 0.05;
        fillPercentage = 1.0; // Full circle for stable
      }
    } else {
      // Default values for unknown sensor types
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      displayStatus = 'Unknown';
      displayValue = 'N/A';
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
                        if (sensor.type == SensorType.float)
                          Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '$floodDescription - ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    sensor.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'Flood Level: ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    displayValue,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.network(
                'https://openweathermap.org/img/wn/${weather.iconCode}@4x.png',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.cloud,
                  size: 100,
                  color: Colors.lightBlueAccent,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weather.temp.round()}°C',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    weather.description,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
                _buildWeatherDetail('Wind', '${weather.windSpeed} km/h'),
                _buildVerticalDivider(),
                _buildWeatherDetail(
                  'Rain',
                  '${(weather.rainChance * 100).round()}%',
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // C. BOTTOM: Hourly Forecast
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHourlyItem("11:00", Icons.cloud, false),
              _buildHourlyItem("Now", Icons.cloud_queue, true), // Active
              _buildHourlyItem("3:00", Icons.bolt, false),
              _buildHourlyItem("5:00", Icons.grain, false),
              _buildHourlyItem("7:00", Icons.wb_cloudy, false),
            ],
          ),
        ],
      ),
    );
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

  // Hourly Forecast Item
  Widget _buildHourlyItem(String time, IconData icon, bool isActive) {
    return Container(
      width: 55,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4A90E2) : const Color(0xFF1D284B),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isActive
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
        children: [
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  // HELPER: Loading Skeleton
  Widget _buildLoadingSkeleton({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  // HELPER: Error Card
  Widget _buildErrorCard(String error) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Error: $error",
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
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
          const Text(
            'Brgy. Dalandanan',
            style: TextStyle(
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
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF101C45),
                  size: 20,
                ),
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
