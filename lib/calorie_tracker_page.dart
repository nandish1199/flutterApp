import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'profile_page.dart';

const String kFoodEntriesStorageKey = 'elateFitFoodEntries';

/// Defines micronutrient reference targets and food suggestions.
class MicroDef {
  const MicroDef(
    this.key,
    this.label,
    this.reference,
    this.unit,
    this.suggestions,
  );
  final String key;
  final String label;
  final double reference;
  final String unit;
  final String suggestions;

  double getTarget(String? gender) {
    if (gender == 'Male' && _maleRefs.containsKey(key)) return _maleRefs[key]!;
    if (gender == 'Female' && _femaleRefs.containsKey(key))
      return _femaleRefs[key]!;
    return reference;
  }
}

const _maleRefs = {
  'vitaminA': 0.9,
  'vitaminC': 90.0,
  'vitaminK': 0.12,
  'vitaminB1': 1.2,
  'vitaminB2': 1.3,
  'vitaminB3': 16.0,
  'iron': 8.0,
  'magnesium': 400.0,
  'zinc': 11.0,
  'potassium': 3400.0,
};

const _femaleRefs = {
  'vitaminA': 0.7,
  'vitaminC': 75.0,
  'vitaminK': 0.09,
  'vitaminB1': 1.1,
  'vitaminB2': 1.1,
  'vitaminB3': 14.0,
  'iron': 18.0,
  'magnesium': 310.0,
  'zinc': 8.0,
  'potassium': 2600.0,
};

const List<MicroDef> micronutrientDefs = [
  MicroDef(
    'vitaminA',
    'Vitamin A',
    0.6,
    'mg RAE',
    'Sweet potatoes, carrots, tuna, butternut squash, spinach, cantaloupe, lettuce, red bell peppers, chicken liver, mango',
  ),
  MicroDef(
    'vitaminC',
    'Vitamin C',
    45,
    'mg',
    'Oranges, strawberries, kiwi, bell peppers, broccoli, Brussels sprouts, tomatoes, papaya, lemons, grapefruits',
  ),
  MicroDef(
    'vitaminD',
    'Vitamin D',
    0.005,
    'mg',
    'Salmon, sardines, herring, canned tuna, cod liver oil, egg yolks, mushrooms, fortified milk, fortified orange juice, fortified cereals',
  ),
  MicroDef(
    'vitaminE',
    'Vitamin E',
    10,
    'mg',
    'Sunflower seeds, almonds, peanuts, spinach, broccoli, hazelnuts, pine nuts, avocado, red bell peppers, mango',
  ),
  MicroDef(
    'vitaminK',
    'Vitamin K',
    0.055,
    'mg',
    'Kale, spinach, broccoli, Brussels sprouts, cabbage, Swiss chard, collard greens, green beans, prunes, kiwi',
  ),
  MicroDef(
    'vitaminB1',
    'Vitamin B1 (Thiamine)',
    1.1,
    'mg',
    'Sunflower seeds, brown rice, whole wheat, green peas, lentils, pecans, black beans, macadamia nuts, edamame',
  ),
  MicroDef(
    'vitaminB2',
    'Vitamin B2 (Riboflavin)',
    1.1,
    'mg',
    'Milk, yogurt, cheese, eggs, chicken breast, salmon, almonds, spinach',
  ),
  MicroDef(
    'vitaminB3',
    'Vitamin B3 (Niacin)',
    14,
    'mg NE',
    'Chicken breast, turkey breast, chicken liver, tuna, salmon, peanuts, avocado, brown rice, whole wheat, mushrooms',
  ),
  MicroDef(
    'vitaminB6',
    'Vitamin B6',
    1.3,
    'mg',
    'Chickpeas, chicken liver, tuna, salmon, chicken breast, fortified cereals, potatoes, turkey, bananas, marinara sauce',
  ),
  MicroDef(
    'folate',
    'Folate (Vitamin B9)',
    0.4,
    'mg DFE',
    'Spinach, black-eyed peas, asparagus, Brussels sprouts, romaine lettuce, avocado, broccoli, mustard greens, green peas, kidney beans',
  ),
  MicroDef(
    'vitaminB12',
    'Vitamin B12',
    0.0024,
    'mg',
    'Chicken liver, clams, sardines, fortified nutritional yeast, trout, salmon, milk, yogurt, eggs',
  ),
  MicroDef(
    'calcium',
    'Calcium',
    1000,
    'mg',
    'Milk, cheese, yogurt, fortified orange juice, winter squash, edamame, tofu, canned sardines, almonds, kale',
  ),
  MicroDef(
    'iron',
    'Iron',
    8,
    'mg',
    'Red meat, poultry, seafood, beans, spinach, raisins, fortified cereals, peas, lentils',
  ),
  MicroDef(
    'magnesium',
    'Magnesium',
    310,
    'mg',
    'Pumpkin seeds, chia seeds, almonds, spinach, cashews, peanuts, edamame, black beans, peanut butter, brown rice',
  ),
  MicroDef(
    'zinc',
    'Zinc',
    8,
    'mg',
    'Oysters, crab, pumpkin seeds, turkey, cheddar cheese, shrimp, lentils, chickpeas',
  ),
  MicroDef(
    'iodine',
    'Iodine',
    0.15,
    'mg',
    'Seaweed, cod, milk, yogurt, cheese, iodized salt, shrimp, tuna, eggs, prunes',
  ),
  MicroDef(
    'selenium',
    'Selenium',
    0.055,
    'mg',
    'Brazil nuts, halibut, tuna, brown rice, eggs, turkey, chicken, cottage cheese, baked beans',
  ),
  MicroDef(
    'copper',
    'Copper',
    0.9,
    'mg',
    'Oysters, shiitake mushrooms, tofu, sweet potatoes, sesame seeds, cashews, chickpeas, salmon, dark chocolate, turkey',
  ),
  MicroDef(
    'potassium',
    'Potassium',
    3500,
    'mg',
    'Bananas, sweet potatoes, spinach, avocados, potatoes, white beans, tomatoes, yogurt, salmon, mushrooms',
  ),
  MicroDef(
    'phosphorus',
    'Phosphorus',
    700,
    'mg',
    'Chicken, turkey, salmon, milk, yogurt, sunflower seeds, pumpkin seeds, almonds, whole grains',
  ),
];

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
    required this.vitaminA,
    required this.vitaminC,
    required this.vitaminD,
    required this.vitaminE,
    required this.vitaminK,
    required this.vitaminB1,
    required this.vitaminB2,
    required this.vitaminB3,
    required this.vitaminB6,
    required this.folate,
    required this.vitaminB12,
    required this.calcium,
    required this.iron,
    required this.magnesium,
    required this.zinc,
    required this.iodine,
    required this.selenium,
    required this.copper,
    required this.potassium,
    required this.phosphorus,
  });

  final String label;
  final double calories,
      protein,
      saturatedFat,
      unsaturatedFat,
      solubleFiber,
      insolubleFiber;
  final double vitaminA,
      vitaminC,
      vitaminD,
      vitaminE,
      vitaminK,
      vitaminB1,
      vitaminB2,
      vitaminB3;
  final double vitaminB6,
      folate,
      vitaminB12,
      calcium,
      iron,
      magnesium,
      zinc,
      iodine;
  final double selenium, copper, potassium, phosphorus;
}

