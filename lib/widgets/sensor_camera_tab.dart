// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/cctv_model.dart';
import '../../services/api_config.dart';

/// Tab widget that displays a live CCTV camera stream for a specific sensor.
/// Shows an HLS video player when a stream URL is available.
class SensorCameraTab extends StatefulWidget {
  final CctvConfig cctvConfig;
  final String sensorId;

  const SensorCameraTab({
    super.key,
    required this.cctvConfig,
    required this.sensorId,
  });

  @override
  State<SensorCameraTab> createState() => _SensorCameraTabState();
}

class _SensorCameraTabState extends State<SensorCameraTab>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  String? get _streamUrl {
    final cfg = widget.cctvConfig;
    // Prefer explicit stream_url, then fallback_hls_url,
    // then construct the MediaMTX HLS URL from the backend host + stream_path
    if (cfg.streamUrl != null && cfg.streamUrl!.isNotEmpty) {
      return cfg.streamUrl;
    }
    if (cfg.fallbackHlsUrl != null && cfg.fallbackHlsUrl!.isNotEmpty) {
      return cfg.fallbackHlsUrl;
    }
    // MediaMTX default: host:8888/{streamPath}/index.m3u8
    final path = cfg.streamPath ?? widget.sensorId;
    final baseHost = ApiConfig.host.replaceAll(RegExp(r':(\d+)$'), '');
    return '$baseHost:8888/$path/index.m3u8';
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
    });

    final url = _streamUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = 'No stream URL configured for this sensor.';
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      final chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: false,
        aspectRatio: 16 / 9,
        placeholder: Container(color: const Color(0xFF070D1E)),
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF38BDF8),
          handleColor: const Color(0xFF38BDF8),
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
        errorBuilder: (ctx, msg) => _buildError(msg),
      );

      if (mounted) {
        setState(() {
          _videoController = controller;
          _chewieController = chewieController;
          _isInitializing = false;
        });
      } else {
        controller.dispose();
        chewieController.dispose();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = 'Failed to connect to camera stream.\n${e.toString().split('\n').first}';
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      color: const Color(0xFF070D1E),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Camera Info Header ────────────────────────────────────────
            _buildCameraInfoHeader(),

            // ── Video Player / Status Area ────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoArea(),
                ),
              ),
            ),

            // ── Stream Details Card ───────────────────────────────────────
            _buildStreamDetailsCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraInfoHeader() {
    final cfg = widget.cctvConfig;
    final isOnline = cfg.isOnline ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Color(0xFF38BDF8),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.cameraName ?? 'CCTV Camera',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${cfg.cameraVendor ?? 'IP Camera'} · ${cfg.resolution ?? '720p'}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          // Online / Offline badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF16A34A).withOpacity(0.18)
                  : Colors.red.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFF22C55E).withOpacity(0.4)
                    : Colors.red.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF22C55E)
                        : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOnline
                        ? const Color(0xFF4ADE80)
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_isInitializing) {
      return Container(
        color: const Color(0xFF0A1227),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF38BDF8),
                strokeWidth: 2.5,
              ),
              SizedBox(height: 12),
              Text(
                'Connecting to stream…',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError || _chewieController == null) {
      return _buildError(_errorMessage ?? 'Unable to load stream.');
    }

    return Chewie(controller: _chewieController!);
  }

  Widget _buildError(String message) {
    return Container(
      color: const Color(0xFF0A1227),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                size: 40,
                color: Colors.red.withOpacity(0.75),
              ),
              const SizedBox(height: 12),
              const Text(
                'Stream Unavailable',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _initPlayer,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: Color(0xFF38BDF8)),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF38BDF8),
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamDetailsCard() {
    final cfg = widget.cctvConfig;
    final resolvedUrl = _streamUrl ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111E44),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: Colors.white54),
              SizedBox(width: 7),
              Text(
                'Stream Details',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDetailRow('Stream Path', cfg.streamPath ?? widget.sensorId),
          _buildDetailRow('Protocol', _resolveProtocol(resolvedUrl)),
          _buildDetailRow('Resolution', cfg.resolution ?? '720p'),
          _buildDetailRow('Vendor', cfg.cameraVendor ?? 'IP Camera'),
        ],
      ),
    );
  }

  String _resolveProtocol(String url) {
    if (url.startsWith('rtsp')) return 'RTSP → HLS (MediaMTX)';
    if (url.contains('.m3u8')) return 'HLS (HTTP Live Streaming)';
    if (url.startsWith('http')) return 'HTTP';
    return 'Unknown';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
