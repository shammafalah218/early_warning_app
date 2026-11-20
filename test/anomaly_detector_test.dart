
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/reading.dart';
import '../lib/models/health_alert.dart';
import '../lib/services/anomaly_detector.dart';

void main() {
  final detector = AnomalyDetector();
  final now = DateTime(2026, 11, 18);

  test('Normal glucose - no alert', () {
    final readings = [
      Reading(
        type: ReadingType.bloodGlucose,
        value: 90,
        timestamp: now,
        source: 'manual',
        context: 'fasting',
      ),
    ];

    final result = detector.detect(readings, now: now);
    expect(result, isEmpty);
  });

  test('Very low glucose - urgent alert', () {
    final readings = [
      Reading(
        type: ReadingType.bloodGlucose,
        value: 50,
        timestamp: now,
        source: 'manual',
        context: 'fasting',
      ),
    ];

    final result = detector.detect(readings, now: now);
    expect(
      result.any((f) =>
          f.category == 'glucose' &&
          f.severity == Severity.urgent),
      isTrue,
    );
  });

  test('Severe blood pressure - urgent alert', () {
    final readings = [
      Reading(
        type: ReadingType.bloodPressure,
        value: 185,
        value2: 120,
        timestamp: now,
        source: 'manual',
      ),
    ];

    final result = detector.detect(readings, now: now);
    expect(
      result.any((f) =>
          f.category == 'blood_pressure' &&
          f.severity == Severity.urgent),
      isTrue,
    );
  });
  test('Fasting glucose threshold 130 vs 131', () {
    List<Reading> readings(double value) => [
      for (int i = 0; i < 3; i++)
        Reading(
          type: ReadingType.bloodGlucose,
          value: value,
          timestamp: now.subtract(Duration(hours: i)),
          source: 'manual',
          context: 'fasting',
        ),
    ];

    final at130 = detector.detect(readings(130), now: now);
    final at131 = detector.detect(readings(131), now: now);

    expect(at130.any((f) => f.code == 'glu_fasting_high'), isFalse);
    expect(at131.any((f) => f.code == 'glu_fasting_high'), isTrue);
  });

  test('Blood pressure threshold 140/90', () {
    final readings = [
      for (int i = 0; i < 3; i++)
        Reading(
          type: ReadingType.bloodPressure,
          value: 140,
          value2: 90,
          timestamp: now.subtract(Duration(hours: i)),
          source: 'manual',
        ),
    ];

    final result = detector.detect(readings, now: now);

    expect(result.any((f) => f.code == 'bp_stage2'), isTrue);
  });
  test('Personal Baseline - Elevated Resting Heart Rate', () {
    final readings = <Reading>[];

    // Historical baseline: 14 readings at 65 bpm
    for (int i = 4; i <= 17; i++) {
      readings.add(Reading(
        type: ReadingType.restingHeartRate,
        value: 65,
        timestamp: now.subtract(Duration(days: i)),
        source: 'healthkit',
      ));
    }

    // Recent resting heart rate: 85 bpm
    for (int i = 0; i < 3; i++) {
      readings.add(Reading(
        type: ReadingType.restingHeartRate,
        value: 85,
        timestamp: now.subtract(Duration(days: i)),
        source: 'healthkit',
      ));
    }

    final result = detector.detect(readings, now: now);

    expect(
      result.any((f) => f.code == 'rhr_above_baseline'),
      isTrue,
    );
  });

  test('Personal Baseline - Significant Steps Drop', () {
    final readings = <Reading>[];

    // Historical baseline: 6000 steps per day
    for (int i = 8; i <= 21; i++) {
      readings.add(Reading(
        type: ReadingType.steps,
        value: 6000,
        timestamp: now.subtract(Duration(days: i)),
        source: 'healthkit',
      ));
    }

    // Recent activity: 2000 steps per day
    for (int i = 0; i < 7; i++) {
      readings.add(Reading(
        type: ReadingType.steps,
        value: 2000,
        timestamp: now.subtract(Duration(days: i)),
        source: 'healthkit',
      ));
    }

    final result = detector.detect(readings, now: now);

    expect(
      result.any((f) => f.code == 'steps_drop'),
      isTrue,
    );
  });
}
