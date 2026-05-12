// All sensors are ultrasonic — the float sensor type was removed from the database.
enum SensorType { ultrasonic }

class SensorModel {
  final String id;
  final String name;
  final SensorType type;
  /// Water level in feet (ft)
  final double waterLevel;
  final bool isRising;
  final String status;
  final String location;
  /// Per-sensor warning threshold in feet (null = use global threshold)
  final double? normalThresholdFt;
  /// Per-sensor critical threshold in feet (null = use global threshold)
  final double? criticalThresholdFt;
  /// GPS coordinates for map display
  final double? latitude;
  final double? longitude;
  /// Timestamp of the last sensor reading (recorded_at from sensor_logs)
  final DateTime? lastReadingAt;
  /// True if last reading was within 10 minutes
  bool get isActive {
    if (lastReadingAt == null) return false;
    return DateTime.now().toUtc().difference(lastReadingAt!.toUtc()).inMinutes < 10;
  }

  // Private constructor to enforce immutability
  SensorModel._internal({
    required this.id,
    required this.name,
    required this.type,
    this.waterLevel = 0.0,
    this.isRising = false,
    required this.status,
    required this.location,
    this.normalThresholdFt,
    this.criticalThresholdFt,
    this.latitude,
    this.longitude,
    this.lastReadingAt,
  });

  /// Factory constructor — all sensors are treated as ultrasonic.
  factory SensorModel.ultrasonic({
    required String id,
    required String name,
    required double waterLevel,
    required String status,
    required String location,
    double? normalThresholdFt,
    double? criticalThresholdFt,
    double? latitude,
    double? longitude,
    DateTime? lastReadingAt,
  }) {
    return SensorModel._internal(
      id: id,
      name: name,
      type: SensorType.ultrasonic,
      waterLevel: waterLevel,
      isRising: false,
      status: status,
      location: location,
      normalThresholdFt: normalThresholdFt,
      criticalThresholdFt: criticalThresholdFt,
      latitude: latitude,
      longitude: longitude,
      lastReadingAt: lastReadingAt,
    );
  }

  factory SensorModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['flood_status'] ?? json['status'] ?? '').toString();
    final status = _normalizeStatus(rawStatus);

    final id = (json['id'] ?? json['sensor_id'] ?? '').toString();
    final name = (json['sensor_name'] ?? json['name'] ?? 'Unknown Sensor')
        .toString();
    final location =
        (json['location_name'] ?? json['location'] ?? 'Unknown Location')
            .toString();

    // water_level / current_water_level is stored in feet by the backend
    final waterLevel = _toDouble(
      json['current_water_level'] ?? json['water_level'] ?? json['waterLevel'],
    );

    final normalThresholdFt = _toDoubleOrNull(json['normal_threshold_ft']);
    final criticalThresholdFt = _toDoubleOrNull(json['critical_threshold_ft']);
    final latitude = _toDoubleOrNull(json['latitude']);
    final longitude = _toDoubleOrNull(json['longitude']);

    // Parse last reading time — prefer recorded_at (from merged log), fall back to last_heartbeat
    DateTime? lastReadingAt;
    final rawTs = (json['recorded_at'] ?? json['last_heartbeat'] ?? '').toString();
    if (rawTs.isNotEmpty) {
      lastReadingAt = DateTime.tryParse(rawTs.replaceFirst(' ', 'T'));
    }

    return SensorModel.ultrasonic(
      id: id,
      name: name,
      waterLevel: waterLevel,
      status: status.isEmpty ? _statusFromWaterLevelFt(waterLevel) : status,
      location: location,
      normalThresholdFt: normalThresholdFt,
      criticalThresholdFt: criticalThresholdFt,
      latitude: latitude,
      longitude: longitude,
      lastReadingAt: lastReadingAt,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _normalizeStatus(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    return text
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Derive a display status from water level in feet.
  static String _statusFromWaterLevelFt(double waterLevelFt) {
    if (waterLevelFt >= 1.50) return 'Critical';
    if (waterLevelFt >= 0.51) return 'Warning';
    if (waterLevelFt >= 0.10) return 'Low Flood';
    return 'No Flood';
  }
}
