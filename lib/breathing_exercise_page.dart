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

  AnimationController? _orbController;
  BreathingVoice _voice = BreathingVoice.count;

  int _sessionId = 0;
  int _techniqueIndex = 0;
  int _phaseIndex = 0;
  int _repetition = 1;
  int _remaining = 0;
  int _elapsed = 0;
  int _totalSeconds = 1;
  bool _inGap = false;
  bool _running = false;
  bool _complete = false;
  bool _isInitialCountdown = false;
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
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sessionId++;
    _orbController?.dispose();
    try {
      _tts.stop();
    } catch (_) {}
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

  bool _isValid(int currentSession) =>
      mounted && _running && _sessionId == currentSession;

  /// Speaks longer words/phrases and waits for them to finish with a safe timeout
  Future<void> _speakPhrase(String text) async {
    if (_voice == BreathingVoice.chimes) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts
          .speak(text)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
    } catch (_) {}
  }

  /// Instantly fires a countdown digit without waiting, ensuring exact 1-second cadence
  void _speakDigit(int number) {
    if (_voice != BreathingVoice.count) return;
    try {
      _tts.speak('$number');
    } catch (_) {}
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
    _sessionId++;
    _orbController?.dispose();
    _orbController = null;
    try {
      _tts.stop();
    } catch (_) {}
    setState(() {
      _running = false;
      _complete = false;
      _inGap = false;
      _isInitialCountdown = false;
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

    final currentSession = ++_sessionId;

    setState(() {
      _running = true;
      _complete = false;
      _isInitialCountdown = true;
      _techniqueIndex = 0;
      _phaseIndex = 0;
      _repetition = 1;
      _remaining = 5;
      _elapsed = 0;
      _totalSeconds = _totalPlanSeconds;
      _status = 'Get comfortable and follow the guide.';
    });

    // 1. Say "Start"
    if (_voice != BreathingVoice.chimes) {
      await _speakPhrase('Start');
    }
    if (!_isValid(currentSession)) return;

    // 2. Exact 200ms gap after "Start" finishes
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_isValid(currentSession)) return;

    // 3. Initial countdown 5 -> 1 with exactly 1 second per count
    for (int i = 5; i >= 1; i--) {
      setState(() => _remaining = i);
      _speakDigit(i);
      await Future.delayed(const Duration(seconds: 1));
      if (!_isValid(currentSession)) return;
    }

    setState(() => _isInitialCountdown = false);

    // 4. Run session plan
    for (int tIdx = 0; tIdx < _plan.length; tIdx++) {
      setState(() {
        _techniqueIndex = tIdx;
        _status = 'Follow the breathing pattern.';
      });

      final item = _plan[tIdx];

      // Announce technique name completely
      _playChime();
      if (_voice != BreathingVoice.chimes) {
        await _speakPhrase(item.technique.name);
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (!_isValid(currentSession)) return;

      // Loop through repetitions
      for (int rep = 1; rep <= item.repetitions; rep++) {
        setState(() => _repetition = rep);

        // Loop through phases (e.g. Inhale, Exhale)
        for (int pIdx = 0; pIdx < item.technique.phases.length; pIdx++) {
          setState(() {
            _phaseIndex = pIdx;
            _remaining = item.technique.phases[pIdx].seconds;
            _status = 'Stay with the rhythm.';
          });

          final phase = item.technique.phases[pIdx];

          _playChime();
          _startOrb(phase);

          // Say "Inhale" or "Exhale" completely before counting down
          if (_voice != BreathingVoice.chimes) {
            await _speakPhrase(phase.name);
            await Future.delayed(const Duration(milliseconds: 200));
          }
          if (!_isValid(currentSession)) return;

          // Countdown sequence: starts immediately at the phase duration (e.g. 5, 4, 3, 2, 1)
          final bool isCounted =
              _voice == BreathingVoice.count && _isCountedPhase(phase.name);

          for (int sec = phase.seconds; sec >= 1; sec--) {
            setState(() {
              _remaining = sec;
              _elapsed++;
            });

            if (isCounted) {
              _speakDigit(sec);
            }

            await Future.delayed(const Duration(seconds: 1));
            if (!_isValid(currentSession)) return;
          }
        }
      }

      // Inter-technique transition gap
      if (tIdx + 1 < _plan.length && _gapSeconds > 0) {
        setState(() {
          _inGap = true;
          _status = 'Transition pause. Let your breathing settle.';
        });
        _orbController?.stop();
        if (_voice != BreathingVoice.chimes) {
          await _speakPhrase('Rest');
        }

        for (int g = _gapSeconds; g >= 1; g--) {
          setState(() => _remaining = g);
          await Future.delayed(const Duration(seconds: 1));
          if (!_isValid(currentSession)) return;
        }

        setState(() => _inGap = false);
      }
    }

    _finishSession();
  }

  bool _isCountedPhase(String name) {
    final lower = name.toLowerCase();
    return lower.contains('inhale') || lower.contains('exhale');
  }

  void _startOrb(BreathingPhase phase) {
    _orbController?.dispose();
    _orbController = AnimationController(
      vsync: this,
      duration: Duration(seconds: phase.seconds),
      lowerBound: _scaleForPhase(phase.name) - 0.08,
      upperBound: _scaleForPhase(phase.name) + 0.08,
    )..repeat(reverse: true);
  }

  double _scaleForPhase(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('inhale')) return 1.12;
    if (lower.contains('exhale')) return 0.88;
    return 1.0;
  }

  void _finishSession() async {
    _sessionId++;
    _orbController?.stop();
    try {
      _tts.stop();
    } catch (_) {}

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
      _isInitialCountdown = false;
      _inGap = false;
      _remaining = 0;
      _elapsed = _totalSeconds;
      _status = 'Session complete. Notice how you feel.';
    });
  }

  String get _sessionLabel {
    if (_complete) return 'COMPLETE';
    if (!_running) return 'READY WHEN YOU ARE';
    if (_isInitialCountdown) return 'STARTING SESSION';
    if (_inGap) return 'TRANSITION PAUSE';
    return 'TECHNIQUE ${_techniqueIndex + 1} OF ${_plan.length}  |  REP $_repetition OF ${_currentItem.repetitions}';
  }

  String get _title {
    if (_complete) return 'Well done';
    if (!_running) return 'Choose your techniques';
    if (_isInitialCountdown) return 'Get Ready';
    if (_inGap) return 'Prepare for the next technique';
    return _currentItem.technique.name;
  }

  String get _phaseLabel {
    if (_complete) return 'Take a moment before returning to your day.';
    if (!_running) return 'Your guided session will appear here.';
    if (_isInitialCountdown) return 'Session begins in a moment.';
    if (_inGap) return 'Rest and let your breathing settle.';
    return '${_currentPhase.name} - ${_currentItem.technique.pattern}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
        value: _totalSeconds == 0
            ? 0
            : (_elapsed / _totalSeconds).clamp(0.0, 1.0),
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
