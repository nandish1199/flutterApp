import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const _stretchPlanKey = 'elateFitStretchCurrentPlan';
const _stretchSavedPlansKey = 'elateFitStretchSavedPlans';
const _stretchDaysKey = 'elateFitStretchCompletedDays';

class StretchBlock {
  StretchBlock({
    required this.id,
    required this.name,
    required this.sets,
    required this.duration,
    required this.restSeconds,
    required this.transitionRest,
    required this.notes,
  });

  final String id;
  String name;
  int sets;
  int duration;
  int restSeconds;
  int transitionRest;
  String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sets': sets,
    'duration': duration,
    'restSeconds': restSeconds,
    'transitionRest': transitionRest,
    'notes': notes,
  };

  factory StretchBlock.fromJson(Map<String, dynamic> json) => StretchBlock(
    id:
        json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? 'Stretch block',
    sets: (json['sets'] as num?)?.toInt() ?? 2,
    duration: (json['duration'] as num?)?.toInt() ?? 30,
    restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 10,
    transitionRest: (json['transitionRest'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String? ?? '',
  );
}

class SavedStretchPlan {
  SavedStretchPlan({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<StretchBlock> items;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedStretchPlan.fromJson(Map<String, dynamic> json) =>
      SavedStretchPlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Stretching routine',
        items: (json['items'] as List? ?? [])
            .map((item) => StretchBlock.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class StretchingConfigurePage extends StatefulWidget {
  const StretchingConfigurePage({super.key});

  @override
  State<StretchingConfigurePage> createState() =>
      _StretchingConfigurePageState();
}

class _StretchingConfigurePageState extends State<StretchingConfigurePage> {
  final _nameController = TextEditingController();
  final _setsController = TextEditingController(text: '2');
  final _durationController = TextEditingController(text: '30');
  final _restController = TextEditingController(text: '10');
  final _notesController = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  List<StretchBlock> _plan = [];
  List<SavedStretchPlan> _savedPlans = [];
  Set<String> _completedDays = {};
  String? _editingId;
  String _status = '';
  bool _statusError = false;
  Timer? _timer;
  _StretchTimerState? _timerState;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    for (final controller in [
      _nameController,
      _setsController,
      _durationController,
      _restController,
      _notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final current = prefs.getString(_stretchPlanKey);
      final saved = prefs.getString(_stretchSavedPlansKey);
      setState(() {
        _plan = current == null
            ? []
            : (jsonDecode(current) as List)
                  .map(
                    (item) =>
                        StretchBlock.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
        _savedPlans = saved == null
            ? []
            : (jsonDecode(saved) as List)
                  .map(
                    (item) =>
                        SavedStretchPlan.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
        _completedDays = prefs.getStringList(_stretchDaysKey)?.toSet() ?? {};
      });
    } catch (_) {
      _showStatus('Stretch storage could not be read.', true);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stretchPlanKey,
      jsonEncode(_plan.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _stretchSavedPlansKey,
      jsonEncode(_savedPlans.map((item) => item.toJson()).toList()),
    );
    await prefs.setStringList(_stretchDaysKey, _completedDays.toList());
  }

  void _showStatus(String message, bool error) => setState(() {
    _status = message;
    _statusError = error;
  });

  int _intValue(TextEditingController controller, {int minimum = 0}) =>
      (int.tryParse(controller.text) ?? minimum).clamp(minimum, 9999).toInt();

  Future<void> _saveBlock() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showStatus('Add a stretch name.', true);
      return;
    }
    final block = StretchBlock(
      id: _editingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      sets: _intValue(_setsController, minimum: 1),
      duration: _intValue(_durationController, minimum: 5),
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
    _showStatus('Stretch saved.', false);
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _setsController.text = '2';
      _durationController.text = '30';
      _restController.text = '10';
      _notesController.clear();
    });
  }

  void _editBlock(StretchBlock block) {
    setState(() {
      _editingId = block.id;
      _nameController.text = block.name;
      _setsController.text = '${block.sets}';
      _durationController.text = '${block.duration}';
      _restController.text = '${block.restSeconds}';
      _notesController.text = block.notes;
    });
  }

  Future<void> _deleteBlock(StretchBlock block) async {
    setState(() => _plan.removeWhere((item) => item.id == block.id));
    await _persist();
    _showStatus('Stretch removed.', false);
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
      _showStatus('Add stretches before saving a routine.', true);
      return;
    }
    final controller = TextEditingController(
      text: 'Stretching plan ${_savedPlans.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save routine'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Routine name'),
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
        SavedStretchPlan(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          items: _plan
              .map((item) => StretchBlock.fromJson(item.toJson()))
              .toList(),
          createdAt: DateTime.now(),
        ),
      ),
    );
    await _persist();
    _showStatus('Routine saved.', false);
  }

  Future<void> _loadPlan(SavedStretchPlan saved) async {
    setState(
      () => _plan = saved.items
          .map((item) => StretchBlock.fromJson(item.toJson()))
          .toList(),
    );
    await _persist();
    _showStatus('Loaded ${saved.name}.', false);
  }

  Future<void> _deleteSavedPlan(SavedStretchPlan saved) async {
    setState(() => _savedPlans.removeWhere((item) => item.id == saved.id));
    await _persist();
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  void _startSession() {
    if (_plan.isEmpty || _timerState != null) {
      if (_plan.isEmpty) _showStatus('Add at least one stretch first.', true);
      return;
    }
    final state = _StretchTimerState(
      itemIndex: 0,
      setNumber: 1,
      phase: _StretchPhase.work,
      remaining: _plan.first.duration,
      total: _plan.first.duration,
    );
    setState(() => _timerState = state);
    _speak('Get ready. ${_plan.first.name}, Set 1.');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final state = _timerState;
    if (state == null || !mounted) return;
    setState(() => state.remaining--);
    final item = _plan[state.itemIndex];

    if (state.phase == _StretchPhase.rest ||
        state.phase == _StretchPhase.transition) {
      if (state.remaining > 0 && state.remaining <= 5)
        _speak('${state.remaining}');
    } else if (state.phase == _StretchPhase.work) {
      if (state.remaining == item.duration ~/ 2) _speak('Halfway there.');
      if (state.remaining > 0 && state.remaining <= 3)
        _speak('${state.remaining}');
    }

    if (state.remaining > 0) return;

    if (state.phase == _StretchPhase.work) {
      if (state.setNumber < item.sets && item.restSeconds > 0) {
        _setTimerPhase(_StretchPhase.rest, item.restSeconds, item.restSeconds);
        _speak('Rest');
      } else if (state.setNumber < item.sets) {
        state.setNumber++;
        _startWork(state, item);
        _speak('${item.name}. Set ${state.setNumber}');
      } else if (state.itemIndex + 1 < _plan.length &&
          item.transitionRest > 0) {
        state.nextIndex = state.itemIndex + 1;
        _setTimerPhase(
          _StretchPhase.transition,
          item.transitionRest,
          item.transitionRest,
        );
        _speak('Rest before ${_plan[state.nextIndex!].name}');
      } else if (state.itemIndex + 1 < _plan.length) {
        _nextBlock(state);
      } else {
        _finishSession();
      }
    } else if (state.phase == _StretchPhase.transition) {
      _nextBlock(state);
    } else {
      state.setNumber++;
      _startWork(state, item);
      _speak('${item.name}. Set ${state.setNumber}');
    }
  }

  void _startWork(_StretchTimerState state, StretchBlock item) {
    state.phase = _StretchPhase.work;
    state.remaining = item.duration;
    state.total = item.duration;
  }

  void _setTimerPhase(_StretchPhase phase, int remaining, int total) {
    setState(() {
      _timerState!.phase = phase;
      _timerState!.remaining = remaining;
      _timerState!.total = total;
    });
  }

  void _nextBlock(_StretchTimerState state) {
    state.itemIndex = state.nextIndex ?? state.itemIndex + 1;
    state.nextIndex = null;
    state.setNumber = 1;
    final next = _plan[state.itemIndex];
    _startWork(state, next);
    _speak('Change. ${next.name}');
  }

  Future<void> _finishSession({bool completed = true}) async {
    _timer?.cancel();
    _timer = null;
    await _tts.stop();
    if (completed) {
      setState(() => _completedDays.add(_dayKey(DateTime.now())));
      await _persist();
      await _speak('Session complete. Great work.');
    }
    if (mounted) setState(() => _timerState = null);
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _formatTime(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(context),
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

  Widget _header(BuildContext context) => Row(
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
          Icons.accessibility_new_rounded,
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
              'Stretching builder',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Build a flexibility routine and recover.',
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
            _editingId == null ? 'ADD STRETCH' : 'UPDATE STRETCH',
          ),
        ),
        if (_editingId != null)
          TextButton(onPressed: _resetForm, child: const Text('Clear')),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _nameController,
      decoration: _decoration('Stretch name · Hamstring stretch'),
    ),
    const SizedBox(height: 11),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _setsController,
            keyboardType: TextInputType.number,
            decoration: _decoration('Sets (Sides)'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: _decoration('Hold (sec)'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 11),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _restController,
            keyboardType: TextInputType.number,
            decoration: _decoration('Rest (sec)'),
          ),
        ),
        const Spacer(),
      ],
    ),
    const SizedBox(height: 11),
    TextField(
      controller: _notesController,
      decoration: _decoration('Notes · Breathe deeply'),
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
            label: Text(_editingId == null ? 'Add stretch' : 'Update stretch'),
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
        Expanded(child: _sectionTitle('YOUR ROUTINE ORDER')),
        Text(
          '${_plan.length} stretch${_plan.length == 1 ? '' : 'es'}',
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
        'No stretches added. Create your first block above to build the routine.',
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
          tooltip: 'Save routine',
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
      _sectionTitle('SAVED ROUTINES'),
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
                '${item.sets} sets · Hold ${item.duration}s · Rest ${item.restSeconds}s',
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

  Widget _savedRow(SavedStretchPlan saved) => Padding(
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
            '${saved.name} · ${saved.items.length} stretches',
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
          tooltip: 'Delete saved routine',
        ),
      ],
    ),
  );

  Widget _timerCard() {
    final state = _timerState!;
    final item = _plan[state.itemIndex];
    final title = state.phase == _StretchPhase.work
        ? item.name
        : state.phase == _StretchPhase.rest
        ? 'Recover'
        : 'Between stretches';
    final phase = state.phase == _StretchPhase.work
        ? 'SET ${state.setNumber} OF ${item.sets}'
        : state.phase == _StretchPhase.rest
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
            color: state.phase == _StretchPhase.work
                ? AppColors.mint
                : AppColors.peach,
            boxShadow: [
              BoxShadow(
                color:
                    (state.phase == _StretchPhase.work
                            ? AppColors.mint
                            : AppColors.peach)
                        .withAlpha(100),
                blurRadius: 24,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _formatTime(state.remaining),
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
                if (_timer == null) {
                  _timer = Timer.periodic(
                    const Duration(seconds: 1),
                    (_) => _tick(),
                  );
                } else {
                  _timer?.cancel();
                  _timer = null;
                }
                setState(() {});
              },
              icon: Icon(
                _timer == null ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
              label: Text(_timer == null ? 'Resume' : 'Pause'),
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
                _sectionTitle('FLEXIBILITY CALENDAR'),
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
            'Completed routine',
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
                      Icons.self_improvement_rounded,
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

enum _StretchPhase { work, rest, transition }

class _StretchTimerState {
  _StretchTimerState({
    required this.itemIndex,
    required this.setNumber,
    required this.phase,
    required this.remaining,
    required this.total,
  });

  int itemIndex;
  int setNumber;
  _StretchPhase phase;
  int remaining;
  int total;
  int? nextIndex;
}
