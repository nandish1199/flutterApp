import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const String kMedicinesStorageKey = 'elateFitMedicines';
const String kMedicineIntakesStorageKey = 'elateFitMedicineIntakes';

const List<String> weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<int> medicinePeriods = [7, 15, 30, 90];

const List<String> kFormTypes = [
  'Tablet',
  'Capsule',
  'Syrup',
  'Drop',
  'Injection',
  'Other',
];

const List<String> kRoutes = [
  'By mouth',
  'With water',
  'Topical',
  'Inhaled',
  'Other',
];

const List<String> kFrequencies = [
  'Once daily',
  'Twice daily',
  'Thrice daily',
  '4 times daily',
  'Hourly',
  'As needed',
];

const List<String> kMealInstructions = [
  'Any time',
  'Before food',
  'With food',
  'After food',
];

class MedicineItem {
  const MedicineItem({
    required this.id,
    required this.name,
    required this.dosage,
    required this.formType,
    required this.route,
    required this.frequency,
    required this.times,
    required this.meal,
    required this.startDate,
    this.endDate,
    required this.notes,
    required this.days,
    required this.active,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String dosage;
  final String formType;
  final String route;
  final String frequency;
  final List<TimeOfDay> times;
  final String meal;
  final DateTime startDate;
  final DateTime? endDate;
  final String notes;
  final List<int> days; // DateTime.weekday values: Monday = 1 ... Sunday = 7
  final bool active;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'formType': formType,
    'route': route,
    'frequency': frequency,
    'times': times
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        )
        .toList(),
    'meal': meal,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'notes': notes,
    'days': days,
    'active': active,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    List<TimeOfDay> parseTimes() {
      final rawList = json['times'] as List?;
      if (rawList != null && rawList.isNotEmpty) {
        return rawList.map((entry) {
          final parts = (entry as String).split(':');
          return TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
          );
        }).toList();
      }
      return [const TimeOfDay(hour: 8, minute: 0)];
    }

    return MedicineItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      formType: json['formType'] as String? ?? 'Tablet',
      route: json['route'] as String? ?? 'By mouth',
      frequency: json['frequency'] as String? ?? 'Once daily',
      times: parseTimes(),
      meal: json['meal'] as String? ?? 'Any time',
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      notes: json['notes'] as String? ?? '',
      days:
          (json['days'] as List?)
              ?.map((day) => (day as num).toInt())
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7],
      active: json['active'] as bool? ?? true,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ScheduledDose {
  const ScheduledDose({required this.medicine, required this.time});

  final MedicineItem medicine;
  final TimeOfDay time;

  String get doseId =>
      '${medicine.id}|${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

Future<List<MedicineItem>> loadMedicines() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kMedicinesStorageKey);
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List)
        .map((item) => MedicineItem.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<Set<String>> loadMedicineIntakes() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(kMedicineIntakesStorageKey)?.toSet() ?? {};
}

Future<void> saveMedicineData(
  List<MedicineItem> medicines,
  Set<String> intakes,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kMedicinesStorageKey,
    jsonEncode(medicines.map((m) => m.toJson()).toList()),
  );
  await prefs.setStringList(kMedicineIntakesStorageKey, intakes.toList());
}

String medicineDayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String medicineIntakeEntryKey(String doseId, DateTime date) =>
    '$doseId|${medicineDayKey(date)}';

class MedicineIntakePage extends StatefulWidget {
  const MedicineIntakePage({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  State<MedicineIntakePage> createState() => _MedicineIntakePageState();
}

class _MedicineIntakePageState extends State<MedicineIntakePage> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  List<MedicineItem> _medicines = [];
  Set<String> _intakes = {};

  String _formType = 'Tablet';
  String _route = 'By mouth';
  String _frequency = 'Once daily';
  String _meal = 'Any time';
  List<TimeOfDay> _reminderTimes = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  List<bool> _selectedDays = List.filled(7, true);
  bool _active = true;

  String? _editingId;
  int _period = 7;
  String _status = '';
  bool _statusIsError = false;
  int _selectedFooterIndex = 0;

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
    final medicines = await loadMedicines();
    final intakes = await loadMedicineIntakes();
    if (!mounted) return;
    setState(() {
      _medicines = medicines;
      _intakes = intakes;
    });
  }

  Future<void> _persist() => saveMedicineData(_medicines, _intakes);

  void _showStatus(String message, bool error) {
    setState(() {
      _status = message;
      _statusIsError = error;
    });
  }

