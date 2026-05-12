class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String targetAudience;
  final DateTime createdAt;
  bool isReadLocally;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetAudience,
    required this.createdAt,
    this.isReadLocally = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['created_at'] ?? '').toString();
    DateTime parsedDate = DateTime.now();
    if (rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return NotificationModel(
      id: (json['notification_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      targetAudience: (json['target_audience'] ?? 'both').toString(),
      createdAt: parsedDate,
    );
  }
}
