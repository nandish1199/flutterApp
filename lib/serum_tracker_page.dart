import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const String kSerumsStorageKey = 'elateFitSerums';
const String kSerumApplicationsStorageKey = 'elateFitSerumApplications';

const List<String> weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<int> serumPeriods = [7, 15, 30, 90, 180];

class SerumItem {
  const SerumItem({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.notes,
    required this.days,
    required this.active,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String dosage;
  final TimeOfDay time;
  final String notes;
  final List<int> days; // DateTime.weekday values: Monday = 1.
  final bool active;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'hour': time.hour,
    'minute': time.minute,
    'notes': notes,
    'days': days,
    'active': active,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SerumItem.fromJson(Map<String, dynamic> json) => SerumItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    dosage: json['dosage'] as String? ?? '',
    time: TimeOfDay(
      hour: (json['hour'] as num?)?.toInt() ?? 8,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
    ),
    notes: json['notes'] as String? ?? '',
    days:
        (json['days'] as List?)?.map((day) => (day as num).toInt()).toList() ??
        [1, 2, 3, 4, 5, 6, 7],
    active: json['active'] as bool? ?? true,
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

Future<List<SerumItem>> loadSerums() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kSerumsStorageKey);
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List)
        .map((item) => SerumItem.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<Set<String>> loadSerumApplications() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(kSerumApplicationsStorageKey)?.toSet() ?? {};
}

Future<void> saveSerumData(
  List<SerumItem> serums,
  Set<String> applications,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kSerumsStorageKey,
    jsonEncode(serums.map((serum) => serum.toJson()).toList()),
  );
  await prefs.setStringList(
    kSerumApplicationsStorageKey,
    applications.toList(),
  );
}

String serumDayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String serumApplicationKey(String serumId, DateTime date) =>
    '$serumId|${serumDayKey(date)}';

class SerumTrackerPage extends StatefulWidget {
  const SerumTrackerPage({super.key});

  @override
  State<SerumTrackerPage> createState() => _SerumTrackerPageState();
}

