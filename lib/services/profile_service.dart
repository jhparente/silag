import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/profile_model.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final String baseUrl = 'http://127.0.0.1:8000';
  final _storage = const FlutterSecureStorage();

  Future<ProfileModel> fetchUserProfile() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userId = await _storage.read(key: 'user_id');

      if (token == null || userId == null) {
        throw Exception("Please log in.");
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);

        if (responseBody['status'] == 'success') {
          return ProfileModel.fromJson(responseBody['data']);
        }
      }

      if (response.statusCode == 404) {
        throw Exception("User profile not found.");
      }

      throw Exception('Failed to load profile.');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable')) {
        throw Exception(
          'Network error occurred. Please check your connection and try again.',
        );
      }
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? username,
    int? alertThreshold,
    File? profileImage,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userId = await _storage.read(key: 'user_id');

      if (token == null || userId == null) {
        throw Exception('Please log in.');
      }

      final uri = Uri.parse('$baseUrl/users/$userId/profile');
      final request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (username != null && username.isNotEmpty) {
        request.fields['username'] = username;
      }
      if (alertThreshold != null) {
        request.fields['alert_threshold'] = alertThreshold.toString();
      }
      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
      }

      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture_file',
            profileImage.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(
          body['detail'] ??
              'Failed to update profile. (${response.statusCode})',
        );
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable')) {
        throw Exception(
          'Network error occurred. Please check your connection and try again.',
        );
      }
      rethrow;
    }
  }

  // =========================================================================
  // --- NEW: LOGOUT USER (Revoke JWT and Clear FCM Token) ---
  // =========================================================================
  // =========================================================================
  // --- SECURE LOGOUT (Returns TRUE if backend succeeds, FALSE if it fails) ---
  // =========================================================================
  Future<bool> logoutUser() async {
    try {
      final token = await _storage.read(key: 'jwt_token');

      // If there's no token, they are effectively already logged out locally
      if (token == null) return true;

      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // If Python returns 200 OK, the backend successfully cleared the tokens!
      if (response.statusCode == 200) {
        return true;
      } else {
        print(
          "Backend failed to process logout. Status: ${response.statusCode}",
        );
        return false; // Backend failed (like your 500 error!)
      }
    } catch (e) {
      print("Logout API network error: $e");
      return false;
    }
  }
}
