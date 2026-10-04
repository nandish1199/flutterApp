import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const String kWorkoutEntriesStorageKey = 'elateFitWorkoutEntries';
const String kChallengeStartStorageKey = 'elateFit90DayChallengeStart';
const int kChallengeLength = 90;

const Map<String, List<String>> exerciseGroups = {
  'Chest': [
    'Bench Press',
    'Incline Bench Press',
    'Chest Fly',
    'Push-up',
    'Cable Crossover',
    'Chest Dip',
  ],
  'Back': [
    'Deadlift',
    'Lat Pulldown',
    'Barbell Row',
    'Seated Cable Row',
    'Pull-up',
    'T-Bar Row',
    'Chin-up',
  ],
  'Shoulders': [
    'Shoulder Press',
    'Lateral Raise',
    'Front Raise',
    'Rear Delt Fly',
    'Face Pull',
    'Arnold Press',
  ],
  'Arms': [
    'Biceps Curl',
    'Hammer Curl',
    'Preacher Curl',
    'Triceps Extension',
    'Tricep Pushdown',
    'Skull Crusher',
    'Tricep Dip',
  ],
  'Legs': [
    'Squat',
    'Leg Press',
    'Romanian Deadlift',
    'Bulgarian Split Squat',
    'Leg Extension',
    'Hamstring Curl',
    'Calf Raise',
    'Hip Thrust',
    'Walking Lunge',
  ],
  'Core': [
    'Crunch',
    'Plank',
    'Hanging Leg Raise',
    'Russian Twist',
    'Bicycle Crunch',
    'Mountain Climbers',
    'Dead Bug',
    'Side Plank',
  ],
};

List<String> get allExercises => [
  ...exerciseGroups.values.expand((group) => group),
  'Other',
];

class WorkoutEntry {
  const WorkoutEntry({
    required this.id,
    required this.exercise,
    required this.reps,
    required this.weight,
    required this.createdAt,
  });

  final String id;
  final String exercise;
  final int reps;
  final double weight;
  final DateTime createdAt;

  double get volume => reps * weight;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercise': exercise,
    'reps': reps,
    'weight': weight,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) => WorkoutEntry(
    id: json['id'] as String? ?? '',
    exercise: json['exercise'] as String? ?? 'Other',
    reps: (json['reps'] as num?)?.toInt() ?? 0,
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class ChallengeData {
  const ChallengeData({
    required this.elapsedDays,
    required this.completedDays,
    required this.streak,
    required this.todayComplete,
    required this.complete,
  });

  final int elapsedDays;
  final int completedDays;
  final int streak;
  final bool todayComplete;
  final bool complete;
}

Future<List<WorkoutEntry>> loadWorkoutEntries() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kWorkoutEntriesStorageKey);
  if (raw == null) return [];
  try {
    final entries = (jsonDecode(raw) as List)
        .map((item) => WorkoutEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  } catch (_) {
    return [];
  }
}

Future<void> saveWorkoutEntries(List<WorkoutEntry> entries) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kWorkoutEntriesStorageKey,
    jsonEncode(entries.map((entry) => entry.toJson()).toList()),
  );
}

String workoutDayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

ChallengeData? calculateChallenge(
  List<WorkoutEntry> entries,
  String? startKey,
) {
  if (startKey == null && entries.isEmpty) return null;
  final resolvedStartKey =
      startKey ??
      entries
          .map((entry) => workoutDayKey(entry.createdAt))
          .reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  final parts = resolvedStartKey.split('-').map(int.parse).toList();
  final startDate = DateTime(parts[0], parts[1], parts[2]);
  final today = dateOnly(DateTime.now());
  final elapsed = today.difference(startDate).inDays + 1;
  final workoutDays = entries
      .map((entry) => workoutDayKey(entry.createdAt))
      .toSet();
  final completedDays = workoutDays.where((key) {
    final dateParts = key.split('-').map(int.parse).toList();
    final date = DateTime(dateParts[0], dateParts[1], dateParts[2]);
    return !date.isBefore(startDate) && !date.isAfter(today);
  }).length;
  var streak = 0;
  var streakDate = today;
  if (!workoutDays.contains(workoutDayKey(streakDate))) {
    streakDate = streakDate.subtract(const Duration(days: 1));
  }
  while (!streakDate.isBefore(startDate) &&
      workoutDays.contains(workoutDayKey(streakDate))) {
    streak++;
    streakDate = streakDate.subtract(const Duration(days: 1));
  }
  return ChallengeData(
    elapsedDays: elapsed.clamp(1, kChallengeLength),
    completedDays: completedDays,
    streak: streak,
    todayComplete: workoutDays.contains(workoutDayKey(today)),
    complete: elapsed >= kChallengeLength,
  );
}

