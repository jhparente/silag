import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _handleBanCheck(http.Response response) async {
    if (response.statusCode == 403) {
      try {
        final body = jsonDecode(response.body);
        final detail = body['detail'];
        final code = detail is Map ? detail['code'] : null;
        final message = detail is Map
            ? (detail['message'] ?? 'Your account has been banned.')
            : detail?.toString() ?? '';

        if (code == 'ACCOUNT_BANNED' ||
            message.toLowerCase().contains('banned')) {
          await _forceLogout(message);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> _forceLogout(String reason) async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
      arguments: reason,
    );
  }

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _authHeaders();
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await http.get(uri, headers: headers);
    await _handleBanCheck(response);
    return response;
  }

  Future<http.Response> post(
    Uri uri, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _authHeaders();
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await http.post(uri, headers: headers, body: body);
    await _handleBanCheck(response);
    return response;
  }

  Future<http.Response> put(
    Uri uri, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _authHeaders();
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await http.put(uri, headers: headers, body: body);
    await _handleBanCheck(response);
    return response;
  }

  Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request,
  ) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final wasBanned = await _handleBanCheck(response);

    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: wasBanned ? 'ACCOUNT_BANNED' : response.reasonPhrase,
    );
  }
}
