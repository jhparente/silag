import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_client.dart';

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

  /// Returns the user's latest pending/accepted evacuation request, or null.
  Future<Map<String, dynamic>?> getMyEvacuationRequest() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final response = await http.get(
        _buildUri('my_evacuation_request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (data == null) return null;
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Submits an evacuation request with household counts, health conditions,
  /// additional info, and an optional proof image — using multipart/form-data.
  Future<void> requestEvacuation({
    required double latitude,
    required double longitude,
    String? note,
    // household counts
    int adultsMale = 0,
    int adultsFemale = 0,
    int minorsMale = 0,
    int minorsFemale = 0,
    int toddlersMale = 0,
    int toddlersFemale = 0,
    int infantsMale = 0,
    int infantsFemale = 0,
    int seniorsMale = 0,
    int seniorsFemale = 0,
    // health conditions
    int lactatingCount = 0,
    int pregnantCount = 0,
    int injuredCount = 0,
    int pwdCount = 0,
    String? pwdTypeSpec,
    // additional
    String? additionalInfo,
    File? proofImage,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        throw Exception('Please log in.');
      }

      final uri = _buildUri('request_evacuation');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // --- Core fields ---
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      if (note != null && note.trim().isNotEmpty) {
        request.fields['note'] = note.trim();
      }

      // --- Household counts ---
      request.fields['adults_male'] = adultsMale.toString();
      request.fields['adults_female'] = adultsFemale.toString();
      request.fields['minors_male'] = minorsMale.toString();
      request.fields['minors_female'] = minorsFemale.toString();
      request.fields['toddlers_male'] = toddlersMale.toString();
      request.fields['toddlers_female'] = toddlersFemale.toString();
      request.fields['infants_male'] = infantsMale.toString();
      request.fields['infants_female'] = infantsFemale.toString();
      request.fields['seniors_male'] = seniorsMale.toString();
      request.fields['seniors_female'] = seniorsFemale.toString();

      // --- Health conditions ---
      request.fields['lactating_count'] = lactatingCount.toString();
      request.fields['pregnant_count'] = pregnantCount.toString();
      request.fields['injured_count'] = injuredCount.toString();
      request.fields['pwd_count'] = pwdCount.toString();
      if (pwdTypeSpec != null && pwdTypeSpec.trim().isNotEmpty) {
        request.fields['pwd_type_spec'] = pwdTypeSpec.trim();
      }

      // --- Additional info ---
      if (additionalInfo != null && additionalInfo.trim().isNotEmpty) {
        request.fields['additional_info'] = additionalInfo.trim();
      }

      // --- Proof image ---
      if (proofImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('proof_image', proofImage.path),
        );
      }

      final streamedResponse = await ApiClient().sendMultipart(request);
      final response = await http.Response.fromStream(streamedResponse);

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
