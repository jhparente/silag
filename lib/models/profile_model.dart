class ProfileModel {
  final String? username;
  final String? geocodedAddress;
  final String? mobileNumber;
  final String? profilePictureUrl;
  final int? alertThreshold; // Changed from double to int!

  ProfileModel({
    this.username,
    this.geocodedAddress,
    this.mobileNumber,
    this.profilePictureUrl,
    this.alertThreshold,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      username: json['username']?.toString(),
      geocodedAddress: json['geocoded_address']?.toString(),
      mobileNumber: json['mobile_number']?.toString(),
      profilePictureUrl: json['profile_picture_url']?.toString(),
      // Safely parse the threshold strictly as an integer
      alertThreshold: json['alert_threshold'] != null
          ? (json['alert_threshold'] as num).toInt()
          : null,
    );
  }
}
