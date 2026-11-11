import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    _ready = true;
  }

  Future<void> requestPermission() async {
    await initialize();
    await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true, badge: true, sound: true);
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  int idFor(String medicationId, String time) {
    var hash = 0;
    for (final code in '$medicationId/$time'.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> schedule(String id, String name, String dose, String time) async {
    await initialize();
    final parts = time.split(':');
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      idFor(id, time), 'Medication reminder', '$name · $dose',
      tz.TZDateTime.from(next, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails('medication_daily',
          'Medication reminders', channelDescription: 'Daily medication schedules',
          importance: Importance.high, priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(String id, String time) async {
    await initialize();
    await _plugin.cancel(idFor(id, time));
  }

  Future<void> targetNotice(String message) async {
    await initialize();
    await _plugin.show(900001, 'Outside your health target', message,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails('health_targets', 'Health target notices',
          importance: Importance.high, priority: Priority.high),
      ));
  }
}
