import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/reading.dart';
import '../services/firestore_service.dart';

class HealthHistoryScreen extends StatefulWidget {
  const HealthHistoryScreen({super.key});

  @override
  State<HealthHistoryScreen> createState() => _HealthHistoryScreenState();
}

class _HealthHistoryScreenState extends State<HealthHistoryScreen> {
  static const _purple = Color(0xFF7048A5);
  static const _background = Color(0xFFFBF8FF);
  static const _types = <ReadingType>[
    ReadingType.bloodGlucose, ReadingType.bloodPressure,
    ReadingType.heartRate, ReadingType.hrv, ReadingType.steps,
  ];
  ReadingType _selected = ReadingType.bloodGlucose;
  int _days = 7;

  String _name(ReadingType type) {
    if (type == ReadingType.bloodGlucose) return 'Blood glucose';
    if (type == ReadingType.bloodPressure) return 'Blood pressure';
    if (type == ReadingType.heartRate) return 'Heart rate';
    if (type == ReadingType.hrv) return 'HRV';
    return 'Steps';
  }

  String _unit(ReadingType type) {
    if (type == ReadingType.bloodGlucose) return 'mg/dL';
    if (type == ReadingType.bloodPressure) return 'mmHg';
    if (type == ReadingType.heartRate) return 'bpm';
    if (type == ReadingType.hrv) return 'ms';
    return 'steps';
  }

  double? _number(Reading reading) {
    // Reading.display is the same formatted value shown on the dashboard.
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(reading.display.replaceAll(',', ''));
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  // Blood pressure is stored as one reading (e.g. 120/80 mmHg).
  // Read both values from the existing display format without changing models.
  List<double> _pressureValues(Reading reading) {
    final matches = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(reading.display.replaceAll(',', ''))
        .take(2)
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();
    return matches.length == 2 ? matches : <double>[];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Health History'),
        backgroundColor: _background,
        foregroundColor: _purple,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your history.'))
          : StreamBuilder<List<Reading>>(
              stream: FirestoreService.instance.recentReadingsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load readings: ${snapshot.error}', textAlign: TextAlign.center),
                  ));
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final now = DateTime.now();
                final cutoff = now.subtract(Duration(days: _days));
                final readings = snapshot.data!
                    .where((r) => r.type == _selected && !r.timestamp.isBefore(cutoff)
                        && !r.timestamp.isAfter(now.add(const Duration(days: 1))))
                    .toList()
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                final points = <_Point>[];
                final diastolicPoints = <_Point>[];
                for (final r in readings) {
                  if (_selected == ReadingType.bloodPressure) {
                    final bp = _pressureValues(r);
                    if (bp.length == 2 && bp[0].isFinite && bp[1].isFinite) {
                      points.add(_Point(r.timestamp, bp[0]));
                      diastolicPoints.add(_Point(r.timestamp, bp[1]));
                    }
                  } else {
                    final value = _number(r);
                    if (value != null && value.isFinite) {
                      points.add(_Point(r.timestamp, value));
                    }
                  }
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    const Text('Your health trends',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: _purple)),
                    const SizedBox(height: 6),
                    const Text('Readings saved from your health devices or manual entry',
                        style: TextStyle(color: Color(0xFF756A80))),
                    const SizedBox(height: 24),
                    Wrap(spacing: 8, runSpacing: 8, children: _types.map((type) {
                      return ChoiceChip(
                        label: Text(_name(type)),
                        selected: _selected == type,
                        selectedColor: const Color(0xFFE9DDF8),
                        labelStyle: TextStyle(color: _selected == type ? _purple : const Color(0xFF5B5264)),
                        onSelected: (_) => setState(() => _selected = type),
                      );
                    }).toList()),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, children: [
                      for (final d in [1, 7, 30])
                        ChoiceChip(
                          label: Text(d == 1 ? '24 hours' : '$d days'),
                          selected: _days == d,
                          selectedColor: const Color(0xFFE9DDF8),
                          onSelected: (_) => setState(() => _days = d),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    if (_selected == ReadingType.bloodGlucose || _selected == ReadingType.bloodPressure)
                      const Text('Target-based highlighting will be available after you set your doctor-recommended targets.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF756A80))),
                    const SizedBox(height: 20),
                    Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_name(_selected),
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: _purple)),
                          const SizedBox(height: 5),
                          Text(points.isEmpty ? 'No readings in this period' :
                              '${points.last.value.toStringAsFixed(_selected == ReadingType.steps || _selected == ReadingType.bloodPressure ? 0 : 1)}${diastolicPoints.isNotEmpty ? '/${diastolicPoints.last.value.toStringAsFixed(0)}' : ''} ${_unit(_selected)} · latest',
                              style: const TextStyle(color: Color(0xFF71677C))),
                          const SizedBox(height: 20),
                          SizedBox(height: 210, width: double.infinity,
                            child: points.isEmpty
                                ? const Center(child: Text('No saved readings for this period.'))
                                : CustomPaint(painter: _HistoryPainter(points, _purple, second: diastolicPoints))),
                          if (diastolicPoints.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text('Purple: systolic  ·  Orange: diastolic',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF756A80))),
                            ),
                          const SizedBox(height: 12),
                          Text('${points.length} reading(s) in selected period',
                              style: const TextStyle(color: Color(0xFF756A80), fontSize: 12)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Recent readings',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _purple)),
                    const SizedBox(height: 10),
                    if (readings.isEmpty)
                      const Padding(padding: EdgeInsets.all(14), child: Text('No readings found.')),
                    for (final r in readings.reversed.take(20))
                      Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.monitor_heart_outlined, color: _purple),
                          title: Text(r.display),
                          subtitle: Text('${r.timestamp.toLocal().toString().substring(0, 16)} · ${r.source}'),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _Point {
  const _Point(this.time, this.value);
  final DateTime time;
  final double value;
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.points, this.color, {this.second = const []});
  final List<_Point> points;
  final Color color;
  final List<_Point> second;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = const Color(0xFFEDE5F3)..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (points.isEmpty) return;
    final values = [...points, ...second].map((p) => p.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final spread = maxValue - minValue;
    final padding = spread == 0 ? math.max(1.0, maxValue.abs() * .1) : spread * .15;
    final lower = minValue - padding;
    final upper = maxValue + padding;
    final first = points.first.time.millisecondsSinceEpoch;
    final last = points.last.time.millisecondsSinceEpoch;
    Offset offset(_Point p) {
      final x = first == last ? size.width / 2 :
          (p.time.millisecondsSinceEpoch - first) / (last - first) * size.width;
      final y = size.height - (p.value - lower) / (upper - lower) * size.height;
      return Offset(x, y);
    }
    final path = Path()..moveTo(offset(points.first).dx, offset(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final p = offset(points[i]);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.5
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    if (points.length <= 60) {
      for (final p in points) {
        canvas.drawCircle(offset(p), 3, Paint()..color = color);
      }
    }
    if (second.isNotEmpty) {
      const orange = Color(0xFFF08B43);
      final secondPath = Path()
        ..moveTo(offset(second.first).dx, offset(second.first).dy);
      for (var i = 1; i < second.length; i++) {
        secondPath.lineTo(offset(second[i]).dx, offset(second[i]).dy);
      }
      canvas.drawPath(secondPath, Paint()
        ..color = orange
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
      if (second.length <= 60) {
        for (final p in second) {
          canvas.drawCircle(offset(p), 3, Paint()..color = orange);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color ||
       oldDelegate.second != second;
}
