import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:silag/models/notification_model.dart';
import 'api_config.dart';

class NotificationService {
  static const _readIdsKey = 'read_notification_ids';
  final _storage = const FlutterSecureStorage();

  Future<String?> _getJwt() => _storage.read(key: 'jwt_token');

  Future<List<NotificationModel>> fetchNotifications() async {
    final jwt = await _getJwt();
    if (jwt == null || jwt.isEmpty) return [];

    final readIds = await _getReadIds();

    final response = await http.get(
      ApiConfig.uri('notifications/mobile', queryParameters: {'limit': '50'}),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] as List? ?? [];

    return data.map((json) {
      final n = NotificationModel.fromJson(json as Map<String, dynamic>);
      n.isReadLocally = readIds.contains(n.id);
      return n;
    }).toList();
  }

  Future<Set<int>> _getReadIds() async {
    final raw = await _storage.read(key: _readIdsKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toSet();
  }

  Future<void> markAsRead(int notificationId) async {
    final ids = await _getReadIds();
    ids.add(notificationId);
    await _storage.write(key: _readIdsKey, value: ids.join(','));
  }

  Future<void> markAllAsRead(List<int> ids) async {
    final existing = await _getReadIds();
    existing.addAll(ids);
    await _storage.write(key: _readIdsKey, value: existing.join(','));
  }
}
