import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:silag/models/user_model.dart';
import 'api_config.dart';
import 'ban_check_service.dart';
import 'notification_service.dart';
import 'push_token_service.dart';

class AuthService {
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
      final response = await http
          .post(
            _buildUri('login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(
              {'mobile_number': mobileNumber, 'password': password},
            ),
          )
          .timeout(const Duration(seconds: 20));

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

        // Record notification cutoff so only post-login notifications show.
        await NotificationService().recordLoginCutoff();

        await PushTokenService().registerTokenIfLoggedIn();

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
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please check your connection and try again.');
      }
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
    required String phoneVerificationToken,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{
        'username': username,
        'mobile_number': mobileNumber,
        'password_hash': password,
        'phone_verification_token': phoneVerificationToken,
      };

      if (latitude != null && longitude != null) {
        payload['latitude'] = latitude;
        payload['longitude'] = longitude;
      }

      final response = await http
          .post(
            _buildUri('register_new_account'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['status'] == 'success') {
        final String token = responseBody['access_token'];
        final Map<String, dynamic> userData = responseBody['data'];
        final normalizedToken = _normalizeToken(token);

        await _storage.write(key: 'jwt_token', value: normalizedToken);
        await _storage.write(key: 'user_id', value: _extractUserId(userData));

        // Record notification cutoff so only post-registration notifications show.
        await NotificationService().recordLoginCutoff();

        await PushTokenService().registerTokenIfLoggedIn();

        // Start ban-check polling for new accounts too.
        BanCheckService().start();

        return UserModel.fromJson(userData, normalizedToken);
      } else {
        // FastAPI returns errors in 'detail'; fallback to 'message' then generic
        final errorMessage =
            responseBody['detail'] ?? responseBody['message'] ?? 'Registration failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please check your connection and try again.');
      }
      final errStr = e.toString();
      if (errStr.contains('ClientException') ||
          errStr.contains('SocketException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable')) {
        throw Exception('Network error occurred. Please try again later.');
      }
      // Re-throw as-is so callers can inspect the actual message
      rethrow;
    }
  }

  /// Step 1 of signup: Request OTP SMS to the given mobile number.
  /// Returns the response map (includes debug_code in staging).
  Future<Map<String, dynamic>> requestRegistrationOtp({
    required String mobileNumber,
  }) async {
    try {
      final response = await http
          .post(
            _buildUri('auth/request-phone-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'mobile_number': mobileNumber}),
          )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return body;
      }
      final msg = (body['detail'] ?? body['message'] ?? 'Failed to send OTP').toString();
      throw Exception(msg);
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please check your connection.');
      }
      final s = e.toString();
      if (s.contains('ClientException') || s.contains('SocketException') ||
          s.contains('Connection refused') || s.contains('Network is unreachable')) {
        throw Exception('Network error. Please check your connection.');
      }
      throw Exception(s.replaceAll('Exception: ', ''));
    }
  }

  /// Step 2 of signup: Submit OTP code and get back a verification_token.
  Future<String> verifyRegistrationOtp({
    required String mobileNumber,
    required String otpCode,
  }) async {
    try {
      final response = await http
          .post(
            _buildUri('auth/verify-phone-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'mobile_number': mobileNumber,
              'otp_code': otpCode,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = body['verification_token'] as String?;
        if (token == null) throw Exception('No verification token returned.');
        return token;
      }
      final msg = (body['detail'] ?? body['message'] ?? 'Verification failed').toString();
      throw Exception(msg);
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Request timed out. Please check your connection.');
      }
      final s = e.toString();
      if (s.contains('ClientException') || s.contains('SocketException') ||
          s.contains('Connection refused') || s.contains('Network is unreachable')) {
        throw Exception('Network error. Please check your connection.');
      }
      throw Exception(s.replaceAll('Exception: ', ''));
    }
  }

  Future<void> requestPasswordResetOtp({
    required String mobileNumber,
    required String deviceToken,
  }) async {
    try {
      final response = await http.post(
        _buildUri('forgot_password/request'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'device_token': deviceToken,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (response.statusCode != 200 || responseBody['status'] != 'success') {
        final message =
            (responseBody['message'] ??
                    responseBody['detail'] ??
                    'Request failed')
                .toString();
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

  Future<void> resetPasswordWithOtp({
    required String mobileNumber,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        _buildUri('forgot_password/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'otp_code': otpCode,
          'new_password': newPassword,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (response.statusCode != 200 || responseBody['status'] != 'success') {
        final message =
            (responseBody['message'] ??
                    responseBody['detail'] ??
                    'Reset failed')
                .toString();
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
    // Clear notification read-state and cutoff so a fresh install/login starts clean.
    await NotificationService().clearOnLogout();
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
  }
}
