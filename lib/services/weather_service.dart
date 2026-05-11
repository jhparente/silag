import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:silag/models/weather_model.dart';
import 'package:silag/services/api_config.dart';

class WeatherService {
  // ── In-memory cache ─────────────────────────────────────────────────────
  // Cache the last successful response for up to 10 minutes so the widget
  // loads instantly on every visit without hitting the network again.
  static WeatherModel? _cachedWeather;
  static DateTime? _cacheExpiry;
  static const _cacheDuration = Duration(minutes: 10);

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    return ApiConfig.uri(path, queryParameters: queryParameters);
  }

  Future<WeatherModel> fetchWeather({bool forceRefresh = false}) async {
    // Return cached data immediately if it is still valid and not forced.
    if (!forceRefresh &&
        _cachedWeather != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedWeather!;
    }

    try {
      final response = await http
          .get(_buildUri('weather'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        // If the network call fails but we have stale cache, return it.
        if (_cachedWeather != null) return _cachedWeather!;
        throw Exception(
          'Failed to load weather data. HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        if (_cachedWeather != null) return _cachedWeather!;
        throw Exception('Invalid weather response format');
      }

      final status = (decoded['status'] ?? '').toString().toLowerCase();
      if (status != 'success') {
        if (_cachedWeather != null) return _cachedWeather!;
        throw Exception('Backend returned non-success status for weather');
      }

      final weatherPayload = decoded['data'];
      if (weatherPayload is! Map<String, dynamic>) {
        if (_cachedWeather != null) return _cachedWeather!;
        throw Exception('Weather payload is missing in backend response');
      }

      final model = WeatherModel.fromJson(weatherPayload);

      // Store in cache.
      _cachedWeather = model;
      _cacheExpiry = DateTime.now().add(_cacheDuration);

      return model;
    } catch (e) {
      // On any network error, serve stale cache if available.
      if (_cachedWeather != null) return _cachedWeather!;

      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable') ||
          errStr.contains('TimeoutException')) {
        throw Exception('Network error occurred. Please try again later.');
      }
      rethrow;
    }
  }
}
