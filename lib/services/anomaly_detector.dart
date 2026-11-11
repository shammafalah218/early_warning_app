import 'dart:math' as math;

import '../models/health_alert.dart';
import '../models/reading.dart';

/// Early-warning detector. SAME rules and constants as data/detector.py,
/// which is where they were evaluated. Change both files together.
///
/// Layer 1: clinical thresholds (ACC/AHA blood-pressure categories,
///          ADA glucose criteria, resting HR limits).
/// Layer 2: personal baseline (resting HR vs the user's own last month,
///          daily steps vs the user's usual activity).
class AnomalyDetector {
  static const bpStage2Sys = 140, bpStage2Dia = 90;
  static const bpStage1Sys = 130, bpStage1Dia = 80;
  static const bpSevereSys = 180, bpSevereDia = 120;
  static const gluFastingHigh = 126, gluFastingPrediabetes = 100;
  static const gluRandomHigh = 200, gluLow = 70, gluVeryLow = 54;
  static const rhrHigh = 100, rhrLow = 40;
  static const windowDays = 7, confirmK = 2, confirmN = 3;
  static const rhrMinDelta = 10.0, rhrZ = 3.0;
  static const stepsDropRatio = 0.5, baselineMinDays = 14;

  List<Finding> detect(List<Reading> history, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final out = <Finding>[];

    List<Reading> recent(ReadingType type, int days,
        {bool Function(Reading)? where}) {
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
    double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;

    // ---- blood pressure ----
    final bp = lastN(recent(ReadingType.bloodPressure, windowDays), confirmN);
    if (bp.isNotEmpty) {
      final last = bp.last;
      final dia = last.value2 ?? 0;
      if (last.value >= bpSevereSys || dia >= bpSevereDia) {
        out.add(Finding('blood_pressure', Severity.urgent, 'bp_severe',
            '${last.value.round()}/${dia.round()} mmHg'));
      } else {
        final high = bp
            .where((r) => r.value >= bpStage2Sys || (r.value2 ?? 0) >= bpStage2Dia)
            .length;
        if (high >= confirmK) {
          out.add(Finding('blood_pressure', Severity.warning, 'bp_stage2',
              '$high of last ${bp.length} readings at or above 140/90 mmHg '
              '(${bp.map((r) => '${r.value.round()}/${r.value2?.round()}').join(', ')})'));
        } else if (bp.length >= confirmN) {
          final ms = mean(bp.map((r) => r.value));
          final md = mean(bp.map((r) => r.value2 ?? 0));
          if (ms >= bpStage1Sys || md >= bpStage1Dia) {
            out.add(Finding('blood_pressure', Severity.info, 'bp_stage1',
                'average ${ms.round()}/${md.round()} mmHg'));
          }
        }
      }
    }

    // ---- fasting glucose ----
    final g = lastN(
        recent(ReadingType.bloodGlucose, windowDays,
            where: (r) => r.context == 'fasting'),
        confirmN);
    if (g.isNotEmpty) {
      final v = g.last.value;
      if (v < gluVeryLow) {
        out.add(Finding('glucose', Severity.urgent, 'glu_very_low', '${v.round()} mg/dL'));
      } else if (v < gluLow) {
        out.add(Finding('glucose', Severity.warning, 'glu_low', '${v.round()} mg/dL'));
      } else {
        final high = g.where((r) => r.value >= gluFastingHigh).length;
        if (high >= confirmK) {
          out.add(Finding('glucose', Severity.warning, 'glu_fasting_high',
              '$high of last ${g.length} fasting readings at or above 126 mg/dL '
              '(${g.map((r) => r.value.round()).join(', ')})'));
        } else if (g.length >= confirmN &&
            mean(g.map((r) => r.value)) >= gluFastingPrediabetes) {
          out.add(Finding('glucose', Severity.info, 'glu_prediabetes_range',
              'average fasting ${mean(g.map((r) => r.value)).round()} mg/dL'));
        }
      }
    }

    // ---- non-fasting / unknown-context glucose ----
    final gr = recent(ReadingType.bloodGlucose, 1,
        where: (r) => r.context != 'fasting');
    if (gr.isNotEmpty && !out.any((f) => f.category == 'glucose')) {
      final v = gr.last.value;
      if (v < gluVeryLow) {
        out.add(Finding('glucose', Severity.urgent, 'glu_very_low', '${v.round()} mg/dL'));
      } else if (v < gluLow) {
        out.add(Finding('glucose', Severity.warning, 'glu_low', '${v.round()} mg/dL'));
      } else if (v >= gluRandomHigh) {
        out.add(Finding('glucose', Severity.warning, 'glu_random_high',
            '${v.round()} mg/dL (non-fasting)'));
      }
    }

    // ---- resting heart rate ----
    final rhr = recent(ReadingType.restingHeartRate, 3);
    if (rhr.length >= 2) {
      final m = mean(rhr.map((r) => r.value));
      if (m > rhrHigh) {
        out.add(Finding('heart_rate', Severity.warning, 'rhr_high', '3-day mean ${m.round()} bpm'));
      } else if (m < rhrLow) {
        out.add(Finding('heart_rate', Severity.warning, 'rhr_low', '3-day mean ${m.round()} bpm'));
      } else {
        final base = history
            .where((r) =>
                r.type == ReadingType.restingHeartRate &&
                !r.timestamp.isAfter(t.subtract(const Duration(days: 3))) &&
                r.timestamp.isAfter(t.subtract(const Duration(days: 31))))
            .map((r) => r.value)
            .toList();
        if (base.length >= baselineMinDays) {
          final mu = mean(base);
          final sd = math.max(_std(base, mu), 2.0);
          if (m - mu >= math.max(rhrMinDelta, rhrZ * sd)) {
            out.add(Finding('heart_rate', Severity.warning, 'rhr_above_baseline',
                '3-day mean ${m.round()} bpm vs usual ${mu.round()} bpm'));
          }
        }
      }
    }

    // ---- activity ----
    final st = recent(ReadingType.steps, 7);
    final stBase = history
        .where((r) =>
            r.type == ReadingType.steps &&
            !r.timestamp.isAfter(t.subtract(const Duration(days: 7))) &&
            r.timestamp.isAfter(t.subtract(const Duration(days: 35))))
        .map((r) => r.value)
        .toList();
    if (st.length >= 5 && stBase.length >= baselineMinDays) {
      final med = _median(stBase);
      final avg = mean(st.map((r) => r.value));
      if (med >= 3000 && avg < stepsDropRatio * med) {
        out.add(Finding('activity', Severity.info, 'steps_drop',
            '7-day average ${avg.round()} vs usual ${med.round()} steps/day'));
      }
    }
    return out;
  }

  static double _std(List<double> v, double mu) {
    if (v.length < 2) return 0;
    final s = v.fold<double>(0, (a, x) => a + (x - mu) * (x - mu));
    return math.sqrt(s / (v.length - 1));
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}
