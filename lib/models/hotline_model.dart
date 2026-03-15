class HotlineModel {
  final int id;
  final String? ownerId; // Nullable because global hotlines don't have an owner
  final String name;
  final String number;

  HotlineModel({
    required this.id,
    this.ownerId,
    required this.name,
    required this.number,
  });

  factory HotlineModel.fromJson(Map<String, dynamic> json) {
    return HotlineModel(
      id: json['contact_id'] ?? 0,
      ownerId: json['owner_id']?.toString(),
      name: json['name'] ?? 'Unknown',
      number: json['phone_number'] ?? 'No number',
    );
  }
}
