import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../services/firestore_service.dart';

const _purple = Color(0xFF713DC6);
const _ink = Color(0xFF2F2051);
const _canvas = Color(0xFFFCF9FF);

// Keep these public helpers: DashboardScreen uses them too.
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

String _severityLabel(Severity s) => switch (s) {
      Severity.urgent => 'Urgent',
      Severity.warning => 'Warning',
      Severity.info => 'Information',
    };

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        title: const Text('Early warnings', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _canvas,
        foregroundColor: _ink,
      ),
      body: StreamBuilder<List<HealthAlert>>(
        stream: FirestoreService.instance.alertsStream(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Unable to load alerts. Please try again.', textAlign: TextAlign.center),
            ));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }
          final alerts = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7846CD), Color(0xFFAD85E9)]),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: const Row(children: [
                  Icon(Icons.notifications_active_outlined, color: Colors.white, size: 34),
                  SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your health alerts', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Review unusual patterns and suggested next steps.',
                        style: TextStyle(color: Colors.white, height: 1.35)),
                  ])),
                ]),
              ),
              const SizedBox(height: 22),
              if (alerts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: const Color(0xFFEEE4FA)),
                  ),
                  child: const Column(children: [
                    Icon(Icons.notifications_none_rounded, size: 58, color: _purple),
                    SizedBox(height: 12),
                    Text('No alerts yet', style: TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Any alerts generated from your readings will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF7B7089), height: 1.45)),
                  ]),
                )
              else ...[
                Text('${alerts.length} alert${alerts.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                for (final a in alerts) ...[
                  _AlertCard(alert: a),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final HealthAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showAlertDetail(context, alert),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEEE4FA)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
              child: Icon(severityIcon(alert.severity), color: color, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(alert.title, style: TextStyle(
                  color: _ink, fontSize: 16,
                  fontWeight: alert.acknowledged ? FontWeight.w500 : FontWeight.w800)),
              const SizedBox(height: 7),
              Text('${alert.createdAt.toLocal()}'.substring(0, 16),
                  style: const TextStyle(color: Color(0xFF81758F), fontSize: 12)),
              const SizedBox(height: 8),
              Text('${_severityLabel(alert.severity)}  •  ${alert.acknowledged ? 'Read' : 'New'}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: _purple),
          ]),
        ),
      ),
    );
  }
}

void showAlertDetail(BuildContext context, HealthAlert a) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(23),
        children: [
          Center(child: Container(width: 40, height: 5,
              decoration: BoxDecoration(color: const Color(0xFFD6C4EF), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 23),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: severityColor(a.severity).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(severityIcon(a.severity), color: severityColor(a.severity))),
            const SizedBox(width: 11),
            Expanded(child: Text(a.title,
                style: const TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 17),
          Text(a.explanation, style: const TextStyle(color: _ink, height: 1.55)),
          const SizedBox(height: 20),
          const _SectionHeading('What the app measured'),
          ...a.findings.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text('• ${f.detail}', style: const TextStyle(height: 1.4)))),
          const SizedBox(height: 16),
          const _SectionHeading('Suggested next steps'),
          ...a.advice.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text('• $s', style: const TextStyle(height: 1.4)))),
          if (a.whenToSeekCare.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionHeading('When to seek care'),
            Text(a.whenToSeekCare, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 20),
          Text(
            'This app does not diagnose. ${a.generatedByLlm ? 'Text written by AI (${a.model}) from the measured findings.' : 'Standard text (AI unavailable).'}',
            style: const TextStyle(color: Color(0xFF82778F), fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (!a.acknowledged && a.id != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purple,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(text, style: const TextStyle(color: _purple, fontWeight: FontWeight.w800, fontSize: 15)),
  );
}
