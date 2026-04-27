import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:silag/models/weather_model.dart';
import 'package:silag/services/api_config.dart';

class WeatherService {
  Uri _buildUri(
    String path, {
    String? version,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiConfig.uri(
      path,
      version: version,
      queryParameters: queryParameters,
    );
  }

  Future<WeatherModel> fetchWeather() async {
    try {
      final response = await http
          .get(_buildUri('weather'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load weather data. HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid weather response format');
      }

      final status = (decoded['status'] ?? '').toString().toLowerCase();
      if (status != 'success') {
        throw Exception('Backend returned non-success status for weather');
      }

      final weatherPayload = decoded['data'];
      if (weatherPayload is! Map<String, dynamic>) {
        throw Exception('Weather payload is missing in backend response');
      }

      return WeatherModel.fromJson(weatherPayload);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable')) {
        throw Exception('Network error occurred. Please try again later.');
      }
      rethrow;
    }
  }
}
