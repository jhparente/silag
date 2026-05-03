/// One slot in the hourly forecast strip.
class HourlyWeatherEntry {
  final DateTime time;
  final String iconCode; // OpenWeatherMap icon code e.g. "04d"
  final double tempC;
  final int rainChance; // 0-100 %

  HourlyWeatherEntry({
    required this.time,
    required this.iconCode,
    required this.tempC,
    required this.rainChance,
  });

  factory HourlyWeatherEntry.fromJson(Map<String, dynamic> json) {
    // "time" comes as "2026-05-02T14:00" (ISO, no timezone)
    final rawTime = json['time']?.toString() ?? '';
    final time = DateTime.tryParse(rawTime) ?? DateTime.now();

    final condition =
        json['condition'] is Map ? json['condition'] as Map<String, dynamic> : <String, dynamic>{};
    final iconCode = (condition['icon'] ?? '01d').toString();

    final tempC = (json['temp_c'] as num?)?.toDouble() ?? 0.0;
    final rainChance = (json['chance_of_rain'] as num?)?.toInt() ?? 0;

    return HourlyWeatherEntry(
      time: time,
      iconCode: iconCode,
      tempC: tempC,
      rainChance: rainChance,
    );
  }
}

class WeatherModel {
  final double temp;
  final String description;
  final int humidity;
  final double windSpeed;
  final double rainChance;
  final String iconCode;
  final List<HourlyWeatherEntry> hourly;

  WeatherModel({
    required this.temp,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.rainChance,
    required this.iconCode,
    this.hourly = const [],
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current = json['list'][0];

    // Parse hourly entries from the backend's top-level "hourly" array
    final rawHourly = json['hourly'];
    final hourly = <HourlyWeatherEntry>[];
    if (rawHourly is List) {
      for (final entry in rawHourly) {
        if (entry is Map<String, dynamic>) {
          hourly.add(HourlyWeatherEntry.fromJson(entry));
        }
      }
    }

    return WeatherModel(
      temp: (current['main']['temp'] as num).toDouble(),
      description: current['weather'][0]['description'],
      humidity: (current['main']['humidity'] as num).toInt(),
      windSpeed: (current['wind']['speed'] as num).toDouble(),
      rainChance: (current['pop'] as num).toDouble(),
      iconCode: current['weather'][0]['icon'],
      hourly: hourly,
    );
  }
}