class _SerumTrackerPageState extends State<SerumTrackerPage> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  List<SerumItem> _serums = [];
  Set<String> _applications = {};
  List<bool> _selectedDays = List.filled(7, true);
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  bool _active = true;
  String? _editingId;
  int _period = 7;
  String _status = '';
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final serums = await loadSerums();
    final applications = await loadSerumApplications();
    if (!mounted) return;
    setState(() {
      _serums = serums;
      _applications = applications;
    });
  }

  Future<void> _persist() => saveSerumData(_serums, _applications);

  void _showStatus(String message, bool error) => setState(() {
    _status = message;
    _statusIsError = error;
  });

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _saveSerum() async {
    final name = _nameController.text.trim();
    final dosage = _dosageController.text.trim();
    final days = [
      for (var i = 0; i < 7; i++)
        if (_selectedDays[i]) i + 1,
    ];
    if (name.isEmpty || dosage.isEmpty) {
      _showStatus('Please add a serum name and dosage.', true);
      return;
    }
    if (days.isEmpty) {
      _showStatus('Please select at least one scheduled day.', true);
      return;
    }
    final now = DateTime.now();
    final serum = SerumItem(
      id: _editingId ?? '${now.microsecondsSinceEpoch}',
      name: name,
      dosage: dosage,
      time: _selectedTime,
      notes: _notesController.text.trim(),
      days: days,
      active: _active,
      updatedAt: now,
    );
    setState(() {
      final index = _serums.indexWhere((item) => item.id == serum.id);
      if (index == -1) {
        _serums.add(serum);
      } else {
        _serums[index] = serum;
      }
    });
    await _persist();
    _clearForm();
    _showStatus(
      _editingId == null
          ? 'Serum added successfully.'
          : 'Serum updated successfully.',
      false,
    );
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _dosageController.clear();
      _notesController.clear();
      _selectedDays = List.filled(7, true);
      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
      _active = true;
    });
  }

  void _editSerum(SerumItem serum) {
    setState(() {
      _editingId = serum.id;
      _nameController.text = serum.name;
      _dosageController.text = serum.dosage;
      _notesController.text = serum.notes;
      _selectedTime = serum.time;
      _selectedDays = [for (var i = 1; i <= 7; i++) serum.days.contains(i)];
      _active = serum.active;
    });
  }

  Future<void> _toggleSerum(SerumItem serum) async {
    final index = _serums.indexOf(serum);
    setState(
      () => _serums[index] = SerumItem(
        id: serum.id,
        name: serum.name,
        dosage: serum.dosage,
        time: serum.time,
        notes: serum.notes,
        days: serum.days,
        active: !serum.active,
        updatedAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  Future<void> _deleteSerum(SerumItem serum) async {
    setState(() {
      _serums.removeWhere((item) => item.id == serum.id);
      _applications.removeWhere((key) => key.startsWith('${serum.id}|'));
    });
    await _persist();
    if (_editingId == serum.id) _clearForm();
    _showStatus('${serum.name} deleted.', false);
  }

  bool _scheduledToday(SerumItem serum) =>
      serum.active && serum.days.contains(DateTime.now().weekday);

  bool _appliedToday(String serumId) =>
      _applications.contains(serumApplicationKey(serumId, DateTime.now()));

  Future<void> _setApplied(SerumItem serum, bool applied) async {
    final key = serumApplicationKey(serum.id, DateTime.now());
    setState(() {
      if (applied) {
        _applications.add(key);
      } else {
        _applications.remove(key);
      }
    });
    await _persist();
  }

  String _timeLabel(TimeOfDay time) => time.format(context);

  String _dayLabel(SerumItem serum) => serum.days.length == 7
      ? 'Daily'
      : '${serum.days.length} day${serum.days.length == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final today = _serums.where(_scheduledToday).toList();
    final appliedCount = today.where((serum) => _appliedToday(serum.id)).length;
    final periodStart = DateTime.now().subtract(Duration(days: _period - 1));
    final periodApplications = _applications.where((key) {
      final dateText = key.split('|').last.split('-');
      if (dateText.length != 3) return false;
      final date = DateTime(
        int.parse(dateText[0]),
        int.parse(dateText[1]),
        int.parse(dateText[2]),
      );
      return !date.isBefore(
        DateTime(periodStart.year, periodStart.month, periodStart.day),
      );
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _header(),
            const SizedBox(height: 22),
            _configureCard(),
            const SizedBox(height: 22),
            _configuredCard(),
            const SizedBox(height: 22),
            _checklistCard(today, appliedCount),
            const SizedBox(height: 22),
            _completionCard(periodApplications, today.length, appliedCount),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      const SizedBox(width: 14),
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.lime,
          size: 24,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Serum tracker',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Make your daily glow ritual consistent.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.soft, fontSize: 13),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

  Widget _configureCard() => _card([
    Row(
      children: [
        Expanded(
          child: _sectionTitle(
            _editingId == null ? 'CONFIGURE SERUM' : 'UPDATE SERUM',
          ),
        ),
        if (_editingId != null)
          TextButton(onPressed: _clearForm, child: const Text('Clear')),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _nameController,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration('Serum name · Vitamin C serum'),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _dosageController,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: _decoration('Dosage · 2 drops'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _chooseTime,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _decoration('Time of day'),
              child: Text(
                _timeLabel(_selectedTime),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _notesController,
      maxLines: 2,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration('Notes · Use after cleansing'),
    ),
    const SizedBox(height: 14),
    const Text(
      'Schedule days',
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _dayButton(i),
            ),
          ),
      ],
    ),
    const SizedBox(height: 12),
    Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Active in tracker',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _active
              ? 'Scheduled serums appear in today\'s checklist.'
              : 'Paused serums are hidden from the checklist.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        value: _active,
        activeThumbColor: AppColors.ink,
        onChanged: (value) => setState(() => _active = value),
      ),
    ),
    const SizedBox(height: 8),
    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _saveSerum,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.lime,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(
          _editingId == null ? Icons.add_rounded : Icons.save_rounded,
          size: 18,
        ),
        label: Text(
          _editingId == null ? 'Add serum' : 'Update serum',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    if (_status.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          _status,
          style: TextStyle(
            color: _statusIsError ? AppColors.danger : AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
  ]);

  Widget _dayButton(int index) => InkWell(
    onTap: () => setState(() => _selectedDays[index] = !_selectedDays[index]),
    borderRadius: BorderRadius.circular(11),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: _selectedDays[index] ? AppColors.lime : AppColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: _selectedDays[index] ? AppColors.lime : AppColors.line,
        ),
      ),
      child: Text(
        weekdayLabels[index],
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _configuredCard() => _card([
    _sectionTitle('CONFIGURED SERUMS'),
    const SizedBox(height: 12),
    if (_serums.isEmpty)
      const Text(
        'No serums configured yet. Add your name, dosage, time, and schedule above.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _serums.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 22, color: AppColors.divider),
        itemBuilder: (context, index) => _serumRow(_serums[index], index),
      ),
  ]);

  Widget _serumRow(SerumItem serum, int index) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tiles[index % AppColors.tiles.length],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: AppColors.ink,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serum.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${serum.dosage} · ${_timeLabel(serum.time)} · ${_dayLabel(serum)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: serum.active ? AppColors.mint : AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              serum.active ? 'Active' : 'Paused',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      Text(
        serum.notes.isEmpty ? 'No extra notes saved.' : serum.notes,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 5),
      Wrap(
        spacing: 2,
        children: [
          TextButton.icon(
            onPressed: () => _editSerum(serum),
            icon: const Icon(Icons.edit_rounded, size: 15),
            label: const Text('Edit'),
          ),
          TextButton.icon(
            onPressed: () => _toggleSerum(serum),
            icon: Icon(
              serum.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 15,
            ),
            label: Text(serum.active ? 'Pause' : 'Activate'),
          ),
          TextButton.icon(
            onPressed: () => _deleteSerum(serum),
            icon: const Icon(Icons.delete_outline_rounded, size: 15),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    ],
  );

  Widget _checklistCard(List<SerumItem> today, int appliedCount) => _card([
    Row(
      children: [
        Expanded(child: _sectionTitle('TODAY\'S CHECKLIST')),
        Text(
          '${today.length} scheduled',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        _stat('Scheduled', '${today.length}', AppColors.lime),
        const SizedBox(width: 8),
        _stat('Applied', '$appliedCount', AppColors.mint),
        const SizedBox(width: 8),
        _stat('Pending', '${today.length - appliedCount}', AppColors.peach),
      ],
    ),
    const SizedBox(height: 12),
    if (today.isEmpty)
      const Text(
        'No serums are scheduled for today. Update your schedule above.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: today.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 18, color: AppColors.divider),
        itemBuilder: (context, index) => _checklistRow(today[index]),
      ),
  ]);

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _checklistRow(SerumItem serum) {
    final applied = _appliedToday(serum.id);
    return Row(
      children: [
        Checkbox(
          value: applied,
          activeColor: AppColors.ink,
          onChanged: (value) => _setApplied(serum, value ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serum.name,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${serum.dosage} · ${_timeLabel(serum.time)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              if (serum.notes.isNotEmpty)
                Text(
                  serum.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.soft, fontSize: 10),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: applied ? AppColors.mint : AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            applied ? 'Applied' : 'Pending',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _completionCard(
    int periodApplications,
    int scheduledToday,
    int appliedToday,
  ) {
    final rate = scheduledToday == 0
        ? 0
        : (appliedToday / scheduledToday * 100).round();
    final days = List.generate(
      _period,
      (index) => DateTime.now().subtract(Duration(days: _period - 1 - index)),
    );
    final values = days
        .map(
          (day) => _applications
              .where((key) => key.endsWith('|${serumDayKey(day)}'))
              .length,
        )
        .toList();
    final maxValue = values.fold<int>(0, (a, b) => b > a ? b : a);
    return _card([
      Row(
        children: [
          Expanded(child: _sectionTitle('COMPLETION TRENDS')),
          PopupMenuButton<int>(
            initialValue: _period,
            color: AppColors.paper,
            onSelected: (value) => setState(() => _period = value),
            itemBuilder: (context) => serumPeriods
                .map(
                  (value) => PopupMenuItem(
                    value: value,
                    child: Text(
                      value < 30
                          ? '$value days'
                          : value == 30
                          ? '1 month'
                          : '${value ~/ 30} months',
                    ),
                  ),
                )
                .toList(),
            child: Row(
              children: [
                Text(
                  _period < 30
                      ? '$_period days'
                      : _period == 30
                      ? '1 month'
                      : '${_period ~/ 30} months',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                  size: 17,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          _stat('Applied', '$periodApplications', AppColors.lime),
          const SizedBox(width: 8),
          _stat('Today', '$scheduledToday', AppColors.mint),
          const SizedBox(width: 8),
          _stat('Rate', '$rate%', AppColors.lavender),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 115,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[i] > 0)
                        Text(
                          '${values[i]}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 7,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        height: maxValue == 0
                            ? 4
                            : 4 + 68 * values[i] / maxValue,
                        decoration: BoxDecoration(
                          color: i == values.length - 1
                              ? AppColors.ink
                              : AppColors.lime,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (i == 0 ||
                          i == values.length - 1 ||
                          i == values.length ~/ 2)
                        Text(
                          '${days[i].day}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}
