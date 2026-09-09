class ProfileModel {
  final String? username;
  final String? geocodedAddress;
  final String? mobileNumber;
  final String? profilePictureUrl;
  final int? alertThreshold; // Changed from double to int!
  final int? barangayId;
  final String? barangayName;

  ProfileModel({
    this.username,
    this.geocodedAddress,
    this.mobileNumber,
    this.profilePictureUrl,
    this.alertThreshold,
    this.barangayId,
    this.barangayName,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // The backend joins barangays(name) as a nested object.
    String? brgyName;
    final barangaysRel = json['barangays'];
    if (barangaysRel is Map) {
      brgyName = barangaysRel['name']?.toString();
    }

    return ProfileModel(
      username: json['username']?.toString(),
      geocodedAddress: json['geocoded_address']?.toString(),
      mobileNumber: json['mobile_number']?.toString(),
      profilePictureUrl: json['profile_picture_url']?.toString(),
      // Safely parse the threshold strictly as an integer
      alertThreshold: json['alert_threshold'] != null
          ? (json['alert_threshold'] as num).toInt()
          : null,
      barangayId: json['barangay_id'] != null
          ? (json['barangay_id'] as num).toInt()
          : null,
      barangayName: brgyName,
    );
  }
}
