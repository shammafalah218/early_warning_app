import '../models/health_alert.dart';
import '../models/reading.dart';
import 'anomaly_detector.dart';
import 'firestore_service.dart';
import 'health_service.dart';
import 'llm_service.dart';

class SyncResult {
  final int readingsSaved;
  final List<HealthAlert> newAlerts;
  final String? error;
  const SyncResult(this.readingsSaved, this.newAlerts, [this.error]);
}

/// The whole pipeline in one place:
///   wearable/manual data → Firestore → detector → LLM explanation → alert
class MonitoringService {
  MonitoringService._();
  static final instance = MonitoringService._();

  final _db = FirestoreService.instance;
  final _health = HealthService();
  final _demo = DemoDataService();
  final _detector = AnomalyDetector();
  final _llm = LlmService();

  static const cooldown = Duration(days: 3);

  /// Pull new wearable data (real or simulated), then analyse.
  Future<SyncResult> sync(String uid,
      {bool demo = false, DemoScenario scenario = DemoScenario.normal}) async {
    List<Reading> fresh;
    if (demo) {
      await _db.deleteSimulatedReadings(uid);
      fresh = _demo.generate(days: 30, scenario: scenario);
    } else {
      final err = await _health.connect();
      if (err != null) return SyncResult(0, const [], err);
      final last = await _db.getLastSync(uid);
      final since = last?.subtract(const Duration(hours: 1)) ??
          DateTime.now().subtract(const Duration(days: 30));
      fresh = await _health.fetchSince(since);
    }
    await _db.saveReadings(uid, fresh);
    await _db.setLastSync(uid, DateTime.now());
    final alerts = await analyse(uid);
    return SyncResult(fresh.length, alerts);
  }

  /// Run the detector on the last 35 days and create alerts for new findings.
  /// Also called after a manual BP/glucose entry.
  Future<List<HealthAlert>> analyse(String uid) async {
    final history = await _db.readingsSince(
        uid, DateTime.now().subtract(const Duration(days: 35)));
    final findings = _detector.detect(history);
    if (findings.isEmpty) return const [];

    final profile = await _db.getProfile(uid);
    final recentAlerts =
        await _db.alertsSince(uid, DateTime.now().subtract(cooldown));
    final created = <HealthAlert>[];

    // One alert per category; the highest severity in the category wins.
    final byCategory = <String, List<Finding>>{};
    for (final f in findings) {
      byCategory.putIfAbsent(f.category, () => []).add(f);
    }
    for (final entry in byCategory.entries) {
      final severity = entry.value
          .map((f) => f.severity)
          .reduce((a, b) => a.index >= b.index ? a : b);
      // Cooldown: don't repeat the same category unless it got worse.
      final repeated = recentAlerts.any((a) =>
          a.category == entry.key && a.severity.index >= severity.index);
      if (repeated) continue;

      final alert = await _llm.explain(
        category: entry.key,
        severity: severity,
        findings: entry.value,
        profile: profile,
      );
      await _db.addAlert(uid, alert);
      created.add(alert);
    }
    return created;
  }
}
