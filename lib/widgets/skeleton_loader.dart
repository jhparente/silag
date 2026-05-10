// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Shared animated shimmer skeleton widgets used across all pages.
// Works for both light (white background) and dark (navy background) pages.
// ---------------------------------------------------------------------------

/// A single shimmer block — a rectangular box with an animated highlight sweep.
class ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;
  final bool darkMode;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 12,
    this.darkMode = true,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
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
    final base = widget.darkMode
        ? const Color(0xFF1A2755)
        : const Color(0xFFE8ECF4);
    final highlight = widget.darkMode
        ? const Color(0xFF243470)
        : const Color(0xFFF5F7FF);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: [base, highlight, base],
              transform: _SlidingGradientTransform(_anim.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

// ---------------------------------------------------------------------------
// Pre-built skeleton layouts for each page section
// ---------------------------------------------------------------------------

/// Skeleton for the weather card on the Home page.
class WeatherCardSkeleton extends StatelessWidget {
  const WeatherCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerBox(height: 100, width: 100, borderRadius: 50),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(height: 48, borderRadius: 8),
                    SizedBox(height: 10),
                    ShimmerBox(height: 20, width: 140, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const ShimmerBox(height: 70, borderRadius: 20),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (_) => const ShimmerBox(height: 80, width: 56, borderRadius: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a single sensor card on the Home page.
class SensorCardSkeleton extends StatelessWidget {
  const SensorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 14, width: 160, borderRadius: 6),
                SizedBox(height: 6),
                ShimmerBox(height: 12, width: 100, borderRadius: 6),
                SizedBox(height: 16),
                ShimmerBox(height: 36, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const ShimmerBox(height: 50, width: 50, borderRadius: 25),
        ],
      ),
    );
  }
}

/// Skeleton for a hotline / evacuation-center card on the Safety page (light bg).
class HotlineCardSkeleton extends StatelessWidget {
  const HotlineCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3F0)),
      ),
      child: Row(
        children: [
          const ShimmerBox(
            height: 48,
            width: 48,
            borderRadius: 24,
            darkMode: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(
                  height: 14,
                  width: 140,
                  borderRadius: 6,
                  darkMode: false,
                ),
                SizedBox(height: 8),
                ShimmerBox(
                  height: 12,
                  width: 100,
                  borderRadius: 6,
                  darkMode: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for an evacuation centre card (dark card with image area).
class EvacuationCenterSkeleton extends StatelessWidget {
  const EvacuationCenterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2755),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: const ShimmerBox(height: 160, borderRadius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 16, width: 180, borderRadius: 6),
                      SizedBox(height: 8),
                      ShimmerBox(height: 12, width: 130, borderRadius: 6),
                    ],
                  ),
                ),
                const ShimmerBox(height: 40, width: 40, borderRadius: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for the community-status / flood-report cards on the Report page.
class ReportStatSkeleton extends StatelessWidget {
  const ReportStatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(
              children: [
                ShimmerBox(height: 32, width: 60, borderRadius: 8, darkMode: false),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 80, borderRadius: 6, darkMode: false),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(
              children: [
                ShimmerBox(height: 32, width: 60, borderRadius: 8, darkMode: false),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 80, borderRadius: 6, darkMode: false),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(
              children: [
                ShimmerBox(height: 32, width: 60, borderRadius: 8, darkMode: false),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 80, borderRadius: 6, darkMode: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Generic light-background shimmer box (for Report/Safety/Profile pages).
class LightShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const LightShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      height: height,
      width: width,
      borderRadius: borderRadius,
      darkMode: false,
    );
  }
}

/// Profile header skeleton.
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const ShimmerBox(height: 80, width: 80, borderRadius: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 20, width: 140, borderRadius: 8),
                SizedBox(height: 10),
                ShimmerBox(height: 14, width: 100, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
