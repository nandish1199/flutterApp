import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const String kProfileStorageKey = 'elateFitUserProfile';

/// Stored user profile, mirroring the fields of the ElateFit web profile page.
class UserProfile {
  const UserProfile({
    required this.username,
    required this.gender,
    required this.calorieTarget,
    required this.age,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.target,
    required this.dietType,
    required this.lactoseIntolerant,
    required this.bodyType,
    required this.activityLevel,
    required this.notes,
    required this.updatedAt,
  });

  final String username;
  final String gender;
  final int? calorieTarget; // Optional manual override.
  final int age;
  final double height; // cm
  final double weight; // kg
  final int targetWeight; // kg
  final String target;
  final String dietType;
  final String lactoseIntolerant;
  final String bodyType;
  final String activityLevel;
  final String notes;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'username': username,
    'gender': gender,
    'calorieTarget': calorieTarget,
    'age': age,
    'height': height,
    'weight': weight,
    'targetWeight': targetWeight,
    'target': target,
    'dietType': dietType,
    'lactoseIntolerant': lactoseIntolerant,
    'bodyType': bodyType,
    'activityLevel': activityLevel,
    'notes': notes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    username: json['username'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    calorieTarget: (json['calorieTarget'] as num?)?.toInt(),
    age: (json['age'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toDouble() ?? 0,
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    targetWeight: (json['targetWeight'] as num?)?.toInt() ?? 0,
    target: json['target'] as String? ?? '',
    dietType: json['dietType'] as String? ?? '',
    lactoseIntolerant: json['lactoseIntolerant'] as String? ?? '',
    bodyType: json['bodyType'] as String? ?? '',
    activityLevel: json['activityLevel'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Daily nutrition goals derived from a profile.
class NutritionTargets {
  const NutritionTargets({
    required this.calories,
    required this.calculatedCalories,
    required this.protein,
    required this.saturatedFat,
    required this.unsaturatedFat,
    required this.solubleFiber,
    required this.insolubleFiber,
  });

  final int calories;
  final int calculatedCalories;
  final int protein;
  final int saturatedFat;
  final int unsaturatedFat;
  final int solubleFiber;
  final int insolubleFiber;
}

double? calculateBmi(double heightCm, double weightKg) {
  if (heightCm <= 0 || weightKg <= 0) return null;
  final heightMeters = heightCm / 100;
  return weightKg / (heightMeters * heightMeters);
}

String bmiLabel(double? bmi) {
  if (bmi == null) return 'Not available';
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Healthy range';
  if (bmi < 30) return 'Overweight';
  return 'Higher range';
}

double activityFactor(String level) => switch (level) {
  'Sedentary' => 1.2,
  'Light' => 1.375,
  'Moderate' => 1.55,
  'Active' => 1.725,
  'Very active' => 1.9,
  _ => 1.2,
};

double bodyTypeFactor(String bodyType) => switch (bodyType) {
  'Ectomorphic' => 1.1,
  'Mesomorphic' => 1.0,
  'Endomorphic' => 0.9,
  _ => 1.0,
};

double targetFactor(String target) => switch (target) {
  'Lose weight' => 0.85,
  'Maintain weight' => 1.0,
  'Gain weight' => 1.15,
  _ => 1.0,
};

double _proteinFactor(UserProfile profile) {
  final base = switch (profile.bodyType) {
    'Ectomorphic' => 1.9,
    'Mesomorphic' => 1.7,
    'Endomorphic' => 1.5,
    _ => 1.6,
  };
  if (profile.target == 'Gain weight') return base + 0.2;
  if (profile.target == 'Lose weight') {
    return base - 0.1 < 1.4 ? 1.4 : base - 0.1;
  }
  return base;
}

/// Same calculation as the web version (Mifflin-St Jeor + adjustments).
NutritionTargets calculateNutritionTargets(UserProfile profile) {
  final isFemale = profile.gender == 'Female';
  final baseCalories =
      10 * profile.weight +
      6.25 * profile.height -
      5 * profile.age +
      (isFemale ? -161 : 5);
  final calculatedCalories =
      (baseCalories *
              activityFactor(profile.activityLevel) *
              bodyTypeFactor(profile.bodyType) *
              targetFactor(profile.target))
          .round();
  final calorieOverride = profile.calorieTarget;
  final calories = (calorieOverride != null && calorieOverride > 0)
      ? calorieOverride
      : calculatedCalories;
  final minRate = isFemale ? 1.3 : 1.4;
  final adjustedRate = _proteinFactor(profile) - (isFemale ? 0.1 : 0.0);
  final proteinRate = minRate > adjustedRate ? minRate : adjustedRate;
  final protein = (profile.weight * proteinRate).round();
  final saturatedFat = (calories * 0.07 / 9).round();
  final unsaturatedFat = (calories * 0.17 / 9).round();
  final fiberFromCalories = (calories / 1000 * 14).round();
  final minFiber = isFemale ? 25 : 38;
  final totalFiber = minFiber > fiberFromCalories
      ? minFiber
      : fiberFromCalories;
  final solubleFiber = (totalFiber * 0.25).round();
  final insoluble = totalFiber - solubleFiber;
  return NutritionTargets(
    calories: calories,
    calculatedCalories: calculatedCalories,
    protein: protein,
    saturatedFat: saturatedFat,
    unsaturatedFat: unsaturatedFat,
    solubleFiber: solubleFiber,
    insolubleFiber: insoluble < 1 ? 1 : insoluble,
  );
}

Future<UserProfile?> loadUserProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kProfileStorageKey);
  if (raw == null) return null;
  try {
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<void> saveUserProfile(UserProfile profile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kProfileStorageKey, jsonEncode(profile.toJson()));
}

String formatDateTime(DateTime value) {
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
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '${months[value.month - 1]} ${value.day}, ${value.year} · $hour:$minute $period';
}

/// Profile form + snapshot page. Stores data in local storage
/// (SharedPreferences) as a JSON record.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _genderOptions = ['Male', 'Female', 'Prefer not to say'];
  static const _targetOptions = [
    'Lose weight',
    'Gain weight',
    'Maintain weight',
  ];
  static const _dietOptions = ['Vegetarian', 'Non-vegetarian', 'Eggetarian'];
  static const _lactoseOptions = [
    'Not lactose intolerant',
    'Lactose intolerant',
  ];
  static const _bodyTypeOptions = ['Ectomorphic', 'Mesomorphic', 'Endomorphic'];
  static const _activityOptions = [
    'Sedentary',
    'Light',
    'Moderate',
    'Active',
    'Very active',
  ];

  final _usernameController = TextEditingController();
  final _calorieTargetController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _notesController = TextEditingController();

  String? _gender;
  String? _target;
  String? _dietType;
  String? _lactose;
  String? _bodyType;
  String? _activityLevel;

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
    _usernameController.dispose();
    _calorieTargetController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await loadUserProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (profile != null) _populate(profile);
    });
  }

