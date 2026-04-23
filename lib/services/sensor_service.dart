import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:silag/models/sensor_model.dart';
import 'package:silag/services/api_config.dart';

class SensorService {
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

  Future<List<SensorModel>> fetchSensors() async {
    try {
      final response = await http
          .get(_buildUri('sensors'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to load sensors. HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid sensor response format');
      }

      final status = (decoded['status'] ?? '').toString().toLowerCase();
      if (status != 'success') {
        throw Exception('Backend returned non-success status');
      }

      final rows = decoded['data'];
      if (rows is! List) return [];

      return rows
          .whereType<Map>()
          .map((row) => SensorModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
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