class WorkoutTrackerPage extends StatefulWidget {
  const WorkoutTrackerPage({super.key});

  @override
  State<WorkoutTrackerPage> createState() => _WorkoutTrackerPageState();
}

class _WorkoutTrackerPageState extends State<WorkoutTrackerPage> {
  final _customExerciseController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  List<WorkoutEntry> _entries = [];
  String? _selectedExercise;
  String? _challengeStart;
  String _status = '';
  bool _statusIsError = false;
  int _range = 7;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customExerciseController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadWorkoutEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _challengeStart = prefs.getString(kChallengeStartStorageKey);
    });
  }

  Future<void> _persist() async {
    await saveWorkoutEntries(_entries);
    final prefs = await SharedPreferences.getInstance();
    if (_challengeStart != null) {
      await prefs.setString(kChallengeStartStorageKey, _challengeStart!);
    } else {
      await prefs.remove(kChallengeStartStorageKey);
    }
  }

  Future<void> _addWorkout() async {
    final custom = _customExerciseController.text.trim();
    final exercise = custom.isNotEmpty ? custom : _selectedExercise;
    final reps = int.tryParse(_repsController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (exercise == null || exercise.isEmpty) {
      _showStatus('Choose an exercise or enter a custom workout.', true);
      return;
    }
    if (reps == null || reps <= 0 || weight == null || weight < 0) {
      _showStatus(
        'Enter valid repetitions and a weight of 0 kg or more.',
        true,
      );
      return;
    }
    final now = DateTime.now();
    final entry = WorkoutEntry(
      id: '${now.microsecondsSinceEpoch}',
      exercise: exercise,
      reps: reps,
      weight: weight,
      createdAt: now,
    );
    setState(() {
      _entries.insert(0, entry);
      _selectedExercise = null;
      _customExerciseController.clear();
      _repsController.clear();
      _weightController.clear();
      _challengeStart ??= workoutDayKey(now);
    });
    await _persist();
    _showStatus('Workout saved with the current date and time.', false);
  }

  void _showStatus(String message, bool error) => setState(() {
    _status = message;
    _statusIsError = error;
  });

  List<WorkoutEntry> get _rangeEntries {
    final start = dateOnly(DateTime.now()).subtract(Duration(days: _range - 1));
    return _entries.where((entry) => !entry.createdAt.isBefore(start)).toList();
  }

  Future<void> _deleteEntry(WorkoutEntry entry) async {
    setState(() => _entries.removeWhere((item) => item.id == entry.id));
    await _persist();
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text(
          'Delete all workouts?',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This removes your complete workout history and challenge progress.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _entries.clear();
      _challengeStart = null;
    });
    await _persist();
    _showStatus('All workouts deleted.', false);
  }

  Future<void> _restartChallenge() async {
    setState(() => _challengeStart = workoutDayKey(DateTime.now()));
    await _persist();
  }

  String _num(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _dateTime(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '${months[value.month - 1]} ${value.day} · $hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final rangeEntries = _rangeEntries;
    final challenge = calculateChallenge(_entries, _challengeStart);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 22),
          _challengeCard(challenge),
          const SizedBox(height: 22),
          _logCard(),
          const SizedBox(height: 22),
          _summaryCard(rangeEntries),
          const SizedBox(height: 22),
          _calendarCard(),
          const SizedBox(height: 22),
          _progressCard(),
          const SizedBox(height: 22),
          _trainingLogCard(rangeEntries),
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
          Icons.fitness_center,
          color: AppColors.lime,
          size: 23,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout tracker',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Record the work and build your rhythm.',
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

  Widget _challengeCard(ChallengeData? challenge) {
    final progress = challenge == null
        ? 0.0
        : challenge.elapsedDays / kChallengeLength;
    final message = challenge == null
        ? 'Your first workout starts the 90-day clock. Make today count.'
        : challenge.complete
        ? '90 days complete. You built a lasting routine.'
        : challenge.todayComplete
        ? '${challenge.streak} day${challenge.streak == 1 ? '' : 's'} in a row. Today\'s work is complete.'
        : 'Your ${challenge.streak}-day streak is ready for today\'s workout.';
    return _card([
      Row(
        children: [
          const Expanded(
            child: Text(
              '90-DAY CHALLENGE',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Text(
            challenge == null
                ? 'Ready'
                : 'Day ${challenge.elapsedDays} / $kChallengeLength',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        message,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: AppColors.line,
          valueColor: const AlwaysStoppedAnimation(AppColors.lime),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _challengeStat(
              'Streak',
              '${challenge?.streak ?? 0} days',
              AppColors.peach,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _challengeStat(
              'Workout days',
              '${challenge?.completedDays ?? 0} / $kChallengeLength',
              AppColors.mint,
            ),
          ),
          const SizedBox(width: 8),
          if (challenge?.complete == true)
            IconButton(
              onPressed: _restartChallenge,
              icon: const Icon(Icons.restart_alt_rounded),
              color: AppColors.ink,
              tooltip: 'Start new challenge',
            )
          else
            const Icon(Icons.bolt_rounded, color: AppColors.ink),
        ],
      ),
    ]);
  }

  Widget _challengeStat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _logCard() => _card([
    _sectionTitle('LOG WORKOUT'),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      initialValue: _selectedExercise,
      isExpanded: true,
      decoration: _decoration('Choose an exercise'),
      items: [
        for (final group in exerciseGroups.entries) ...[
          DropdownMenuItem<String>(
            enabled: false,
            value: '__${group.key}',
            child: Text(
              group.key.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...group.value.map(
            (exercise) =>
                DropdownMenuItem(value: exercise, child: Text(exercise)),
          ),
        ],
        const DropdownMenuItem(value: 'Other', child: Text('Other')),
      ],
      onChanged: (value) => setState(() => _selectedExercise = value),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.muted,
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _customExerciseController,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration('Custom workout (optional)'),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: _decoration('Repetitions'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: _decoration('Weight in kg'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _addWorkout,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.lime,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'Add workout',
          style: TextStyle(fontWeight: FontWeight.w800),
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

  Widget _summaryCard(List<WorkoutEntry> entries) {
    final reps = entries.fold<int>(0, (sum, entry) => sum + entry.reps);
    final volume = entries.fold<double>(0, (sum, entry) => sum + entry.volume);
    return _card([
      Row(
        children: [
          Expanded(child: _sectionTitle('TRAINING SUMMARY')),
          _rangeSelector(),
        ],
      ),
      const SizedBox(height: 14),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        childAspectRatio: 1.35,
        children: [
          _summaryTile('Sessions', '${entries.length}', AppColors.lime),
          _summaryTile('Total reps', '$reps', AppColors.mint),
          _summaryTile('Total volume', '${_num(volume)} kg', AppColors.peach),
        ],
      ),
    ]);
  }

  Widget _rangeSelector() => PopupMenuButton<int>(
    initialValue: _range,
    onSelected: (value) => setState(() => _range = value),
    color: AppColors.paper,
    itemBuilder: (context) => [7, 15, 30]
        .map((value) => PopupMenuItem(value: value, child: Text('$value days')))
        .toList(),
    child: Row(
      children: [
        Text(
          '$_range days',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 17,
          color: AppColors.muted,
        ),
      ],
    ),
  );

  Widget _summaryTile(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _calendarCard() {
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final days = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final leading = first.weekday % 7;
    final workoutDays = _entries
        .map((entry) => workoutDayKey(entry.createdAt))
        .toSet();
    return _card([
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('WORKOUT CALENDAR'),
                const SizedBox(height: 4),
                Text(
                  '${_monthName(_calendarMonth.month)} ${_calendarMonth.year}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(
              () => _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month - 1,
              ),
            ),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            onPressed: () => setState(
              () => _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month + 1,
              ),
            ),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          for (final day in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
            Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        children: [
          for (var i = 0; i < leading; i++) const SizedBox.shrink(),
          for (var day = 1; day <= days; day++)
            _calendarDay(
              DateTime(_calendarMonth.year, _calendarMonth.month, day),
              workoutDays.contains(
                workoutDayKey(
                  DateTime(_calendarMonth.year, _calendarMonth.month, day),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Row(
        children: [
          Icon(Icons.fitness_center_rounded, color: AppColors.muted, size: 15),
          SizedBox(width: 6),
          Text(
            'Workout completed',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ]);
  }

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  Widget _calendarDay(DateTime date, bool complete) {
    final today = _isToday(date);
    return Container(
      decoration: BoxDecoration(
        color: complete ? AppColors.lime : AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: today ? Border.all(color: AppColors.ink) : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 11,
              child: complete
                  ? const Icon(
                      Icons.fitness_center_rounded,
                      size: 10,
                      color: AppColors.ink,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _progressCard() {
    final today = dateOnly(DateTime.now());
    final dates = List.generate(
      _range,
      (index) => today.subtract(Duration(days: _range - 1 - index)),
    );
    final values = dates
        .map(
          (date) => _entries
              .where(
                (entry) =>
                    workoutDayKey(entry.createdAt) == workoutDayKey(date),
              )
              .fold<double>(0, (sum, entry) => sum + entry.volume),
        )
        .toList();
    final maxValue = values.fold<double>(0, (a, b) => b > a ? b : a);
    return _card([
      Row(
        children: [
          Expanded(child: _sectionTitle('VOLUME PROGRESSION')),
          Text(
            'kg',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 15),
      SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < values.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[index] > 0)
                        Text(
                          _num(values[index]),
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 7,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        height: maxValue == 0
                            ? 4
                            : 4 + 72 * values[index] / maxValue,
                        decoration: BoxDecoration(
                          color: index == values.length - 1
                              ? AppColors.ink
                              : AppColors.lime,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (index == 0 ||
                          index == values.length - 1 ||
                          index == values.length ~/ 2)
                        Text(
                          '${dates[index].day}',
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

  Widget _trainingLogCard(List<WorkoutEntry> entries) => _card([
    Row(
      children: [
        Expanded(child: _sectionTitle('TRAINING LOG')),
        IconButton(
          onPressed: entries.isEmpty ? null : _deleteAll,
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.danger,
          tooltip: 'Delete all workouts',
        ),
      ],
    ),
    if (entries.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No workouts in this period.\nAdd your first workout above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
        ),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 22, color: AppColors.divider),
        itemBuilder: (context, index) => _entryRow(entries[index], index),
      ),
  ]);

  Widget _entryRow(WorkoutEntry entry, int index) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.tiles[index % AppColors.tiles.length],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.fitness_center, color: AppColors.ink, size: 17),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.exercise,
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
              '${entry.reps} reps · ${_num(entry.weight)} kg · ${_dateTime(entry.createdAt)}',
              style: const TextStyle(color: AppColors.soft, fontSize: 10.5),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${_num(entry.volume)} kg',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'volume',
            style: TextStyle(color: AppColors.soft, fontSize: 10),
          ),
        ],
      ),
      IconButton(
        onPressed: () => _deleteEntry(entry),
        icon: const Icon(Icons.close_rounded, size: 18),
        color: AppColors.danger,
        splashRadius: 18,
        tooltip: 'Delete workout',
      ),
    ],
  );
}
