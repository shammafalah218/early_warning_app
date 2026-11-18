
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
}
