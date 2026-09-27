class HydrographPoint {
  final String label;
  final double value;
  final bool isForecast;

  HydrographPoint({
    required this.label,
    required this.value,
    required this.isForecast,
  });

  factory HydrographPoint.fromJson(Map<String, dynamic> json) {
    return HydrographPoint(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      isForecast: json['isForecast'] == true || json['is_forecast'] == true,
    );
  }
}

class HydrographModel {
  final List<HydrographPoint> points;
  final double? meanLatest;
  final double? predictedRiseFt;

  HydrographModel({
    required this.points,
    this.meanLatest,
    this.predictedRiseFt,
  });

  factory HydrographModel.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List?)
            ?.map((e) => HydrographPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return HydrographModel(
      points: pointsList,
      meanLatest: (json['mean_latest'] as num?)?.toDouble(),
      predictedRiseFt: (json['predicted_rise_ft'] as num?)?.toDouble(),
    );
  }
}
