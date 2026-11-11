import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative only: no Firebase, HealthKit, or navigation changes.
class AnimatedHealthBackground extends StatefulWidget {
  const AnimatedHealthBackground({super.key});
  @override
  State<AnimatedHealthBackground> createState() => _AnimatedHealthBackgroundState();
}
class _AnimatedHealthBackgroundState extends State<AnimatedHealthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(seconds: 16))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _HealthGlowPainter(_controller.value),
        child: const SizedBox.expand(),
      ),
    ),
  );
}
class _HealthGlowPainter extends CustomPainter {
  const _HealthGlowPainter(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    const spots = [
      (0.12, 0.13, 100.0, 1.0),
      (0.91, 0.34, 130.0, 0.75),
      (0.15, 0.76, 110.0, 1.2),
      (0.88, 0.91, 95.0, 0.85),
    ];
    for (final s in spots) {
      final angle = phase * math.pi * 2 * s.$4;
      final center = Offset(size.width * s.$1 + math.sin(angle) * 18,
          size.height * s.$2 + math.cos(angle) * 20);
      final paint = Paint()..shader = RadialGradient(colors: [
        const Color(0xFFC6A4F6).withValues(alpha: .28),
        const Color(0xFFEBDDFB).withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: center, radius: s.$3));
      canvas.drawCircle(center, s.$3, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _HealthGlowPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
