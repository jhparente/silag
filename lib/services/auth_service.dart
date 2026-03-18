import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silag/models/user_model.dart';
import 'ban_check_service.dart';

class AuthService {
  final String baseUrl = 'http://127.0.0.1:8000'; // web / USB run
  // final String baseUrl = 'http://10.0.2.2:8000';      // Android emulator
  // final String baseUrl = 'http://192.168.100.17:8000';  // physical device WiFi

  final _storage = const FlutterSecureStorage();

  String _normalizeToken(String token) {
    final trimmed = token.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }

  String _extractUserId(Map<String, dynamic> userData) {
    return (userData['user_id'] ?? userData['id'] ?? '').toString();
  }

  Future<UserModel> login({
    required String mobileNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'mobile_number': mobileNumber, 'password': password}),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      // check if the response is successful and contains the expected data
      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        // Extract the token and user data from the response
        final String? token = responseBody['access_token'] as String?;
        final Map<String, dynamic>? userData =
            responseBody['data'] as Map<String, dynamic>?;

        if (token == null || userData == null) {
          throw Exception('Invalid response from server. Please try again.');
        }

        final normalizedToken = _normalizeToken(token);

        // Store a normalized token and user_id securely.
        await _storage.write(key: 'jwt_token', value: normalizedToken);
        await _storage.write(key: 'user_id', value: _extractUserId(userData));

        // Start the ban-check polling so a banned user is kicked out
        // automatically even while the app is open.
        BanCheckService().start();

        // Pass normalized token to the UserModel.
        return UserModel.fromJson(userData, normalizedToken);
      } else {
        final String code = (responseBody['code'] ?? '').toString();
        final String errorMessage =
            (responseBody['message'] ??
                    responseBody['detail'] ??
                    'Login failed')
                .toString();

        if (code == 'ACCOUNT_BANNED' ||
            errorMessage.toLowerCase().contains('banned')) {
          throw Exception('Account is banned. Contact the admin.');
        }

        throw Exception(errorMessage);
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

      if (errStr.toLowerCase().contains('banned')) {
        throw Exception('Account is banned. Contact the admin.');
      }

      throw Exception(errStr.replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel> register({
    required String username,
    required String mobileNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register_new_account'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'mobile_number': mobileNumber,
          'password_hash': password,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        final String token = responseBody['access_token'];
        final Map<String, dynamic> userData = responseBody['data'];
        final normalizedToken = _normalizeToken(token);

        await _storage.write(key: 'jwt_token', value: normalizedToken);
        await _storage.write(key: 'user_id', value: _extractUserId(userData));

        // Start ban-check polling for new accounts too.
        BanCheckService().start();

        return UserModel.fromJson(userData, normalizedToken);
      } else {
        final errorMessage = responseBody['message'] ?? 'Registration failed';
        throw Exception(errorMessage);
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
      throw Exception('Server Error: $e');
    }
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return null;

    final normalizedToken = _normalizeToken(token);
    if (normalizedToken != token) {
      await _storage.write(key: 'jwt_token', value: normalizedToken);
    }
    return normalizedToken;
  }

  Future<void> logout() async {
    // Stop the background polling before clearing credentials.
    BanCheckService().stop();
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
  }
}
