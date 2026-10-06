import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../models/reading.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/health_service.dart';
import '../services/monitoring_service.dart';
import 'alerts_screen.dart';
import 'manual_entry_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  Widget _metric(IconData icon, String title, Reading? r, {String? emptyText}) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(r == null ? (emptyText ?? 'No data yet') : '${r.source} · ${_ago(r.timestamp)}'),
          trailing: Text(r?.display ?? '--', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ManualEntryScreen())),
        icon: const Icon(Icons.add),
        label: const Text('BP / Glucose'),
      ),
      body: StreamBuilder<UserProfile?>(
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
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                    Text('Hello ${p?.username ?? ''}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Profile'),
                        subtitle: Text(p == null
                            ? ''
                            : 'Age: ${p.age} | Height: ${p.height?.round()} cm | Weight: ${p.weight} kg'
                                '${p.bmi == null ? '' : ' | BMI: ${p.bmi!.toStringAsFixed(1)}'}'),
                      ),
                    ),
                    Card(
                      color: top == null ? null : severityColor(top.severity).withValues(alpha: 0.12),
                      child: ListTile(
                        leading: Icon(top == null ? Icons.check_circle_outline : severityIcon(top.severity),
                            color: top == null ? Colors.green : severityColor(top.severity)),
                        title: const Text('Early Warning Status'),
                        subtitle: Text(top?.title ?? 'No abnormal pattern detected'),
                        onTap: top == null ? null : () => showAlertDetail(context, top),
                      ),
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
                    OutlinedButton.icon(
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
    );
  }
}
