// lib/notification_service_web.dart

class NotificationService {
  static Future<void> init() async {}

  static Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
  }) async {}

  static Future<void> cancel(int id) async {}

  static Future<void> cancelAll() async {}
}
