// lib/water_intake_reminder_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'notification_service.dart';

class WaterReminderItem {
  final int id;
  final List<String> days;
  final int hour;
  final int minute;
  final String customMessage;

  const WaterReminderItem({
    required this.id,
    required this.days,
    required this.hour,
    required this.minute,
    required this.customMessage,
  });

  String get day {
    if (days.length >= 7 || days.contains('Every day')) return 'Every day';
    const shortMap = {
      'Monday': 'Mon',
      'Tuesday': 'Tue',
      'Wednesday': 'Wed',
      'Thursday': 'Thu',
      'Friday': 'Fri',
      'Saturday': 'Sat',
      'Sunday': 'Sun',
    };
    return days.map((d) => shortMap[d] ?? d).join(', ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'days': days,
    'hour': hour,
    'minute': minute,
    'customMessage': customMessage,
  };

  factory WaterReminderItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedDays = [];
    if (json['days'] is List) {
      parsedDays = (json['days'] as List).map((e) => e.toString()).toList();
    } else if (json['day'] is String) {
      final oldDay = json['day'] as String;
      if (oldDay == 'Every day') {
        parsedDays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
      } else {
        parsedDays = [oldDay];
      }
    }
    if (parsedDays.isEmpty) {
      parsedDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
    }
    return WaterReminderItem(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch % 10000,
      days: parsedDays,
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
      customMessage:
          json['customMessage'] as String? ??
          'Time for a fresh glass of water! Stay hydrated. 💧',
    );
  }
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

    await NotificationService.cancelAll();

    if (!enabled) return;

    for (final reminder in reminders) {
      final title = '💧 Water Intake Reminder';
      final body = reminder.customMessage.trim().isNotEmpty
          ? reminder.customMessage.trim()
          : 'Time to drink a fresh glass of water!';

      final targetDays = reminder.days.contains('Every day')
          ? [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ]
          : reminder.days;

      for (final dayName in targetDays) {
        final weekday = weekdayToInt(dayName);
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
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Set<String> _selectedDays = {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  };

  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _initPermissionsAndLoad();
  }

  Future<void> _initPermissionsAndLoad() async {
    await NotificationService.requestPermissions();
    await _loadData();
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

  void _showDaySelectionDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isAllSelected = _selectedDays.length == 7;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Days',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (isAllSelected) {
                                  _selectedDays.clear();
                                } else {
                                  _selectedDays.addAll(_daysList);
                                }
                              });
                              setSheetState(() {});
                            },
                            child: Text(
                              isAllSelected ? 'Deselect All' : 'Select All',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.line),
                      ..._daysList.map((day) {
                        final isChecked = _selectedDays.contains(day);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: AppColors.ink,
                          checkColor: AppColors.lime,
                          title: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                            setSheetState(() {});
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.lime,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Done',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addReminder() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Please select at least one day.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
      return;
    }

    final text = _customTextController.text.trim();
    final sortedDays = _daysList
        .where((d) => _selectedDays.contains(d))
        .toList();

    final newReminder = WaterReminderItem(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      days: sortedDays,
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
          'Reminder logged for ${_formatTimeOfDay(_selectedTime)} (${newReminder.day})',
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

  String get _selectedDaysSummary {
    if (_selectedDays.length == 7) return 'Every day (7 days)';
    if (_selectedDays.isEmpty) return 'No days selected';
    const shortMap = {
      'Monday': 'Mon',
      'Tuesday': 'Tue',
      'Wednesday': 'Wed',
      'Thursday': 'Thu',
      'Friday': 'Fri',
      'Saturday': 'Sat',
      'Sunday': 'Sun',
    };
    return _daysList
        .where((d) => _selectedDays.contains(d))
        .map((d) => shortMap[d] ?? d)
        .join(', ');
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
                      'Select days, set time, and customize message',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const Text(
            'SELECT DAYS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showDaySelectionDialog,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDaysSummary,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedDays.isEmpty
                            ? AppColors.soft
                            : AppColors.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: _daysList.map((day) {
              final isSelected = _selectedDays.contains(day);
              final label = day.substring(0, 3);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ink : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.ink : AppColors.line,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppColors.lime : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 8),
          // Test button to instantly check Android notification display
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.showTestNotification();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Test notification dispatched! Check your status bar.',
                    ),
                    backgroundColor: AppColors.ink,
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text(
                'Send Test Notification Now',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                  'No reminders logged yet.\nPick days and a time, then tap "+" above.',
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
                              Flexible(
                                child: Container(
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.muted,
                                    ),
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
