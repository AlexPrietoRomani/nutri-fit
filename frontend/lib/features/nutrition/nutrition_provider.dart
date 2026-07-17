import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/supabase_config.dart';

/// Recalcula los macros de un plato a partir de su composición por ingredientes
/// (T18.8.2). Función PURA y testeable sin Supabase.
///
/// [items] es la composición: cada item `{ingredient_id, grams}`.
/// [ingredientsById] mapea ingredient_id -> fila de `nutrition.ingredients`
/// (con los campos `*_per_100`). Los ids ausentes en el mapa se ignoran.
///
/// Devuelve `{calories, protein_g, carbs_g, fat_g}` sumando
/// `grams/100 * <campo>_per_100` por ingrediente, redondeado a 1 decimal.
Map<String, double> macrosFromIngredients(
  List<Map<String, dynamic>> items,
  Map<int, Map<String, dynamic>> ingredientsById,
) {
  double calories = 0, protein = 0, carbs = 0, fat = 0;
  for (final item in items) {
    final id = (item['ingredient_id'] as num?)?.toInt();
    final ing = id == null ? null : ingredientsById[id];
    if (ing == null) continue; // id ausente en el mapa: se ignora
    final factor = ((item['grams'] as num?)?.toDouble() ?? 0) / 100.0;
    double per(String key) => (ing[key] as num?)?.toDouble() ?? 0;
    calories += factor * per('calories_per_100');
    protein += factor * per('protein_per_100');
    carbs += factor * per('carbs_per_100');
    fat += factor * per('fat_per_100');
  }
  double r(double v) => (v * 10).round() / 10;
  return {
    'calories': r(calories),
    'protein_g': r(protein),
    'carbs_g': r(carbs),
    'fat_g': r(fat),
  };
}

/// Los 7 micronutrientes por 100 g/ml que `nutrition.ingredients` puede traer.
/// Mapea la clave de columna -> (etiqueta legible, unidad). Orden estable.
const microNutrients = <String, (String, String)>{
  'iron_mg': ('Hierro', 'mg'),
  'calcium_mg': ('Calcio', 'mg'),
  'sodium_mg': ('Sodio', 'mg'),
  'potassium_mg': ('Potasio', 'mg'),
  'vitamin_c_mg': ('Vitamina C', 'mg'),
  'vitamin_a_ug': ('Vitamina A', 'µg'),
  'zinc_mg': ('Zinc', 'mg'),
};

/// Suma los micronutrientes de un plato desde su composición (T18.5.2).
/// Función PURA y testeable sin Supabase.
///
/// Como los micros son un subconjunto PARCIAL y algunos ingredientes los tienen
/// NULL, los NULL se IGNORAN (no cuentan como 0). Un micro solo aparece en el
/// resultado si al menos un ingrediente aportó un valor no-NULL para él; si
/// todos son NULL/ausentes, el micro se OMITE (ausencia honesta, no un 0 falso).
///
/// [items] es `{ingredient_id, grams}`; [ingredientsById] mapea id -> fila.
/// Suma `grams/100 * <micro>` y redondea a 1 decimal.
Map<String, double> microsFromIngredients(
  List<Map<String, dynamic>> items,
  Map<int, Map<String, dynamic>> ingredientsById,
) {
  final totals = <String, double>{};
  final present = <String>{};
  for (final item in items) {
    final id = (item['ingredient_id'] as num?)?.toInt();
    final ing = id == null ? null : ingredientsById[id];
    if (ing == null) continue;
    final factor = ((item['grams'] as num?)?.toDouble() ?? 0) / 100.0;
    for (final key in microNutrients.keys) {
      final raw = ing[key] as num?;
      if (raw == null) continue; // NULL: no cuenta
      present.add(key);
      totals[key] = (totals[key] ?? 0) + factor * raw.toDouble();
    }
  }
  return {
    for (final key in microNutrients.keys)
      if (present.contains(key)) key: (totals[key]! * 10).round() / 10,
  };
}

