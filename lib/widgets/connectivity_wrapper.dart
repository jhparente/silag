// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Wraps any page and replaces it entirely when:
///   - There is no internet connection (shows animated skeleton-like screen)
///   - The backend server is down (shows server-down screen with retry)
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final _service = ConnectivityService();
  late AppConnectivityStatus _status;

  @override
  void initState() {
    super.initState();
    _status = _service.currentStatus;
    _service.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == AppConnectivityStatus.noInternet) {
      return const _NoInternetScreen();
    }
    if (_status == AppConnectivityStatus.serverDown) {
      return const _ServerDownScreen();
    }
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// No-Internet Screen — Skeleton-like, non-interactive
// ---------------------------------------------------------------------------

class _NoInternetScreen extends StatelessWidget {
  const _NoInternetScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: Column(
          children: [
            // Fake app bar
            Container(
              height: 60,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ShimBlock(width: 140, height: 18, radius: 8),
                  const Spacer(),
                  _ShimBlock(width: 32, height: 32, radius: 16),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weather card skeleton
                    _ShimBlock(height: 260, radius: 24),
                    const SizedBox(height: 36),
                    _ShimBlock(width: 120, height: 18, radius: 8),
                    const SizedBox(height: 12),
                    _ShimBlock(height: 90, radius: 16),
                    const SizedBox(height: 10),
                    _ShimBlock(height: 90, radius: 16),
                  ],
                ),
              ),
            ),
            // Bottom notice bar
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF101C45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'No internet connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Lightweight shimmer-style placeholder block
class _ShimBlock extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const _ShimBlock({required this.height, this.width, required this.radius});

  @override
  State<_ShimBlock> createState() => _ShimBlockState();
}

class _ShimBlockState extends State<_ShimBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.5, 1.0],
            colors: const [
              Color(0xFFE0E5F5),
              Color(0xFFF5F7FF),
              Color(0xFFE0E5F5),
            ],
            transform: _SlidingTransform(_anim.value),
          ),
        ),
      ),
    );
  }
}

class _SlidingTransform extends GradientTransform {
  final double slide;
  const _SlidingTransform(this.slide);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

// ---------------------------------------------------------------------------
// Server-Down Screen — Only a Retry button is interactive
// ---------------------------------------------------------------------------

class _ServerDownScreen extends StatefulWidget {
  const _ServerDownScreen();

  @override
  State<_ServerDownScreen> createState() => _ServerDownScreenState();
}

class _ServerDownScreenState extends State<_ServerDownScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await ConnectivityService().checkNow();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101C45).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Color(0xFF101C45),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Server is Down',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101C45),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The SILAG server is currently unreachable.\nPlease wait a moment and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF6B7BA4),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _retrying ? null : _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF101C45),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF101C45).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _retrying ? 'Checking...' : 'Retry',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
