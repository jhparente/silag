import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:silag/models/notification_model.dart';
import 'api_config.dart';

class NotificationService {
  static const _readIdsKey = 'read_notification_ids';
  static const _cutoffKey = 'notif_cutoff_timestamp';
  final _storage = const FlutterSecureStorage();

  Future<String?> _getJwt() => _storage.read(key: 'jwt_token');

  // ── Called on successful login ──────────────────────────────────────────────
  // Saves the current UTC epoch (ms) as the "cutoff" so only notifications
  // received AFTER this point are shown to the user.
  // Only writes once per install — does not advance on subsequent logins.
  Future<void> recordLoginCutoff() async {
    final existing = await _storage.read(key: _cutoffKey);
    if (existing == null || existing.isEmpty) {
      final ms = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
      await _storage.write(key: _cutoffKey, value: ms);
    }
  }

  // ── Called on logout ────────────────────────────────────────────────────────
  // Clears read-IDs AND the cutoff so a reinstall + new login starts fresh.
  Future<void> clearOnLogout() async {
    await _storage.delete(key: _readIdsKey);
    await _storage.delete(key: _cutoffKey);
  }

  Future<List<NotificationModel>> fetchNotifications() async {
    final jwt = await _getJwt();
    if (jwt == null || jwt.isEmpty) return [];

    final cutoff = await _getCutoff();

    // Fetch cloud read IDs and sync locally
    try {
      final readRes = await http.get(
        ApiConfig.uri('notifications/mobile/read-ids'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      if (readRes.statusCode == 200) {
        final serverReadIds = (jsonDecode(readRes.body)['data'] as List).cast<int>();
        await markAllAsRead(serverReadIds, syncToCloud: false);
      }
    } catch (_) {}

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

    return data
        .map((json) {
          final n = NotificationModel.fromJson(json as Map<String, dynamic>);
          n.isReadLocally = readIds.contains(n.id);
          return n;
        })
        // Only show notifications created AFTER the login cutoff.
        // Exception: Evacuation and Flood Report notifications are persisted.
        .where((n) {
          final text = '${n.title} ${n.body}'.toLowerCase();
          final isEvac = text.contains('evacuation') || text.contains('rescue');
          final isReport = text.contains('flood report') || text.contains('report status');
          
          if (isEvac || isReport) {
            return true;
          }
          return cutoff == null || n.createdAt.isAfter(cutoff);
        })
        .toList();
  }

  Future<DateTime?> _getCutoff() async {
    final raw = await _storage.read(key: _cutoffKey);
    if (raw == null || raw.isEmpty) return null;
    final ms = int.tryParse(raw.trim());
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
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
    _syncReadIdsToCloud([notificationId]);
  }

  Future<void> markAllAsRead(List<int> ids, {bool syncToCloud = true}) async {
    if (ids.isEmpty) return;
    final existing = await _getReadIds();
    existing.addAll(ids);
    await _storage.write(key: _readIdsKey, value: existing.join(','));
    if (syncToCloud) {
      _syncReadIdsToCloud(ids);
    }
  }

  Future<void> _syncReadIdsToCloud(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;
      await http.post(
        ApiConfig.uri('notifications/mobile/read-bulk'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'notification_ids': ids}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
