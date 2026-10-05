import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const _favoritesKey = 'elateFitSleepSoundFavorites';

class SleepSound {
  const SleepSound({
    required this.file,
    required this.name,
    required this.category,
    required this.icon,
  });

  final String file;
  final String name;
  final String category;
  final IconData icon;
}

class SavedSoundMix {
  const SavedSoundMix({required this.name, required this.sounds});

  final String name;
  final List<Map<String, dynamic>> sounds;

  Map<String, dynamic> toJson() => {'name': name, 'sounds': sounds};

  factory SavedSoundMix.fromJson(Map<String, dynamic> json) => SavedSoundMix(
    name: json['name'] as String? ?? 'Sleep mix',
    sounds: (json['sounds'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
  );
}

const _soundCatalog = [
  SleepSound(
    file: 'campFire.mp3',
    name: 'Campfire',
    category: 'Nature',
    icon: Icons.local_fire_department_rounded,
  ),
  SleepSound(
    file: 'distantThunder.mp3',
    name: 'Distant Thunder',
    category: 'Nature',
    icon: Icons.thunderstorm_outlined,
  ),
  SleepSound(
    file: 'LakeWindAmbience.mp3',
    name: 'Lake Wind',
    category: 'Nature',
    icon: Icons.air_rounded,
  ),
  SleepSound(
    file: 'windForest.mp3',
    name: 'Forest Wind',
    category: 'Nature',
    icon: Icons.forest_rounded,
  ),
  SleepSound(
    file: 'windQuietCreaks.mp3',
    name: 'Quiet Wind',
    category: 'Nature',
    icon: Icons.eco_rounded,
  ),
  SleepSound(
    file: 'IceRain.mp3',
    name: 'Ice Rain',
    category: 'Rain & Water',
    icon: Icons.water_drop_rounded,
  ),
  SleepSound(
    file: 'rainOnCarHeavy.mp3',
    name: 'Heavy Rain on Car',
    category: 'Rain & Water',
    icon: Icons.cloudy_snowing,
  ),
  SleepSound(
    file: 'rainOnRoof.mp3',
    name: 'Rain on Roof',
    category: 'Rain & Water',
    icon: Icons.umbrella_rounded,
  ),
  SleepSound(
    file: 'RainOnRooftop.mp3',
    name: 'Rain on Rooftop',
    category: 'Rain & Water',
    icon: Icons.water_rounded,
  ),
  SleepSound(
    file: 'rainWaterDrop.mp3',
    name: 'Rain Drops',
    category: 'Rain & Water',
    icon: Icons.grain_rounded,
  ),
  SleepSound(
    file: 'carDriveBy.mp3',
    name: 'Car Drive By',
    category: 'Travel & City',
    icon: Icons.directions_car_rounded,
  ),
  SleepSound(
    file: 'highway1.mp3',
    name: 'Highway One',
    category: 'Travel & City',
    icon: Icons.route_rounded,
  ),
  SleepSound(
    file: 'highway2.mp3',
    name: 'Highway Two',
    category: 'Travel & City',
    icon: Icons.alt_route_rounded,
  ),
  SleepSound(
    file: 'FactoryHard.mp3',
    name: 'Factory Hard',
    category: 'Travel & City',
    icon: Icons.business_rounded,
  ),
  SleepSound(
    file: 'factoryMorning.mp3',
    name: 'Factory Morning',
    category: 'Travel & City',
    icon: Icons.location_city_rounded,
  ),
  SleepSound(
    file: 'KidsPlaying.mp3',
    name: 'Kids Playing',
    category: 'Life',
    icon: Icons.groups_rounded,
  ),
  SleepSound(
    file: 'hero.mp3',
    name: 'Soft Atmosphere',
    category: 'Ambient',
    icon: Icons.auto_awesome_rounded,
  ),
  SleepSound(
    file: 'hit.mp3',
    name: 'Soft Pulse',
    category: 'Ambient',
    icon: Icons.favorite_rounded,
  ),
  SleepSound(
    file: 'silver.mp3',
    name: 'Silver Ambience',
    category: 'Ambient',
    icon: Icons.nightlight_round,
  ),
  SleepSound(
    file: 'WoodDanHenig.mp3',
    name: 'Wooden Strings',
    category: 'Ambient',
    icon: Icons.music_note_rounded,
  ),
];

class SleepSoundsPage extends StatefulWidget {
  const SleepSoundsPage({super.key});

  @override
  State<SleepSoundsPage> createState() => _SleepSoundsPageState();
}

class _SleepSoundsPageState extends State<SleepSoundsPage> {
  final _searchController = TextEditingController();
  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {
    for (final sound in _soundCatalog) sound.file: 0.35,
  };
  List<SavedSoundMix> _favorites = [];
  Set<String> _selected = {};
  String _category = 'All sounds';
  String _query = '';
  String _status = 'Choose a sound to begin.';
  bool _statusError = false;

  List<String> get _categories => [
    'All sounds',
    ...{for (final sound in _soundCatalog) sound.category},
  ];

  List<SleepSound> get _visibleSounds => _soundCatalog
      .where(
        (sound) =>
            (_category == 'All sounds' || sound.category == _category) &&
            (_query.isEmpty || sound.name.toLowerCase().contains(_query)),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null || !mounted) return;
    try {
      setState(
        () => _favorites = (jsonDecode(raw) as List)
            .map((item) => SavedSoundMix.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(_favorites.map((mix) => mix.toJson()).toList()),
    );
  }

  AudioPlayer _playerFor(SleepSound sound) =>
      _players.putIfAbsent(sound.file, () => AudioPlayer());

  Future<void> _playSound(SleepSound sound) async {
    final player = _playerFor(sound);
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(_volumes[sound.file] ?? 0.35);
    try {
      await player.play(AssetSource('sounds/${sound.file}'));
      if (mounted) setState(() => _status = '${sound.name} is playing.');
    } catch (_) {
      _showStatus('Could not play ${sound.name}.', true);
    }
  }

  Future<void> _stopSound(SleepSound sound) async {
    await _playerFor(sound).stop();
    if (mounted) setState(() => _status = '${sound.name} stopped.');
  }

  Future<void> _toggleSelected(SleepSound sound) async {
    final selected = !_selected.contains(sound.file);
    setState(
      () => selected ? _selected.add(sound.file) : _selected.remove(sound.file),
    );
    if (selected) {
      await _playSound(sound);
    } else {
      await _stopSound(sound);
    }
  }

  Future<void> _playMix() async {
    if (_selected.isEmpty) {
      _showStatus('Choose at least one sound to play your mix.', true);
      return;
    }
    for (final sound in _soundCatalog.where(
      (item) => _selected.contains(item.file),
    )) {
      await _playSound(sound);
    }
    _showStatus('${_selected.length} sounds are playing together.', false);
  }

  Future<void> _stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
    _showStatus('Mix stopped.', false);
  }

  Future<void> _clearMix() async {
    await _stopAll();
    if (mounted) setState(() => _selected = {});
    _showStatus('Mix cleared.', false);
  }

  Future<void> _setVolume(SleepSound sound, double value) async {
    setState(() => _volumes[sound.file] = value);
    await _playerFor(sound).setVolume(value);
  }

  Future<void> _saveFavorite() async {
    if (_selected.isEmpty) {
      _showStatus('Choose at least one sound before saving a favourite.', true);
      return;
    }
    final controller = TextEditingController(
      text: 'Sleep mix ${_favorites.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save favourite mix'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mix name'),
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
    final sounds = _soundCatalog
        .where((sound) => _selected.contains(sound.file))
        .map(
          (sound) => {
            'file': sound.file,
            'name': sound.name,
            'volume': _volumes[sound.file] ?? 0.35,
          },
        )
        .toList();
    setState(() => _favorites.add(SavedSoundMix(name: name, sounds: sounds)));
    await _persistFavorites();
    _showStatus('Saved $name.', false);
  }

  void _loadMix(SavedSoundMix mix) {
    _stopAll();
    final files = <String>{};
    for (final sound in mix.sounds) {
      final file = sound['file'] as String?;
      if (file == null) continue;
      files.add(file);
      _volumes[file] = (sound['volume'] as num?)?.toDouble() ?? 0.35;
    }
    setState(() => _selected = files);
    _showStatus('Loaded ${mix.name}. Press Play to start.', false);
  }

  Future<void> _deleteFavorite(SavedSoundMix mix) async {
    setState(() => _favorites.remove(mix));
    await _persistFavorites();
  }

  void _showStatus(String message, bool error) {
    if (mounted) {
      setState(() {
        _status = message;
        _statusError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 18),
          _libraryCard(),
          const SizedBox(height: 18),
          _favoritesCard(),
        ],
      ),
    ),
  );

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
          Icons.nightlight_round,
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
              'Sleep sounds',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Layer gentle sounds into a personal soundscape.',
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

  Widget _libraryCard() => _card([
    Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Explore sounds',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_selected.length} selected',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Icon(Icons.headphones_rounded, color: AppColors.muted, size: 20),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        hintText: 'Search rain, wind, campfire...',
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
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
              ),
      ),
    ),
    const SizedBox(height: 11),
    SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final active = category == _category;
          return ChoiceChip(
            label: Text(category),
            selected: active,
            onSelected: (_) => setState(() => _category = category),
            selectedColor: AppColors.lime,
            backgroundColor: AppColors.background,
            labelStyle: TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
            side: const BorderSide(color: AppColors.line),
          );
        },
      ),
    ),
    const SizedBox(height: 13),
    if (_visibleSounds.isEmpty)
      const Text(
        'No sounds match your search.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _visibleSounds.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 18, color: AppColors.divider),
        itemBuilder: (context, index) => _soundRow(_visibleSounds[index]),
      ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _playMix,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Play my mix'),
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
          onPressed: _stopAll,
          icon: const Icon(Icons.stop_rounded),
          tooltip: 'Stop mix',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.peach,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        const SizedBox(width: 5),
        IconButton.filledTonal(
          onPressed: _clearMix,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Clear mix',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Text(
      _status,
      style: TextStyle(
        color: _statusError ? AppColors.danger : AppColors.muted,
        fontSize: 11,
      ),
    ),
  ]);

  Widget _soundRow(SleepSound sound) {
    final selected = _selected.contains(sound.file);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.lime
                : AppColors.tiles[_soundCatalog.indexOf(sound) %
                      AppColors.tiles.length],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(sound.icon, color: AppColors.ink, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sound.name,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sound.category,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              if (selected)
                Slider(
                  value: _volumes[sound.file] ?? 0.35,
                  min: 0,
                  max: 1,
                  activeColor: AppColors.ink,
                  onChanged: (value) => _setVolume(sound, value),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _toggleSelected(sound),
          icon: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: selected ? AppColors.success : AppColors.ink,
          ),
          tooltip: selected ? 'Remove from mix' : 'Add to mix',
        ),
      ],
    );
  }

  Widget _favoritesCard() => _card([
    Row(
      children: [
        const Expanded(
          child: Text(
            'Saved mixes',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(
          Icons.bookmark_outline_rounded,
          color: AppColors.muted,
          size: 19,
        ),
      ],
    ),
    const SizedBox(height: 4),
    const Text(
      'Your personal soundscapes, saved on this device.',
      style: TextStyle(color: AppColors.muted, fontSize: 11),
    ),
    const SizedBox(height: 10),
    if (_favorites.isEmpty)
      const Text(
        'No saved mixes yet. Choose a few sounds and save your first calm space.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
      )
    else
      ..._favorites.map((mix) => _favoriteRow(mix)),
    if (_selected.isNotEmpty) ...[
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saveFavorite,
          icon: const Icon(Icons.favorite_border_rounded, size: 18),
          label: const Text('Save current mix'),
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
    ],
  ]);

  Widget _favoriteRow(SavedSoundMix mix) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        const Icon(Icons.bookmark_rounded, color: AppColors.muted, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${mix.name} · ${mix.sounds.length} sounds',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(onPressed: () => _loadMix(mix), child: const Text('Load')),
        IconButton(
          onPressed: () => _deleteFavorite(mix),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: AppColors.danger,
          tooltip: 'Delete mix',
        ),
      ],
    ),
  );
}
