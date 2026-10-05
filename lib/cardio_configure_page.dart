import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const _cardioPlanKey = 'elateFitCardioCurrentPlan';
const _cardioSavedPlansKey = 'elateFitCardioSavedPlans';
const _cardioDaysKey = 'elateFitCardioCompletedDays';

class CardioBlock {
  CardioBlock({
    required this.id,
    required this.name,
    required this.rounds,
    required this.reps,
    required this.secondsPerRep,
    required this.restSeconds,
    required this.transitionRest,
    required this.notes,
  });

  final String id;
  String name;
  int rounds;
  int reps;
  double secondsPerRep;
  int restSeconds;
  int transitionRest;
  String notes;

  int get workSeconds => (reps * secondsPerRep).ceil();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rounds': rounds,
    'reps': reps,
    'secondsPerRep': secondsPerRep,
    'restSeconds': restSeconds,
    'transitionRest': transitionRest,
    'notes': notes,
  };

  factory CardioBlock.fromJson(Map<String, dynamic> json) => CardioBlock(
    id:
        json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? 'Cardio block',
    rounds: (json['rounds'] as num?)?.toInt() ?? 1,
    reps: (json['reps'] as num?)?.toInt() ?? 1,
    secondsPerRep: (json['secondsPerRep'] as num?)?.toDouble() ?? 1,
    restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 0,
    transitionRest: (json['transitionRest'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String? ?? '',
  );
}

class SavedCardioPlan {
  SavedCardioPlan({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<CardioBlock> items;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedCardioPlan.fromJson(Map<String, dynamic> json) =>
      SavedCardioPlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Cardio plan',
        items: (json['items'] as List? ?? [])
            .map((item) => CardioBlock.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class CardioConfigurePage extends StatefulWidget {
  const CardioConfigurePage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CardioConfigurePage> createState() => _CardioConfigurePageState();
}

class _CardioConfigurePageState extends State<CardioConfigurePage> {
  final _nameController = TextEditingController();
  final _roundsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '15');
  final _secondsController = TextEditingController(text: '3');
  final _restController = TextEditingController(text: '10');
  final _notesController = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  List<CardioBlock> _plan = [];
  List<SavedCardioPlan> _savedPlans = [];
  Set<String> _completedDays = {};
  String? _editingId;
  String _status = '';
  bool _statusError = false;

  int _sessionId = 0;
  bool _isPaused = false;
  _CardioTimerState? _timerState;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

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
    try {
      _tts.stop();
    } catch (_) {}
    for (final controller in [
      _nameController,
      _roundsController,
      _repsController,
      _secondsController,
      _restController,
      _notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isValid(int currentSession) =>
      mounted && _timerState != null && _sessionId == currentSession;

  /// Speaks longer phrases and awaits natural completion before proceeding
  Future<void> _speakPhrase(String text) async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts
          .speak(text)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
    } catch (_) {}
  }

  /// Instantly fires digits to keep countdown cadence strict
  void _speakDigit(dynamic number) {
    try {
      _tts.speak('$number');
    } catch (_) {}
  }

  Future<void> _waitDelay(Duration duration, int currentSession) async {
    int elapsedMs = 0;
    final targetMs = duration.inMilliseconds;
    while (elapsedMs < targetMs) {
      if (!_isValid(currentSession)) return;
      while (_isPaused) {
        if (!_isValid(currentSession)) return;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      final step = (targetMs - elapsedMs) > 100 ? 100 : (targetMs - elapsedMs);
      await Future.delayed(Duration(milliseconds: step));
      if (!_isPaused) {
        elapsedMs += step;
      }
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final current = prefs.getString(_cardioPlanKey);
      final saved = prefs.getString(_cardioSavedPlansKey);
      setState(() {
        _plan = current == null
            ? []
            : (jsonDecode(current) as List)
                  .map(
                    (item) =>
                        CardioBlock.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
        _savedPlans = saved == null
            ? []
            : (jsonDecode(saved) as List)
                  .map(
                    (item) =>
                        SavedCardioPlan.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
        _completedDays = prefs.getStringList(_cardioDaysKey)?.toSet() ?? {};
      });
    } catch (_) {
      _showStatus('Cardio storage could not be read.', true);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardioPlanKey,
      jsonEncode(_plan.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _cardioSavedPlansKey,
      jsonEncode(_savedPlans.map((item) => item.toJson()).toList()),
    );
    await prefs.setStringList(_cardioDaysKey, _completedDays.toList());
  }

  void _showStatus(String message, bool error) => setState(() {
    _status = message;
    _statusError = error;
  });

  int _intValue(TextEditingController controller, {int minimum = 0}) =>
      (int.tryParse(controller.text) ?? minimum).clamp(minimum, 9999).toInt();

  double _doubleValue(TextEditingController controller) =>
      (double.tryParse(controller.text) ?? 0.1).clamp(0.1, 9999).toDouble();

  Future<void> _saveBlock() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showStatus('Add a cardio name.', true);
      return;
    }
    final block = CardioBlock(
      id: _editingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      rounds: _intValue(_roundsController, minimum: 1),
      reps: _intValue(_repsController, minimum: 1),
      secondsPerRep: _doubleValue(_secondsController),
      restSeconds: _intValue(_restController),
      transitionRest: _editingId == null
          ? 0
          : _plan.firstWhere((item) => item.id == _editingId).transitionRest,
      notes: _notesController.text.trim(),
    );
    setState(() {
      final index = _plan.indexWhere((item) => item.id == block.id);
      if (index == -1) {
        _plan.add(block);
      } else {
        _plan[index] = block;
      }
    });
    await _persist();
    _resetForm();
    _showStatus('Cardio saved.', false);
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _roundsController.text = '3';
      _repsController.text = '15';
      _secondsController.text = '3';
      _restController.text = '10';
      _notesController.clear();
    });
  }

  void _editBlock(CardioBlock block) {
    setState(() {
      _editingId = block.id;
      _nameController.text = block.name;
      _roundsController.text = '${block.rounds}';
      _repsController.text = '${block.reps}';
      _secondsController.text = '${block.secondsPerRep}';
      _restController.text = '${block.restSeconds}';
      _notesController.text = block.notes;
    });
  }

  Future<void> _deleteBlock(CardioBlock block) async {
    setState(() => _plan.removeWhere((item) => item.id == block.id));
    await _persist();
    _showStatus('Cardio removed.', false);
  }

  Future<void> _moveBlock(int index, int direction) async {
    final next = index + direction;
    if (next < 0 || next >= _plan.length) return;
    setState(() {
      final item = _plan.removeAt(index);
      _plan.insert(next, item);
    });
    await _persist();
  }

  Future<void> _savePlan() async {
    if (_plan.isEmpty) {
      _showStatus('Add cardio before saving a session.', true);
      return;
    }
    final controller = TextEditingController(
      text: 'Cardio plan ${_savedPlans.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Plan name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(
      () => _savedPlans.add(
        SavedCardioPlan(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          items: _plan
              .map((item) => CardioBlock.fromJson(item.toJson()))
              .toList(),
          createdAt: DateTime.now(),
        ),
      ),
    );
    await _persist();
    _showStatus('Session saved.', false);
  }

  Future<void> _loadPlan(SavedCardioPlan saved) async {
    setState(
      () => _plan = saved.items
          .map((item) => CardioBlock.fromJson(item.toJson()))
          .toList(),
    );
    await _persist();
    _showStatus('Loaded ${saved.name}.', false);
  }

  Future<void> _deleteSavedPlan(SavedCardioPlan saved) async {
    setState(() => _savedPlans.removeWhere((item) => item.id == saved.id));
    await _persist();
  }

  void _startSession() {
    if (_plan.isEmpty || _timerState != null) {
      if (_plan.isEmpty) _showStatus('Add at least one cardio first.', true);
      return;
    }
    _runSession();
  }

  Future<void> _runSession() async {
    final currentSession = ++_sessionId;
    _isPaused = false;

    final firstItem = _plan.first;
    final state = _CardioTimerState(
      itemIndex: 0,
      round: 1,
      phase: _CardioPhase.prepare,
      remaining: 5,
      total: 5,
      reps: firstItem.reps,
      secondsPerRep: firstItem.secondsPerRep,
      currentRep: firstItem.reps,
    );
    setState(() => _timerState = state);

    // -------------------------------------------------------------------------
    // STEP 1: Start with "Start", then 5 - 1sec gap - 4 - 1sec gap - 3 - 2 - 1
    // -------------------------------------------------------------------------
    await _speakPhrase('Start');
    if (!_isValid(currentSession)) return;

    await _waitDelay(const Duration(milliseconds: 250), currentSession);
    if (!_isValid(currentSession)) return;

    for (int i = 5; i >= 1; i--) {
      if (!_isValid(currentSession)) return;
      setState(() {
        state.remaining = i;
        state.total = 5;
      });
      _speakDigit(i);
      await _waitDelay(const Duration(seconds: 1), currentSession);
      if (!_isValid(currentSession)) return;
    }

    // Run through configured cardio blocks
    for (int bIdx = 0; bIdx < _plan.length; bIdx++) {
      state.itemIndex = bIdx;
      final block = _plan[bIdx];

      for (int round = 1; round <= block.rounds; round++) {
        state.round = round;
        state.phase = _CardioPhase.work;
        state.remaining = block.workSeconds;
        state.total = block.workSeconds;
        state.reps = block.reps;
        state.secondsPerRep = block.secondsPerRep;
        state.currentRep = block.reps;
        setState(() {});

        // ---------------------------------------------------------------------
        // STEP 2: Say the complete cardio name followed by round (e.g. Round 1)
        // ---------------------------------------------------------------------
        await _speakPhrase('${block.name}. Round $round');
        if (!_isValid(currentSession)) return;

        await _waitDelay(const Duration(milliseconds: 300), currentSession);
        if (!_isValid(currentSession)) return;

        // ---------------------------------------------------------------------
        // STEP 3: Count down reps from reps down to 1 with (seconds/rep) gap
        // ---------------------------------------------------------------------
        final repMs = (block.secondsPerRep * 1000).round();
        for (int rep = block.reps; rep >= 1; rep--) {
          if (!_isValid(currentSession)) return;
          setState(() => state.currentRep = rep);
          _speakDigit(rep);

          int repElapsed = 0;
          int lastSecTicked = 0;
          while (repElapsed < repMs) {
            if (!_isValid(currentSession)) return;
            while (_isPaused) {
              if (!_isValid(currentSession)) return;
              await Future.delayed(const Duration(milliseconds: 100));
            }
            final step = (repMs - repElapsed) > 100
                ? 100
                : (repMs - repElapsed);
            await Future.delayed(Duration(milliseconds: step));
            if (!_isPaused) {
              repElapsed += step;
              final secNow = repElapsed ~/ 1000;
              if (secNow > lastSecTicked) {
                lastSecTicked = secNow;
                if (mounted) {
                  setState(() {
                    if (state.remaining > 0) state.remaining--;
                  });
                }
              }
            }
          }
        }

        setState(() => state.remaining = 0);

        // Rest interval between rounds within the current block
        if (round < block.rounds && block.restSeconds > 0) {
          state.phase = _CardioPhase.rest;
          state.remaining = block.restSeconds;
          state.total = block.restSeconds;
          setState(() {});

          await _speakPhrase('Rest');
          if (!_isValid(currentSession)) return;

          for (int sec = block.restSeconds; sec >= 1; sec--) {
            if (!_isValid(currentSession)) return;
            setState(() => state.remaining = sec);
            if (sec <= 5) {
              _speakDigit(sec);
            }
            await _waitDelay(const Duration(seconds: 1), currentSession);
            if (!_isValid(currentSession)) return;
          }
        }
      }

      // Transition rest between different cardio blocks
      if (bIdx + 1 < _plan.length && block.transitionRest > 0) {
        state.nextIndex = bIdx + 1;
        state.phase = _CardioPhase.transition;
        state.remaining = block.transitionRest;
        state.total = block.transitionRest;
        setState(() {});

        await _speakPhrase('Rest before ${_plan[state.nextIndex!].name}');
        if (!_isValid(currentSession)) return;

        for (int sec = block.transitionRest; sec >= 1; sec--) {
          if (!_isValid(currentSession)) return;
          setState(() => state.remaining = sec);
          if (sec <= 5) {
            _speakDigit(sec);
          }
          await _waitDelay(const Duration(seconds: 1), currentSession);
          if (!_isValid(currentSession)) return;
        }
      }
    }

    _finishSession(completed: true);
  }

  Future<void> _finishSession({bool completed = true}) async {
    _sessionId++;
    _isPaused = false;
    try {
      await _tts.stop();
    } catch (_) {}
    if (completed) {
      setState(() => _completedDays.add(_dayKey(DateTime.now())));
      await _persist();
      await _speakPhrase('Session complete. Great work.');
    }
    if (mounted) setState(() => _timerState = null);
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatTime(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 22),
          _formCard(),
          const SizedBox(height: 22),
          _orderCard(),
          if (_timerState != null) ...[
            const SizedBox(height: 22),
            _timerCard(),
          ],
          const SizedBox(height: 22),
          _calendarCard(),
        ],
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      IconButton(
        onPressed: _goBack,
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
          Icons.directions_run_rounded,
          color: AppColors.lime,
          size: 25,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cardio builder',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Build a session and train with purpose.',
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
    labelText: hint,
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

  Widget _formCard() => _card([
    Row(
      children: [
        Expanded(
          child: _sectionTitle(
            _editingId == null ? 'ADD CARDIO' : 'UPDATE CARDIO',
          ),
        ),
        if (_editingId != null)
          TextButton(onPressed: _resetForm, child: const Text('Clear')),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _nameController,
      decoration: _decoration('Cardio name · Jumping jacks'),
    ),
    const SizedBox(height: 11),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _roundsController,
            keyboardType: TextInputType.number,
            decoration: _decoration('Rounds'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            decoration: _decoration('Reps'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 11),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _secondsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration('Seconds / rep'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _restController,
            keyboardType: TextInputType.number,
            decoration: _decoration('Rest seconds'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 11),
    TextField(
      controller: _notesController,
      decoration: _decoration('Notes · Moderate pace'),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _saveBlock,
            icon: Icon(
              _editingId == null ? Icons.add_rounded : Icons.save_rounded,
              size: 18,
            ),
            label: Text(_editingId == null ? 'Add cardio' : 'Update cardio'),
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
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _resetForm,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Clear form',
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
    if (_status.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          _status,
          style: TextStyle(
            color: _statusError ? AppColors.danger : AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
  ]);

  Widget _orderCard() => _card([
    Row(
      children: [
        Expanded(child: _sectionTitle('YOUR CARDIO ORDER')),
        Text(
          '${_plan.length} block${_plan.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    if (_plan.isEmpty)
      const Text(
        'No cardio added. Create your first block above to build the session.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _plan.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 20, color: AppColors.divider),
        itemBuilder: (context, index) => _blockRow(index),
      ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _startSession,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _savePlan,
          icon: const Icon(Icons.bookmark_add_outlined),
          tooltip: 'Save plan',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    ),
    if (_savedPlans.isNotEmpty) ...[
      const SizedBox(height: 20),
      _sectionTitle('SAVED SESSIONS'),
      const SizedBox(height: 8),
      ..._savedPlans.map(_savedRow),
    ],
  ]);

  Widget _blockRow(int index) {
    final item = _plan[index];
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.tiles[index % AppColors.tiles.length],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.rounds} rounds · ${item.reps} reps x ${item.secondsPerRep}s · ${item.workSeconds}s work · ${item.restSeconds}s rest',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              Text(
                item.notes.isEmpty ? 'No notes' : item.notes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.soft, fontSize: 10),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'up') _moveBlock(index, -1);
            if (action == 'down') _moveBlock(index, 1);
            if (action == 'edit') _editBlock(item);
            if (action == 'delete') _deleteBlock(item);
          },
          itemBuilder: (context) => [
            if (index > 0)
              const PopupMenuItem(value: 'up', child: Text('Move up')),
            if (index < _plan.length - 1)
              const PopupMenuItem(value: 'down', child: Text('Move down')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );
  }

  Widget _savedRow(SavedCardioPlan saved) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const Icon(
          Icons.bookmark_outline_rounded,
          color: AppColors.muted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${saved.name} · ${saved.items.length} blocks',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _loadPlan(saved),
          child: const Text('Load'),
        ),
        IconButton(
          onPressed: () => _deleteSavedPlan(saved),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: AppColors.danger,
          tooltip: 'Delete saved plan',
        ),
      ],
    ),
  );

  Widget _timerCard() {
    final state = _timerState!;
    final item = _plan[state.itemIndex];
    final title = state.phase == _CardioPhase.prepare
        ? 'Get ready'
        : state.phase == _CardioPhase.work
        ? item.name
        : state.phase == _CardioPhase.rest
        ? 'Recover'
        : 'Between cardio';

    final phase = state.phase == _CardioPhase.prepare
        ? 'GET READY'
        : state.phase == _CardioPhase.work
        ? 'ROUND ${state.round} OF ${item.rounds}  •  REP ${state.currentRep ?? state.reps} OF ${item.reps}'
        : state.phase == _CardioPhase.rest
        ? 'REST'
        : 'TRANSITION';

    return _card([
      Center(
        child: Text(
          phase,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Container(
          width: 145,
          height: 145,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state.phase == _CardioPhase.work
                ? AppColors.lime
                : state.phase == _CardioPhase.prepare
                ? AppColors.mint
                : AppColors.peach,
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withAlpha(100),
                blurRadius: 24,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              state.phase == _CardioPhase.prepare
                  ? '${state.remaining}'
                  : _formatTime(state.remaining),
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      LinearProgressIndicator(
        value: state.total == 0 ? 0 : 1 - state.remaining / state.total,
        minHeight: 8,
        backgroundColor: AppColors.background,
        color: AppColors.ink,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isPaused = !_isPaused;
                  if (_isPaused) {
                    _tts.stop();
                  }
                });
              },
              icon: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
              label: Text(_isPaused ? 'Resume' : 'Pause'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => _finishSession(completed: false),
            icon: const Icon(Icons.stop_rounded),
            tooltip: 'End session',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ]);
  }

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
                _sectionTitle('CARDIO CALENDAR'),
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
            'Completed cardio',
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
                      Icons.directions_run_rounded,
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

enum _CardioPhase { prepare, work, rest, transition }

class _CardioTimerState {
  _CardioTimerState({
    required this.itemIndex,
    required this.round,
    required this.phase,
    required this.remaining,
    required this.total,
    required this.reps,
    required this.secondsPerRep,
    this.currentRep,
    this.nextIndex,
  });

  int itemIndex;
  int round;
  _CardioPhase phase;
  int remaining;
  int total;
  int reps;
  double secondsPerRep;
  int? currentRep;
  int? nextIndex;
}