/// Macros efectivos de un plato con FALLBACK a macros planas (T18.8.2).
///
/// Si el plato trae composición (`dish['ingredients']` no null ni vacío), la
/// recalcula con [macrosFromIngredients]. Si NO trae composición (NULL/vacío,
/// caso de la mayoría de platos del catálogo), devuelve las macros planas
/// existentes del plato (`calories/protein_g/carbs_g/fat_g`), preservando la
/// compatibilidad con los platos que nunca declararon ingredientes.
Map<String, double> dishMacros(
  Map<String, dynamic> dish,
  Map<int, Map<String, dynamic>> ingredientsById,
) {
  final raw = dish['ingredients'];
  if (raw is List && raw.isNotEmpty) {
    final items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return macrosFromIngredients(items, ingredientsById);
  }
  double f(String key) => (dish[key] as num?)?.toDouble() ?? 0;
  return {
    'calories': f('calories'),
    'protein_g': f('protein_g'),
    'carbs_g': f('carbs_g'),
    'fat_g': f('fat_g'),
  };
}

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
  final SupabaseClient? _clientOverride;

  NutritionProvider({SupabaseClient? client}) : _clientOverride = client;

  // Se resuelve perezosamente (no en el constructor): instanciar
  // `SupabaseConfig.client` antes de que `Supabase.initialize()` haya
  // corrido lanza una excepción síncrona (ver INC-015, docs/logs/log.md),
  // lo que rompía `NutritionProvider()` incluso en tests que solo usan los
  // seams inyectables (`fetchOverride`/`setDefaultOverride`) y nunca tocan
  // el cliente real.
  SupabaseClient get _client => _clientOverride ?? SupabaseConfig.client;

  UserGoals? _goals;
  List<FoodLog> _foodLogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _mealPlans = [];

  UserGoals? get goals => _goals;
  List<FoodLog> get foodLogs => _foodLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get mealPlans => List.unmodifiable(_mealPlans);

  /// Plan de comida marcado como predeterminado (`is_default == true`), o
  /// `null` si no hay ninguno marcado (T16.3.1). Usado por `DiaryScreen`
  /// para comparar lo planificado vs. lo realmente registrado por comida.
  Map<String, dynamic>? get defaultMealPlan {
    for (final plan in _mealPlans) {
      if (plan['is_default'] == true) return plan;
    }
    return null;
  }

  double get totalCalories => _foodLogs.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => _foodLogs.fold(0, (sum, item) => sum + item.proteinG);
  double get totalCarbs => _foodLogs.fold(0, (sum, item) => sum + item.carbsG);
  double get totalFat => _foodLogs.fold(0, (sum, item) => sum + item.fatG);

  List<FoodLog> getMealsOfType(String type) => _foodLogs.where((item) => item.mealType == type).toList();

  String get _currentUserId {
    return _client.auth.currentUser!.id;
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

  /// Carga los planes de comida guardados por el usuario (`nutrition.meal_plans`).
  ///
  /// [fetchOverride] permite inyectar la respuesta en tests sin levantar un
  /// `SupabaseClient` real (mismo seam que
  /// `TrainingProvider.fetchSavedRoutines`, ver INC-015 en docs/logs/log.md).
  Future<void> fetchMealPlans({
    Future<List<Map<String, dynamic>>> Function()? fetchOverride,
  }) async {
    try {
      if (fetchOverride != null) {
        _mealPlans = await fetchOverride();
      } else {
        final data = await _client
            .schema('nutrition')
            .from('meal_plans')
            .select()
            .order('created_at', ascending: false);
        _mealPlans = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Marca [planId] como predeterminado (`nutrition.meal_plans.is_default`),
  /// desmarcando primero cualquier otro plan que ya lo fuera del usuario, y
  /// refresca [mealPlans]. Mismo patrón que `TrainingProvider.setDefaultRoutine`.
  Future<void> setDefaultMealPlan(
    String planId, {
    Future<void> Function()? setDefaultOverride,
    Future<List<Map<String, dynamic>>> Function()? fetchOverride,
  }) async {
    try {
      if (setDefaultOverride != null) {
        await setDefaultOverride();
      } else {
        final userId = _currentUserId;
        await _client
            .schema('nutrition')
            .from('meal_plans')
            .update({'is_default': false})
            .eq('user_id', userId)
            .eq('is_default', true);
        await _client
            .schema('nutrition')
            .from('meal_plans')
            .update({'is_default': true})
            .eq('id', planId);
      }
      await fetchMealPlans(fetchOverride: fetchOverride);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Busca platos en `nutrition.food_catalog` por nombre (T17.4.1).
  ///
  /// [searchOverride] es el seam de test (patrón INC-015): evita instanciar un
  /// `SupabaseClient` real. Devuelve `[]` ante error o query vacía.
  Future<List<Map<String, dynamic>>> searchFoodCatalog(
    String query, {
    Future<List<Map<String, dynamic>>> Function(String)? searchOverride,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      if (searchOverride != null) {
        return await searchOverride(query);
      }
      final data = await _client
          .schema('nutrition')
          .from('food_catalog')
          .select()
          .ilike('name', '%$query%')
          .limit(30);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Busca ingredientes base en `nutrition.ingredients` por nombre (T18.8.1/T18.5.1).
  ///
  /// Devuelve id, nombre, macros por 100 g/ml y los 7 micronutrientes clave.
  /// [searchOverride] es el seam de test (mismo patrón que [searchFoodCatalog]):
  /// evita instanciar un `SupabaseClient` real. Devuelve `[]` ante error o query vacía.
  Future<List<Map<String, dynamic>>> searchIngredients(
    String query, {
    Future<List<Map<String, dynamic>>> Function(String)? searchOverride,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      if (searchOverride != null) {
        return await searchOverride(query);
      }
      final data = await _client
          .schema('nutrition')
          .from('ingredients')
          .select()
          .ilike('name', '%$query%')
          .limit(30);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Carga las filas de `nutrition.ingredients` para un conjunto de ids
  /// (T18.8.3): usado por la UI de plato componible para resolver nombres y
  /// macros de cada `ingredient_id` de la composición. [fetchOverride] es el
  /// seam de test (mismo patrón que [searchIngredients]): evita instanciar un
  /// `SupabaseClient` real. Devuelve `[]` ante lista vacía o error.
  Future<List<Map<String, dynamic>>> fetchIngredientsByIds(
    List<int> ids, {
    Future<List<Map<String, dynamic>>> Function(List<int>)? fetchOverride,
  }) async {
    if (ids.isEmpty) return [];
    try {
      if (fetchOverride != null) {
        return await fetchOverride(ids);
      }
      final data = await _client
          .schema('nutrition')
          .from('ingredients')
          .select()
          .inFilter('id', ids);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Lee la fila de preferencias/restricciones del usuario en
  /// `nutrition.food_preferences`, o `null` si aún no existe (T18.2.1).
  ///
  /// [fetchOverride] es el seam de test (mismo patrón que [fetchMealPlans], ver
  /// INC-015): evita instanciar un `SupabaseClient` real.
  Future<Map<String, dynamic>?> fetchPreferences({
    Future<Map<String, dynamic>?> Function()? fetchOverride,
  }) async {
    try {
      if (fetchOverride != null) {
        return await fetchOverride();
      }
      final data = await _client
          .schema('nutrition')
          .from('food_preferences')
          .select()
          .eq('user_id', _currentUserId)
          .maybeSingle();
      return data;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  /// Guarda (upsert por `user_id`) las preferencias del usuario en
  /// `nutrition.food_preferences` (T18.2.1). Inserta o actualiza la única fila
  /// del usuario. [saveOverride] es el seam de test (mismo patrón que
  /// [setDefaultMealPlan]): evita instanciar un `SupabaseClient` real.
  Future<void> savePreferences(
    Map<String, dynamic> prefs, {
    Future<void> Function(Map<String, dynamic>)? saveOverride,
    String? userId,
  }) async {
    final payload = {...prefs, 'user_id': userId ?? _currentUserId};
    try {
      if (saveOverride != null) {
        await saveOverride(payload);
      } else {
        await _client
            .schema('nutrition')
            .from('food_preferences')
            .upsert(payload, onConflict: 'user_id');
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
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
        final lastDigit = int.tryParse(barcode.isNotEmpty ? barcode.substring(barcode.length - 1) : '5') ?? 5;
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
        
        final selectedName = foodNames[lastDigit % foodNames.length];
        mockResult = {
          'barcode': barcode,
          'food_name': '$selectedName (Escaneado)',
          'calories': (80 + lastDigit * 25).toDouble(),
          'protein_g': (2 + lastDigit * 1.5).toDouble(),
          'carbs_g': (5 + lastDigit * 3.5).toDouble(),
          'fat_g': (0.5 + lastDigit * 0.8).toDouble(),
          'serving_size_g': 100.0,
        };
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
