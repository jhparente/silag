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
      final sensorsResponse = await http
          .get(_buildUri('sensors'))
          .timeout(const Duration(seconds: 15));

      final sensorRows = _extractRowsFromResponse(
        response: sensorsResponse,
        endpointName: 'sensors',
      );

      final logsResponse = await http
          .get(_buildUri('sensor_logs'))
          .timeout(const Duration(seconds: 15));

      final logRows = _extractRowsFromResponse(
        response: logsResponse,
        endpointName: 'sensor_logs',
      );

      final sensorsById = <String, Map<String, dynamic>>{};
      for (final row in sensorRows) {
        final id = (row['id'] ?? row['sensor_id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        sensorsById[id] = row;
      }

      if (sensorsById.isEmpty) return [];

      final latestLogBySensorId = _latestLogBySensorId(logRows);

      // Iterate over ALL sensors (not just those with logs) so that newly
      // registered sensors with no log history are still displayed.
      final mergedRows = sensorsById.entries.map((entry) {
        final sensorId = entry.key;
        final sensorRow = entry.value;
        final logRow = latestLogBySensorId[sensorId] ?? const <String, dynamic>{};

        return <String, dynamic>{
          ...sensorRow,
          ...logRow,
          'id': sensorRow['id'] ?? sensorId,
          'sensor_id': sensorId,
          'current_water_level':
              logRow['water_level'] ?? sensorRow['current_water_level'],
          'flood_status': logRow['status'] ?? sensorRow['flood_status'],
          'status': logRow['status'] ?? sensorRow['status'],
        };
      }).toList();

      mergedRows.sort((a, b) {
        final aId = (a['id'] ?? a['sensor_id'] ?? '').toString();
        final bId = (b['id'] ?? b['sensor_id'] ?? '').toString();
        return aId.compareTo(bId);
      });

      return mergedRows.map(SensorModel.fromJson).toList();
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

  Map<String, Map<String, dynamic>> _latestLogBySensorId(
    List<Map<String, dynamic>> logRows,
  ) {
    final latest = <String, Map<String, dynamic>>{};
    final latestTimestamps = <String, DateTime?>{};

    for (final row in logRows) {
      final sensorId = (row['sensor_id'] ?? row['id'] ?? '').toString().trim();
      if (sensorId.isEmpty) continue;

      final recordedAtRaw = (row['recorded_at'] ?? '').toString();
      final recordedAt = DateTime.tryParse(recordedAtRaw);

      final currentTs = latestTimestamps[sensorId];
      final shouldReplace =
          !latest.containsKey(sensorId) ||
          (recordedAt != null && currentTs == null) ||
          (recordedAt != null &&
              currentTs != null &&
              recordedAt.isAfter(currentTs)) ||
          (recordedAt == null && currentTs == null);

      if (shouldReplace) {
        latest[sensorId] = row;
        latestTimestamps[sensorId] = recordedAt;
      }
    }

    return latest;
  }
}
