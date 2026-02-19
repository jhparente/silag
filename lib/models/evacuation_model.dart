class EvacuationModel {
  final String id;
  final String
  location; // name of the place, e.g. "Dalandanan Elementary School"
  final String address;
  final String imageUrl;
  final double latitude;
  final double longitude;

  EvacuationModel({
    required this.id,
    required this.location,
    required this.address,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
  });
}
