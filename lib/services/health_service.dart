import 'dart:io' show Platform;
import 'dart:math';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/reading.dart';

/// Reads wearable data.
///  * iPhone: Apple Health (HealthKit). Apple Watch data only reaches an app
///    through HealthKit on the paired iPhone — there is no Android path.
///  * Android: Health Connect (Samsung/Fitbit/Pixel watches, cuffs, meters).
/// Blood pressure and glucose appear only if a cuff/meter app writes them to
/// Health; otherwise the user enters them in ManualEntryScreen.
class HealthService {
  final Health _health = Health();
  bool _configured = false;

  List<HealthDataType> get _types => [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.STEPS,
        Platform.isIOS
            ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
            : HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_GLUCOSE,
      ];

  String get _source => Platform.isIOS ? 'healthkit' : 'health_connect';

  /// Returns null on success, otherwise a message to show the user.
  Future<String?> connect() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _health.installHealthConnect();
        return 'Please install/update Health Connect, then try again.';
      }
      await Permission.activityRecognition.request();
    }
    final ok = await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    return ok ? null : 'Health permission was not granted.';
  }

  Future<List<Reading>> fetchSince(DateTime since) async {
    final now = DateTime.now();
    final raw = await _health.getHealthDataFromTypes(
        types: _types.where((t) => t != HealthDataType.STEPS).toList(),
        startTime: since,
        endTime: now);
    final points = _health.removeDuplicates(raw);
    final out = <Reading>[];
    final systolic = <int, double>{}, diastolic = <int, double>{};

    for (final p in points) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final x = v.numericValue.toDouble();
      final ts = p.dateFrom;
      switch (p.type) {
        case HealthDataType.HEART_RATE:
          out.add(Reading(type: ReadingType.heartRate, value: x, timestamp: ts, source: _source));
        case HealthDataType.RESTING_HEART_RATE:
          out.add(Reading(type: ReadingType.restingHeartRate, value: x, timestamp: ts, source: _source));
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          out.add(Reading(type: ReadingType.hrv, value: x, timestamp: ts, source: _source));
        case HealthDataType.BLOOD_GLUCOSE:
          // Health does not reliably say if a sample was fasting → 'random'.
          out.add(Reading(type: ReadingType.bloodGlucose, value: x, timestamp: ts, source: _source, context: 'random'));
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          systolic[ts.millisecondsSinceEpoch] = x;
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          diastolic[ts.millisecondsSinceEpoch] = x;
        default:
          break;
      }
    }
    // Pair systolic/diastolic samples recorded at the same moment.
    systolic.forEach((ms, s) {
      final d = diastolic[ms];
      if (d != null) {
        out.add(Reading(
            type: ReadingType.bloodPressure,
            value: s,
            value2: d,
            timestamp: DateTime.fromMillisecondsSinceEpoch(ms),
            source: _source));
      }
    });
    // Steps: one total per day (stamped 23:00 so the day is unambiguous).
    var day = DateTime(since.year, since.month, since.day);
    while (!day.isAfter(now)) {
      final end = day.add(const Duration(days: 1));
      final total = await _health.getTotalStepsInInterval(day, end.isAfter(now) ? now : end);
      if (total != null) {
        out.add(Reading(
            type: ReadingType.steps,
            value: total.toDouble(),
            timestamp: day.add(const Duration(hours: 23)),
            source: _source));
      }
      day = end;
    }
    return out;
  }
}

enum DemoScenario { normal, hypertension, highGlucose, elevatedHeartRate, inactivity }

/// Simulated wearable data for the Android emulator and the project demo.
/// Same generative model as data/generate_synthetic_data.py.
class DemoDataService {
  List<Reading> generate({int days = 30, DemoScenario scenario = DemoScenario.normal, int? seed}) {
    final rng = Random(seed);
    double n(double mu, double sd) {
      // Box–Muller
      final u1 = rng.nextDouble().clamp(1e-9, 1.0), u2 = rng.nextDouble();
      return mu + sd * sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    final bRhr = n(66, 5), bSteps = n(8000, 1500), bSys = n(116, 4), bDia = n(74, 3), bGlu = n(90, 3);
    // Episode = the most recent days. 3 days so the resting-HR baseline
    // (which excludes only the last 3 days) stays clean; 7 for inactivity
    // because the steps rule compares 7-day averages.
    final episodeDays = scenario == DemoScenario.inactivity ? 7 : 3;
    final out = <Reading>[];

    for (var d = 0; d < days; d++) {
      final day = start.add(Duration(days: d));
      final ep = d >= days - episodeDays;
      Reading r(ReadingType t, double v, int h, {double? v2, String? ctx}) => Reading(
          type: t, value: v.roundToDouble(), value2: v2?.roundToDouble(),
          timestamp: day.add(Duration(hours: h)), source: 'simulated', context: ctx);

      final rhr = bRhr + n(0, 2.5) + (ep && scenario == DemoScenario.elevatedHeartRate ? 22 : 0);
      out.add(r(ReadingType.restingHeartRate, rhr, 7));
      for (final h in [9, 13, 17, 21]) {
        out.add(r(ReadingType.heartRate, rhr + 10 + n(0, 8), h));
      }
      final stepFactor = ep && scenario == DemoScenario.inactivity ? 0.2 : 1.0;
      out.add(r(ReadingType.steps, max(200.0, bSteps * exp(n(0, 0.3)) * stepFactor), 23));
      if (d.isEven || ep) {
        final hyper = ep && scenario == DemoScenario.hypertension;
        out.add(r(ReadingType.bloodPressure, bSys + n(0, 5) + (hyper ? 30 : 0), 8,
            v2: bDia + n(0, 3) + (hyper ? 17 : 0)));
      }
      if (d % 3 == 0 || ep) {
        final high = ep && scenario == DemoScenario.highGlucose;
        out.add(r(ReadingType.bloodGlucose, bGlu + n(0, 5) + (high ? 55 : 0), 7, ctx: 'fasting'));
      }
    }
    // Drop samples stamped later today (they haven't "happened" yet).
    return out.where((r) => !r.timestamp.isAfter(today)).toList();
  }
}
