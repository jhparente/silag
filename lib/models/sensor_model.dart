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
}
