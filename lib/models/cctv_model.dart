/// Model for the CCTV camera stream configuration returned by
/// GET /v1/sensors/{sensor_id}/cctv
class CctvConfig {
  final bool cctvEnabled;
  final String? cameraName;
  final String? streamPath;
  final String? streamUrl;
  final String? fallbackHlsUrl;
  final String? internalRtspUrl;
  final String? cameraVendor;
  final String? resolution;
  final bool? isOnline;

  const CctvConfig({
    required this.cctvEnabled,
    this.cameraName,
    this.streamPath,
    this.streamUrl,
    this.fallbackHlsUrl,
    this.internalRtspUrl,
    this.cameraVendor,
    this.resolution,
    this.isOnline,
  });

  factory CctvConfig.fromJson(Map<String, dynamic> json) {
    final hasStreamOrCamera = (json['stream_url'] != null &&
            json['stream_url'].toString().trim().isNotEmpty) ||
        (json['fallback_hls_url'] != null &&
            json['fallback_hls_url'].toString().trim().isNotEmpty) ||
        (json['internal_rtsp_url'] != null &&
            json['internal_rtsp_url'].toString().trim().isNotEmpty) ||
        (json['camera_name'] != null &&
            json['camera_name'].toString().trim().isNotEmpty);

    final isExplicitlyDisabled =
        json['cctv_enabled'] == false && !hasStreamOrCamera;
    final enabled = json['cctv_enabled'] == true || hasStreamOrCamera;

    return CctvConfig(
      cctvEnabled: !isExplicitlyDisabled && enabled,
      cameraName: json['camera_name']?.toString(),
      streamPath: json['stream_path']?.toString(),
      streamUrl: json['stream_url']?.toString(),
      fallbackHlsUrl: json['fallback_hls_url']?.toString(),
      internalRtspUrl: json['internal_rtsp_url']?.toString(),
      cameraVendor: json['camera_vendor']?.toString(),
      resolution: json['resolution']?.toString(),
      isOnline: json['is_online'] == true ||
          json['is_online']?.toString() == 'true',
    );
  }

  factory CctvConfig.disabled() {
    return const CctvConfig(cctvEnabled: false);
  }

  bool get hasStream =>
      (streamUrl != null && streamUrl!.isNotEmpty) ||
      (fallbackHlsUrl != null && fallbackHlsUrl!.isNotEmpty) ||
      (internalRtspUrl != null && internalRtspUrl!.isNotEmpty);

  bool get isAvailable =>
      cctvEnabled || hasStream || (cameraName != null && cameraName!.isNotEmpty);
}

class SensorCctvResponse {
  final String sensorId;
  final String? sensorName;
  final CctvConfig cctvConfig;

  const SensorCctvResponse({
    required this.sensorId,
    this.sensorName,
    required this.cctvConfig,
  });

  factory SensorCctvResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['cctv_config'];
    final config = (raw is Map<String, dynamic>)
        ? CctvConfig.fromJson(raw)
        : CctvConfig.disabled();
    return SensorCctvResponse(
      sensorId: json['sensor_id']?.toString() ?? '',
      sensorName: json['sensor_name']?.toString(),
      cctvConfig: config,
    );
  }
}
