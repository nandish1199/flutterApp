import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

class BreathingTechnique {
  const BreathingTechnique({
    required this.name,
    required this.pattern,
    required this.phases,
  });

  final String name;
  final String pattern;
  final List<BreathingPhase> phases;

  int get cycleSeconds =>
      phases.fold(0, (total, phase) => total + phase.seconds);
}

class BreathingPhase {
  const BreathingPhase(this.name, this.seconds);

  final String name;
  final int seconds;
}

const breathingTechniques = [
  BreathingTechnique(
    name: 'Diaphragmatic breathing',
    pattern: 'Belly expands on inhale',
    phases: [BreathingPhase('Inhale', 4), BreathingPhase('Exhale', 6)],
  ),
  BreathingTechnique(
    name: 'Slow deep breathing',
    pattern: 'About 5-6 breaths per minute',
    phases: [BreathingPhase('Inhale', 5), BreathingPhase('Exhale', 5)],
  ),
  BreathingTechnique(
    name: '4-6 breathing',
    pattern: '4 sec inhale -> 6 sec exhale',
    phases: [BreathingPhase('Inhale', 4), BreathingPhase('Exhale', 6)],
  ),
  BreathingTechnique(
    name: '4-7-8 breathing',
    pattern: '4 sec inhale -> 7 sec hold -> 8 sec exhale',
    phases: [
      BreathingPhase('Inhale', 4),
      BreathingPhase('Hold', 7),
      BreathingPhase('Exhale', 8),
    ],
  ),
  BreathingTechnique(
    name: 'Box breathing',
    pattern: '4 sec inhale -> 4 sec hold -> 4 sec exhale -> 4 sec hold',
    phases: [
      BreathingPhase('Inhale', 4),
      BreathingPhase('Hold', 4),
      BreathingPhase('Exhale', 4),
      BreathingPhase('Hold', 4),
    ],
  ),
  BreathingTechnique(
    name: 'Coherent/resonance breathing',
    pattern: 'About 5-6 breaths per minute',
    phases: [BreathingPhase('Inhale', 5), BreathingPhase('Exhale', 5)],
  ),
  BreathingTechnique(
    name: 'Extended-exhale breathing',
    pattern: 'Exhale longer than inhale',
    phases: [BreathingPhase('Inhale', 4), BreathingPhase('Exhale', 8)],
  ),
  BreathingTechnique(
    name: 'Physiological sigh',
    pattern: 'Double inhale -> long exhale',
    phases: [
      BreathingPhase('Inhale', 2),
      BreathingPhase('Inhale again', 2),
      BreathingPhase('Long exhale', 6),
    ],
  ),
  BreathingTechnique(
    name: 'Pursed-lip breathing',
    pattern: 'Inhale through nose -> slow pursed exhale',
    phases: [
      BreathingPhase('Inhale through nose', 4),
      BreathingPhase('Slow pursed exhale', 6),
    ],
  ),
  BreathingTechnique(
    name: 'Equal breathing',
    pattern: 'Equal inhale/exhale',
    phases: [BreathingPhase('Inhale', 5), BreathingPhase('Exhale', 5)],
  ),
];

enum BreathingVoice { count, voice, chimes }

class BreathingPlanItem {
  BreathingPlanItem({required this.techniqueIndex, this.repetitions = 3});

  int techniqueIndex;
  int repetitions;

  BreathingTechnique get technique => breathingTechniques[techniqueIndex];
}

class BreathingExercisePage extends StatefulWidget {
  const BreathingExercisePage({super.key});

  @override
  State<BreathingExercisePage> createState() => _BreathingExercisePageState();
}

