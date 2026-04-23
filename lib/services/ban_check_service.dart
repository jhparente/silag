import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'api_client.dart';

class BanCheckService {
  static final BanCheckService _instance = BanCheckService._internal();
  factory BanCheckService() => _instance;
  BanCheckService._internal();

  final _storage = const FlutterSecureStorage();
  // Must use ApiClient so the 403 response gets intercepted and triggers logout
  final _client = ApiClient();

  Timer? _timer;

  void start({Duration interval = const Duration(seconds: 30)}) {
    stop();
    _timer = Timer.periodic(interval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        stop();
        return;
      }
      // ApiClient.get() will call _handleBanCheck on the response.
      // If the account is banned, it will automatically clear storage
      // and navigate to /login. No extra handling needed here.
      await _client.get(ApiConfig.uri('users/$userId/profile'));
    } catch (_) {
      // Silently ignore network errors — only act on 403 ACCOUNT_BANNED
    }
  }
}
