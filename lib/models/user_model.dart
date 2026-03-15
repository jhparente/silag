class UserModel {
  final String userId;
  final String username;
  final String mobileNumber;
  final String geocodedAddress;
  final String? profilePictureUrl;
  final String token;

  UserModel({
    required this.userId,
    required this.username,
    required this.mobileNumber,
    this.geocodedAddress = '',
    this.profilePictureUrl,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> data, String token) {
    return UserModel(
      userId: data['user_id']?.toString() ?? '',
      username: data['username'] ?? 'Resident',
      mobileNumber: data['mobile_number'] ?? '',
      geocodedAddress: data['geocoded_address'] ?? '',
      profilePictureUrl: data['profile_picture_url'], // Will safely accept null
      token: token,
    );
  }
}
