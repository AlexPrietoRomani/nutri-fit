import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/supabase_config.dart';

class FoodLog {
  final int? id;
  final String userId;
  final DateTime loggedAt;
  final String mealType; // 'breakfast', 'lunch', 'dinner', 'snack'
  final String foodName;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingSizeG;

  FoodLog({
    this.id,
    required this.userId,
    required this.loggedAt,
    required this.mealType,
    required this.foodName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.servingSizeG,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as int?,
      userId: json['user_id'] as String,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      mealType: json['meal_type'] as String,
      foodName: json['food_name'] as String,
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      servingSizeG: (json['serving_size_g'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'user_id': userId,
      'logged_at': loggedAt.toIso8601String(),
      'meal_type': mealType,
      'food_name': foodName,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'serving_size_g': servingSizeG,
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
}

class UserGoals {
  final String userId;
  final int targetCalories;
  final double targetProteinG;
  final double targetCarbsG;
  final double targetFatG;
  final String goalType;

  UserGoals({
    required this.userId,
    required this.targetCalories,
    required this.targetProteinG,
    required this.targetCarbsG,
    required this.targetFatG,
    required this.goalType,
  });

  factory UserGoals.fromJson(Map<String, dynamic> json) {
    return UserGoals(
      userId: json['user_id'] as String,
      targetCalories: json['target_calories'] as int,
      targetProteinG: (json['target_protein_g'] as num).toDouble(),
      targetCarbsG: (json['target_carbs_g'] as num).toDouble(),
      targetFatG: (json['target_fat_g'] as num).toDouble(),
      goalType: json['goal_type'] as String? ?? 'maintenance',
    );
  }
}

class NutritionProvider extends ChangeNotifier {
  final SupabaseClient _client;

  NutritionProvider({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  UserGoals? _goals;
  List<FoodLog> _foodLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  UserGoals? get goals => _goals;
  List<FoodLog> get foodLogs => _foodLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalCalories => _foodLogs.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => _foodLogs.fold(0, (sum, item) => sum + item.proteinG);
  double get totalCarbs => _foodLogs.fold(0, (sum, item) => sum + item.carbsG);
  double get totalFat => _foodLogs.fold(0, (sum, item) => sum + item.fatG);

  List<FoodLog> getMealsOfType(String type) => _foodLogs.where((item) => item.mealType == type).toList();

  String get _currentUserId {
    return _client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';
  }

  Future<void> loadDailyData(DateTime date) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _currentUserId;

      final goalsData = await _client
          .schema('nutrition')
          .from('user_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (goalsData != null) {
        _goals = UserGoals.fromJson(goalsData);
      } else {
        _goals = UserGoals(
          userId: userId,
          targetCalories: 2000,
          targetProteinG: 150.0,
          targetCarbsG: 200.0,
          targetFatG: 65.0,
          goalType: 'maintenance',
        );
      }

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      final logsData = await _client
          .schema('nutrition')
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lte('logged_at', endOfDay.toIso8601String())
          .order('logged_at', ascending: true);

      _foodLogs = (logsData as List)
          .map((json) => FoodLog.fromJson(json as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> addFoodLog({
    required String foodName,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double servingSizeG,
    required String mealType,
    required DateTime date,
  }) async {
    try {
      final userId = _currentUserId;
      final logDate = DateTime(date.year, date.month, date.day, DateTime.now().hour, DateTime.now().minute);

      final insertedData = await _client
          .schema('nutrition')
          .from('food_logs')
          .insert({
            'user_id': userId,
            'logged_at': logDate.toIso8601String(),
            'meal_type': mealType,
            'food_name': foodName,
            'calories': calories,
            'protein_g': proteinG,
            'carbs_g': carbsG,
            'fat_g': fatG,
            'serving_size_g': servingSizeG,
          })
          .select()
          .single();

      _foodLogs.add(FoodLog.fromJson(insertedData));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFoodLog(int id) async {
    try {
      await _client
          .schema('nutrition')
          .from('food_logs')
          .delete()
          .eq('id', id);

      _foodLogs.removeWhere((item) => item.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> searchBarcode(String barcode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cacheData = await _client
          .schema('nutrition')
          .from('food_cache')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (cacheData != null) {
        _isLoading = false;
        notifyListeners();
        return cacheData;
      }

      await Future.delayed(const Duration(milliseconds: 800));

      Map<String, dynamic>? mockResult;
      if (barcode == '7501055310884') {
        mockResult = {
          'barcode': barcode,
          'food_name': 'Atún en Agua Tuny (Lata)',
          'calories': 116.0,
          'protein_g': 25.0,
          'carbs_g': 0.0,
          'fat_g': 1.8,
          'serving_size_g': 100.0,
        };
      } else if (barcode == '7501000111207') {
        mockResult = {
          'barcode': barcode,
          'food_name': 'Leche Entera Lala (1L)',
          'calories': 146.0,
          'protein_g': 7.8,
          'carbs_g': 11.6,
          'fat_g': 7.6,
          'serving_size_g': 240.0,
        };
      } else if (barcode == '0041220516599') {
        mockResult = {
          'barcode': barcode,
          'food_name': 'Avena en Hojuelas Quaker (Organic)',
          'calories': 150.0,
          'protein_g': 5.0,
          'carbs_g': 27.0,
          'fat_g': 2.5,
          'serving_size_g': 40.0,
        };
      } else {
        final lastDigit = int.tryParse(barcode.isNotEmpty ? barcode[-1] : '5') ?? 5;
        final foodNames = [
          'Yogurt Griego Fage',
          'Barra de Proteína Quest',
          'Pan Integral Bimbo Cero Cero',
          'Galletas Marias Pozuelo',
          'Crema de Cacahuate Jif',
          'Almendras Naturales Kirkland',
          'Arroz Integral Precocido Verde Valle',
          'Pasta Spaghetti Barilla',
          'Pechuga de Pavo Fud Lunas',
          'Queso Cottage Lyncott'
        ];
        
        final selectedName = foodNames[lastDigit % len(foodNames)]
        mockResult = {
          'barcode': barcode,
          'food_name': f'{selectedName} (Escaneado)',
          'calories': float(80 + lastDigit * 25),
          'protein_g': float(2 + lastDigit * 1.5),
          'carbs_g': float(5 + lastDigit * 3.5),
          'fat_g': float(0.5 + lastDigit * 0.8),
          'serving_size_g': 100.0,
        }

      await _client
          .schema('nutrition')
          .from('food_cache')
          .upsert(mockResult);

      _isLoading = false;
      notifyListeners();
      return mockResult;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
