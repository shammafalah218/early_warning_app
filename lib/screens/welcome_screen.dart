import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'animated_health_background.dart';

/// Intro screen for signed-out users. No Firebase or HealthKit changes.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF6938C6);
    const dark = Color(0xFF27134F);
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      body: Stack(children: [
        const Positioned.fill(child: AnimatedHealthBackground()),
        SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - 44)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.favorite_border_rounded, color: violet, size: 29),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text('EARLY WARNING',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              letterSpacing: 1.1, color: dark)),
                    ),
                  ]),
                  const SizedBox(height: 27),
                  const Text('SMART HEALTH MONITORING',
                      style: TextStyle(fontSize: 11, letterSpacing: 2.1,
                          color: violet, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Your health,\nour priority.',
                      style: TextStyle(fontSize: 39, height: 1.1,
                          fontWeight: FontWeight.w800, color: dark)),
                  const SizedBox(height: 13),
                  const Text(
                    'Stay informed with health insights from your smartwatch. '
                    'Track heart rate, HRV and steps, and receive alerts when '
                    'unusual patterns are detected.',
                    style: TextStyle(fontSize: 14.5, height: 1.55,
                        color: Color(0xFF645A76)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 255,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5ECFF), Color(0xFFE1D0FA), Color(0xFFFBF8FF)],
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(child: CustomPaint(
                            painter: _WavePainter(_pulse.value))),
                          Transform.scale(
                            scale: 1 + math.sin(_pulse.value * math.pi * 2) * .025,
                            child: Container(
                              width: 139, height: 169,
                              decoration: BoxDecoration(
                                color: dark, borderRadius: BorderRadius.circular(37),
                                border: Border.all(color: const Color(0xFFB69AE5), width: 7),
                                boxShadow: const [BoxShadow(color: Color(0x556938C6),
                                    blurRadius: 30, offset: Offset(0, 12))],
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.monitor_heart_outlined, color: Color(0xFFDBBBFF), size: 57),
                                  SizedBox(height: 9),
                                  Text('Monitoring', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  SizedBox(height: 5),
                                  Text('● ● ●', style: TextStyle(color: Color(0xFFCDA6FF), fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(top: 23, left: 9,
                            child: _DataChip(icon: Icons.favorite, label: 'Heart rate', value: '66 bpm')),
                          const Positioned(top: 32, right: 8,
                            child: _DataChip(icon: Icons.show_chart, label: 'HRV', value: '45 ms')),
                          const Positioned(bottom: 19, right: 13,
                            child: _DataChip(icon: Icons.directions_walk, label: 'Steps', value: '292')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 21),
                  const Row(children: [
                    Expanded(child: _Feature(icon: Icons.watch_outlined,
                        title: 'Health tracking', detail: 'Your key metrics')),
                    SizedBox(width: 8),
                    Expanded(child: _Feature(icon: Icons.notifications_active_outlined,
                        title: 'Early alerts', detail: 'Unusual changes')),
                    SizedBox(width: 8),
                    Expanded(child: _Feature(icon: Icons.insights_outlined,
                        title: 'Health insights', detail: 'Know your trends')),
                  ]),
                  const SizedBox(height: 21),
                  FilledButton.icon(
                    onPressed: widget.onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: violet,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
      ]),
    );
  }
}

class _DataChip extends StatelessWidget {
  const _DataChip({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xF9FFFFFF),
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [BoxShadow(color: Color(0x188E6BBE), blurRadius: 12)]),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: const Color(0xFF7C4AD0), size: 17),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF756988))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: Color(0xFF301852))),
      ]),
    ]),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE9DDF9))),
    child: Column(children: [
      Icon(icon, color: const Color(0xFF7944C8), size: 23),
      const SizedBox(height: 7),
      Text(title, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(detail, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Color(0xFF85788E))),
    ]),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF9E6FE8).withValues(alpha: .48)
      ..strokeWidth = 2.4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i <= 160; i++) {
      final x = size.width * i / 160;
      final shifted = (i / 160 + phase) * 5 * math.pi;
      final spike = math.pow(math.max(0, math.sin(shifted)), 18).toDouble();
      final y = size.height * .52 + math.sin(shifted) * 6 - spike * 32;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.phase != phase;
}