  void _populate(UserProfile profile) {
    _usernameController.text = profile.username;
    _calorieTargetController.text = profile.calorieTarget?.toString() ?? '';
    _ageController.text = profile.age.toString();
    _heightController.text = profile.height.toString();
    _weightController.text = profile.weight.toString();
    _targetWeightController.text = profile.targetWeight.toString();
    _notesController.text = profile.notes;
    _gender = profile.gender.isEmpty ? null : profile.gender;
    _target = profile.target.isEmpty ? null : profile.target;
    _dietType = profile.dietType.isEmpty ? null : profile.dietType;
    _lactose = profile.lactoseIntolerant.isEmpty
        ? null
        : profile.lactoseIntolerant;
    _bodyType = profile.bodyType.isEmpty ? null : profile.bodyType;
    _activityLevel = profile.activityLevel.isEmpty
        ? null
        : profile.activityLevel;
  }

  String? _validate() {
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final targetWeight = int.tryParse(_targetWeightController.text.trim());
    final calorieText = _calorieTargetController.text.trim();
    final calorieTarget = calorieText.isEmpty
        ? null
        : int.tryParse(calorieText);

    if (_usernameController.text.trim().isEmpty ||
        _gender == null ||
        age == null ||
        age <= 0 ||
        height == null ||
        height <= 0 ||
        weight == null ||
        weight <= 0 ||
        targetWeight == null ||
        targetWeight <= 0) {
      return 'Please complete the username, gender, age, height, weight, and whole-number target weight fields.';
    }
    if (calorieText.isNotEmpty &&
        (calorieTarget == null || calorieTarget < 0)) {
      return 'Set a whole-number calorie target or leave it blank to use the calculated target.';
    }
    if (_target == null ||
        _dietType == null ||
        _lactose == null ||
        _bodyType == null ||
        _activityLevel == null) {
      return 'Please choose your target, diet, lactose preference, body type, and activity level.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      setState(() {
        _status = error;
        _statusIsError = true;
      });
      return;
    }
    final calorieText = _calorieTargetController.text.trim();
    final profile = UserProfile(
      username: _usernameController.text.trim(),
      gender: _gender!,
      calorieTarget: calorieText.isEmpty ? null : int.parse(calorieText),
      age: int.parse(_ageController.text.trim()),
      height: double.parse(_heightController.text.trim()),
      weight: double.parse(_weightController.text.trim()),
      targetWeight: int.parse(_targetWeightController.text.trim()),
      target: _target!,
      dietType: _dietType!,
      lactoseIntolerant: _lactose!,
      bodyType: _bodyType!,
      activityLevel: _activityLevel!,
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );
    await saveUserProfile(profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _status = 'Profile saved successfully.';
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(),
          const SizedBox(height: 22),
          _formCard(),
          const SizedBox(height: 22),
          _snapshot(),
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
          Icons.person_rounded,
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
              'Your profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Measurements, targets & diet preferences.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
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

  Widget _labeled(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    bool decimal = false,
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: decimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: const TextStyle(
      color: AppColors.ink,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    decoration: _fieldDecoration(hint),
  );

  Widget _dropdown(
    String? value,
    List<String> options,
    String hint,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    items: options
        .map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(
              option,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: (next) => setState(() => onChanged(next)),
    decoration: _fieldDecoration(hint),
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
    dropdownColor: AppColors.paper,
  );

  Widget _formCard() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('PROFILE FORM'),
        const SizedBox(height: 14),
        _labeled(
          'Username',
          _textField(_usernameController, 'Enter your name'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _labeled(
                'Gender',
                _dropdown(
                  _gender,
                  _genderOptions,
                  'Choose',
                  (v) => _gender = v,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'Calorie target (optional)',
                _textField(_calorieTargetController, 'Auto', decimal: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labeled('Age', _textField(_ageController, '25'))),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'Height in cm',
                _textField(_heightController, '170', decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _labeled(
                'Weight in kg',
                _textField(_weightController, '65', decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'Target weight in kg',
                _textField(_targetWeightController, '60'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _labeled(
          'Target',
          _dropdown(_target, _targetOptions, 'Choose a target', (v) {
            _target = v;
          }),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _labeled(
                'Diet preference',
                _dropdown(_dietType, _dietOptions, 'Choose', (v) {
                  _dietType = v;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'Lactose tolerance',
                _dropdown(_lactose, _lactoseOptions, 'Choose', (v) {
                  _lactose = v;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _labeled(
                'Body type',
                _dropdown(_bodyType, _bodyTypeOptions, 'Choose', (v) {
                  _bodyType = v;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _labeled(
                'Activity level',
                _dropdown(_activityLevel, _activityOptions, 'Choose', (v) {
                  _activityLevel = v;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _labeled(
          'Health notes or allergies (optional)',
          _textField(
            _notesController,
            'Add any food preferences, allergies, or fitness notes.',
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.lime,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text(
              'Save profile',
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

  Widget _snapshot() {
    final profile = _profile;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('PROFILE SNAPSHOT'),
          const SizedBox(height: 14),
          if (profile == null)
            const Text(
              'Complete the form and save to store your measurements, target, and dietary preferences on this device.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            )
          else
            _snapshotContent(profile),
        ],
      ),
    );
  }

  Widget _snapshotContent(UserProfile profile) {
    final bmi = calculateBmi(profile.height, profile.weight);
    final bmiText = bmi == null
        ? 'Not available'
        : '${bmi.toStringAsFixed(1)} (${bmiLabel(bmi)})';
    final nutrition = calculateNutritionTargets(profile);
    final stats = <(String, String)>[
      ('Gender', profile.gender.isEmpty ? 'Not specified' : profile.gender),
      ('Age', '${profile.age} years'),
      ('Height', '${profile.height} cm'),
      ('Weight', '${profile.weight} kg'),
      ('Target weight', '${profile.targetWeight} kg'),
      ('BMI', bmiText),
      ('Diet', profile.dietType),
      ('Body type', profile.bodyType),
      ('Lactose', profile.lactoseIntolerant),
      ('Activity', profile.activityLevel),
      ('Calculated calories', '${nutrition.calculatedCalories} kcal'),
      ('Daily calorie target', '${nutrition.calories} kcal'),
      ('Daily protein', '${nutrition.protein} g'),
      ('Saturated fat limit', '${nutrition.saturatedFat} g'),
      ('Unsaturated fat', '${nutrition.unsaturatedFat} g'),
      ('Soluble fiber', '${nutrition.solubleFiber} g'),
      ('Insoluble fiber', '${nutrition.insolubleFiber} g'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Saved ${formatDateTime(profile.updatedAt)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.target,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.45,
          ),
          itemBuilder: (context, index) {
            final stat = stats[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tiles[index % AppColors.tiles.length],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.$1.toUpperCase(),
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
                    stat.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (profile.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              profile.notes,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
