import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/health_alert.dart';
import '../models/user_profile.dart';

/// Turns detector findings into a short, plain-language alert using Gemini
/// through Firebase AI Logic (no API key inside the app; works on the free
/// Spark plan with the Gemini Developer API).
///
/// Design rules (worth stating in the report):
///  * The LLM never decides WHETHER to alert or HOW serious it is. The
///    detector does. The LLM only explains.
///  * Only de-identified context is sent: age, sex, BMI, yes/no risk
///    factors and the findings. No name, email or uid.
///  * If the call fails (offline, quota, model retired) a template text is
///    used, so an alert is never lost because of the LLM.
class LlmService {
  /// Check the current model list in Firebase console → AI Logic before the
  /// demo: Gemini models are retired on a schedule. In production, read this
  /// value from Firebase Remote Config instead of hard-coding it.
  static const modelName = 'gemini-3.1-flash-lite';

  static const _systemPrompt = '''
You are the explanation component of a health early-warning mobile app.
You receive structured findings that a rule-based detector has ALREADY
produced from the user's own measurements. Your job is to explain them.

Rules:
- Explain only the findings given. Do not add new findings or guess values.
- Do not diagnose. Say the pattern "may indicate" or "is worth checking";
  never say the user "has diabetes" or "has hypertension".
- Do not suggest starting, stopping or changing any medication or dose.
- Do not change the severity. If severity is "urgent", the first advice item
  must tell the user to seek medical care promptly.
- Advice: 2 to 4 short, practical, general items (re-measure correctly,
  lifestyle steps, see a doctor). No brand names.
- Plain language, calm tone, max 90 words for the explanation.
- Write in the language requested (en = English, ar = Arabic).
''';

  // App Check tokens are attached automatically once App Check is activated
  // in main.dart.
  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: modelName,
    systemInstruction: Content.system(_systemPrompt),
    generationConfig: GenerationConfig(
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: Schema.object(properties: {
        'title': Schema.string(description: 'Short alert title, max 8 words'),
        'explanation': Schema.string(),
        'advice': Schema.array(items: Schema.string()),
        'whenToSeekCare': Schema.string(),
      }),
    ),
  );

  Future<HealthAlert> explain({
    required String category,
    required Severity severity,
    required List<Finding> findings,
    required UserProfile? profile,
  }) async {
    final context = {
      'language': profile?.language ?? 'en',
      'severity': severity.name,
      'category': category,
      'findings': findings.map((f) => f.toMap()).toList(),
      'user': {
        'age': profile?.age,
        'sex': profile?.gender,
        'bmi': profile?.bmi == null ? null : double.parse(profile!.bmi!.toStringAsFixed(1)),
        'familyHistoryDiabetes': profile?.familyHistoryDiabetes,
        'familyHistoryHypertension': profile?.familyHistoryHypertension,
        'smoker': profile?.smoker,
      },
    };
    try {
      final res = await _model
          .generateContent([Content.text(jsonEncode(context))])
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(res.text ?? '{}') as Map<String, dynamic>;
      final advice = List<String>.from(j['advice'] as List? ?? const []);
      if ((j['explanation'] as String? ?? '').isEmpty || advice.isEmpty) {
        throw const FormatException('incomplete LLM output');
      }
      return HealthAlert(
        category: category,
        severity: severity,
        findings: findings,
        title: j['title'] as String? ?? _fallbackTitle(category),
        explanation: j['explanation'] as String,
        advice: advice,
        whenToSeekCare: j['whenToSeekCare'] as String? ?? '',
        generatedByLlm: true,
        model: modelName,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return _fallback(category, severity, findings);
    }
  }

  static String _fallbackTitle(String c) => const {
        'blood_pressure': 'Blood pressure needs attention',
        'glucose': 'Blood glucose needs attention',
        'heart_rate': 'Unusual resting heart rate',
        'activity': 'Activity has dropped',
      }[c] ??
      'Unusual health pattern';

  HealthAlert _fallback(String category, Severity severity, List<Finding> f) =>
      HealthAlert(
        category: category,
        severity: severity,
        findings: f,
        title: _fallbackTitle(category),
        explanation:
            'The app noticed: ${f.map((x) => x.detail).join('; ')}. This is not a diagnosis, but it is worth checking.',
        advice: [
          if (severity == Severity.urgent) 'Seek medical care promptly.',
          'Repeat the measurement after resting for 5 minutes.',
          'Share these readings with your doctor.',
        ],
        whenToSeekCare: severity == Severity.urgent
            ? 'Now, especially if you feel unwell.'
            : 'If the pattern continues over the next few days.',
        generatedByLlm: false,
        createdAt: DateTime.now(),
      );
}
