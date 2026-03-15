import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:silag/models/flood_report_model.dart';

class FloodReportService {
  static final FloodReportService _instance = FloodReportService._internal();
  factory FloodReportService() => _instance;
  FloodReportService._internal();

  final String baseUrl = 'http://127.0.0.1:8000'; // web / USB run
  // final String baseUrl = 'http://10.0.2.2:8000';      // Android emulator
  // final String baseUrl = 'http://192.168.100.17:8000';  // physical device WiFi
  final _storage = const FlutterSecureStorage();

  // --- HELPER: Common auth headers ---
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      throw Exception(
        'User not authenticated. Please log out and log in again.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // --- SUBMIT REPORT (called from CreateReportPage) ---
  Future<void> submitReport({
    required String address,
    required String floodLevel,
    required String description,
    required String imageUrl,
  }) async {
    try {
      final userId = await _storage.read(key: 'user_id');
      final headers = await _authHeaders();

      if (userId == null) {
        throw Exception(
          'User not authenticated. Please log out and log in again.',
        );
      }

      final uri = Uri.parse('$baseUrl/submit_flood_report');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'address': address,
          'flood_level': floodLevel,
          'description': description,
          'image_url': imageUrl,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to submit report. (${response.statusCode})');
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

  // --- SHARED: Fetch all accepted reports from backend ---
  Future<List<FloodReportModel>> _fetchPublicReports() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/flood_reports_public');
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['data'] ?? [];
      return data.map((json) => FloodReportModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load reports. (${response.statusCode})');
    }
  }

  // --- FETCH RECENT REPORTS (last 24 hours, called from ReportPage) ---
  Future<List<FloodReportModel>> fetchRecentReports() async {
    try {
      final all = await _fetchPublicReports();
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final filtered = all
          .where((r) => (r.acceptedAt ?? r.reportedAt).isAfter(cutoff))
          .toList();
      // Sort newest first so the most recent appears on the left
      filtered.sort(
        (a, b) => (b.acceptedAt ?? b.reportedAt).compareTo(
          a.acceptedAt ?? a.reportedAt,
        ),
      );
      return filtered;
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

  // --- FETCH ALL VALID REPORTS (called from AllFloodReportsPage) ---
  Future<List<FloodReportModel>> fetchAllValidReports() async {
    try {
      return await _fetchPublicReports();
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

  // --- SUBMIT FLOOD REPORT WITH GPS + IMAGE FILE (multipart) ---
  Future<void> submitFloodReport({
    required double latitude,
    required double longitude,
    required String floodLevel,
    required String description,
    required File imageFile,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final userId = await _storage.read(key: 'user_id');

      if (token == null || userId == null) {
        throw Exception(
          'User not authenticated. Please log out and log in again.',
        );
      }

      final uri = Uri.parse('$baseUrl/submit_flood_report');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['user_id'] = userId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['flood_level'] = floodLevel;
      debugPrint('>>> Sending flood_level: $floodLevel');
      if (description.isNotEmpty) {
        request.fields['description'] = description;
      }

      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Submit status: ${response.statusCode}');
      debugPrint('Submit body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to submit report. (${response.statusCode}): ${response.body}',
        );
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
}
