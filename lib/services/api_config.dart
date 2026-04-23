class ApiConfig {
  ApiConfig._();

  // Override with: --dart-define=API_HOST=http://10.0.2.2:8000
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // Override with: --dart-define=API_DEFAULT_VERSION=v2
  static const String defaultVersion = String.fromEnvironment(
    'API_DEFAULT_VERSION',
    defaultValue: 'v1',
  );

  static const String v1 = 'v1';
  static const String v2 = 'v2';

  static String get _normalizedHost =>
      host.endsWith('/') ? host.substring(0, host.length - 1) : host;

  static String _versionPrefix(String? version) {
    final selected = (version ?? defaultVersion).trim();
    if (selected.isEmpty) return '';

    final cleaned = selected.replaceAll(RegExp(r'^/+|/+$'), '');
    if (cleaned.isEmpty) return '';

    return '/$cleaned';
  }

  static Uri uri(
    String path, {
    String? version,
    Map<String, dynamic>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    final normalizedQuery = <String, String>{};
    queryParameters?.forEach((key, value) {
      if (value != null) {
        normalizedQuery[key] = value.toString();
      }
    });

    return Uri.parse(
      '$_normalizedHost${_versionPrefix(version)}$normalizedPath',
    ).replace(
      queryParameters: normalizedQuery.isEmpty ? null : normalizedQuery,
    );
  }

  static String baseUrl({String? version}) {
    return '$_normalizedHost${_versionPrefix(version)}';
  }
}
