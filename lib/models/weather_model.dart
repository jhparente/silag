class WeatherModel {
  final double temp;
  final String description;
  final int humidity;
  final double windSpeed;
  final double rainChance;
  final String iconCode;

  WeatherModel({
    required this.temp,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.rainChance,
    required this.iconCode,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current = json['list'][0];

    return WeatherModel(
      temp: current['main']['temp'].toDouble(),
      description: current['weather'][0]['description'],
      humidity: current['main']['humidity'],
      windSpeed: (current['wind']['speed'] as num).toDouble(),
      rainChance: (current['pop'] as num).toDouble(),
      iconCode: current['weather'][0]['icon'],
    );
  }
}
