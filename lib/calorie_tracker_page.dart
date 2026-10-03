import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'profile_page.dart';

const String kFoodEntriesStorageKey = 'elateFitFoodEntries';

/// Nutrition values per 100 g, matching the web food catalog.
class FoodItem {
  const FoodItem(
    this.label, {
    required this.calories,
    required this.protein,
    required this.saturatedFat,
    required this.unsaturatedFat,
    required this.solubleFiber,
    required this.insolubleFiber,
  });

  final String label;
  final double calories;
  final double protein;
  final double saturatedFat;
  final double unsaturatedFat;
  final double solubleFiber;
  final double insolubleFiber;
}

const Map<String, FoodItem> foodCatalog = {
  'rice': FoodItem(
    'Rice raw',
    calories: 365,
    protein: 7.2,
    saturatedFat: 0.3,
    unsaturatedFat: 0.6,
    solubleFiber: 0.55,
    insolubleFiber: 1.92,
  ),
  'boiled_rice': FoodItem(
    'Rice boiled',
    calories: 121.67,
    protein: 2.4,
    saturatedFat: 0.1,
    unsaturatedFat: 0.2,
    solubleFiber: 0.183,
    insolubleFiber: 0.64,
  ),
  'brown_rice': FoodItem(
    'Brown rice raw',
    calories: 367,
    protein: 7.3,
    saturatedFat: 0.6,
    unsaturatedFat: 2.1,
    solubleFiber: 0.4,
    insolubleFiber: 3.0,
  ),
  'oats': FoodItem(
    'Oats raw',
    calories: 389,
    protein: 16.9,
    saturatedFat: 1.22,
    unsaturatedFat: 4.72,
    solubleFiber: 3.5,
    insolubleFiber: 6,
  ),
  'boiled_oats': FoodItem(
    'Oats boiled',
    calories: 129.67,
    protein: 5.63,
    saturatedFat: 0.41,
    unsaturatedFat: 1.57,
    solubleFiber: 1.17,
    insolubleFiber: 2,
  ),
  'wheat': FoodItem(
    'Whole wheat raw',
    calories: 340,
    protein: 13.2,
    saturatedFat: 0.43,
    unsaturatedFat: 1.453,
    solubleFiber: 1.2,
    insolubleFiber: 7.0,
  ),
  'wheat_roti': FoodItem(
    'Wheat roti / chapati',
    calories: 297,
    protein: 9.0,
    saturatedFat: 0.5,
    unsaturatedFat: 2.0,
    solubleFiber: 2.0,
    insolubleFiber: 6.5,
  ),
  'jowar_roti': FoodItem(
    'Jowar roti',
    calories: 205,
    protein: 6.2,
    saturatedFat: 0.3,
    unsaturatedFat: 1.2,
    solubleFiber: 1.2,
    insolubleFiber: 3.8,
  ),
  'ragi_roti': FoodItem(
    'Ragi roti (finger millet)',
    calories: 210,
    protein: 5.0,
    saturatedFat: 0.2,
    unsaturatedFat: 1.0,
    solubleFiber: 1.5,
    insolubleFiber: 5.5,
  ),
  'chickpeas': FoodItem(
    'Chickpeas raw',
    calories: 378,
    protein: 20.47,
    saturatedFat: 0.603,
    unsaturatedFat: 4.108,
    solubleFiber: 2,
    insolubleFiber: 6,
  ),
  'boiled_chickpeas': FoodItem(
    'Chickpeas boiled',
    calories: 126,
    protein: 6.823,
    saturatedFat: 0.201,
    unsaturatedFat: 1.369,
    solubleFiber: 0.63,
    insolubleFiber: 2,
  ),
  'green_gram': FoodItem(
    'Green gram raw',
    calories: 347,
    protein: 23.86,
    saturatedFat: 0.348,
    unsaturatedFat: 0.545,
    solubleFiber: 1.5,
    insolubleFiber: 12.3,
  ),
  'boiled_green_gram': FoodItem(
    'Green gram boiled',
    calories: 115.67,
    protein: 7.953,
    saturatedFat: 0.116,
    unsaturatedFat: 0.182,
    solubleFiber: 0.5,
    insolubleFiber: 4.1,
  ),
  'boiled_red_lentils': FoodItem(
    'Red lentils / masoor dal boiled',
    calories: 116,
    protein: 9.02,
    saturatedFat: 0.05,
    unsaturatedFat: 0.28,
    solubleFiber: 1.5,
    insolubleFiber: 6.4,
  ),
  'boiled_kidney_beans': FoodItem(
    'Kidney beans / rajma boiled',
    calories: 127,
    protein: 8.67,
    saturatedFat: 0.07,
    unsaturatedFat: 0.35,
    solubleFiber: 1.4,
    insolubleFiber: 5.0,
  ),
  'banana': FoodItem(
    'Banana',
    calories: 89,
    protein: 1.09,
    saturatedFat: 0.038,
    unsaturatedFat: 0.105,
    solubleFiber: 0.6,
    insolubleFiber: 2.0,
  ),
  'apple': FoodItem(
    'Apple',
    calories: 52,
    protein: 0.26,
    saturatedFat: 0.028,
    unsaturatedFat: 0.058,
    solubleFiber: 1.0,
    insolubleFiber: 1.4,
  ),
  'orange': FoodItem(
    'Orange',
    calories: 47,
    protein: 0.94,
    saturatedFat: 0.015,
    unsaturatedFat: 0.048,
    solubleFiber: 1.4,
    insolubleFiber: 1.0,
  ),
  'mango': FoodItem(
    'Mango',
    calories: 60,
    protein: 0.82,
    saturatedFat: 0.092,
    unsaturatedFat: 0.211,
    solubleFiber: 0.6,
    insolubleFiber: 1.0,
  ),
  'papaya': FoodItem(
    'Papaya',
    calories: 43,
    protein: 0.47,
    saturatedFat: 0.043,
    unsaturatedFat: 0.096,
    solubleFiber: 0.7,
    insolubleFiber: 1.0,
  ),
  'guava': FoodItem(
    'Guava',
    calories: 68,
    protein: 2.55,
    saturatedFat: 0.272,
    unsaturatedFat: 0.489,
    solubleFiber: 1.4,
    insolubleFiber: 4.0,
  ),
  'pomegranate': FoodItem(
    'Pomegranate',
    calories: 83,
    protein: 1.67,
    saturatedFat: 0.12,
    unsaturatedFat: 0.65,
    solubleFiber: 1.0,
    insolubleFiber: 3.0,
  ),
  'watermelon': FoodItem(
    'Watermelon',
    calories: 30,
    protein: 0.61,
    saturatedFat: 0.016,
    unsaturatedFat: 0.087,
    solubleFiber: 0.1,
    insolubleFiber: 0.3,
  ),
  'boiled_potato': FoodItem(
    'Potato boiled (with skin)',
    calories: 87,
    protein: 1.87,
    saturatedFat: 0.02,
    unsaturatedFat: 0.04,
    solubleFiber: 0.6,
    insolubleFiber: 1.2,
  ),
  'boiled_carrot': FoodItem(
    'Carrot boiled',
    calories: 35,
    protein: 0.76,
    saturatedFat: 0.028,
    unsaturatedFat: 0.11,
    solubleFiber: 1.3,
    insolubleFiber: 1.7,
  ),
  'boiled_spinach': FoodItem(
    'Spinach boiled',
    calories: 23,
    protein: 2.97,
    saturatedFat: 0.04,
    unsaturatedFat: 0.15,
    solubleFiber: 0.7,
    insolubleFiber: 1.7,
  ),
  'boiled_beans': FoodItem(
    'Green beans boiled',
    calories: 35,
    protein: 1.9,
    saturatedFat: 0.06,
    unsaturatedFat: 0.14,
    solubleFiber: 1.0,
    insolubleFiber: 2.2,
  ),
  'boiled_tomato': FoodItem(
    'Tomato boiled',
    calories: 18,
    protein: 0.9,
    saturatedFat: 0.03,
    unsaturatedFat: 0.12,
    solubleFiber: 0.3,
    insolubleFiber: 0.7,
  ),
  'boiled_chicken': FoodItem(
    'Chicken boiled',
    calories: 177,
    protein: 27.29,
    saturatedFat: 1.84,
    unsaturatedFat: 3.93,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'fried_chicken': FoodItem(
    'Chicken fried (meat only)',
    calories: 219,
    protein: 30.57,
    saturatedFat: 2.46,
    unsaturatedFat: 6.66,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'boiled_egg': FoodItem(
    'Egg boiled whole',
    calories: 155,
    protein: 12.6,
    saturatedFat: 3.27,
    unsaturatedFat: 5.49,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'boiled_egg_white': FoodItem(
    'Egg white boiled',
    calories: 52,
    protein: 10.7,
    saturatedFat: 0,
    unsaturatedFat: 0,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'fried_egg_omlet': FoodItem(
    'Whole egg omlet / burji',
    calories: 154,
    protein: 10.57,
    saturatedFat: 3.32,
    unsaturatedFat: 7.56,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'boiled_fish': FoodItem(
    'Fish boiled',
    calories: 146,
    protein: 24.2,
    saturatedFat: 1.0,
    unsaturatedFat: 3.2,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'boiled_mutton': FoodItem(
    'Mutton boiled',
    calories: 234,
    protein: 33.4,
    saturatedFat: 5.1,
    unsaturatedFat: 6.0,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'boiled_milk': FoodItem(
    'Milk boiled',
    calories: 61,
    protein: 3.15,
    saturatedFat: 1.865,
    unsaturatedFat: 1.007,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'curd': FoodItem(
    'Curd',
    calories: 61,
    protein: 3.47,
    saturatedFat: 2.096,
    unsaturatedFat: 0.985,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'paneer': FoodItem(
    'Paneer',
    calories: 344,
    protein: 20,
    saturatedFat: 18.02,
    unsaturatedFat: 3.86,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'low_fat_paneer': FoodItem(
    'Paneer (low fat / cottage cheese)',
    calories: 120,
    protein: 15.0,
    saturatedFat: 3.5,
    unsaturatedFat: 1.5,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'cheese': FoodItem(
    'Cheese cheddar',
    calories: 403,
    protein: 22.87,
    saturatedFat: 18.87,
    unsaturatedFat: 10.33,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'ghee': FoodItem(
    'Ghee (clarified butter)',
    calories: 876,
    protein: 0.28,
    saturatedFat: 61.924,
    unsaturatedFat: 32.426,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'butter': FoodItem(
    'Butter (without salt)',
    calories: 717,
    protein: 0.85,
    saturatedFat: 50.5,
    unsaturatedFat: 26.44,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
  'idli': FoodItem(
    'Idli (steamed)',
    calories: 148,
    protein: 4.1,
    saturatedFat: 0.1,
    unsaturatedFat: 0.4,
    solubleFiber: 0.4,
    insolubleFiber: 1.1,
  ),
  'dosa': FoodItem(
    'Dosa (plain)',
    calories: 168,
    protein: 4.2,
    saturatedFat: 0.5,
    unsaturatedFat: 3.0,
    solubleFiber: 0.3,
    insolubleFiber: 0.8,
  ),
  'masala_dosa': FoodItem(
    'Masala dosa',
    calories: 175,
    protein: 3.8,
    saturatedFat: 0.8,
    unsaturatedFat: 3.8,
    solubleFiber: 0.5,
    insolubleFiber: 1.2,
  ),
  'poha': FoodItem(
    'Poha',
    calories: 180,
    protein: 3.5,
    saturatedFat: 0.8,
    unsaturatedFat: 4.2,
    solubleFiber: 0.4,
    insolubleFiber: 1.1,
  ),
  'upma': FoodItem(
    'Upma',
    calories: 145,
    protein: 3.0,
    saturatedFat: 0.8,
    unsaturatedFat: 3.2,
    solubleFiber: 0.4,
    insolubleFiber: 1.1,
  ),
  'chicken_biriyani': FoodItem(
    'Chicken biriyani',
    calories: 195,
    protein: 10.5,
    saturatedFat: 2.5,
    unsaturatedFat: 5.0,
    solubleFiber: 0.3,
    insolubleFiber: 0.7,
  ),
  'roasted_peanuts': FoodItem(
    'Roasted peanuts',
    calories: 585,
    protein: 23.7,
    saturatedFat: 6.8,
    unsaturatedFat: 40.0,
    solubleFiber: 2.5,
    insolubleFiber: 6.0,
  ),
  'roasted_almonds': FoodItem(
    'Roasted almonds',
    calories: 598,
    protein: 21.0,
    saturatedFat: 4.1,
    unsaturatedFat: 46.0,
    solubleFiber: 1.2,
    insolubleFiber: 9.7,
  ),
  'whey_protein': FoodItem(
    'Whey protein (unflavored)',
    calories: 382,
    protein: 76.0,
    saturatedFat: 3.5,
    unsaturatedFat: 1.5,
    solubleFiber: 0,
    insolubleFiber: 0,
  ),
};

/// A single logged food, persisted in local storage.
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.foodKey,
    required this.grams,
    required this.timestamp,
  });

  final String id;
  final String foodKey;
  final double grams;
  final DateTime timestamp;

  FoodItem? get food => foodCatalog[foodKey];

  Map<String, dynamic> toJson() => {
    'id': id,
    'foodKey': foodKey,
    'grams': grams,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
    id: json['id'] as String? ?? '',
    foodKey: json['foodKey'] as String? ?? '',
    grams: (json['grams'] as num?)?.toDouble() ?? 0,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Running total of the tracked nutrients.
class NutritionTotals {
  double calories = 0;
  double protein = 0;
  double saturatedFat = 0;
  double unsaturatedFat = 0;
  double solubleFiber = 0;
  double insolubleFiber = 0;

  void addFood(FoodItem food, double grams) {
    final factor = grams / 100;
    calories += food.calories * factor;
    protein += food.protein * factor;
    saturatedFat += food.saturatedFat * factor;
    unsaturatedFat += food.unsaturatedFat * factor;
    solubleFiber += food.solubleFiber * factor;
    insolubleFiber += food.insolubleFiber * factor;
  }
}

/// Calorie intake journal. Entries are stored in local storage
/// (SharedPreferences) as a JSON list, like the web version's IndexedDB.
class CalorieTrackerPage extends StatefulWidget {
  const CalorieTrackerPage({super.key, this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  State<CalorieTrackerPage> createState() => _CalorieTrackerPageState();
}

class _CalorieTrackerPageState extends State<CalorieTrackerPage> {
  final _foodSearchController = TextEditingController();
  final _gramsController = TextEditingController();

  MapEntry<String, FoodItem>? _selectedFood;
  List<FoodEntry> _entries = [];
  UserProfile? _profile;
  String _status = '';
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _foodSearchController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kFoodEntriesStorageKey);
    final entries = <FoodEntry>[];
    if (raw != null) {
      try {
        entries.addAll(
          (jsonDecode(raw) as List).map(
            (item) => FoodEntry.fromJson(item as Map<String, dynamic>),
          ),
        );
      } catch (_) {
        // Ignore corrupted data and start fresh.
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final profile = await loadUserProfile();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _profile = profile;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kFoodEntriesStorageKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<FoodEntry> get _todayEntries {
    final now = DateTime.now();
    return _entries.where((entry) => _isSameDay(entry.timestamp, now)).toList();
  }

  NutritionTotals _totalsFor(Iterable<FoodEntry> entries) {
    final totals = NutritionTotals();
    for (final entry in entries) {
      final food = entry.food;
      if (food != null) totals.addFood(food, entry.grams);
    }
    return totals;
  }

  Future<void> _addEntry() async {
    final selected = _selectedFood;
    final grams = double.tryParse(_gramsController.text.trim());
    if (selected == null) {
      setState(() {
        _status = 'Choose a food from the list.';
        _statusIsError = true;
      });
      return;
    }
    if (grams == null || grams <= 0) {
      setState(() {
        _status = 'Enter an amount in grams (1 or more).';
        _statusIsError = true;
      });
      return;
    }
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodKey: selected.key,
      grams: grams,
      timestamp: DateTime.now(),
    );
    setState(() {
      _entries.insert(0, entry);
      _foodSearchController.clear();
      _gramsController.clear();
      _selectedFood = null;
      _status =
          'Added ${selected.value.label.toLowerCase()} to today\'s journal.';
      _statusIsError = false;
    });
    await _persist();
  }

  Future<void> _deleteEntry(String id) async {
    setState(() => _entries.removeWhere((entry) => entry.id == id));
    await _persist();
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text(
          'Delete all saved data?',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'This removes every saved food entry from local storage.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.paper,
            ),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _entries.clear());
      await _persist();
    }
  }

  String _num(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final todayEntries = _todayEntries;
    final totals = _totalsFor(todayEntries);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 22),
          _addFoodCard(),
          const SizedBox(height: 22),
          _todayCard(totals, todayEntries.length),
          const SizedBox(height: 22),
          _targetsCard(totals),
          const SizedBox(height: 22),
          _weekCard(),
          const SizedBox(height: 22),
          _entriesCard(todayEntries),
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
        child: const Icon(Icons.ramen_dining, color: AppColors.lime, size: 24),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calorie journal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Log foods by weight · values per 100 g.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
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

  Widget _card({required List<Widget> children}) => Container(
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

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.soft,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
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

  Widget _addFoodCard() => _card(
    children: [
      _sectionTitle('ADD FOOD'),
      const SizedBox(height: 14),
      DropdownMenu<MapEntry<String, FoodItem>>(
        controller: _foodSearchController,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 320,
        width: MediaQuery.sizeOf(context).width - 74,
        label: const Text('Food'),
        hintText: 'Try rice, dal, banana',
        leadingIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.muted,
        ),
        textStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
        ),
        dropdownMenuEntries: foodCatalog.entries
            .map(
              (entry) => DropdownMenuEntry<MapEntry<String, FoodItem>>(
                value: entry,
                label: entry.value.label,
              ),
            )
            .toList(),
        onSelected: (entry) => setState(() => _selectedFood = entry),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _gramsController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: _fieldDecoration('Amount in grams'),
      ),
      const SizedBox(height: 10),
      _preview(),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _addEntry,
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
            'Add food',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
    ],
  );

  Widget _preview() {
    final food = _selectedFood?.value;
    if (food == null) {
      return const Text(
        'Choose a food to see its nutrition per 100 g.',
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
      );
    }
    final base =
        'Per 100 g: ${_num(food.calories)} kcal · ${_num(food.protein)} g protein';
    final grams = double.tryParse(_gramsController.text.trim());
    if (grams != null && grams > 0) {
      final factor = grams / 100;
      return Text(
        '$base\nFor ${_num(grams)} g: ${_num(food.calories * factor)} kcal · '
        '${_num(food.protein * factor)} g protein',
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      );
    }
    return Text(
      base,
      style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
    );
  }

  Widget _statTile(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _todayCard(NutritionTotals totals, int entryCount) => _card(
    children: [
      _sectionTitle('TODAY\'S INTAKE'),
      const SizedBox(height: 14),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          _statTile(
            'Calories',
            '${_num(totals.calories)} kcal',
            AppColors.lime,
          ),
          _statTile('Protein', '${_num(totals.protein)} g', AppColors.mint),
          _statTile('Food entries', '$entryCount', AppColors.peach),
        ],
      ),
      const SizedBox(height: 10),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.3,
        children: [
          _statTile(
            'Saturated fat',
            '${_num(totals.saturatedFat)} g',
            AppColors.lavender,
          ),
          _statTile(
            'Unsaturated fat',
            '${_num(totals.unsaturatedFat)} g',
            AppColors.mint,
          ),
          _statTile(
            'Soluble fiber',
            '${_num(totals.solubleFiber)} g',
            AppColors.peach,
          ),
          _statTile(
            'Insoluble fiber',
            '${_num(totals.insolubleFiber)} g',
            AppColors.lavender,
          ),
        ],
      ),
    ],
  );

  Widget _targetsCard(NutritionTotals totals) {
    final profile = _profile;
    return _card(
      children: [
        _sectionTitle('DAILY TARGETS'),
        const SizedBox(height: 14),
        if (profile == null) ...[
          const Text(
            'Set up your profile to unlock daily calorie and protein targets.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onOpenProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.person_rounded, size: 17),
            label: const Text(
              'Open profile',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ] else ...[
          Builder(
            builder: (context) {
              final targets = calculateNutritionTargets(profile);
              return Column(
                children: [
                  _targetRow(
                    'Calories',
                    totals.calories,
                    targets.calories,
                    'kcal',
                    AppColors.lime,
                  ),
                  const SizedBox(height: 16),
                  _targetRow(
                    'Protein',
                    totals.protein,
                    targets.protein,
                    'g',
                    AppColors.mint,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _targetRow(
    String label,
    double consumed,
    int target,
    String unit,
    Color color,
  ) {
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final done = consumed >= target && target > 0;
    final remaining = (target - consumed).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: done ? AppColors.mint : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: done ? null : Border.all(color: AppColors.line),
              ),
              child: Text(
                done ? 'Goal reached' : '$remaining $unit left',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation(done ? AppColors.ink : color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_num(consumed)} / $target $unit',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _weekCard() {
    final now = DateTime.now();
    final days = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });
    final values = days
        .map(
          (day) => _totalsFor(
            _entries.where((entry) => _isSameDay(entry.timestamp, day)),
          ).calories,
        )
        .toList();
    final maxValue = values.fold<double>(0, (a, b) => b > a ? b : a);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return _card(
      children: [
        _sectionTitle('LAST 7 DAYS · CALORIES'),
        const SizedBox(height: 16),
        SizedBox(
          height: 122,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          values[i] > 0 ? _num(values[i]) : '',
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: maxValue <= 0
                              ? 4
                              : 4 + (76 * values[i] / maxValue),
                          decoration: BoxDecoration(
                            color: i == 6 ? AppColors.ink : AppColors.lime,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLetters[days[i].weekday - 1],
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
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
      ],
    );
  }

  Widget _entriesCard(List<FoodEntry> todayEntries) => _card(
    children: [
      _sectionTitle('TODAY\'S FOODS'),
      const SizedBox(height: 8),
      if (todayEntries.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              'No foods logged yet today.\nAdd your first food above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        )
      else ...[
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: todayEntries.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 22, color: AppColors.divider),
          itemBuilder: (context, index) =>
              _entryRow(todayEntries[index], index),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _deleteAll,
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: const Text(
              'Delete all saved data',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ),
      ],
    ],
  );

  Widget _entryRow(FoodEntry entry, int index) {
    final food = entry.food;
    final factor = entry.grams / 100;
    final calories = food == null ? 0.0 : food.calories * factor;
    final protein = food == null ? 0.0 : food.protein * factor;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.tiles[index % AppColors.tiles.length],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: AppColors.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food?.label ?? entry.foodKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_num(entry.grams)} g · ${_time(entry.timestamp)}',
                style: const TextStyle(color: AppColors.soft, fontSize: 10.5),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_num(calories)} kcal',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_num(protein)} g protein',
              style: const TextStyle(color: AppColors.soft, fontSize: 10),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _deleteEntry(entry.id),
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.danger,
          splashRadius: 18,
          tooltip: 'Delete entry',
        ),
      ],
    );
  }
}
