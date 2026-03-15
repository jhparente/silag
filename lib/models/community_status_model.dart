class CommunitySafetyStatus {
  int safeCount;
  int unsafeCount;
  int todaysReports;
  DateTime lastUpdated;

  CommunitySafetyStatus({
    required this.safeCount,
    required this.unsafeCount,
    required this.todaysReports,
    required this.lastUpdated,
  });

  factory CommunitySafetyStatus.fromJson(Map<String, dynamic> json) {
    return CommunitySafetyStatus(
      safeCount: json['safeCount'] ?? 0,
      unsafeCount: json['unsafeCount'] ?? 0,
      todaysReports: json['todaysReports'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }
}