const Map<String, FoodItem> foodCatalog = {
  'rice': FoodItem(
    'RICE RAW',
    calories: 365,
    protein: 7.2,
    saturatedFat: 0.3,
    unsaturatedFat: 0.6,
    solubleFiber: 0.55,
    insolubleFiber: 1.92,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.04,
    vitaminK: 0,
    vitaminB1: 0.326,
    vitaminB2: 0.102,
    vitaminB3: 6.27,
    vitaminB6: 0.161,
    folate: 0.003,
    vitaminB12: 0,
    calcium: 8,
    iron: 1.5,
    magnesium: 115,
    zinc: 1.85,
    iodine: 0,
    selenium: 0.0148,
    copper: 0.27,
    potassium: 250,
    phosphorus: 303,
  ),
  'boiled_rice': FoodItem(
    'RICE BOILED',
    calories: 121.67,
    protein: 2.4,
    saturatedFat: 0.1,
    unsaturatedFat: 0.2,
    solubleFiber: 0.183,
    insolubleFiber: 0.64,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.013,
    vitaminK: 0,
    vitaminB1: 0.109,
    vitaminB2: 0.034,
    vitaminB3: 2.09,
    vitaminB6: 0.054,
    folate: 0.001,
    vitaminB12: 0,
    calcium: 2.67,
    iron: 0.5,
    magnesium: 38.33,
    zinc: 0.617,
    iodine: 0,
    selenium: 0.0049,
    copper: 0.09,
    potassium: 83.33,
    phosphorus: 101,
  ),
  'brown_rice': FoodItem(
    'BROWN RICE RAW',
    calories: 367,
    protein: 7.3,
    saturatedFat: 0.6,
    unsaturatedFat: 2.1,
    solubleFiber: 0.4,
    insolubleFiber: 3.0,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.59,
    vitaminK: 0.0019,
    vitaminB1: 0.401,
    vitaminB2: 0.093,
    vitaminB3: 6.4,
    vitaminB6: 0.509,
    folate: 0.038,
    vitaminB12: 0,
    calcium: 9,
    iron: 1.29,
    magnesium: 116,
    zinc: 2.13,
    iodine: 0,
    selenium: 0.0171,
    copper: 0.302,
    potassium: 250,
    phosphorus: 311,
  ),
  'boiled_brown_rice': FoodItem(
    'BROWN RICE BOILED',
    calories: 122.33,
    protein: 2.43,
    saturatedFat: 0.2,
    unsaturatedFat: 0.7,
    solubleFiber: 0.133,
    insolubleFiber: 1,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.197,
    vitaminK: 0.00063,
    vitaminB1: 0.134,
    vitaminB2: 0.031,
    vitaminB3: 2.13,
    vitaminB6: 0.17,
    folate: 0.0127,
    vitaminB12: 0,
    calcium: 3,
    iron: 0.43,
    magnesium: 38.67,
    zinc: 0.71,
    iodine: 0,
    selenium: 0.0057,
    copper: 0.101,
    potassium: 83.33,
    phosphorus: 103.67,
  ),
  'wheat': FoodItem(
    'WHOLE WHEAT RAW',
    calories: 340,
    protein: 13.2,
    saturatedFat: 0.43,
    unsaturatedFat: 1.453,
    solubleFiber: 1.2,
    insolubleFiber: 7.0,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.71,
    vitaminK: 0.0019,
    vitaminB1: 0.502,
    vitaminB2: 0.165,
    vitaminB3: 4.96,
    vitaminB6: 0.407,
    folate: 0.044,
    vitaminB12: 0,
    calcium: 34,
    iron: 3.6,
    magnesium: 137,
    zinc: 2.6,
    iodine: 0,
    selenium: 0.0618,
    copper: 0.41,
    potassium: 363,
    phosphorus: 357,
  ),
  'boiled_wheat': FoodItem(
    'WHOLE WHEAT BOILED',
    calories: 113.33,
    protein: 4.4,
    saturatedFat: 0.143,
    unsaturatedFat: 0.484,
    solubleFiber: 0.4,
    insolubleFiber: 2.333,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.237,
    vitaminK: 0.00063,
    vitaminB1: 0.167,
    vitaminB2: 0.055,
    vitaminB3: 1.65,
    vitaminB6: 0.136,
    folate: 0.0147,
    vitaminB12: 0,
    calcium: 11.33,
    iron: 1.2,
    magnesium: 45.67,
    zinc: 0.867,
    iodine: 0,
    selenium: 0.0206,
    copper: 0.137,
    potassium: 121,
    phosphorus: 119,
  ),
  'oats': FoodItem(
    'OATS RAW',
    calories: 389,
    protein: 16.9,
    saturatedFat: 1.22,
    unsaturatedFat: 4.72,
    solubleFiber: 3.5,
    insolubleFiber: 6,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.42,
    vitaminK: 0.002,
    vitaminB1: 0.763,
    vitaminB2: 0.139,
    vitaminB3: 0.961,
    vitaminB6: 0.119,
    folate: 0.056,
    vitaminB12: 0,
    calcium: 54,
    iron: 4.72,
    magnesium: 177,
    zinc: 3.97,
    iodine: 0,
    selenium: 0.028,
    copper: 0.626,
    potassium: 429,
    phosphorus: 523,
  ),
  'boiled_oats': FoodItem(
    'OATS BOILED',
    calories: 129.67,
    protein: 5.63,
    saturatedFat: 0.41,
    unsaturatedFat: 1.57,
    solubleFiber: 1.17,
    insolubleFiber: 2,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.14,
    vitaminK: 0.0007,
    vitaminB1: 0.254,
    vitaminB2: 0.046,
    vitaminB3: 0.32,
    vitaminB6: 0.04,
    folate: 0.019,
    vitaminB12: 0,
    calcium: 18,
    iron: 1.57,
    magnesium: 59,
    zinc: 1.32,
    iodine: 0,
    selenium: 0.0093,
    copper: 0.209,
    potassium: 143,
    phosphorus: 174.33,
  ),
  'jowar': FoodItem(
    'JOWAR RAW',
    calories: 329,
    protein: 10.62,
    saturatedFat: 0.61,
    unsaturatedFat: 1.8,
    solubleFiber: 1.5,
    insolubleFiber: 8,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.5,
    vitaminK: 0,
    vitaminB1: 0.332,
    vitaminB2: 0.096,
    vitaminB3: 3.688,
    vitaminB6: 0.443,
    folate: 0.02,
    vitaminB12: 0,
    calcium: 13,
    iron: 3.36,
    magnesium: 165,
    zinc: 1.67,
    iodine: 0,
    selenium: 0.0122,
    copper: 0.284,
    potassium: 363,
    phosphorus: 289,
  ),
  'boiled_jowar': FoodItem(
    'JOWAR BOILED',
    calories: 109.67,
    protein: 3.54,
    saturatedFat: 0.203,
    unsaturatedFat: 0.6,
    solubleFiber: 0.5,
    insolubleFiber: 2.67,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.167,
    vitaminK: 0,
    vitaminB1: 0.111,
    vitaminB2: 0.032,
    vitaminB3: 1.229,
    vitaminB6: 0.148,
    folate: 0.0067,
    vitaminB12: 0,
    calcium: 4.33,
    iron: 1.12,
    magnesium: 55,
    zinc: 0.557,
    iodine: 0,
    selenium: 0.0041,
    copper: 0.0947,
    potassium: 121,
    phosphorus: 96.33,
  ),
  'pearl_millet': FoodItem(
    'PEARL MILLET RAW',
    calories: 378,
    protein: 11.0,
    saturatedFat: 0.723,
    unsaturatedFat: 2.903,
    solubleFiber: 3.0,
    insolubleFiber: 7.0,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0.05,
    vitaminK: 0.0009,
    vitaminB1: 0.421,
    vitaminB2: 0.29,
    vitaminB3: 4.72,
    vitaminB6: 0.384,
    folate: 0.085,
    vitaminB12: 0,
    calcium: 8,
    iron: 3.01,
    magnesium: 114,
    zinc: 1.68,
    iodine: 0,
    selenium: 0.0027,
    copper: 0.75,
    potassium: 195,
    phosphorus: 285,
  ),
  'chickpeas': FoodItem(
    'CHICKPEAS RAW',
    calories: 378,
    protein: 20.47,
    saturatedFat: 0.603,
    unsaturatedFat: 4.108,
    solubleFiber: 2,
    insolubleFiber: 6,
    vitaminA: 0.003,
    vitaminC: 4,
    vitaminD: 0,
    vitaminE: 0.82,
    vitaminK: 0.009,
    vitaminB1: 0.477,
    vitaminB2: 0.212,
    vitaminB3: 1.541,
    vitaminB6: 0.535,
    folate: 0.557,
    vitaminB12: 0,
    calcium: 57,
    iron: 4.31,
    magnesium: 79,
    zinc: 2.76,
    iodine: 0,
    selenium: 0,
    copper: 0.656,
    potassium: 718,
    phosphorus: 252,
  ),
  'boiled_chickpeas': FoodItem(
    'CHICKPEAS BOILED',
    calories: 126,
    protein: 6.823,
    saturatedFat: 0.201,
    unsaturatedFat: 1.369,
    solubleFiber: 0.63,
    insolubleFiber: 2,
    vitaminA: 0.001,
    vitaminC: 1.333,
    vitaminD: 0,
    vitaminE: 0.273,
    vitaminK: 0.003,
    vitaminB1: 0.159,
    vitaminB2: 0.071,
    vitaminB3: 0.514,
    vitaminB6: 0.178,
    folate: 0.186,
    vitaminB12: 0,
    calcium: 19,
    iron: 1.437,
    magnesium: 26.33,
    zinc: 0.92,
    iodine: 0,
    selenium: 0,
    copper: 0.219,
    potassium: 239.33,
    phosphorus: 84,
  ),
  'green_gram': FoodItem(
    'GREEN GRAM RAW',
    calories: 347,
    protein: 23.86,
    saturatedFat: 0.348,
    unsaturatedFat: 0.545,
    solubleFiber: 1.5,
    insolubleFiber: 12.3,
    vitaminA: 0.011,
    vitaminC: 4.8,
    vitaminD: 0,
    vitaminE: 0.51,
    vitaminK: 0.009,
    vitaminB1: 0.621,
    vitaminB2: 0.233,
    vitaminB3: 2.251,
    vitaminB6: 0.382,
    folate: 0.625,
    vitaminB12: 0,
    calcium: 132,
    iron: 6.74,
    magnesium: 189,
    zinc: 2.68,
    iodine: 0,
    selenium: 0.0082,
    copper: 0.941,
    potassium: 1246,
    phosphorus: 367,
  ),
  'boiled_green_gram': FoodItem(
    'GREEN GRAM BOILED',
    calories: 115.67,
    protein: 7.953,
    saturatedFat: 0.116,
    unsaturatedFat: 0.182,
    solubleFiber: 0.5,
    insolubleFiber: 4.1,
    vitaminA: 0.0037,
    vitaminC: 1.6,
    vitaminD: 0,
    vitaminE: 0.17,
    vitaminK: 0.003,
    vitaminB1: 0.207,
    vitaminB2: 0.078,
    vitaminB3: 0.75,
    vitaminB6: 0.127,
    folate: 0.208,
    vitaminB12: 0,
    calcium: 44,
    iron: 2.247,
    magnesium: 63,
    zinc: 0.893,
    iodine: 0,
    selenium: 0.0027,
    copper: 0.314,
    potassium: 415.33,
    phosphorus: 122.33,
  ),
  'boiled_red_lentils': FoodItem(
    'RED LENTILS / MASOOR DAL BOILED',
    calories: 116,
    protein: 9.02,
    saturatedFat: 0.05,
    unsaturatedFat: 0.28,
    solubleFiber: 1.5,
    insolubleFiber: 6.4,
    vitaminA: 0.001,
    vitaminC: 1.5,
    vitaminD: 0,
    vitaminE: 0.11,
    vitaminK: 0.0017,
    vitaminB1: 0.169,
    vitaminB2: 0.073,
    vitaminB3: 1.06,
    vitaminB6: 0.178,
    folate: 0.181,
    vitaminB12: 0,
    calcium: 19,
    iron: 3.33,
    magnesium: 36,
    zinc: 1.27,
    iodine: 0,
    selenium: 0.0028,
    copper: 0.251,
    potassium: 369,
    phosphorus: 180,
  ),
  'boiled_kidney_beans': FoodItem(
    'KIDNEY BEANS / RAJMA BOILED',
    calories: 127,
    protein: 8.67,
    saturatedFat: 0.07,
    unsaturatedFat: 0.35,
    solubleFiber: 1.4,
    insolubleFiber: 5.0,
    vitaminA: 0,
    vitaminC: 1.2,
    vitaminD: 0,
    vitaminE: 0.03,
    vitaminK: 0.0084,
    vitaminB1: 0.16,
    vitaminB2: 0.058,
    vitaminB3: 0.578,
    vitaminB6: 0.12,
    folate: 0.13,
    vitaminB12: 0,
    calcium: 28,
    iron: 2.94,
    magnesium: 42,
    zinc: 1.07,
    iodine: 0,
    selenium: 0.0012,
    copper: 0.218,
    potassium: 405,
    phosphorus: 142,
  ),
  'banana': FoodItem(
    'BANANA',
    calories: 89,
    protein: 1.09,
    saturatedFat: 0.038,
    unsaturatedFat: 0.105,
    solubleFiber: 0.6,
    insolubleFiber: 2.0,
    vitaminA: 0.003,
    vitaminC: 8.7,
    vitaminD: 0,
    vitaminE: 0.1,
    vitaminK: 0.0005,
    vitaminB1: 0.031,
    vitaminB2: 0.073,
    vitaminB3: 0.665,
    vitaminB6: 0.367,
    folate: 0.02,
    vitaminB12: 0,
    calcium: 5,
    iron: 0.26,
    magnesium: 27,
    zinc: 0.15,
    iodine: 0,
    selenium: 0.001,
    copper: 0.078,
    potassium: 358,
    phosphorus: 22,
  ),
  'apple': FoodItem(
    'APPLE',
    calories: 52,
    protein: 0.26,
    saturatedFat: 0.028,
    unsaturatedFat: 0.058,
    solubleFiber: 1.0,
    insolubleFiber: 1.4,
    vitaminA: 0.003,
    vitaminC: 4.6,
    vitaminD: 0,
    vitaminE: 0.18,
    vitaminK: 0.0022,
    vitaminB1: 0.017,
    vitaminB2: 0.026,
    vitaminB3: 0.091,
    vitaminB6: 0.041,
    folate: 0.003,
    vitaminB12: 0,
    calcium: 6,
    iron: 0.12,
    magnesium: 5,
    zinc: 0.04,
    iodine: 0,
    selenium: 0,
    copper: 0.027,
    potassium: 107,
    phosphorus: 11,
  ),
  'orange': FoodItem(
    'ORANGE',
    calories: 47,
    protein: 0.94,
    saturatedFat: 0.015,
    unsaturatedFat: 0.048,
    solubleFiber: 1.4,
    insolubleFiber: 1.0,
    vitaminA: 0.011,
    vitaminC: 53.2,
    vitaminD: 0,
    vitaminE: 0.18,
    vitaminK: 0,
    vitaminB1: 0.087,
    vitaminB2: 0.04,
    vitaminB3: 0.282,
    vitaminB6: 0.06,
    folate: 0.03,
    vitaminB12: 0,
    calcium: 40,
    iron: 0.1,
    magnesium: 10,
    zinc: 0.07,
    iodine: 0,
    selenium: 0.0005,
    copper: 0.045,
    potassium: 181,
    phosphorus: 14,
  ),
  'mango': FoodItem(
    'MANGO',
    calories: 60,
    protein: 0.82,
    saturatedFat: 0.092,
    unsaturatedFat: 0.211,
    solubleFiber: 0.6,
    insolubleFiber: 1.0,
    vitaminA: 0.054,
    vitaminC: 36.4,
    vitaminD: 0,
    vitaminE: 0.9,
    vitaminK: 0.0042,
    vitaminB1: 0.028,
    vitaminB2: 0.038,
    vitaminB3: 0.669,
    vitaminB6: 0.119,
    folate: 0.043,
    vitaminB12: 0,
    calcium: 11,
    iron: 0.16,
    magnesium: 10,
    zinc: 0.09,
    iodine: 0,
    selenium: 0.0006,
    copper: 0.111,
    potassium: 168,
    phosphorus: 14,
  ),
  'boiled_potato': FoodItem(
    'POTATO BOILED (WITH SKIN)',
    calories: 87,
    protein: 1.87,
    saturatedFat: 0.02,
    unsaturatedFat: 0.04,
    solubleFiber: 0.6,
    insolubleFiber: 1.2,
    vitaminA: 0.001,
    vitaminC: 13.0,
    vitaminD: 0,
    vitaminE: 0.01,
    vitaminK: 0.0019,
    vitaminB1: 0.07,
    vitaminB2: 0.02,
    vitaminB3: 0.9,
    vitaminB6: 0.2,
    folate: 0.009,
    vitaminB12: 0,
    calcium: 8,
    iron: 0.31,
    magnesium: 20,
    zinc: 0.27,
    iodine: 0,
    selenium: 0.0002,
    copper: 0.09,
    potassium: 328,
    phosphorus: 44,
  ),
  'boiled_carrot': FoodItem(
    'CARROT BOILED',
    calories: 35,
    protein: 0.76,
    saturatedFat: 0.028,
    unsaturatedFat: 0.11,
    solubleFiber: 1.3,
    insolubleFiber: 1.7,
    vitaminA: 0.828,
    vitaminC: 3.6,
    vitaminD: 0,
    vitaminE: 0.6,
    vitaminK: 0.0137,
    vitaminB1: 0.046,
    vitaminB2: 0.04,
    vitaminB3: 0.603,
    vitaminB6: 0.129,
    folate: 0.014,
    vitaminB12: 0,
    calcium: 30,
    iron: 0.34,
    magnesium: 10,
    zinc: 0.2,
    iodine: 0,
    selenium: 0.0006,
    copper: 0.035,
    potassium: 235,
    phosphorus: 30,
  ),
  'boiled_spinach': FoodItem(
    'SPINACH BOILED',
    calories: 23,
    protein: 2.97,
    saturatedFat: 0.04,
    unsaturatedFat: 0.15,
    solubleFiber: 0.7,
    insolubleFiber: 1.7,
    vitaminA: 0.524,
    vitaminC: 9.8,
    vitaminD: 0,
    vitaminE: 2.08,
    vitaminK: 0.493,
    vitaminB1: 0.095,
    vitaminB2: 0.236,
    vitaminB3: 0.49,
    vitaminB6: 0.242,
    folate: 0.146,
    vitaminB12: 0,
    calcium: 136,
    iron: 3.57,
    magnesium: 87,
    zinc: 0.76,
    iodine: 0,
    selenium: 0.0015,
    copper: 0.17,
    potassium: 466,
    phosphorus: 56,
  ),
  'boiled_tomato': FoodItem(
    'TOMATO BOILED',
    calories: 18,
    protein: 0.9,
    saturatedFat: 0.03,
    unsaturatedFat: 0.12,
    solubleFiber: 0.3,
    insolubleFiber: 0.7,
    vitaminA: 0.042,
    vitaminC: 11.6,
    vitaminD: 0,
    vitaminE: 0.5,
    vitaminK: 0.007,
    vitaminB1: 0.03,
    vitaminB2: 0.015,
    vitaminB3: 0.5,
    vitaminB6: 0.07,
    folate: 0.009,
    vitaminB12: 0,
    calcium: 11,
    iron: 0.3,
    magnesium: 10,
    zinc: 0.15,
    iodine: 0,
    selenium: 0,
    copper: 0.05,
    potassium: 218,
    phosphorus: 24,
  ),
  'lemon': FoodItem(
    'LEMON',
    calories: 29,
    protein: 0.4,
    saturatedFat: 0.04,
    unsaturatedFat: 0.1,
    solubleFiber: 1.2,
    insolubleFiber: 1.6,
    vitaminA: 0.001,
    vitaminC: 45.0,
    vitaminD: 0,
    vitaminE: 0.15,
    vitaminK: 0,
    vitaminB1: 0.04,
    vitaminB2: 0.02,
    vitaminB3: 0.1,
    vitaminB6: 0.08,
    folate: 0.011,
    vitaminB12: 0,
    calcium: 26,
    iron: 0.6,
    magnesium: 8,
    zinc: 0.06,
    iodine: 0,
    selenium: 0.0004,
    copper: 0.037,
    potassium: 138,
    phosphorus: 16,
  ),
  'boiled_chicken': FoodItem(
    'CHICKEN BOILED',
    calories: 177,
    protein: 27.29,
    saturatedFat: 1.84,
    unsaturatedFat: 3.93,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.015,
    vitaminC: 0,
    vitaminD: 0.0001,
    vitaminE: 0.265,
    vitaminK: 0.0024,
    vitaminB1: 0.049,
    vitaminB2: 0.163,
    vitaminB3: 6.117,
    vitaminB6: 0.26,
    folate: 0.006,
    vitaminB12: 0.00022,
    calcium: 14,
    iron: 1.17,
    magnesium: 21,
    zinc: 1.99,
    iodine: 0,
    selenium: 0.0209,
    copper: 0.061,
    potassium: 180,
    phosphorus: 150,
  ),
  'boiled_egg': FoodItem(
    'EGG BOILED WHOLE',
    calories: 155,
    protein: 12.6,
    saturatedFat: 3.27,
    unsaturatedFat: 5.49,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.149,
    vitaminC: 0,
    vitaminD: 0.0022,
    vitaminE: 1.03,
    vitaminK: 0.0003,
    vitaminB1: 0.066,
    vitaminB2: 0.513,
    vitaminB3: 0.064,
    vitaminB6: 0.121,
    folate: 0.044,
    vitaminB12: 0.00111,
    calcium: 50,
    iron: 1.19,
    magnesium: 10,
    zinc: 1.05,
    iodine: 0,
    selenium: 0.0308,
    copper: 0.01,
    potassium: 126,
    phosphorus: 172,
  ),
  'boiled_egg_white': FoodItem(
    'EGG WHITE BOILED',
    calories: 52,
    protein: 10.7,
    saturatedFat: 0,
    unsaturatedFat: 0,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.011,
    vitaminC: 0,
    vitaminD: 0.0001,
    vitaminE: 0.86,
    vitaminK: 0.0047,
    vitaminB1: 0.003,
    vitaminB2: 0.35,
    vitaminB3: 0.088,
    vitaminB6: 0.041,
    folate: 0.003,
    vitaminB12: 0.00007,
    calcium: 7,
    iron: 0.08,
    magnesium: 11,
    zinc: 0.04,
    iodine: 0,
    selenium: 0.027,
    copper: 0.023,
    potassium: 163,
    phosphorus: 15,
  ),
  'boiled_mutton': FoodItem(
    'MUTTON BOILED',
    calories: 234,
    protein: 33.4,
    saturatedFat: 5.1,
    unsaturatedFat: 6.0,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0.0001,
    vitaminE: 0.1,
    vitaminK: 0.004,
    vitaminB1: 0.09,
    vitaminB2: 0.15,
    vitaminB3: 3.3,
    vitaminB6: 0.13,
    folate: 0.015,
    vitaminB12: 0.00096,
    calcium: 10,
    iron: 4.8,
    magnesium: 31,
    zinc: 3.4,
    iodine: 0,
    selenium: 0.0068,
    copper: 0.1,
    potassium: 409,
    phosphorus: 122,
  ),
  'boiled_fish': FoodItem(
    'FISH BOILED',
    calories: 146,
    protein: 24.2,
    saturatedFat: 1.0,
    unsaturatedFat: 3.2,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.027,
    vitaminC: 0,
    vitaminD: 0.005,
    vitaminE: 0.7,
    vitaminK: 0.001,
    vitaminB1: 0.05,
    vitaminB2: 0.12,
    vitaminB3: 3.5,
    vitaminB6: 0.46,
    folate: 0.006,
    vitaminB12: 0.0023,
    calcium: 20,
    iron: 0.5,
    magnesium: 30,
    zinc: 0.7,
    iodine: 0.05,
    selenium: 0.04,
    copper: 0.05,
    potassium: 400,
    phosphorus: 200,
  ),
  'boiled_milk': FoodItem(
    'MILK BOILED',
    calories: 61,
    protein: 3.15,
    saturatedFat: 1.865,
    unsaturatedFat: 1.007,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.046,
    vitaminC: 0,
    vitaminD: 0.0001,
    vitaminE: 0.07,
    vitaminK: 0.0003,
    vitaminB1: 0.046,
    vitaminB2: 0.169,
    vitaminB3: 0.089,
    vitaminB6: 0.036,
    folate: 0.005,
    vitaminB12: 0.00045,
    calcium: 113,
    iron: 0.03,
    magnesium: 10,
    zinc: 0.37,
    iodine: 0,
    selenium: 0.0037,
    copper: 0.025,
    potassium: 132,
    phosphorus: 84,
  ),
  'curd': FoodItem(
    'CURD',
    calories: 61,
    protein: 3.47,
    saturatedFat: 2.096,
    unsaturatedFat: 0.985,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.027,
    vitaminC: 0.5,
    vitaminD: 0.0001,
    vitaminE: 0.06,
    vitaminK: 0.0002,
    vitaminB1: 0.029,
    vitaminB2: 0.142,
    vitaminB3: 0.075,
    vitaminB6: 0.032,
    folate: 0.007,
    vitaminB12: 0.00037,
    calcium: 121,
    iron: 0.05,
    magnesium: 12,
    zinc: 0.59,
    iodine: 0,
    selenium: 0.0022,
    copper: 0.009,
    potassium: 155,
    phosphorus: 95,
  ),
  'paneer': FoodItem(
    'PANEER',
    calories: 344,
    protein: 20,
    saturatedFat: 18.02,
    unsaturatedFat: 3.86,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.155,
    vitaminC: 0,
    vitaminD: 0.0053,
    vitaminE: 0.24,
    vitaminK: 0.0015,
    vitaminB1: 0.272,
    vitaminB2: 0.669,
    vitaminB3: 0.509,
    vitaminB6: 0.296,
    folate: 0,
    vitaminB12: 0.00262,
    calcium: 597,
    iron: 0,
    magnesium: 58,
    zinc: 2.04,
    iodine: 0,
    selenium: 0.0093,
    copper: 0,
    potassium: 728,
    phosphorus: 490,
  ),
  'whey_protein': FoodItem(
    'WHEY PROTEIN (UNFLAVORED)',
    calories: 382,
    protein: 76.0,
    saturatedFat: 3.5,
    unsaturatedFat: 1.5,
    solubleFiber: 0,
    insolubleFiber: 0,
    vitaminA: 0.03,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 0,
    vitaminK: 0,
    vitaminB1: 0.2,
    vitaminB2: 1.2,
    vitaminB3: 0.5,
    vitaminB6: 0.1,
    folate: 0.01,
    vitaminB12: 0.0025,
    calcium: 550,
    iron: 0.5,
    magnesium: 70,
    zinc: 0.8,
    iodine: 0.05,
    selenium: 0.02,
    copper: 0.05,
    potassium: 500,
    phosphorus: 350,
  ),
  'peanut_butter': FoodItem(
    'PEANUT BUTTER (100% NATURAL)',
    calories: 588,
    protein: 25.0,
    saturatedFat: 10.0,
    unsaturatedFat: 40.0,
    solubleFiber: 2.0,
    insolubleFiber: 4.0,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 9.0,
    vitaminK: 0.003,
    vitaminB1: 0.11,
    vitaminB2: 0.1,
    vitaminB3: 13.2,
    vitaminB6: 0.5,
    folate: 0.074,
    vitaminB12: 0,
    calcium: 43,
    iron: 1.9,
    magnesium: 154,
    zinc: 2.5,
    iodine: 0,
    selenium: 0.005,
    copper: 0.4,
    potassium: 649,
    phosphorus: 358,
  ),
  'roasted_peanuts': FoodItem(
    'ROASTED PEANUTS',
    calories: 585,
    protein: 23.7,
    saturatedFat: 6.8,
    unsaturatedFat: 40.0,
    solubleFiber: 2.5,
    insolubleFiber: 6.0,
    vitaminA: 0,
    vitaminC: 0,
    vitaminD: 0,
    vitaminE: 6.9,
    vitaminK: 0.001,
    vitaminB1: 0.44,
    vitaminB2: 0.1,
    vitaminB3: 13.5,
    vitaminB6: 0.26,
    folate: 0.145,
    vitaminB12: 0,
    calcium: 54,
    iron: 2.26,
    magnesium: 176,
    zinc: 3.3,
    iodine: 0,
    selenium: 0.007,
    copper: 0.67,
    potassium: 658,
    phosphorus: 358,
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
  double calories = 0,
      protein = 0,
      saturatedFat = 0,
      unsaturatedFat = 0,
      solubleFiber = 0,
      insolubleFiber = 0;

  Map<String, double> micros = {
    'vitaminA': 0,
    'vitaminC': 0,
    'vitaminD': 0,
    'vitaminE': 0,
    'vitaminK': 0,
    'vitaminB1': 0,
    'vitaminB2': 0,
    'vitaminB3': 0,
    'vitaminB6': 0,
    'folate': 0,
    'vitaminB12': 0,
    'calcium': 0,
    'iron': 0,
    'magnesium': 0,
    'zinc': 0,
    'iodine': 0,
    'selenium': 0,
    'copper': 0,
    'potassium': 0,
    'phosphorus': 0,
  };

  void addFood(FoodItem food, double grams) {
    final factor = grams / 100;
    calories += food.calories * factor;
    protein += food.protein * factor;
    saturatedFat += food.saturatedFat * factor;
    unsaturatedFat += food.unsaturatedFat * factor;
    solubleFiber += food.solubleFiber * factor;
    insolubleFiber += food.insolubleFiber * factor;

    micros['vitaminA'] = micros['vitaminA']! + (food.vitaminA * factor);
    micros['vitaminC'] = micros['vitaminC']! + (food.vitaminC * factor);
    micros['vitaminD'] = micros['vitaminD']! + (food.vitaminD * factor);
    micros['vitaminE'] = micros['vitaminE']! + (food.vitaminE * factor);
    micros['vitaminK'] = micros['vitaminK']! + (food.vitaminK * factor);
    micros['vitaminB1'] = micros['vitaminB1']! + (food.vitaminB1 * factor);
    micros['vitaminB2'] = micros['vitaminB2']! + (food.vitaminB2 * factor);
    micros['vitaminB3'] = micros['vitaminB3']! + (food.vitaminB3 * factor);
    micros['vitaminB6'] = micros['vitaminB6']! + (food.vitaminB6 * factor);
    micros['folate'] = micros['folate']! + (food.folate * factor);
    micros['vitaminB12'] = micros['vitaminB12']! + (food.vitaminB12 * factor);
    micros['calcium'] = micros['calcium']! + (food.calcium * factor);
    micros['iron'] = micros['iron']! + (food.iron * factor);
    micros['magnesium'] = micros['magnesium']! + (food.magnesium * factor);
    micros['zinc'] = micros['zinc']! + (food.zinc * factor);
    micros['iodine'] = micros['iodine']! + (food.iodine * factor);
    micros['selenium'] = micros['selenium']! + (food.selenium * factor);
    micros['copper'] = micros['copper']! + (food.copper * factor);
    micros['potassium'] = micros['potassium']! + (food.potassium * factor);
    micros['phosphorus'] = micros['phosphorus']! + (food.phosphorus * factor);
  }
}

class _NutritionLineChartPainter extends CustomPainter {
  const _NutritionLineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final left = 8.0,
        top = 8.0,
        right = size.width - 8.0,
        bottom = size.height - 8.0;
    final width = right - left, height = bottom - top;
    final maximum = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    final scale = maximum == 0 ? 1.0 : maximum;

    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()..color = color;

    for (var index = 0; index < 3; index++) {
      final y = top + height * index / 2;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    if (values.isEmpty) return;
    final path = Path();
    final points = <Offset>[];

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? left + width / 2
          : left + width * index / (values.length - 1);
      final y = bottom - height * (values[index] / scale);
      final point = Offset(x, y);
      points.add(point);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
      canvas.drawCircle(point, 1.5, Paint()..color = AppColors.paper);
    }
  }

  @override
  bool shouldRepaint(covariant _NutritionLineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

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
  int _chartRange = 7;

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
      } catch (_) {}
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
          _entriesCard(todayEntries),
          const SizedBox(height: 22),
          _intakeTrendsCard(),
          const SizedBox(height: 22),
          _micronutrientsCard(totals),
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

  Widget _card({
    required List<Widget> children,
    Color borderColor = AppColors.line,
  }) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor),
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
        '$base\nFor ${_num(grams)} g: ${_num(food.calories * factor)} kcal · ${_num(food.protein * factor)} g protein',
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

  Widget _micronutrientsCard(NutritionTotals totals) {
    return _card(
      borderColor: AppColors.success,
      children: [
        _sectionTitle('TODAY\'S MICRONUTRIENTS'),
        const SizedBox(height: 6),
        const Text(
          'Based on today\'s catalog foods vs. standard targets.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: micronutrientDefs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final def = micronutrientDefs[index];
            final consumed = totals.micros[def.key] ?? 0;
            final target = def.getTarget(_profile?.gender);
            final progress = (consumed / target).clamp(0.0, 1.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      def.label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${consumed.toStringAsFixed(3)} / $target ${def.unit}',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.line,
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                  ),
                ),
                if (progress < 1.0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'FOODS TO CONSIDER:\n${def.suggestions}',
                    style: const TextStyle(
                      color: AppColors.soft,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

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

  Widget _intakeTrendsCard() {
    final today = DateTime.now();
    final dates = List.generate(_chartRange, (index) {
      final day = today.subtract(Duration(days: _chartRange - 1 - index));
      return DateTime(day.year, day.month, day.day);
    });
    final dailyTotals = dates.map((day) {
      return _totalsFor(
        _entries.where((entry) => _isSameDay(entry.timestamp, day)),
      );
    }).toList();
    final calories = dailyTotals.map((total) => total.calories).toList();
    final protein = dailyTotals.map((total) => total.protein).toList();

    return _card(
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('INTAKE TRENDS')),
            PopupMenuButton<int>(
              initialValue: _chartRange,
              onSelected: (value) => setState(() => _chartRange = value),
              color: AppColors.paper,
              itemBuilder: (context) => [7, 15, 30]
                  .map(
                    (value) =>
                        PopupMenuItem(value: value, child: Text('$value days')),
                  )
                  .toList(),
              child: Row(
                children: [
                  Text(
                    '$_chartRange days',
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
            ),
          ],
        ),
        const SizedBox(height: 16),
        _lineChart(
          title: 'Calories',
          value: calories.fold<double>(0, (sum, value) => sum + value),
          unit: 'kcal total',
          values: calories,
          color: AppColors.ink,
        ),
        const SizedBox(height: 18),
        _lineChart(
          title: 'Protein',
          value: protein.fold<double>(0, (sum, value) => sum + value),
          unit: 'g total',
          values: protein,
          color: AppColors.success,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${dates.first.month}/${dates.first.day}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            Text(
              '${dates.last.month}/${dates.last.day}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lineChart({
    required String title,
    required double value,
    required String unit,
    required List<double> values,
    required Color color,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${_num(value)} $unit',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 118,
        width: double.infinity,
        child: CustomPaint(
          painter: _NutritionLineChartPainter(values: values, color: color),
        ),
      ),
    ],
  );

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
