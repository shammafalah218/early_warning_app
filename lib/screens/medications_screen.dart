import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/reminder_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});
  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final db = FirestoreService.instance;
  String get today {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final dose = TextEditingController();
    TimeOfDay time = TimeOfDay.now();
    final result = await showDialog<Map<String, String>>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('Add prescribed medication'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Medication name')),
          TextField(controller: dose, decoration: const InputDecoration(labelText: 'Prescribed dose')),
          TextButton.icon(icon: const Icon(Icons.schedule),
            label: Text('Time: ${time.format(ctx)}'),
            onPressed: () async {
              final picked = await showTimePicker(context: ctx, initialTime: time);
              if (picked != null) refresh(() => time = picked);
            }),
          const Text('One daily reminder per medication. Add another entry for a second dose time.',
            style: TextStyle(fontSize: 12)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty || dose.text.trim().isEmpty) return;
            Navigator.pop(ctx, {'name': name.text.trim(), 'dose': dose.text.trim(),
              'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'});
          }, child: const Text('Add'))],
      )));
    if (result == null) return;
    try {
      await ReminderService.instance.requestPermission();
      final id = await db.addMedication(uid, {...result, 'createdAt': FieldValue.serverTimestamp()});
      try {
        await ReminderService.instance.schedule(id, result['name']!, result['dose']!, result['time']!);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Medication saved, but reminder could not be scheduled: $e')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add medication: $e')));
    }
  }

  Future<void> _delete(String id, String time) async {
    try {
      await db.deleteMedication(uid, id);
      await ReminderService.instance.cancel(id, time);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Medications')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _add,
      icon: const Icon(Icons.add), label: const Text('Add medication')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.medicationsStream(uid), builder: (context, meds) {
        if (meds.hasError) return Center(child: Text('Unable to load medications: ${meds.error}'));
        if (!meds.hasData) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.doseLogsStream(uid), builder: (context, logs) {
            final statusByKey = <String, String>{};
            for (final doc in logs.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              final v = doc.data();
              if (v['day'] == today) statusByKey['${v['medicationId']}_${v['time']}'] = v['status'] as String? ?? '';
            }
            final items = meds.data!.docs;
            if (items.isEmpty) return const Center(child: Text('No medications yet. Tap Add medication.'));
            return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
              const Padding(padding: EdgeInsets.all(8), child: Text(
                'Daily schedule · Mark each dose Taken or Missed. Reminders require notification permission.')),
              for (final doc in items) Builder(builder: (context) {
                final m = doc.data();
                final time = m['time'] as String? ?? '09:00';
                final status = statusByKey['${doc.id}_$time'];
                return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.medication),
                    title: Text(m['name'] as String? ?? ''),
                    subtitle: Text('${m['dose'] ?? ''} · $time daily'),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(doc.id, time))),
                  Text('Today: ${status ?? 'Not recorded'}'),
                  Row(children: [
                    TextButton(onPressed: () => db.logDose(uid, doc.id, today, time, 'Taken'),
                      child: const Text('Taken ✓')),
                    TextButton(onPressed: () => db.logDose(uid, doc.id, today, time, 'Missed'),
                      child: const Text('Missed ✕')),
                  ]),
                ])));
              }),
            ]);
          });
      }),
  );
}
