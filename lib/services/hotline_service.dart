import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import '../models/hotline_model.dart'; // Adjust path if needed

class HotlineService {
  static final HotlineService _instance = HotlineService._internal();
  factory HotlineService() => _instance;
  HotlineService._internal();

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

  // --- FETCH USER HOTLINES ---
  Future<List<HotlineModel>> fetchMyHotlines() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userId = await _storage.read(key: 'user_id');

      if (token == null || userId == null) {
        throw Exception("Please log in.");
      }

      // Calls your brand new endpoint!
      final response = await http.get(
        _buildUri('user_hotline', queryParameters: {'owner_id': userId}),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> allHotlines = responseBody['data'] ?? [];

        return allHotlines.map((json) => HotlineModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load hotlines.');
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
      throw Exception('Network error: $e');
    }
  }

  Future<void> addLocalHotline(String name, String number) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userId = await _storage.read(key: 'user_id');

      if (token == null || userId == null) {
        throw Exception("Please log in.");
      }

      final response = await http.post(
        _buildUri('add_local_hotline'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'owner_id': userId,
          'name': name,
          'phone_number': number,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode != 200 || responseBody['status'] != 'success') {
        throw Exception(responseBody['detail'] ?? 'Failed to add contact.');
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
      throw Exception('Server error: $e');
    }
  }
}
