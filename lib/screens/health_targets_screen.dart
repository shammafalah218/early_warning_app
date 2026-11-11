import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class HealthTargetsScreen extends StatefulWidget {
  const HealthTargetsScreen({super.key});
  @override
  State<HealthTargetsScreen> createState() => _HealthTargetsScreenState();
}

class _HealthTargetsScreenState extends State<HealthTargetsScreen> {
  final _keys = ['glucoseMin', 'glucoseMax', 'systolicMin', 'systolicMax',
    'diastolicMin', 'diastolicMax'];
  final _labels = ['Glucose minimum (mg/dL)', 'Glucose maximum (mg/dL)',
    'Systolic minimum (mmHg)', 'Systolic maximum (mmHg)',
    'Diastolic minimum (mmHg)', 'Diastolic maximum (mmHg)'];
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _form = GlobalKey<FormState>();
  bool _loaded = false;
  bool _saving = false;
  @override
  void dispose() { for (final c in _controllers) { c.dispose(); } super.dispose(); }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final values = [for (final c in _controllers) double.parse(c.text.trim())];
    for (var i = 0; i < 6; i += 2) {
      if (values[i] >= values[i + 1]) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Minimum must be lower than maximum.')));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.saveTargets(FirebaseAuth.instance.currentUser!.uid,
        {for (var i = 0; i < 6; i++) _keys[i]: values[i]});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor-recommended targets saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(appBar: AppBar(title: const Text('My Health Targets')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FirestoreService.instance.targetsStream(uid),
        builder: (context, snapshot) {
          if (!_loaded && snapshot.hasData) {
            _loaded = true;
            for (var i = 0; i < 6; i++) {
              final value = snapshot.data![_keys[i]];
              if (value is num) _controllers[i].text = value.toString();
            }
          }
          return Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Enter only the target ranges recommended by your clinician. '
              'These targets do not replace emergency safety alerts.'),
            const SizedBox(height: 16),
            for (var i = 0; i < 6; i++) Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(controller: _controllers[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _labels[i], border: const OutlineInputBorder()),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return n == null || !n.isFinite || n <= 0 ? 'Enter a positive number' : null;
                }),
            ),
            FilledButton(onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save targets')),
          ]));
        },
      ));
  }
}
