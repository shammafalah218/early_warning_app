import 'package:cloud_firestore/cloud_firestore.dart';

/// One health measurement. Stored at users/{uid}/readings/{id}.
/// Field names match data/generate_synthetic_data.py so the Python
/// evaluation and the app use the same schema.
enum ReadingType {
  heartRate('heart_rate', 'bpm', 'Heart rate'),
  restingHeartRate('resting_heart_rate', 'bpm', 'Resting heart rate'),
  steps('steps', 'steps', 'Steps'),
  hrv('hrv', 'ms', 'Heart rate variability'),
  bloodPressure('blood_pressure', 'mmHg', 'Blood pressure'),
  bloodGlucose('blood_glucose', 'mg/dL', 'Blood glucose');

  const ReadingType(this.key, this.unit, this.label);
  final String key;
  final String unit;
  final String label;

  static ReadingType fromKey(String k) =>
      ReadingType.values.firstWhere((t) => t.key == k);
}

class Reading {
  final ReadingType type;
  final double value; // systolic for blood pressure
  final double? value2; // diastolic for blood pressure
  final DateTime timestamp;
  final String source; // healthkit | health_connect | manual | simulated
  final String? context; // blood glucose: fasting | random

  const Reading({
    required this.type,
    required this.value,
    this.value2,
    required this.timestamp,
    required this.source,
    this.context,
  });

  /// Deterministic id so re-syncing the same sample never creates duplicates.
  String get docId => '${type.key}_${timestamp.millisecondsSinceEpoch}';

  String get display => type == ReadingType.bloodPressure
      ? '${value.round()}/${value2?.round() ?? '-'} ${type.unit}'
      : '${value.round()} ${type.unit}';

  Map<String, dynamic> toMap() => {
        'type': type.key,
        'value': value,
        if (value2 != null) 'value2': value2,
        'unit': type.unit,
        'timestamp': Timestamp.fromDate(timestamp),
        'source': source,
        if (context != null) 'context': context,
      };

  factory Reading.fromMap(Map<String, dynamic> m) => Reading(
        type: ReadingType.fromKey(m['type'] as String),
        value: (m['value'] as num).toDouble(),
        value2: (m['value2'] as num?)?.toDouble(),
        timestamp: (m['timestamp'] as Timestamp).toDate(),
        source: m['source'] as String? ?? 'unknown',
        context: m['context'] as String?,
      );
}
