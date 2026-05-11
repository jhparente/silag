import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

enum AppConnectivityStatus { online, noInternet, serverDown }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _statusController =
      StreamController<AppConnectivityStatus>.broadcast();

  Stream<AppConnectivityStatus> get statusStream => _statusController.stream;

  AppConnectivityStatus _current = AppConnectivityStatus.online;
  AppConnectivityStatus get currentStatus => _current;

  StreamSubscription? _connectivitySub;
  Timer? _pollTimer;

  void start() {
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Poll the backend every 10 s so we can detect server-down quickly
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkBackend());

    // Run immediately
    _checkAll();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    _statusController.close();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _checkAll();
  }

  Future<void> _checkAll() async {
    final results = await _connectivity.checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      _emit(AppConnectivityStatus.noInternet);
      return;
    }

    await _checkBackend();
  }

  Future<void> _checkBackend() async {
    try {
      // Hit the root endpoint which is always public and lightweight
      final uri = Uri.parse(ApiConfig.host);
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 500) {
        _emit(AppConnectivityStatus.online);
      } else {
        _emit(AppConnectivityStatus.serverDown);
      }
    } catch (_) {
      // Could not reach server — but first re-confirm internet
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) {
        _emit(AppConnectivityStatus.noInternet);
      } else {
        _emit(AppConnectivityStatus.serverDown);
      }
    }
  }

  void _emit(AppConnectivityStatus status) {
    if (_current != status) {
      _current = status;
      _statusController.add(status);
    }
  }

  /// Public method to force-check connectivity — used by the retry button.
  Future<void> checkNow() => _checkAll();
}
