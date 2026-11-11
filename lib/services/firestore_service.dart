import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/health_alert.dart';
import '../models/reading.dart';
import '../models/user_profile.dart';

/// Data layout:
///   users/{uid}                  profile (existing document)
///   users/{uid}/readings/{id}    Reading
///   users/{uid}/alerts/{id}      HealthAlert
/// All queries use a single field, so no composite indexes are needed.
class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  // ---------- profile ----------
  Stream<UserProfile?> profileStream(String uid) => _user(uid)
      .snapshots()
      .map((d) => d.exists ? UserProfile.fromMap(uid, d.data()!) : null);

  Future<UserProfile?> getProfile(String uid) async {
    final d = await _user(uid).get();
    return d.exists ? UserProfile.fromMap(uid, d.data()!) : null;
  }

  Future<void> saveProfile(UserProfile p) =>
      _user(p.uid).set(p.toUpdateMap(), SetOptions(merge: true));

  Future<void> setLastSync(String uid, DateTime t) => _user(uid)
      .set({'lastHealthSync': Timestamp.fromDate(t)}, SetOptions(merge: true));

  Future<DateTime?> getLastSync(String uid) async {
    final d = await _user(uid).get();
    return (d.data()?['lastHealthSync'] as Timestamp?)?.toDate();
  }

  // ---------- readings ----------
  Future<void> saveReadings(String uid, List<Reading> readings) async {
    final col = _user(uid).collection('readings');
    for (var i = 0; i < readings.length; i += 450) {
      final batch = _db.batch();
      for (final r in readings.skip(i).take(450)) {
        batch.set(col.doc(r.docId), r.toMap());
      }
      await batch.commit();
    }
  }

  Future<List<Reading>> readingsSince(String uid, DateTime since) async {
    final q = await _user(uid)
        .collection('readings')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp')
        .get();
    return q.docs.map((d) => Reading.fromMap(d.data())).toList();
  }

  /// Last 35 days, live. The dashboard picks the latest value per type.
  Stream<List<Reading>> recentReadingsStream(String uid) {
    final since = DateTime.now().subtract(const Duration(days: 35));
    return _user(uid)
        .collection('readings')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map((d) => Reading.fromMap(d.data())).toList());
  }

  Future<void> deleteSimulatedReadings(String uid) async {
    final q = await _user(uid)
        .collection('readings')
        .where('source', isEqualTo: 'simulated')
        .get();
    for (var i = 0; i < q.docs.length; i += 450) {
      final batch = _db.batch();
      for (final d in q.docs.skip(i).take(450)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  // ---------- alerts ----------
  Future<void> addAlert(String uid, HealthAlert a) =>
      _user(uid).collection('alerts').add(a.toMap());

  Stream<List<HealthAlert>> alertsStream(String uid) => _user(uid)
      .collection('alerts')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(HealthAlert.fromDoc).toList());

  Future<List<HealthAlert>> alertsSince(String uid, DateTime since) async {
    final q = await _user(uid)
        .collection('alerts')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return q.docs.map(HealthAlert.fromDoc).toList();
  }

  Future<void> acknowledge(String uid, String alertId) => _user(uid)
      .collection('alerts')
      .doc(alertId)
      .update({'acknowledged': true});

  // Optional doctor-set targets. No default medical targets are assumed.
  Stream<Map<String, dynamic>> targetsStream(String uid) =>
      _user(uid).collection('settings').doc('healthTargets').snapshots()
          .map((doc) => doc.data() ?? <String, dynamic>{});

  Future<void> saveTargets(String uid, Map<String, double> targets) =>
      _user(uid).collection('settings').doc('healthTargets').set(targets);

  Stream<QuerySnapshot<Map<String, dynamic>>> medicationsStream(String uid) =>
      _user(uid).collection('medications').snapshots();

  Future<String> addMedication(String uid, Map<String, dynamic> data) async =>
      (await _user(uid).collection('medications').add(data)).id;

  Future<void> deleteMedication(String uid, String id) =>
      _user(uid).collection('medications').doc(id).delete();

  Future<void> logDose(String uid, String medicationId, String day, String time,
      String status) => _user(uid).collection('doseLogs')
      .doc('${medicationId}_${day}_$time').set({
        'medicationId': medicationId, 'day': day, 'time': time,
        'status': status, 'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<QuerySnapshot<Map<String, dynamic>>> doseLogsStream(String uid) =>
      _user(uid).collection('doseLogs').snapshots();

}
