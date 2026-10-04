import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'profile_page.dart';

const _weightEntriesKey = 'elateFitWeightEntries';
const _weightPhotosKey = 'elateFitProgressPhotos';

class WeightEntry {
  WeightEntry({
    required this.id,
    required this.weight,
    required this.notes,
    required this.recordedAt,
  });

  final String id;
  final double weight;
  final String notes;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'notes': notes,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'] as String? ?? '',
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    notes: json['notes'] as String? ?? '',
    recordedAt:
        DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class ProgressPhoto {
  ProgressPhoto({
    required this.id,
    required this.bytes,
    required this.note,
    required this.capturedAt,
  });

  final String id;
  final String bytes;
  final String note;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bytes': bytes,
    'note': note,
    'capturedAt': capturedAt.toIso8601String(),
  };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
    id: json['id'] as String? ?? '',
    bytes: json['bytes'] as String? ?? '',
    note: json['note'] as String? ?? '',
    capturedAt:
        DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class WeightTrackerPage extends StatefulWidget {
  const WeightTrackerPage({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  State<WeightTrackerPage> createState() => _WeightTrackerPageState();
}

class _WeightTrackerPageState extends State<WeightTrackerPage> {
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final _photoNoteController = TextEditingController();
  final _picker = ImagePicker();
  List<WeightEntry> _entries = [];
  List<ProgressPhoto> _photos = [];
  UserProfile? _profile;
  int _period = 7;
  String _status = '';
  bool _statusError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    _photoNoteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final rawEntries = prefs.getString(_weightEntriesKey);
      final rawPhotos = prefs.getString(_weightPhotosKey);
      if (!mounted) return;
      setState(() {
        _entries = rawEntries == null
            ? []
            : (jsonDecode(rawEntries) as List)
                  .map(
                    (item) =>
                        WeightEntry.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
        _photos = rawPhotos == null
            ? []
            : (jsonDecode(rawPhotos) as List)
                  .map(
                    (item) =>
                        ProgressPhoto.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
      });
      final profile = await loadUserProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      _showStatus('Weight tracker storage could not be read.', true);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _weightEntriesKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _weightPhotosKey,
      jsonEncode(_photos.map((photo) => photo.toJson()).toList()),
    );
  }

  void _showStatus(String message, bool error) => setState(() {
    _status = message;
    _statusError = error;
  });

  Future<void> _saveWeight() async {
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0 || weight > 500) {
      _showStatus('Enter a valid weight in kilograms.', true);
      return;
    }
    setState(
      () => _entries.add(
        WeightEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          weight: weight,
          notes: _notesController.text.trim(),
          recordedAt: DateTime.now(),
        ),
      ),
    );
    await _persist();
    _weightController.clear();
    _notesController.clear();
    _showStatus('Weight entry saved.', false);
  }

  Future<void> _deleteWeight(WeightEntry entry) async {
    setState(() => _entries.removeWhere((item) => item.id == entry.id));
    await _persist();
  }

  Future<void> _addPhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image == null) return;
      final bytes = base64Encode(await image.readAsBytes());
      setState(
        () => _photos.add(
          ProgressPhoto(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            bytes: bytes,
            note: _photoNoteController.text.trim(),
            capturedAt: DateTime.now(),
          ),
        ),
      );
      await _persist();
      _photoNoteController.clear();
      _showStatus('Progress photo saved locally.', false);
    } catch (_) {
      _showStatus('Could not add that photo.', true);
    }
  }

  Future<void> _deletePhoto(ProgressPhoto photo) async {
    setState(() => _photos.removeWhere((item) => item.id == photo.id));
    await _persist();
  }

  List<WeightEntry> get _sortedEntries =>
      [..._entries]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  List<WeightEntry> get _recentEntries => _sortedEntries
      .where(
        (entry) => entry.recordedAt.isAfter(
          DateTime.now().subtract(Duration(days: _period)),
        ),
      )
      .toList();
  WeightEntry? get _latest =>
      _sortedEntries.isEmpty ? null : _sortedEntries.last;
  WeightEntry? get _first =>
      _sortedEntries.isEmpty ? null : _sortedEntries.first;

  String _date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';
  static const _months = [
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _intro(),
          const SizedBox(height: 18),
          _measurementCard(),
          const SizedBox(height: 18),
          _trendCard(),
          const SizedBox(height: 18),
          _goalCard(),
          const SizedBox(height: 18),
          _historyCard(),
          const SizedBox(height: 18),
          _photosCard(),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      backgroundColor: Colors.white,
      elevation: 0,
      selectedIndex: 0,
      indicatorColor: AppColors.lime,
      onDestinationSelected: widget.onNavigate,
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
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'Serum',
        ),
        NavigationDestination(
          icon: Icon(Icons.air_outlined),
          selectedIcon: Icon(Icons.air),
          label: 'Breathe',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
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

  Widget _intro() => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(
          Icons.monitor_weight_rounded,
          color: AppColors.lime,
          size: 24,
        ),
      ),
      const SizedBox(width: 11),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress starts today',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Record measurements privately on this device.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
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
  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.ink,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    ),
  );
  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
  );

  Widget _measurementCard() => _card([
    _title('Daily measurement'),
    const SizedBox(height: 13),
    TextField(
      controller: _weightController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _decoration('Weight in kg · 65.0'),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _notesController,
      decoration: _decoration('Notes (optional) · Morning measurement'),
    ),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _saveWeight,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Save weight'),
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

  Widget _trendCard() {
    final latest = _latest;
    final first = _first;
    final change = latest == null || first == null
        ? null
        : latest.weight - first.weight;
    return _card([
      Row(
        children: [
          Expanded(child: _title('Weight trend')),
          PopupMenuButton<int>(
            initialValue: _period,
            onSelected: (value) => setState(() => _period = value),
            itemBuilder: (context) => [
              for (final value in [7, 15, 30])
                PopupMenuItem(value: value, child: Text('$value days')),
            ],
            child: Row(
              children: [
                Text(
                  '$_period days',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      Row(
        children: [
          _metric(
            'Current',
            latest == null ? '--' : '${latest.weight.toStringAsFixed(1)} kg',
            AppColors.lime,
          ),
          const SizedBox(width: 8),
          _metric(
            'Total change',
            change == null
                ? '--'
                : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
            AppColors.mint,
          ),
          const SizedBox(width: 8),
          _metric('Entries', '${_entries.length}', AppColors.lavender),
        ],
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 145,
        child: CustomPaint(
          painter: _WeightChartPainter(_recentEntries),
          child: const SizedBox.expand(),
        ),
      ),
    ]);
  }

  Widget _metric(String label, String value, Color color) => Expanded(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
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
    ),
  );

  Widget _goalCard() {
    final target = _profile?.targetWeight ?? 0;
    final latest = _latest?.weight;
    final first = _first?.weight;
    final hasGoal = target > 0 && latest != null && first != null;
    if (!hasGoal) {
      return _card([
        Row(
          children: [
            Expanded(child: _title('Goal map')),
            Text(
              target > 0
                  ? 'Target ${target.toStringAsFixed(0)} kg'
                  : 'Set a profile target',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Add a weight entry and set a target weight in your Profile to build your progress route.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
        ),
      ]);
    }
    final goalFirst = first;
    final goalLatest = latest;
    final total = (target - goalFirst).abs();
    final done = (goalLatest - goalFirst).abs();
    final progress = total > 0 ? (done / total).clamp(0, 1).toDouble() : 0.0;
    return _card([
      Row(
        children: [
          Expanded(child: _title('Goal map')),
          Text(
            target > 0
                ? 'Target ${target.toStringAsFixed(0)} kg'
                : 'Set a profile target',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start ${goalFirst.toStringAsFixed(1)} kg',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              Text(
                'Current ${goalLatest.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.background,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress >= 1
                ? 'Target reached. Set a new goal in Profile when ready.'
                : '${(progress * 100).round()}% of the distance to your target',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ]);
  }

  Widget _historyCard() => _card([
    Row(
      children: [
        Expanded(child: _title('Weight history')),
        Text(
          '${_entries.length} entries',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    if (_entries.isEmpty)
      const Text(
        'No weight entries yet.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _sortedEntries.reversed.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 16, color: AppColors.divider),
        itemBuilder: (context, index) {
          final entry = _sortedEntries.reversed.toList()[index];
          return Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.scale_rounded,
                  size: 17,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.weight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_date(entry.recordedAt)}${entry.notes.isEmpty ? '' : ' · ${entry.notes}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteWeight(entry),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.danger,
                tooltip: 'Delete entry',
              ),
            ],
          );
        },
      ),
  ]);

  Widget _photosCard() => _card([
    Row(
      children: [
        Expanded(child: _title('Monthly progress photos')),
        const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.muted,
          size: 17,
        ),
      ],
    ),
    const SizedBox(height: 6),
    const Text(
      'Photos stay stored locally on this device.',
      style: TextStyle(color: AppColors.muted, fontSize: 11),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _photoNoteController,
      decoration: _decoration('Photo note (optional)'),
    ),
    const SizedBox(height: 10),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addPhoto,
        icon: const Icon(Icons.photo_library_outlined, size: 18),
        label: const Text('Add progress photo'),
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
    if (_photos.isNotEmpty) ...[
      const SizedBox(height: 14),
      SizedBox(
        height: 115,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _photos.length,
          separatorBuilder: (context, index) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final photo = _photos[_photos.length - 1 - index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.memory(
                    base64Decode(photo.bytes),
                    width: 100,
                    height: 115,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 3,
                  top: 3,
                  child: InkWell(
                    onTap: () => _deletePhoto(photo),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  ]);
}

class _WeightChartPainter extends CustomPainter {
  const _WeightChartPainter(this.entries);
  final List<WeightEntry> entries;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var row = 1; row <= 3; row++) {
      canvas.drawLine(
        Offset(0, size.height * row / 4),
        Offset(size.width, size.height * row / 4),
        gridPaint,
      );
    }
    if (entries.isEmpty) return;
    final weights = entries.map((entry) => entry.weight).toList();
    final min = weights.reduce((a, b) => a < b ? a : b) - 1;
    final max = weights.reduce((a, b) => a > b ? a : b) + 1;
    final span = (max - min).clamp(1, double.infinity).toDouble();
    final points = [
      for (var i = 0; i < entries.length; i++)
        Offset(
          entries.length == 1
              ? size.width / 2
              : size.width * i / (entries.length - 1),
          size.height - (entries[i].weight - min) / span * size.height,
        ),
    ];
    final line = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.success;
    for (final point in points) {
      canvas.drawCircle(point, 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.entries != entries;
}
