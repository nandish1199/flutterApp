// lib/water_intake_reminder_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'notification_service.dart';

class WaterReminderItem {
  final int id;
  final String day;
  final int hour;
  final int minute;
  final String customMessage;

  const WaterReminderItem({
    required this.id,
    required this.day,
    required this.hour,
    required this.minute,
    required this.customMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'hour': hour,
    'minute': minute,
    'customMessage': customMessage,
  };

  factory WaterReminderItem.fromJson(Map<String, dynamic> json) =>
      WaterReminderItem(
        id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch % 10000,
        day: json['day'] as String? ?? 'Every day',
        hour: json['hour'] as int? ?? 8,
        minute: json['minute'] as int? ?? 0,
        customMessage:
            json['customMessage'] as String? ??
            'Time for a fresh glass of water! Stay hydrated. 💧',
      );
}

class WaterReminderStorage {
  static const String kRemindersKey = 'elateFitWaterReminders';
  static const String kEnabledKey = 'elateFitWaterReminderEnabled';

  static Future<List<WaterReminderItem>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kRemindersKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => WaterReminderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveReminders(List<WaterReminderItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kRemindersKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kEnabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kEnabledKey, enabled);
  }

  static int weekdayToInt(String day) => switch (day) {
    'Monday' => 1,
    'Tuesday' => 2,
    'Wednesday' => 3,
    'Thursday' => 4,
    'Friday' => 5,
    'Saturday' => 6,
    'Sunday' => 7,
    _ => 0,
  };

  static Future<void> syncNotifications() async {
    final enabled = await isEnabled();
    final reminders = await loadReminders();

    // Cancel all previously scheduled water alerts
    await NotificationService.cancelAll();

    if (!enabled) return;

    for (final reminder in reminders) {
      final title = '💧 Water Intake Reminder';
      final body = reminder.customMessage.trim().isNotEmpty
          ? reminder.customMessage.trim()
          : 'Time to drink a fresh glass of water!';

      if (reminder.day == 'Every day') {
        for (int w = 1; w <= 7; w++) {
          await NotificationService.scheduleWeeklyReminder(
            id: (reminder.id % 1000) * 10 + w,
            title: title,
            body: body,
            weekday: w,
            hour: reminder.hour,
            minute: reminder.minute,
          );
        }
      } else {
        final weekday = weekdayToInt(reminder.day);
        if (weekday > 0) {
          await NotificationService.scheduleWeeklyReminder(
            id: (reminder.id % 1000) * 10 + weekday,
            title: title,
            body: body,
            weekday: weekday,
            hour: reminder.hour,
            minute: reminder.minute,
          );
        }
      }
    }
  }
}

class WaterIntakeReminderPage extends StatefulWidget {
  const WaterIntakeReminderPage({super.key});

  @override
  State<WaterIntakeReminderPage> createState() =>
      _WaterIntakeReminderPageState();
}

class _WaterIntakeReminderPageState extends State<WaterIntakeReminderPage> {
  final List<WaterReminderItem> _reminders = [];
  final TextEditingController _customTextController = TextEditingController(
    text: 'Time for a fresh glass of water! Stay hydrated. 💧',
  );

  static const List<String> _daysList = [
    'Every day',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _selectedDay = 'Every day';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loaded = await WaterReminderStorage.loadReminders();
    setState(() {
      _reminders.clear();
      _reminders.addAll(loaded);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.ink,
              onPrimary: AppColors.lime,
              surface: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _addReminder() async {
    final text = _customTextController.text.trim();
    final newReminder = WaterReminderItem(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      day: _selectedDay,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      customMessage: text.isNotEmpty
          ? text
          : 'Time for a fresh glass of water! Stay hydrated. 💧',
    );

    setState(() => _reminders.add(newReminder));
    await WaterReminderStorage.saveReminders(_reminders);
    await WaterReminderStorage.syncNotifications();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Reminder logged for ${_formatTimeOfDay(_selectedTime)} (${_selectedDay})',
          style: const TextStyle(color: AppColors.lime),
        ),
      ),
    );
  }

  Future<void> _deleteReminder(int index) async {
    setState(() => _reminders.removeAt(index));
    await WaterReminderStorage.saveReminders(_reminders);
    await WaterReminderStorage.syncNotifications();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Water Intake Reminder',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            _setupCard(),
            const SizedBox(height: 22),
            _remindersList(),
          ],
        ),
      ),
    );
  }

  Widget _setupCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppColors.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log New Reminder',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Select day, set time, and customize message',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Dropdown menu to select days in a week
          const Text(
            'SELECT DAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDay,
            decoration: _inputDecoration(),
            dropdownColor: AppColors.paper,
            items: _daysList
                .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedDay = val);
            },
          ),
          const SizedBox(height: 16),

          // 2. Select Time & Plus Button to log
          const Text(
            'SET TIME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTimeOfDay(_selectedTime),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.muted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Plus Button to log time
              Material(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _addReminder,
                  child: Container(
                    height: 50,
                    width: 54,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.lime,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Field to add custom notification
          const Text(
            'CUSTOM NOTIFICATION MESSAGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customTextController,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            decoration: _inputDecoration(
              hint: 'Enter your custom water reminder note...',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Log Water Reminder',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.lime,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remindersList() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOGGED REMINDERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${_reminders.length} active',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_reminders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No reminders logged yet.\nPick a time and tap "+" above to schedule.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reminders.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 20, color: AppColors.line),
              itemBuilder: (context, index) {
                final item = _reminders[index];
                final timeFormatted = _formatTimeOfDay(
                  TimeOfDay(hour: item.hour, minute: item.minute),
                );
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: AppColors.ink,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                timeFormatted,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.day,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.customMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      onPressed: () => _deleteReminder(index),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.soft, fontSize: 13),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
    ),
  );
}
