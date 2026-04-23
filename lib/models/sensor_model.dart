enum SensorType { ultrasonic, float }

class SensorModel {
  final String id;
  final String name;
  final SensorType type;
  final double waterLevel;
  final bool isRising;
  final String status;
  final String location;

  // Private constructor to enforce immutability
  SensorModel._internal({
    required this.id,
    required this.name,
    required this.type,
    this.waterLevel = 0.0,
    this.isRising = false,
    required this.status,
    required this.location,
  });

  // Factory constructor for creating a new SensorModel instance
  factory SensorModel.ultrasonic({
    required String id,
    required String name,
    required double waterLevel,
    required String status,
    required String location,
  }) {
    return SensorModel._internal(
      id: id,
      name: name,
      type: SensorType.ultrasonic,
      waterLevel: waterLevel,
      isRising: false, // Default value for ultrasonic sensors
      status: status,
      location: location,
    );
  }

  factory SensorModel.float({
    required String id,
    required String name,
    required bool isRising,
    required String status,
    required String location,
  }) {
    return SensorModel._internal(
      id: id,
      name: name,
      type: SensorType.float,
      waterLevel: 0.0, // Default value for float sensors
      isRising: isRising,
      status: status,
      location: location,
    );
  }

  factory SensorModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['flood_status'] ?? json['status'] ?? '').toString();
    final status = _normalizeStatus(rawStatus);

    final rawType = (json['sensor_type'] ?? json['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final hasRisingFlag =
        json.containsKey('is_rising') || json.containsKey('isRising');

    final type = rawType.contains('ultra')
        ? SensorType.ultrasonic
        : rawType.contains('float')
        ? SensorType.float
        : (hasRisingFlag || status.toLowerCase() == 'rising')
        ? SensorType.float
        : SensorType.ultrasonic;

    final id = (json['id'] ?? json['sensor_id'] ?? '').toString();
    final name = (json['sensor_name'] ?? json['name'] ?? 'Unknown Sensor')
        .toString();
    final location =
        (json['location_name'] ?? json['location'] ?? 'Unknown Location')
            .toString();

    final waterLevel = _toDouble(
      json['current_water_level'] ?? json['water_level'] ?? json['waterLevel'],
    );

    final isRising =
        _toBool(json['is_rising'] ?? json['isRising']) ||
        status.toLowerCase() == 'rising';

    if (type == SensorType.float) {
      return SensorModel.float(
        id: id,
        name: name,
        isRising: isRising,
        status: status.isEmpty ? (isRising ? 'Rising' : 'Normal') : status,
        location: location,
      );
    }

    return SensorModel.ultrasonic(
      id: id,
      name: name,
      waterLevel: waterLevel,
      status: status.isEmpty ? _statusFromWaterLevel(waterLevel) : status,
      location: location,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes' || v == 'rising';
    }
    return false;
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

  static String _statusFromWaterLevel(double waterLevel) {
    if (waterLevel >= 3.0) return 'Danger';
    if (waterLevel >= 2.0) return 'Warning';
    if (waterLevel >= 1.0) return 'Alert';
    return 'Normal';
  }
}
