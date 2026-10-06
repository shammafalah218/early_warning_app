import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../services/firestore_service.dart';

Color severityColor(Severity s) => switch (s) {
      Severity.urgent => Colors.red.shade700,
      Severity.warning => Colors.orange.shade700,
      Severity.info => Colors.blue.shade600,
    };

IconData severityIcon(Severity s) => switch (s) {
      Severity.urgent => Icons.error,
      Severity.warning => Icons.warning_amber_rounded,
      Severity.info => Icons.info_outline,
    };

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Early warnings')),
      body: StreamBuilder<List<HealthAlert>>(
        stream: FirestoreService.instance.alertsStream(uid),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final alerts = snap.data!;
          if (alerts.isEmpty) return const Center(child: Text('No alerts yet.'));
          return ListView.separated(
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = alerts[i];
              return ListTile(
                leading: Icon(severityIcon(a.severity), color: severityColor(a.severity)),
                title: Text(a.title,
                    style: TextStyle(fontWeight: a.acknowledged ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text('${a.createdAt.toLocal()}'.substring(0, 16)),
                onTap: () => showAlertDetail(context, a),
              );
            },
          );
        },
      ),
    );
  }
}

void showAlertDetail(BuildContext context, HealthAlert a) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Icon(severityIcon(a.severity), color: severityColor(a.severity)),
            const SizedBox(width: 8),
            Expanded(child: Text(a.title, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 12),
          Text(a.explanation),
          const SizedBox(height: 16),
          Text('What the app measured', style: Theme.of(context).textTheme.titleSmall),
          ...a.findings.map((f) => Text('• ${f.detail}')),
          const SizedBox(height: 16),
          Text('Suggested next steps', style: Theme.of(context).textTheme.titleSmall),
          ...a.advice.map((s) => Text('• $s')),
          if (a.whenToSeekCare.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('When to seek care', style: Theme.of(context).textTheme.titleSmall),
            Text(a.whenToSeekCare),
          ],
          const SizedBox(height: 16),
          Text(
            'This app does not diagnose. ${a.generatedByLlm ? 'Text written by AI (${a.model}) from the measured findings.' : 'Standard text (AI unavailable).'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (!a.acknowledged && a.id != null)
            FilledButton(
              onPressed: () {
                FirestoreService.instance.acknowledge(uid, a.id!);
                Navigator.pop(context);
              },
              child: const Text('Got it'),
            ),
        ],
      ),
    ),
  );
}
