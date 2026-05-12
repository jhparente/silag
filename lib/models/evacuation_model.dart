class EvacuationModel {
  final String id;
  final String name;
  final String address;
  final String evacuationImageUrl; // Clean Dart camelCase!
  final double latitude;
  final double longitude;
  final int maxCapacity;
  final int currentOccupancyFamily;
  final int currentOccupancyIndividual;

  EvacuationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.evacuationImageUrl,
    required this.latitude,
    required this.longitude,
    required this.maxCapacity,
    required this.currentOccupancyFamily,
    required this.currentOccupancyIndividual,
  });

  factory EvacuationModel.fromJson(Map<String, dynamic> json) {
    return EvacuationModel(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown Name',
      address: json['address'] ?? 'No address provided',

      // Translating the image URL specifically!
      evacuationImageUrl: json['evacuation_image_url'] ?? '',

      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 0,
      currentOccupancyFamily: (json['current_occupancy_family'] as num?)?.toInt() ?? 0,
      currentOccupancyIndividual: (json['current_occupancy_individual'] as num?)?.toInt() ?? 0,
    );
  }
}