class _BreathingExercisePageState extends State<BreathingExercisePage>
    with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _gapController = TextEditingController(text: '1');
  final List<BreathingPlanItem> _plan = [BreathingPlanItem(techniqueIndex: 0)];

  Timer? _timer;
  AnimationController? _orbController;
  BreathingVoice _voice = BreathingVoice.count;

  int _techniqueIndex = 0;
  int _phaseIndex = 0;
  int _repetition = 1;
  int _remaining = 0;
  int _elapsed = 0;
  int _totalSeconds = 1;
  bool _inGap = false;
  bool _running = false;
  bool _complete = false;
  String _status = 'Audio guidance is available when you start.';

  // Calendar State
  Set<String> _completedDays = {};
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _hasSession => _running || _complete;
  BreathingPlanItem get _currentItem => _plan[_techniqueIndex];
  BreathingPhase get _currentPhase =>
      _currentItem.technique.phases[_phaseIndex];
  int get _gapSeconds =>
      (int.tryParse(_gapController.text) ?? 0).clamp(0, 30).toInt();
  int get _totalBreathingSeconds => _plan.fold(
    0,
    (total, item) => total + item.repetitions * item.technique.cycleSeconds,
  );
  int get _totalPlanSeconds =>
      _totalBreathingSeconds + _gapSeconds * (_plan.length - 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orbController?.dispose();
    _tts.stop();
    _gapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _completedDays =
          prefs.getStringList('elateFitBreatheCompletedDays')?.toSet() ?? {};
    });
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _speak(String text, {bool count = false}) async {
    if (_voice == BreathingVoice.chimes ||
        (count && _voice != BreathingVoice.count)) {
      return;
    }
    try {
      await _tts.speak(text);
    } catch (_) {
      // The visual guide and chimes remain available when speech is unavailable.
    }
  }

  Future<void> _announce(String text) async {
    await _speak(text);
    if (mounted) _playChime();
  }

  void _playChime() => SystemSound.play(SystemSoundType.click);

  void _addTechnique() {
    if (_hasSession || _plan.length >= breathingTechniques.length) return;
    setState(() => _plan.add(BreathingPlanItem(techniqueIndex: _plan.length)));
  }

  void _removeTechnique(int index) {
    if (_hasSession || _plan.length == 1) return;
    setState(() => _plan.removeAt(index));
  }

  void _reset() {
    _timer?.cancel();
    _orbController?.dispose();
    _orbController = null;
    _tts.stop();
    setState(() {
      _running = false;
      _complete = false;
      _inGap = false;
      _techniqueIndex = 0;
      _phaseIndex = 0;
      _repetition = 1;
      _remaining = 0;
      _elapsed = 0;
      _status = 'Audio guidance is available when you start.';
    });
  }

  Future<void> _start() async {
    if (_hasSession) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final firstPhase = _plan.first.technique.phases.first;
    setState(() {
      _running = true;
      _complete = false;
      _techniqueIndex = 0;
      _phaseIndex = 0;
      _repetition = 1;
      _remaining = firstPhase.seconds;
      _elapsed = 0;
      _totalSeconds = _totalPlanSeconds;
      _status = 'Get comfortable and follow the guide.';
    });
    _orbController = AnimationController(
      vsync: this,
      duration: Duration(seconds: firstPhase.seconds),
      lowerBound: 0.82,
      upperBound: 1.16,
    )..repeat(reverse: true);
    await _speak('Start. 3, 2, 1');
    if (!mounted || !_running) return;
    await _announce(_plan.first.technique.name);
    if (mounted && _running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!_running || !mounted) return;
    setState(() {
      _remaining--;
      _elapsed++;
    });
    if (_remaining > 0) {
      if (_voice == BreathingVoice.count &&
          _isCountedPhase(_currentPhase.name)) {
        _speak('$_remaining');
      }
      return;
    }
    if (_inGap) {
      _finishGap();
      return;
    }
    final item = _currentItem;
    if (_phaseIndex + 1 < item.technique.phases.length) {
      _startPhase(_phaseIndex + 1);
    } else if (_repetition < item.repetitions) {
      setState(() {
        _repetition++;
        _phaseIndex = 0;
        _remaining = item.technique.phases.first.seconds;
      });
      _announcePhase(item.technique.phases.first);
    } else if (_techniqueIndex + 1 < _plan.length) {
      _techniqueIndex++;
      _phaseIndex = 0;
      _repetition = 1;
      if (_gapSeconds > 0) {
        setState(() {
          _inGap = true;
          _remaining = _gapSeconds;
          _status = 'Transition pause. Let your breathing settle.';
        });
        _orbController?.stop();
        _speak('Rest');
      } else {
        _announceTechnique();
      }
    } else {
      _finishSession();
    }
  }

  bool _isCountedPhase(String name) {
    final lower = name.toLowerCase();
    return lower.contains('inhale') || lower.contains('exhale');
  }

  void _startPhase(int phaseIndex) {
    final phase = _currentItem.technique.phases[phaseIndex];
    setState(() {
      _phaseIndex = phaseIndex;
      _remaining = phase.seconds;
      _status = 'Stay with the rhythm.';
    });
    _orbController?.dispose();
    _orbController = AnimationController(
      vsync: this,
      duration: Duration(seconds: phase.seconds),
      lowerBound: _scaleForPhase(phase.name) - 0.08,
      upperBound: _scaleForPhase(phase.name) + 0.08,
    )..repeat(reverse: true);
    _announcePhase(phase);
  }

  double _scaleForPhase(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('inhale')) return 1.12;
    if (lower.contains('exhale')) return 0.88;
    return 1.0;
  }

  void _announcePhase(BreathingPhase phase) {
    _playChime();
    final counted =
        _voice == BreathingVoice.count && _isCountedPhase(phase.name);
    _speak(counted ? '${phase.name}, ${phase.seconds}' : phase.name);
  }

  void _announceTechnique() {
    _orbController?.stop();
    _announce(_currentItem.technique.name).then((_) {
      if (!mounted || !_running) return;
      _startPhase(0);
    });
  }

  void _finishGap() {
    setState(() {
      _inGap = false;
      _remaining = _currentItem.technique.phases.first.seconds;
      _status = 'New technique. Follow the next pattern.';
    });
    _announceTechnique();
  }

  void _finishSession() async {
    _timer?.cancel();
    _orbController?.stop();
    _tts.stop();

    // Save completion to SharedPreferences and update calendar state
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = _dayKey(now);
    final completedDaysList =
        prefs.getStringList('elateFitBreatheCompletedDays') ?? [];

    if (!completedDaysList.contains(todayStr)) {
      completedDaysList.add(todayStr);
      await prefs.setStringList(
        'elateFitBreatheCompletedDays',
        completedDaysList,
      );
    }

    setState(() {
      _completedDays.add(todayStr);
      _running = false;
      _complete = true;
      _remaining = 0;
      _elapsed = _totalSeconds;
      _status = 'Session complete. Notice how you feel.';
    });
  }

  String get _sessionLabel {
    if (_complete) return 'COMPLETE';
    if (!_running) return 'READY WHEN YOU ARE';
    if (_inGap) return 'TRANSITION PAUSE';
    return 'TECHNIQUE ${_techniqueIndex + 1} OF ${_plan.length}  |  REP $_repetition OF ${_currentItem.repetitions}';
  }

  String get _title {
    if (_complete) return 'Well done';
    if (!_running) return 'Choose your techniques';
    if (_inGap) return 'Prepare for the next technique';
    return _currentItem.technique.name;
  }

  String get _phaseLabel {
    if (_complete) return 'Take a moment before returning to your day.';
    if (!_running) return 'Your guided session will appear here.';
    if (_inGap) return 'Rest and let your breathing settle.';
    return '${_currentPhase.name} - ${_currentItem.technique.pattern}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 22),
          _setupCard(),
          const SizedBox(height: 22),
          _practiceCard(),
          const SizedBox(height: 22),
          _calendarCard(),
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
        child: const Icon(Icons.air_rounded, color: AppColors.lime, size: 25),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breathing practice',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Slow down with a guided rhythm.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
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

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.line),
    ),
  );

  Widget _setupCard() => _card([
    Row(
      children: [
        Expanded(child: _sectionTitle('SESSION PLAN')),
        Text(
          '${_plan.length} technique${_plan.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    ...[for (var i = 0; i < _plan.length; i++) _planRow(i)],
    const SizedBox(height: 8),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _hasSession ? null : _addTechnique,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add technique'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _gapController,
            enabled: !_hasSession,
            keyboardType: TextInputType.number,
            decoration: _decoration('Gap minutes'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<BreathingVoice>(
            initialValue: _voice,
            decoration: _decoration('Audio guidance'),
            items: const [
              DropdownMenuItem(
                value: BreathingVoice.count,
                child: Text('Voice + count'),
              ),
              DropdownMenuItem(
                value: BreathingVoice.voice,
                child: Text('Voice + chimes'),
              ),
              DropdownMenuItem(
                value: BreathingVoice.chimes,
                child: Text('Chimes only'),
              ),
            ],
            onChanged: _hasSession
                ? null
                : (value) =>
                      setState(() => _voice = value ?? BreathingVoice.count),
          ),
        ),
      ],
    ),
    const SizedBox(height: 11),
    Text(
      '${_plan.map((item) => '${item.technique.name} (${item.repetitions} rep${item.repetitions == 1 ? '' : 's'})').join(' -> ')} | About ${(_totalPlanSeconds / 60).ceil()} minute${(_totalPlanSeconds / 60).ceil() == 1 ? '' : 's'}',
      style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _hasSession ? null : _start,
            icon: const Icon(Icons.play_arrow_rounded, size: 19),
            label: const Text('Start session'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.lime,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        IconButton.filledTonal(
          onPressed: _reset,
          icon: const Icon(Icons.stop_rounded),
          tooltip: 'Reset / end session',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.peach,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    ),
  ]);

  Widget _planRow(int index) {
    final item = _plan[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: item.techniqueIndex,
              isExpanded: true,
              decoration: _decoration('Technique'),
              items: [
                for (var i = 0; i < breathingTechniques.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      breathingTechniques[i].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _hasSession
                  ? null
                  : (value) => setState(() => item.techniqueIndex = value ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 83,
            child: TextFormField(
              initialValue: '${item.repetitions}',
              enabled: !_hasSession,
              keyboardType: TextInputType.number,
              decoration: _decoration('Reps'),
              onChanged: (value) => setState(
                () => item.repetitions = (int.tryParse(value) ?? 1)
                    .clamp(1, 70)
                    .toInt(),
              ),
            ),
          ),
          if (_plan.length > 1)
            IconButton(
              onPressed: _hasSession ? null : () => _removeTechnique(index),
              icon: const Icon(Icons.close_rounded),
              color: AppColors.danger,
              tooltip: 'Remove technique',
            ),
        ],
      ),
    );
  }

  Widget _practiceCard() => _card([
    Center(
      child: Text(
        _sessionLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    ),
    const SizedBox(height: 10),
    Center(
      child: Text(
        _title.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    const SizedBox(height: 5),
    Center(
      child: Text(
        _phaseLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    ),
    const SizedBox(height: 24),
    Center(
      child: AnimatedBuilder(
        animation: _orbController ?? const AlwaysStoppedAnimation(1.0),
        builder: (context, child) =>
            Transform.scale(scale: _orbController?.value ?? 1, child: child),
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _complete ? AppColors.mint : AppColors.lime,
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withAlpha(110),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _complete
                  ? 'Done'
                  : _running
                  ? '$_remaining'
                  : '--',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: 22),
    ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: _totalSeconds == 0 ? 0 : _elapsed / _totalSeconds,
        minHeight: 8,
        backgroundColor: AppColors.background,
        color: AppColors.ink,
      ),
    ),
    const SizedBox(height: 14),
    Center(
      child: Text(
        _status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    ),
  ]);

  Widget _calendarCard() {
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final days = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final leading = first.weekday % 7;
    return _card([
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('BREATHING CALENDAR'),
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
          for (var day = 1; day <= days; day++) _calendarDay(day),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Completed session',
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

  Widget _calendarDay(int day) {
    final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
    final complete = _completedDays.contains(_dayKey(date));
    final today = _dayKey(date) == _dayKey(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: complete
            ? AppColors.lime
            : today
            ? AppColors.mint
            : AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: today ? Border.all(color: AppColors.ink) : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
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
                      Icons.air_rounded,
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
}
