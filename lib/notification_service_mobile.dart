// lib/notification_service_mobile.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Fallback: match by offset if getting native timezone fails
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      tz.Location? fallback;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.timeZone(now.millisecondsSinceEpoch).offset == offsetMs) {
          fallback = loc;
          break;
        }
      }
      if (fallback != null) {
        tz.setLocalLocation(fallback);
      }
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  /// Request runtime permissions after the UI is mounted
  static Future<void> requestPermissions() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// Instant notification to verify your device displays notifications
  static Future<void> showTestNotification() async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'water_intake_channel',
        'Water Intake Reminders',
        channelDescription: 'Notifications reminding you to hydrate',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      9999,
      '💧 Hydration Test',
      'Notifications are working properly on your phone!',
      details,
    );
  }

  static Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday || !scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      scheduledDate = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      );
    }

    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'water_intake_channel',
        'Water Intake Reminders',
        channelDescription: 'Notifications reminding you to hydrate',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
