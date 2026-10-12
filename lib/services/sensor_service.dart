import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:silag/models/sensor_model.dart';
import 'package:silag/models/hydrograph_model.dart';
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
      final sensorsResponse = await http
          .get(_buildUri('sensors'))
          .timeout(const Duration(seconds: 15));

      final sensorRows = _extractRowsFromResponse(
        response: sensorsResponse,
        endpointName: 'sensors',
      );

      final sensors = <SensorModel>[];
      for (final row in sensorRows) {
        final id = (row['id'] ?? row['sensor_id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        sensors.add(SensorModel.fromJson(row));
      }

      sensors.sort((a, b) => a.id.compareTo(b.id));
      return sensors;
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

  List<Map<String, dynamic>> _extractRowsFromResponse({
    required http.Response response,
    required String endpointName,
  }) {
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load $endpointName. HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid $endpointName response format');
    }

    final status = (decoded['status'] ?? '').toString().toLowerCase();
    if (status != 'success') {
      throw Exception('Backend returned non-success status for $endpointName');
    }

    final rows = decoded['data'];
    if (rows is! List) return [];

    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }


  Future<HydrographModel> fetchGlobalHydrograph() async {
    try {
      final response = await http
          .get(_buildUri('sensor_hydrograph', version: 'v1'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to load hydrograph');
      }

      final decoded = jsonDecode(response.body);
      if (decoded['status'] != 'success') {
        throw Exception('Backend returned non-success for hydrograph');
      }

      return HydrographModel.fromJson(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load hydrograph data');
    }
  }
  Future<HydrographModel> fetchSensorHydrograph(String sensorId) async {
    try {
      final response = await http
          .get(_buildUri('sensor_hydrograph/$sensorId', version: 'v1'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          return HydrographModel.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return fetchGlobalHydrograph();
    } catch (_) {
      try {
        return await fetchGlobalHydrograph();
      } catch (e) {
        throw Exception('Failed to load sensor hydrograph data');
      }
    }
  }
}