  Future<void> _addReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (time != null &&
        !_reminderTimes.any(
          (t) => t.hour == time.hour && t.minute == time.minute,
        )) {
      setState(() {
        _reminderTimes = [..._reminderTimes, time]
          ..sort(
            (a, b) =>
                (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
          );
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _saveMedicine() async {
    final name = _nameController.text.trim();
    final dosage = _dosageController.text.trim();
    final days = [
      for (var i = 0; i < 7; i++)
        if (_selectedDays[i]) i + 1,
    ];

    if (name.isEmpty || dosage.isEmpty) {
      _showStatus('Please add the medicine name and dosage.', true);
      return;
    }
    if (_reminderTimes.isEmpty) {
      _showStatus('Please set at least one reminder time.', true);
      return;
    }
    if (days.isEmpty) {
      _showStatus('Please select at least one scheduled day.', true);
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      _showStatus('End date cannot be earlier than start date.', true);
      return;
    }

    final now = DateTime.now();
    final item = MedicineItem(
      id: _editingId ?? '${now.microsecondsSinceEpoch}',
      name: name,
      dosage: dosage,
      formType: _formType,
      route: _route,
      frequency: _frequency,
      times: _reminderTimes,
      meal: _meal,
      startDate: _startDate,
      endDate: _endDate,
      notes: _notesController.text.trim(),
      days: days,
      active: _active,
      updatedAt: now,
    );

    setState(() {
      final index = _medicines.indexWhere((m) => m.id == item.id);
      if (index == -1) {
        _medicines.add(item);
      } else {
        _medicines[index] = item;
      }
    });

    await _persist();
    _clearForm();
    _showStatus(
      _editingId == null
          ? 'Medicine added successfully.'
          : 'Medicine updated successfully.',
      false,
    );
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _dosageController.clear();
      _notesController.clear();
      _formType = 'Tablet';
      _route = 'By mouth';
      _frequency = 'Once daily';
      _meal = 'Any time';
      _reminderTimes = [const TimeOfDay(hour: 8, minute: 0)];
      _startDate = DateTime.now();
      _endDate = null;
      _selectedDays = List.filled(7, true);
      _active = true;
    });
  }

  void _editMedicine(MedicineItem medicine) {
    setState(() {
      _editingId = medicine.id;
      _nameController.text = medicine.name;
      _dosageController.text = medicine.dosage;
      _notesController.text = medicine.notes;
      _formType = medicine.formType;
      _route = medicine.route;
      _frequency = medicine.frequency;
      _meal = medicine.meal;
      _reminderTimes = List.from(medicine.times);
      _startDate = medicine.startDate;
      _endDate = medicine.endDate;
      _selectedDays = [for (var i = 1; i <= 7; i++) medicine.days.contains(i)];
      _active = medicine.active;
    });
  }

  Future<void> _toggleMedicine(MedicineItem medicine) async {
    final index = _medicines.indexOf(medicine);
    setState(
      () => _medicines[index] = MedicineItem(
        id: medicine.id,
        name: medicine.name,
        dosage: medicine.dosage,
        formType: medicine.formType,
        route: medicine.route,
        frequency: medicine.frequency,
        times: medicine.times,
        meal: medicine.meal,
        startDate: medicine.startDate,
        endDate: medicine.endDate,
        notes: medicine.notes,
        days: medicine.days,
        active: !medicine.active,
        updatedAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  Future<void> _deleteMedicine(MedicineItem medicine) async {
    setState(() {
      _medicines.removeWhere((item) => item.id == medicine.id);
      _intakes.removeWhere((key) => key.startsWith('${medicine.id}|'));
    });
    await _persist();
    if (_editingId == medicine.id) _clearForm();
    _showStatus('${medicine.name} deleted.', false);
  }

  bool _isScheduled(MedicineItem medicine, DateTime date) {
    if (!medicine.active) return false;
    if (!medicine.days.contains(date.weekday)) return false;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(
      medicine.startDate.year,
      medicine.startDate.month,
      medicine.startDate.day,
    );
    if (dateOnly.isBefore(startOnly)) return false;
    if (medicine.endDate != null) {
      final endOnly = DateTime(
        medicine.endDate!.year,
        medicine.endDate!.month,
        medicine.endDate!.day,
      );
      if (dateOnly.isAfter(endOnly)) return false;
    }
    return true;
  }

  bool _isDoseTakenToday(ScheduledDose dose) {
    final key = medicineIntakeEntryKey(dose.doseId, DateTime.now());
    return _intakes.contains(key);
  }

  Future<void> _setDoseTaken(ScheduledDose dose, bool taken) async {
    final key = medicineIntakeEntryKey(dose.doseId, DateTime.now());
    setState(() {
      if (taken) {
        _intakes.add(key);
      } else {
        _intakes.remove(key);
      }
    });
    await _persist();
  }

  String _timeLabel(TimeOfDay time) => time.format(context);

  String _dayLabel(MedicineItem medicine) => medicine.days.length == 7
      ? 'Daily'
      : '${medicine.days.length} day${medicine.days.length == 1 ? '' : 's'}';

  void _onFooterDestinationSelected(int index) {
    setState(() => _selectedFooterIndex = index);
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayMedicines = _medicines
        .where((m) => _isScheduled(m, now))
        .toList();

    final todayDoses =
        todayMedicines.expand((med) {
          return med.times.map((t) => ScheduledDose(medicine: med, time: t));
        }).toList()..sort(
          (a, b) => (a.time.hour * 60 + a.time.minute).compareTo(
            b.time.hour * 60 + b.time.minute,
          ),
        );

    final takenCount = todayDoses.where(_isDoseTakenToday).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _header(),
            const SizedBox(height: 14),
            _safetyBanner(),
            const SizedBox(height: 20),
            _configureCard(),
            const SizedBox(height: 22),
            _cabinetCard(),
            const SizedBox(height: 22),
            _checklistCard(todayDoses, takenCount),
            const SizedBox(height: 22),
            _adherenceCard(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        selectedIndex: _selectedFooterIndex,
        indicatorColor: AppColors.lime,
        onDestinationSelected: _onFooterDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.ramen_dining),
            selectedIcon: Icon(Icons.ramen_dining),
            label: 'Calories',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: 'Cardio',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.medication_rounded,
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
              'Medicine intake tracker',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Keep your doses on track and stay consistent.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _safetyBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.lavender.withAlpha(50),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.lavender),
    ),
    child: const Row(
      children: [
        Icon(Icons.health_and_safety_outlined, size: 20, color: AppColors.ink),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Safety note: This tracker logs your personal routine and does not replace medical advice from a doctor or pharmacist.',
            style: TextStyle(color: AppColors.ink, fontSize: 11, height: 1.35),
          ),
        ),
      ],
    ),
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
            _editingId == null ? 'ADD MEDICINE' : 'UPDATE MEDICINE',
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
      decoration: _decoration('Medicine name · e.g. Vitamin D3'),
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
            decoration: _decoration('Dose · 1 tablet / 500mg'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _formType,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: _decoration('Form'),
            items: kFormTypes
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _formType = val);
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _route,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: _decoration('How to take'),
            items: kRoutes
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _route = val);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _meal,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: _decoration('Meal instruction'),
            items: kMealInstructions
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _meal = val);
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _frequency,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration('Frequency'),
      items: kFrequencies
          .map((freq) => DropdownMenuItem(value: freq, child: Text(freq)))
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _frequency = val);
      },
    ),
    const SizedBox(height: 14),
    const Text(
      'Reminder times',
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < _reminderTimes.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(_reminderTimes[i]),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_reminderTimes.length > 1) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _reminderTimes.removeAt(i)),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        InkWell(
          onTap: _addReminderTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: AppColors.ink),
                SizedBox(width: 4),
                Text(
                  'Add time',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _selectStartDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _decoration('Start date'),
              child: Text(
                '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _selectEndDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _decoration('End date (optional)'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _endDate == null
                          ? 'Ongoing'
                          : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                      style: TextStyle(
                        color: _endDate == null
                            ? AppColors.soft
                            : AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_endDate != null)
                    InkWell(
                      onTap: () => setState(() => _endDate = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    const Text(
      'Scheduled days',
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
    TextField(
      controller: _notesController,
      maxLines: 2,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration(
        'Notes · Take after breakfast, with full glass of water',
      ),
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
              ? 'Scheduled doses appear in today\'s checklist.'
              : 'Paused medicines are hidden from the checklist.',
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
        onPressed: _saveMedicine,
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
          _editingId == null ? 'Add medicine' : 'Update medicine',
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

  Widget _cabinetCard() => _card([
    _sectionTitle('MEDICINE CABINET'),
    const SizedBox(height: 12),
    if (_medicines.isEmpty)
      const Text(
        'No medicines added yet. Configure your schedule above to get started.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _medicines.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 22, color: AppColors.divider),
        itemBuilder: (context, index) => _medicineRow(_medicines[index], index),
      ),
  ]);

  Widget _medicineRow(MedicineItem item, int index) {
    final timesStr = item.times.map(_timeLabel).join(', ');
    return Column(
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
                Icons.medical_services_outlined,
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
                    item.name,
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
                    '${item.dosage} · ${item.formType} · ${item.frequency}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$timesStr · ${item.meal} · ${_dayLabel(item)}',
                    style: const TextStyle(color: AppColors.soft, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: item.active ? AppColors.mint : AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.active ? 'Active' : 'Paused',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (item.notes.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            item.notes,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 5),
        Wrap(
          spacing: 2,
          children: [
            TextButton.icon(
              onPressed: () => _editMedicine(item),
              icon: const Icon(Icons.edit_rounded, size: 15),
              label: const Text('Edit'),
            ),
            TextButton.icon(
              onPressed: () => _toggleMedicine(item),
              icon: Icon(
                item.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 15,
              ),
              label: Text(item.active ? 'Pause' : 'Activate'),
            ),
            TextButton.icon(
              onPressed: () => _deleteMedicine(item),
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ],
        ),
      ],
    );
  }

  Widget _checklistCard(List<ScheduledDose> todayDoses, int takenCount) {
    final pendingCount = todayDoses.length - takenCount;
    return _card([
      Row(
        children: [
          Expanded(child: _sectionTitle('TODAY\'S DOSES')),
          Text(
            '${todayDoses.length} scheduled',
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
          _stat('Scheduled', '${todayDoses.length}', AppColors.lime),
          const SizedBox(width: 8),
          _stat('Taken', '$takenCount', AppColors.mint),
          const SizedBox(width: 8),
          _stat('Pending', '$pendingCount', AppColors.peach),
        ],
      ),
      const SizedBox(height: 14),
      if (todayDoses.isEmpty)
        const Text(
          'Nothing is scheduled for today. Add a medicine or check scheduled days above.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: todayDoses.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 18, color: AppColors.divider),
          itemBuilder: (context, index) => _checklistRow(todayDoses[index]),
        ),
    ]);
  }

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

  Widget _checklistRow(ScheduledDose dose) {
    final taken = _isDoseTakenToday(dose);
    return Row(
      children: [
        Checkbox(
          value: taken,
          activeColor: AppColors.ink,
          onChanged: (value) => _setDoseTaken(dose, value ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dose.medicine.name,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dose.medicine.dosage} · ${_timeLabel(dose.time)} · ${dose.medicine.meal}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                '${dose.medicine.route}${dose.medicine.notes.isNotEmpty ? ' · ${dose.medicine.notes}' : ''}',
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
            color: taken ? AppColors.mint : AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            taken ? 'Taken' : 'Pending',
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

  Widget _adherenceCard() {
    final days = List.generate(
      _period,
      (index) => DateTime.now().subtract(Duration(days: _period - 1 - index)),
    );

    int periodTaken = 0;
    int periodScheduled = 0;

    final values = <int>[];
    for (final day in days) {
      final key = medicineDayKey(day);
      final takenCountForDay = _intakes
          .where((item) => item.endsWith('|$key'))
          .length;
      values.add(takenCountForDay);
      periodTaken += takenCountForDay;

      final scheduledForDay = _medicines
          .where((m) => _isScheduled(m, day))
          .fold<int>(0, (sum, m) => sum + m.times.length);
      periodScheduled += scheduledForDay;
    }

    final rate = periodScheduled == 0
        ? 0
        : ((periodTaken / periodScheduled) * 100).round();
    final maxValue = values.fold<int>(0, (a, b) => b > a ? b : a);

    return _card([
      Row(
        children: [
          Expanded(child: _sectionTitle('ADHERENCE HISTORY')),
          PopupMenuButton<int>(
            initialValue: _period,
            color: AppColors.paper,
            onSelected: (value) => setState(() => _period = value),
            itemBuilder: (context) => medicinePeriods
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
          _stat('Taken', '$periodTaken', AppColors.mint),
          const SizedBox(width: 8),
          _stat('Scheduled', '$periodScheduled', AppColors.lime),
          const SizedBox(width: 8),
          _stat('Adherence', '$rate%', AppColors.lavender),
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
