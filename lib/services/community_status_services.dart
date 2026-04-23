import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:silag/models/community_status_model.dart';
import 'api_config.dart';

class CommunityStatusServices {
  static final CommunityStatusServices _instance =
      CommunityStatusServices._internal();
  factory CommunityStatusServices() => _instance;
  CommunityStatusServices._internal();

  final _storage = FlutterSecureStorage();

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

  Future<CommunitySafetyStatus> fetchCommunitySafetyStatus() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        throw Exception('Please login again');
      }

      final response = await http.get(
        _buildUri('get_community_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        if (responseBody['status'] == 'success') {
          return CommunitySafetyStatus.fromJson(responseBody['data']);
        }
      }
      throw Exception('Failed to fetch community safety status');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable')) {
        throw Exception('Network error occurred. Please try again later.');
      }
      throw Exception('Error fetching community safety status: $e');
    }
  }

  Future<void> castVote(bool isSafe) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userId = await _storage.read(key: 'user_id');

      if (token == null || userId == null) {
        throw Exception('Please login again');
      }

      final response = await http.post(
        _buildUri('cast_safety_status_vote'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId, 'is_safe': isSafe}),
      );
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      // Catch the 1-hour cooldown error from Python (HTTP 429)
      if (response.statusCode == 429) {
        throw Exception(
          responseBody['detail'],
        ); // Displays: "You can only vote once every hour."
      }

      // Catch any other backend errors
      if (response.statusCode != 200 || responseBody['status'] != 'success') {
        throw Exception(responseBody['detail'] ?? 'Failed to submit vote.');
      }
    } catch (e) {
      // Clean up the error message for the UI
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
