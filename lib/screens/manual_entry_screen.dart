import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../models/reading.dart';
import '../services/firestore_service.dart';
import '../services/monitoring_service.dart';

/// Apple Watch does not measure blood pressure values or blood glucose, so
/// the two key indicators for hypertension and diabetes are entered here
/// (from a home cuff / glucometer) unless a connected device writes them
/// to Apple Health / Health Connect.
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _form = GlobalKey<FormState>();
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _glu = TextEditingController();
  String _gluContext = 'fasting';
  bool _saving = false;

  String? _opt(String? v, num min, num max) {
    if (v == null || v.isEmpty) return null;
    final x = num.tryParse(v);
    if (x == null || x < min || x > max) return '$min–$max';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final hasBp = _sys.text.isNotEmpty && _dia.text.isNotEmpty;
    final hasGlu = _glu.text.isNotEmpty;
    if (!hasBp && !hasGlu) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter blood pressure and/or glucose')));
      return;
    }
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    await FirestoreService.instance.saveReadings(uid, [
      if (hasBp)
        Reading(
            type: ReadingType.bloodPressure,
            value: double.parse(_sys.text),
            value2: double.parse(_dia.text),
            timestamp: now,
            source: 'manual'),
      if (hasGlu)
        Reading(
            type: ReadingType.bloodGlucose,
            value: double.parse(_glu.text),
            timestamp: now,
            source: 'manual',
            context: _gluContext),
    ]);
    final alerts = await MonitoringService.instance.analyse(uid);
    if (!mounted) return;
    final urgent = alerts.any((a) => a.severity == Severity.urgent);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(alerts.isEmpty
          ? 'Saved. No unusual pattern detected.'
          : urgent
              ? 'Saved. URGENT: please open the alert now.'
              : 'Saved. ${alerts.length} new alert(s).'),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a reading')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Blood pressure', style: Theme.of(context).textTheme.titleMedium),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: _sys,
                    decoration: const InputDecoration(labelText: 'Systolic (top)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _opt(v, 60, 260))),
            const SizedBox(width: 16),
            Expanded(
                child: TextFormField(
                    controller: _dia,
                    decoration: const InputDecoration(labelText: 'Diastolic (bottom)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _opt(v, 30, 160))),
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Sit quietly for 5 minutes, arm supported at heart level.',
                style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 28),
          Text('Blood glucose (mg/dL)', style: Theme.of(context).textTheme.titleMedium),
          TextFormField(
              controller: _glu,
              decoration: const InputDecoration(labelText: 'Glucose'),
              keyboardType: TextInputType.number,
              validator: (v) => _opt(v, 20, 600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fasting', label: Text('Fasting (8h+)')),
              ButtonSegment(value: 'random', label: Text('After eating / other')),
            ],
            selected: {_gluContext},
            onSelectionChanged: (s) => setState(() => _gluContext = s.first),
          ),
          const SizedBox(height: 28),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Analysing…' : 'Save & analyse')),
        ]),
      ),
    );
  }
}
