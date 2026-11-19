import 'dart:math' as math;

import '../models/health_alert.dart';
import '../models/reading.dart';

/// Early-warning detector.
/// Layer 1: threshold-based detection.
/// Layer 2: personal baseline detection.
class AnomalyDetector {
  static const bpStage2Sys = 140, bpStage2Dia = 90;
  static const bpStage1Sys = 130, bpStage1Dia = 80;
 static const bpSevereSys = 180, bpSevereDia = 120;

// Low blood pressure thresholds
static const bpLowSys = 90;
static const bpLowDia = 60;

  static const gluFastingHigh = 130;
  static const gluRandomHigh = 200, gluLow = 70, gluVeryLow = 54;

  // Provisional severe high-glucose rule; requires clinical review.
  static const gluVeryHigh = 300;

  static const rhrHigh = 100, rhrLow = 40;
  static const windowDays = 7, confirmK = 2, confirmN = 3;
  static const rhrMinDelta = 10.0, rhrZ = 3.0;
  static const stepsDropRatio = 0.5, baselineMinDays = 14;

  List<Finding> detect(List<Reading> history, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final out = <Finding>[];

    List<Reading> recent(
      ReadingType type,
      int days, {
      bool Function(Reading)? where,
    }) {
      final from = t.subtract(Duration(days: days));
      final r = history
          .where((x) =>
              x.type == type &&
              !x.timestamp.isAfter(t) &&
              x.timestamp.isAfter(from) &&
              (where == null || where(x)))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return r;
    }

    List<Reading> lastN(List<Reading> l, int n) =>
        l.length <= n ? l : l.sublist(l.length - n);

    double mean(Iterable<double> v) =>
        v.reduce((a, b) => a + b) / v.length;

    // ---- Blood pressure ----
   
    
final bp = lastN(
  recent(
    ReadingType.bloodPressure,
    windowDays,
    where: (r) =>
        r.value > 0 &&
        r.value2 != null &&
        r.value2! > 0 &&
        r.value > r.value2!,
  ),
  confirmN,
);


    if (bp.isNotEmpty) {
      final last = bp.last;
      final dia = last.value2;

      // Severe high blood pressure
      if (last.value >= bpSevereSys ||
          (dia != null && dia >= bpSevereDia)) {
        out.add(Finding(
          'blood_pressure',
          Severity.urgent,
          'bp_severe',
          '${last.value.round()}/${dia?.round() ?? "N/A"} mmHg',
        ));
      }

      // Low blood pressure
      else if (dia != null &&
          (last.value < bpLowSys || dia < bpLowDia)) {
        out.add(Finding(
          'blood_pressure',
          Severity.warning,
          'bp_low',
          '${last.value.round()}/${dia.round()} mmHg',
        ));
      }

      // High blood pressure
      else {
        final high = bp
            .where((r) =>
                r.value >= bpStage2Sys ||
                (r.value2 ?? 0) >= bpStage2Dia)
            .length;

        if (high >= confirmK) {
          out.add(Finding(
            'blood_pressure',
            Severity.warning,
            'bp_stage2',
            '$high of last ${bp.length} readings at or above 140/90 mmHg '
            '(${bp.map((r) => '${r.value.round()}/${r.value2?.round()}').join(', ')})',
          ));
        } else if (bp.length >= confirmN) {
          final ms = mean(bp.map((r) => r.value));
          final md = mean(bp
              .where((r) => r.value2 != null)
              .map((r) => r.value2!));

          if (ms >= bpStage1Sys || md >= bpStage1Dia) {
            out.add(Finding(
              'blood_pressure',
              Severity.info,
              'bp_stage1',
              'average ${ms.round()}/${md.round()} mmHg',
            ));
          }
        }
      }
    }


    // ---- Fasting glucose ----
    final g = lastN(
      recent(
        ReadingType.bloodGlucose,
        windowDays,
where: (r) =>
    r.context.toLowerCase().trim() == 'fasting' &&
    r.value > 0,
      ),
      confirmN,
    );

    if (g.isNotEmpty) {
      final v = g.last.value;

      if (v >= gluVeryHigh) {
        out.add(Finding(
          'glucose',
          Severity.urgent,
          'glu_very_high',
          '${v.round()} mg/dL (fasting)',
        ));
      } else if (v < gluVeryLow) {
        out.add(Finding(
          'glucose',
          Severity.urgent,
          'glu_very_low',
          '${v.round()} mg/dL',
        ));
      } else if (v < gluLow) {
        out.add(Finding(
          'glucose',
          Severity.warning,
          'glu_low',
          '${v.round()} mg/dL',
        ));
      } else {
        final high =
            g.where((r) => r.value > gluFastingHigh).length;

        if (high >= confirmK) {
          out.add(Finding(
            'glucose',
            Severity.warning,
            'glu_fasting_high',
            '$high of last ${g.length} fasting readings above 130 mg/dL '
            '(${g.map((r) => r.value.round()).join(', ')})',
          ));
        }
      }
    }

    // ---- Non-fasting / unknown-context glucose ----
    final gr = recent(
      ReadingType.bloodGlucose,
      1,
      where: (r) => r.context != 'fasting',
    );

    if (gr.isNotEmpty) {
      final v = gr.last.value;

      if (v >= gluVeryHigh) {
        out.add(Finding(
          'glucose',
          Severity.urgent,
          'glu_very_high',
          '${v.round()} mg/dL (non-fasting)',
        ));
      } else if (v < gluVeryLow) {
        out.add(Finding(
          'glucose',
          Severity.urgent,
          'glu_very_low',
          '${v.round()} mg/dL',
        ));
      } else if (!out.any((f) => f.category == 'glucose') &&
          v < gluLow) {
        out.add(Finding(
          'glucose',
          Severity.warning,
          'glu_low',
          '${v.round()} mg/dL',
        ));
      } else if (!out.any((f) => f.category == 'glucose') &&
          v >= gluRandomHigh) {
        out.add(Finding(
          'glucose',
          Severity.warning,
          'glu_random_high',
          '${v.round()} mg/dL (non-fasting)',
        ));
      }
    }

    // ---- Resting heart rate ----
    final rhr = recent(ReadingType.restingHeartRate, 3);

    if (rhr.length >= 2) {
      final m = mean(rhr.map((r) => r.value));

      if (m > rhrHigh) {
        out.add(Finding(
          'heart_rate',
          Severity.warning,
          'rhr_high',
          '3-day mean ${m.round()} bpm',
        ));
      } else if (m < rhrLow) {
        out.add(Finding(
          'heart_rate',
          Severity.warning,
          'rhr_low',
          '3-day mean ${m.round()} bpm',
        ));
      } else {
        final base = history
            .where((r) =>
                r.type == ReadingType.restingHeartRate &&
                !r.timestamp.isAfter(
                    t.subtract(const Duration(days: 3))) &&
                r.timestamp.isAfter(
                    t.subtract(const Duration(days: 31))))
            .map((r) => r.value)
            .toList();

        if (base.length >= baselineMinDays) {
          final mu = mean(base);
          final sd = math.max(_std(base, mu), 2.0);

          if (m - mu >= math.max(rhrMinDelta, rhrZ * sd)) {
            out.add(Finding(
              'heart_rate',
              Severity.warning,
              'rhr_above_baseline',
              '3-day mean ${m.round()} bpm vs usual ${mu.round()} bpm',
            ));
          }
        }
      }
    }

    // ---- Activity ----
    final st = recent(ReadingType.steps, 7);
    final stBase = history
        .where((r) =>
            r.type == ReadingType.steps &&
            !r.timestamp.isAfter(
                t.subtract(const Duration(days: 7))) &&
            r.timestamp.isAfter(
                t.subtract(const Duration(days: 35))))
        .map((r) => r.value)
        .toList();

    if (st.length >= 5 && stBase.length >= baselineMinDays) {
      final med = _median(stBase);
      final avg = mean(st.map((r) => r.value));

      if (med >= 3000 && avg < stepsDropRatio * med) {
        out.add(Finding(
          'activity',
          Severity.info,
          'steps_drop',
          '7-day average ${avg.round()} vs usual ${med.round()} steps/day',
        ));
      }
    }

    return out;
  }

  static double _std(List<double> v, double mu) {
    if (v.length < 2) return 0;
    final s = v.fold<double>(
      0,
      (a, x) => a + (x - mu) * (x - mu),
    );
    return math.sqrt(s / (v.length - 1));
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final n = s.length;
    return n.isOdd
        ? s[n ~/ 2]
        : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}
