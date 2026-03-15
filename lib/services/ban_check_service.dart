import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BanCheckService {
  static final BanCheckService _instance = BanCheckService._internal();
  factory BanCheckService() => _instance;
  BanCheckService._internal();

  final String _baseUrl = 'http://127.0.0.1:8000';
  final _storage = const FlutterSecureStorage();

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
      final token = await _storage.read(key: 'jwt_token');
      if (userId == null) {
        stop();
        return;
      }
      await http.get(
        Uri.parse('$_baseUrl/users/$userId/profile'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
  }
}
