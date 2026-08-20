class FloodReportModel {
  final int? reportId;
  final String userId;
  final String uploadedBy;
  final String geocodedAddress;
  final String floodLevel;
  final String? description;
  final String imageUrl;
  final String? profilePictureUrl;
  final DateTime reportedAt;
  final DateTime? acceptedAt;
  final String reportStatus; // 'Pending', 'Approved', 'Rejected'

  FloodReportModel({
    this.reportId,
    required this.userId,
    required this.uploadedBy,
    required this.geocodedAddress,
    required this.floodLevel,
    this.description = '',
    required this.imageUrl,
    this.profilePictureUrl,
    required this.reportedAt,
    this.acceptedAt,
    this.reportStatus = 'Pending',
  });

  // Convenience getters for UI compatibility
  String get uploaderName => uploadedBy;
  String get address => geocodedAddress;
  String get safeDescription => description ?? '';

  factory FloodReportModel.fromJson(Map<String, dynamic> json) {
    // Resolve timestamp fields — DB may use different column names
    final String? reportedAtRaw = (json['reported_at'] ?? json['created_at'])
        ?.toString();
    final String? acceptedAtRaw = json['accepted_at']?.toString();

    return FloodReportModel(
      reportId: json['report_id'] != null
          ? int.tryParse(json['report_id'].toString())
          : null,
      userId: json['user_id'].toString(),
      uploadedBy: (json['uploaded_by'] ?? 'Unknown').toString(),
      geocodedAddress:
          (json['location_address'] ?? json['geocoded_address'] ?? '')
              .toString(),
      floodLevel: (json['flood_level'] ?? 'Unknown').toString(),
      description: json['description']?.toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      profilePictureUrl: (json['users'] is Map)
          ? json['users']['profile_picture_url']?.toString()
          : json['profile_picture_url']?.toString(),
      reportedAt: reportedAtRaw != null
          ? DateTime.tryParse(reportedAtRaw) ?? DateTime.now()
          : DateTime.now(),
      acceptedAt: acceptedAtRaw != null
          ? DateTime.tryParse(acceptedAtRaw)
          : null,
      reportStatus: (json['report_status'] ?? 'Pending').toString(),
    );
  }
}

