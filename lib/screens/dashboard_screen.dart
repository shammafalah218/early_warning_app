import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../models/reading.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/health_service.dart';
import '../services/monitoring_service.dart';
import 'alerts_screen.dart';
import 'health_history_screen.dart';
import 'health_targets_screen.dart';
import 'medications_screen.dart';
import 'manual_entry_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  static const _violet = Color(0xFF6E3FB5);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _db = FirestoreService.instance;
  bool _syncing = false;

  Future<void> _sync({bool demo = false, DemoScenario s = DemoScenario.normal}) async {
    setState(() => _syncing = true);
    final r = await MonitoringService.instance.sync(_uid, demo: demo, scenario: s);
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.error ??
            'Synced ${r.readingsSaved} readings. ${r.newAlerts.isEmpty ? 'No new alerts.' : '${r.newAlerts.length} new alert(s).'}')));
    if (r.newAlerts.isNotEmpty) showAlertDetail(context, r.newAlerts.first);
  }

  Future<void> _pickDemo() async {
    final s = await showDialog<DemoScenario>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Load simulated 30-day data'),
        children: DemoScenario.values
            .map((s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, s), child: Text(s.name)))
            .toList(),
      ),
    );
    if (s != null) _sync(demo: true, s: s);
  }

  Reading? _latest(List<Reading> r, ReadingType t) {
    for (var i = r.length - 1; i >= 0; i--) {
      if (r[i].type == t) return r[i];
    }
    return null;
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(17)}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .95), width: 1.4),
          boxShadow: [
            BoxShadow(color: const Color(0xFF65449C).withValues(alpha: .12),
                blurRadius: 24, offset: const Offset(0, 12)),
            BoxShadow(color: Colors.white.withValues(alpha: .85),
                blurRadius: 8, offset: const Offset(-3, -3)),
          ],
        ),
        child: child,
      );

  Widget _metric(IconData icon, String title, Reading? r, {String? emptyText}) =>
      _panel(child: Row(children: [
        Container(width: 49, height: 49,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAF8DE8), Color(0xFF7040B5)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _violet.withValues(alpha: .25),
              blurRadius: 10, offset: const Offset(0, 5))]),
          child: Icon(icon, color: Colors.white, size: 25)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700,
              fontSize: 14, color: Color(0xFF35224C))),
          const SizedBox(height: 5),
          Text(r == null ? (emptyText ?? 'No data yet')
                  : '${r.source} · ${_ago(r.timestamp)}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF81728F))),
        ])),
        const SizedBox(width: 8),
        Text(r?.display ?? '--',
          style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 17, color: _violet)),
      ]));

  Widget _feature(IconData icon, String title, String subtitle, Widget page) =>
      _panel(padding: EdgeInsets.zero, child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFFF0E6FF),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _violet)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700,
            color: Color(0xFF392550))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: _violet),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => page)),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F3FF),
        foregroundColor: _violet,
        elevation: 0,
        title: const Text('Health Dashboard'),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AlertsScreen()))),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'profile') {
                final p = await _db.getProfile(_uid);
                if (!context.mounted) return;
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(existing: p)));
              } else if (v == 'demo') {
                _pickDemo();
              } else if (v == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Edit profile')),
              PopupMenuItem(value: 'demo', child: Text('Demo data (simulated)')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _violet,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ManualEntryScreen())),
        icon: const Icon(Icons.add),
        label: const Text('BP / Glucose'),
      ),
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: _motion,
          builder: (_, __) => CustomPaint(painter: _FloatingBackground(_motion.value)))),
        StreamBuilder<UserProfile?>(
        stream: _db.profileStream(_uid),
        builder: (context, ps) {
          final p = ps.data;
          return StreamBuilder<List<Reading>>(
            stream: _db.recentReadingsStream(_uid),
            builder: (context, rs) {
              final r = rs.data ?? const <Reading>[];
              return StreamBuilder<List<HealthAlert>>(
                stream: _db.alertsStream(_uid),
                builder: (context, alertSnap) {
                  final open = (alertSnap.data ?? const <HealthAlert>[])
                      .where((a) => !a.acknowledged)
                      .toList();
                  final top = open.isEmpty
                      ? null
                      : open.reduce((a, b) => a.severity.index >= b.severity.index ? a : b);
                  return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 108), children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 25, 22, 25),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9868D7), Color(0xFF6331A8), Color(0xFF46207D)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(29),
                        boxShadow: [BoxShadow(
                          color: _violet.withValues(alpha: .3),
                          blurRadius: 27, offset: const Offset(0, 14))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [
                          Icon(Icons.auto_awesome, color: Color(0xFFE8D5FF), size: 17),
                          SizedBox(width: 7),
                          Text('YOUR HEALTH OVERVIEW',
                            style: TextStyle(color: Color(0xFFE9DBFF),
                              fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 17),
                        Text('Hello ${p?.username ?? ''} 👋',
                          style: const TextStyle(color: Colors.white,
                            fontSize: 27, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Stay connected to your wellbeing.',
                          style: TextStyle(color: Color(0xFFE9DBFF), fontSize: 13)),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: Colors.white.withValues(alpha: .25))),
                          child: Row(children: [
                            Icon(top == null ? Icons.verified_rounded : severityIcon(top.severity),
                              color: Colors.white),
                            const SizedBox(width: 11),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Early Warning Status',
                                  style: TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(top?.title ?? 'No abnormal pattern detected',
                                  style: const TextStyle(color: Color(0xFFE9DBFF),
                                    fontSize: 12)),
                              ])),
                            if (top != null)
                              IconButton(onPressed: () => showAlertDetail(context, top),
                                icon: const Icon(Icons.arrow_forward_ios,
                                  color: Colors.white, size: 16)),
                          ]),
                        ),
                      ]),
                    ),
                    _panel(child: Row(children: [
                      const Icon(Icons.person_outline_rounded, color: _violet),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Profile', style: TextStyle(
                            fontWeight: FontWeight.w700, color: Color(0xFF392550))),
                          const SizedBox(height: 4),
                          Text(p == null ? 'Loading profile…'
                            : 'Age: ${p.age} · Height: ${p.height?.round()} cm · Weight: ${p.weight} kg'
                              '${p.bmi == null ? '' : ' · BMI: ${p.bmi!.toStringAsFixed(1)}'}',
                            style: const TextStyle(fontSize: 11.5,
                              color: Color(0xFF81728F))),
                        ])),
                    ])),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(3, 8, 0, 14),
                      child: Text('Live health readings',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                          color: Color(0xFF392550))),
                    ),
                    _metric(Icons.favorite, 'Heart rate', _latest(r, ReadingType.heartRate),
                        emptyText: 'Apple Watch data will appear here'),
                    _metric(Icons.bedtime_outlined, 'Resting heart rate', _latest(r, ReadingType.restingHeartRate)),
                    _metric(Icons.directions_walk, 'Steps (daily total)', _latest(r, ReadingType.steps),
                        emptyText: 'Apple Watch data will appear here'),
                    _metric(Icons.speed, 'Blood pressure', _latest(r, ReadingType.bloodPressure),
                        emptyText: 'Tap + to add a cuff reading'),
                    _metric(Icons.water_drop_outlined, 'Blood glucose', _latest(r, ReadingType.bloodGlucose),
                        emptyText: 'Tap + to add a glucometer reading'),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(3, 18, 0, 14),
                      child: Text('Explore your health',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                          color: Color(0xFF392550))),
                    ),
                    _feature(Icons.show_chart_rounded, 'Health Trends',
                      'Glucose & blood pressure · 7 / 30 days',
                      const HealthHistoryScreen()),
                    _feature(Icons.medication_outlined, 'My Medications',
                      'Daily reminders and dose tracking',
                      const MedicationsScreen()),
                    _feature(Icons.track_changes_rounded, 'My Health Targets',
                      'Doctor-recommended target ranges',
                      const HealthTargetsScreen()),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _violet,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                      onPressed: _syncing ? null : () => _sync(),
                      icon: _syncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.watch),
                      label: Text(_syncing ? 'Syncing…' : 'Connect / Sync Apple Watch'),
                    ),
                    const SizedBox(height: 8),
                    Text('Not a medical device. Alerts support, not replace, a doctor.',
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  ]);
                },
              );
            },
          );
        },
      ),
      ]),
    );
  }
}

/// Subtle animated decorative background; ignores touch and never accesses health data.
class _FloatingBackground extends CustomPainter {
  const _FloatingBackground(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = <({double x, double y, double radius, double speed})>[
      (x: .08, y: .11, radius: 85, speed: 1),
      (x: .92, y: .27, radius: 115, speed: .7),
      (x: .12, y: .62, radius: 105, speed: 1.3),
      (x: .85, y: .89, radius: 95, speed: .85),
    ];
    for (final spot in spots) {
      final phase = (progress * math.pi * 2 * spot.speed);
      final center = Offset(
        size.width * spot.x + math.sin(phase) * 16,
        size.height * spot.y + math.cos(phase) * 20);
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFC9AAFA).withValues(alpha: .30),
          const Color(0xFFEDE1FF).withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: spot.radius));
      canvas.drawCircle(center, spot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingBackground oldDelegate) =>
      oldDelegate.progress != progress;
}
