import 'package:cloud_firestore/cloud_firestore.dart';

enum Severity { info, warning, urgent }

Severity severityFromString(String s) =>
    Severity.values.firstWhere((e) => e.name == s, orElse: () => Severity.info);

/// Output of the rule/baseline detector (anomaly_detector.dart).
class Finding {
  final String category; // blood_pressure | glucose | heart_rate | activity
  final Severity severity;
  final String code; // e.g. bp_stage2, rhr_above_baseline
  final String detail; // short factual description with numbers

  const Finding(this.category, this.severity, this.code, this.detail);

  Map<String, dynamic> toMap() => {
        'category': category,
        'severity': severity.name,
        'code': code,
        'detail': detail,
      };
}

/// Stored at users/{uid}/alerts/{id}.
/// Severity always comes from the detector; the LLM only writes the text.
class HealthAlert {
  final String? id;
  final String category;
  final Severity severity;
  final List<Finding> findings;
  final String title;
  final String explanation;
  final List<String> advice;
  final String whenToSeekCare;
  final bool generatedByLlm;
  final String? model;
  final DateTime createdAt;
  final bool acknowledged;

  const HealthAlert({
    this.id,
    required this.category,
    required this.severity,
    required this.findings,
    required this.title,
    required this.explanation,
    required this.advice,
    required this.whenToSeekCare,
    required this.generatedByLlm,
    this.model,
    required this.createdAt,
    this.acknowledged = false,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'severity': severity.name,
        'findings': findings.map((f) => f.toMap()).toList(),
        'title': title,
        'explanation': explanation,
        'advice': advice,
        'whenToSeekCare': whenToSeekCare,
        'generatedByLlm': generatedByLlm,
        'model': model,
        'createdAt': Timestamp.fromDate(createdAt),
        'acknowledged': acknowledged,
      };

  factory HealthAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return HealthAlert(
      id: d.id,
      category: m['category'] as String,
      severity: severityFromString(m['severity'] as String),
      findings: ((m['findings'] as List?) ?? [])
          .map((f) => Finding(
                f['category'] as String,
                severityFromString(f['severity'] as String),
                f['code'] as String,
                f['detail'] as String,
              ))
          .toList(),
      title: m['title'] as String? ?? '',
      explanation: m['explanation'] as String? ?? '',
      advice: List<String>.from(m['advice'] as List? ?? const []),
      whenToSeekCare: m['whenToSeekCare'] as String? ?? '',
      generatedByLlm: m['generatedByLlm'] as bool? ?? false,
      model: m['model'] as String?,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      acknowledged: m['acknowledged'] as bool? ?? false,
    );
  }
}
