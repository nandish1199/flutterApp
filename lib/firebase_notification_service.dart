// lib/firebase_notification_service.dart

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'browser_time_zone.dart'
    if (dart.library.io) 'browser_time_zone_stub.dart'
    as browser_time_zone;

class FirebaseNotificationService {
  static const String _apiEndpoint =
      'https://elatefit.com/api/save_reminder.php';

  static const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyD1jERLWS1ZdmZC_7PhOUZRrbzp3_L83xc',
    appId: '1:120148446375:web:f296838ef166b2041adf82',
    messagingSenderId: '120148446375',
    projectId: 'elatefit-49091',
    authDomain: 'elatefit-49091.firebaseapp.com',
    storageBucket: 'elatefit-49091.firebasestorage.app',
  );

  static const String _vapidKey =
      'BCeTOk-7llH_xbEQLfIBF9t3EhweAYrSQ7VOHVheDLe73iagFWSqb-ojRNC9gZ7zfV3rE7phhPZMcO6H0StU4R4';

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        await Firebase.initializeApp(options: _webFirebaseOptions);
      } else {
        // Android initializes automatically using google-services.json
        await Firebase.initializeApp();
      }
    }

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      if (kIsWeb) {
        await browser_time_zone.showBrowserNotification(
          notification.title ?? '💧 Water Intake Reminder',
          notification.body ?? 'Time to stay hydrated!',
        );
      }
    });
  }

  /// Requests permission and retrieves the registration token
  static Future<String?> requestPermissionAndRegister() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return null;
    }

    // Web requires VAPID key; Android APK must NOT include VAPID key
    final token = kIsWeb
        ? await _messaging.getToken(vapidKey: _vapidKey)
        : await _messaging.getToken();

    return token;
  }

  /// Sends reminder schedules to the BigRock MySQL database
  static Future<void> syncWaterReminders({
    required List<Map<String, dynamic>> reminders,
    required bool enabled,
  }) async {
    if (!enabled || reminders.isEmpty) return;

    final token = await requestPermissionAndRegister();
    if (token == null) return;

    for (final reminder in reminders) {
      final hour = reminder['hour'] as int;
      final minute = reminder['minute'] as int;
      final formattedTime =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      final daysRaw = reminder['days'];
      final List<String> daysList = daysRaw is List
          ? List<String>.from(daysRaw)
          : ['Every day'];

      final formattedDays =
          daysList.length == 7 || daysList.contains('Every day')
          ? 'Every day'
          : daysList.map((d) => d.substring(0, 3)).join(',');

      final message = (reminder['customMessage'] as String?)?.trim();
      final body = (message != null && message.isNotEmpty)
          ? message
          : 'Time for a fresh glass of water! Stay hydrated. 💧';

      try {
        await http.post(
          Uri.parse(_apiEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'time': formattedTime,
            'days': formattedDays,
            'message': body,
          }),
        );
      } catch (e) {
        debugPrint('Failed to sync with BigRock: $e');
      }
    }
  }

  static Future<List<Map<String, dynamic>>> loadWaterReminders() async => [];
  static Future<void> setEnabled(bool enabled) async {}
}
