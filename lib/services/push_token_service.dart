import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class PushTokenService {
  PushTokenService._internal();
  static final PushTokenService _instance = PushTokenService._internal();
  factory PushTokenService() => _instance;

  final _storage = const FlutterSecureStorage();
  final _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}
    try {
      await registerTokenIfLoggedIn();
    } catch (_) {}
    _messaging.onTokenRefresh.listen((token) {
      registerTokenIfLoggedIn(tokenOverride: token);
    });
  }

  Future<void> registerTokenIfLoggedIn({String? tokenOverride}) async {
    String? token;
    try {
      // Give getToken() a maximum of 8 seconds to avoid blocking startup
      token = tokenOverride ??
          await _messaging.getToken().timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );
    } catch (_) {
      return;
    }
    if (token == null || token.isEmpty) return;

    final jwt = await _storage.read(key: 'jwt_token');
    final userId = await _storage.read(key: 'user_id');
    if (jwt == null || userId == null || userId.isEmpty) return;

    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : Platform.operatingSystem;

    try {
      await http.post(
        ApiConfig.uri('users/$userId/device_tokens'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'token': token, 'platform': platform}),
      );
    } catch (_) {
      // Best-effort only. Token will be retried on next launch or refresh.
    }
  }
}
