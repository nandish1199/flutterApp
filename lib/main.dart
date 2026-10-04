import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'breathing_exercise_page.dart';
import 'cardio_configure_page.dart';
import 'calorie_tracker_page.dart';
import 'profile_page.dart';
import 'serum_tracker_page.dart';
import 'sleep_sounds_page.dart';
import 'stretching_configure_page.dart'; // Added Import
import 'workout_tracker_page.dart';
import 'weight_tracker_page.dart';

void main() => runApp(const ElateFitApp());

class ElateFitApp extends StatelessWidget {
  const ElateFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElateFit',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAF7),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBFDCCB)),
      ),
      home: const MainShell(),
    );
  }
}

/// Hosts the bottom navigation and switches between the
/// Home, Workout, Progress, Serum, Breathing, Cardio, and Profile tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _openTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onOpenWorkout: () => _openTab(1),
        onOpenProgress: () => _openTab(2),
        onOpenSerum: () => _openTab(3),
        onOpenBreathing: () => _openTab(4),
        onOpenWeight: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WeightTrackerPage(
              onNavigate: (index) {
                Navigator.of(context).pop();
                _openTab(index);
              },
            ),
          ),
        ),
        onOpenSleepSounds: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SleepSoundsPage()),
        ),
        onOpenStretching: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const StretchingConfigurePage(),
          ),
        ),
      ),
      const WorkoutTrackerPage(),
      CalorieTrackerPage(onOpenProfile: () => _openTab(6)),
      const SerumTrackerPage(),
      const BreathingExercisePage(),
      const CardioConfigurePage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        selectedIndex: _index,
        indicatorColor: HomePage.lime,
        onDestinationSelected: _openTab,
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
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.onOpenWorkout,
    this.onOpenProgress,
    this.onOpenSerum,
    this.onOpenBreathing,
    this.onOpenWeight,
    this.onOpenSleepSounds,
    this.onOpenStretching,
  });

  final VoidCallback? onOpenWorkout;
  final VoidCallback? onOpenProgress;
  final VoidCallback? onOpenSerum;
  final VoidCallback? onOpenBreathing;
  final VoidCallback? onOpenWeight;
  final VoidCallback? onOpenSleepSounds;
  final VoidCallback? onOpenStretching;

  static const ink = AppColors.ink;
  static const muted = AppColors.muted;
  static const lime = AppColors.lime;
  static const mint = AppColors.mint;
  static const peach = AppColors.peach;
  static const lavender = AppColors.lavender;

  Future<Map<String, dynamic>> _fetchSnapshotData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    double calories = 0;
    double protein = 0;
    final foodRaw = prefs.getString(kFoodEntriesStorageKey);
    if (foodRaw != null) {
      try {
        final items = jsonDecode(foodRaw) as List;
        for (final item in items) {
          final entry = FoodEntry.fromJson(item as Map<String, dynamic>);
          if (entry.timestamp.year == now.year &&
              entry.timestamp.month == now.month &&
              entry.timestamp.day == now.day) {
            final food = entry.food;
            if (food != null) {
              final factor = entry.grams / 100;
              calories += food.calories * factor;
              protein += food.protein * factor;
            }
          }
        }
      } catch (_) {}
    }

    bool workoutDone = false;
    final workoutRaw = prefs.getString(kWorkoutEntriesStorageKey);
    if (workoutRaw != null) {
      try {
        final items = jsonDecode(workoutRaw) as List;
        for (final item in items) {
          final entry = WorkoutEntry.fromJson(item as Map<String, dynamic>);
          if (entry.createdAt.year == now.year &&
              entry.createdAt.month == now.month &&
              entry.createdAt.day == now.day) {
            workoutDone = true;
            break;
          }
        }
      } catch (_) {}
    }

    bool cardioDone = false;
    final cardioDays = prefs.getStringList('elateFitCardioCompletedDays') ?? [];
    if (cardioDays.contains(todayStr)) cardioDone = true;

    bool stretchDone = false;
    final stretchDays =
        prefs.getStringList('elateFitStretchCompletedDays') ?? [];
    if (stretchDays.contains(todayStr)) stretchDone = true;

    return {
      'calories': calories,
      'protein': protein,
      'workoutDone': workoutDone,
      'cardioDone': cardioDone,
      'stretchDone': stretchDone,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _header(),
                const SizedBox(height: 26),
                _snapshot(),
                const SizedBox(height: 26),
                _heading('Your wellness space', 'See all'),
                const SizedBox(height: 14),
                _features(),
                const SizedBox(height: 26),
                _heading('Today\'s rhythm', 'Edit plan'),
                const SizedBox(height: 14),
                _plan(),
              ]),
            ),
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
          color: ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.bolt_rounded, color: lime, size: 26),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning, Nandish',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Let’s make today feel good.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: null,
        style: const ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.white),
          foregroundColor: WidgetStatePropertyAll(ink),
        ),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    ],
  );

  Widget _snapshot() => FutureBuilder<Map<String, dynamic>>(
    future: _fetchSnapshotData(),
    builder: (context, snapshot) {
      final data =
          snapshot.data ??
          {
            'calories': 0.0,
            'protein': 0.0,
            'workoutDone': false,
            'cardioDone': false,
            'stretchDone': false,
          };

      final now = DateTime.now();
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      final dateStr =
          '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DAILY SNAPSHOT',
                  style: TextStyle(
                    color: lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calories Intake',
                        style: TextStyle(
                          color: Color(0xFFB6C3BC),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data['calories']!.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Protein Intake',
                        style: TextStyle(
                          color: Color(0xFFB6C3BC),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data['protein']!.toStringAsFixed(0)} g',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _taskIcon(
                  Icons.fitness_center_rounded,
                  data['workoutDone'],
                  'Workout',
                ),
                _taskIcon(
                  Icons.directions_run_rounded,
                  data['cardioDone'],
                  'Cardio',
                ),
                _taskIcon(
                  Icons.accessibility_new_rounded,
                  data['stretchDone'],
                  'Stretch',
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _taskIcon(IconData icon, bool isCompleted, String label) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCompleted
                    ? lime.withAlpha(50)
                    : Colors.white.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isCompleted ? lime : Colors.white54,
                size: 26,
              ),
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: ink, size: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isCompleted ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _heading(String title, String action) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        action,
        style: const TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _features() {
    const items = [
      _Feature('Lift', 'Workout tracker', Icons.fitness_center, peach),
      _Feature('Fuel', 'Calorie tracker', Icons.ramen_dining, lime),
      _Feature('Restore', 'Sleep sounds', Icons.nightlight_round, lavender),
      _Feature('Care', 'Medicine intake', Icons.medication_rounded, mint),
      _Feature('Breathe', 'Breathing exercise', Icons.air, mint),
      _Feature(
        'Stretch',
        'Stretching routine',
        Icons.accessibility_new_rounded,
        lavender,
      ),
      _Feature(
        'Balance',
        'Weight tracker',
        Icons.monitor_weight_rounded,
        peach,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.46,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: item.color,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: item.title == 'Fuel'
                ? onOpenProgress
                : item.title == 'Restore'
                ? onOpenSleepSounds
                : item.title == 'Lift'
                ? onOpenWorkout
                : item.title == 'Care'
                ? onOpenSerum
                : item.title == 'Breathe'
                ? onOpenBreathing
                : item.title == 'Stretch'
                ? onOpenStretching
                : item.title == 'Balance'
                ? onOpenWeight
                : null,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(item.icon, color: ink, size: 25),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _plan() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9EEE9)),
    ),
    child: const Column(
      children: [
        _PlanItem(
          '07:30',
          'Morning stretch',
          '5 min · Mobility',
          Icons.accessibility_new_rounded,
          peach,
        ),
        Divider(height: 26, color: Color(0xFFEFF2EF)),
        _PlanItem(
          '12:30',
          'Hydration check-in',
          '2 glasses · Daily goal',
          Icons.water_drop_rounded,
          mint,
        ),
        Divider(height: 26, color: Color(0xFFEFF2EF)),
        _PlanItem(
          '21:30',
          'Wind down',
          'Sleep sounds · 20 min',
          Icons.spa_rounded,
          lavender,
        ),
      ],
    ),
  );
}

class _Feature {
  const _Feature(this.title, this.subtitle, this.icon, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _PlanItem extends StatelessWidget {
  const _PlanItem(this.time, this.title, this.subtitle, this.icon, this.color);
  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 44,
        child: Text(
          time,
          style: const TextStyle(
            color: Color(0xFF87938C),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: HomePage.ink, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: HomePage.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF87938C), fontSize: 11),
            ),
          ],
        ),
      ),
      const Icon(Icons.chevron_right_rounded, color: Color(0xFFB5BEB8)),
    ],
  );
}
