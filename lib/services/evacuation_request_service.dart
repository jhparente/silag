import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class EvacuationRequestService {
  static final EvacuationRequestService _instance =
      EvacuationRequestService._internal();
  factory EvacuationRequestService() => _instance;
  EvacuationRequestService._internal();

  final _storage = const FlutterSecureStorage();

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

  Future<void> requestEvacuation({
    required double latitude,
    required double longitude,
    String? note,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        throw Exception('Please log in.');
      }

      final response = await http.post(
        _buildUri('request_evacuation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Failed to submit evacuation request.';

        try {
          final Map<String, dynamic> responseBody = jsonDecode(response.body);
          final detail = responseBody['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail.trim();
          }
        } catch (_) {}

        throw Exception(message);
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable')) {
        throw Exception('Network error occurred. Please try again later.');
      }
      throw Exception(errStr.replaceAll('Exception: ', ''));
    }
  }
}
