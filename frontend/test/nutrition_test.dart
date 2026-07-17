import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifit/features/nutrition/nutrition_provider.dart';

// NOTA: Los flujos que tocan la base de datos (loadDailyData, addFoodLog,
// deleteFoodLog, searchBarcode) se validan por E2E real contra el stack Docker
// (ver docs/logs/log.md y e2e/): mockear toda la cadena fluida de PostgREST
// resultó frágil y acoplado a la versión interna de `postgrest`. Aquí se testea
// la lógica pura de serialización, que es la que define el contrato de datos.
void main() {
  group('FoodLog serialización', () {
    final json = {
      'id': 7,
      'user_id': 'u-1',
      'logged_at': '2026-07-15T12:30:00.000Z',
      'meal_type': 'lunch',
      'food_name': 'Pollo con Arroz',
      'calories': 450.0,
      'protein_g': 35.0,
      'carbs_g': 40.0,
      'fat_g': 8.0,
      'serving_size_g': 300.0,
    };

    test('fromJson mapea todos los campos', () {
      final log = FoodLog.fromJson(json);
      expect(log.id, 7);
      expect(log.userId, 'u-1');
      expect(log.mealType, 'lunch');
      expect(log.foodName, 'Pollo con Arroz');
      expect(log.calories, 450.0);
      expect(log.proteinG, 35.0);
      expect(log.carbsG, 40.0);
      expect(log.fatG, 8.0);
      expect(log.servingSizeG, 300.0);
      expect(log.loggedAt.toUtc().hour, 12);
    });

    test('fromJson acepta enteros donde se esperan dobles (num->double)', () {
      final intJson = Map<String, dynamic>.from(json)
        ..['calories'] = 450
        ..['protein_g'] = 35;
      final log = FoodLog.fromJson(intJson);
      expect(log.calories, 450.0);
      expect(log.proteinG, 35.0);
    });

    test('toJson incluye id solo cuando no es null', () {
      final conId = FoodLog.fromJson(json).toJson();
      expect(conId.containsKey('id'), isTrue);

      final sinId = FoodLog(
        userId: 'u-1',
        loggedAt: DateTime.parse('2026-07-15T12:30:00.000Z'),
        mealType: 'snack',
        foodName: 'Plátano',
        calories: 90.0,
        proteinG: 1.0,
        carbsG: 22.0,
        fatG: 0.3,
        servingSizeG: 100.0,
      ).toJson();
      expect(sinId.containsKey('id'), isFalse);
      expect(sinId['food_name'], 'Plátano');
      expect(sinId['meal_type'], 'snack');
    });
  });

  group('NutritionProvider.fetchMealPlans / setDefaultMealPlan (T16.2.2)', () {
    // Mismo seam inyectable que TrainingProvider.fetchSavedRoutines/
    // setDefaultRoutine: no se instancia SupabaseClient real (INC-015).
    test('fetchMealPlans puebla mealPlans desde la respuesta inyectada', () async {
      final provider = NutritionProvider();
      final fakePlans = [
        {'id': 'p1', 'name': 'Plan IA', 'meals': [], 'is_default': false},
      ];

      await provider.fetchMealPlans(fetchOverride: () async => fakePlans);

      expect(provider.mealPlans, fakePlans);
      expect(provider.errorMessage, isNull);
    });

    test('marcar otro plan como default deja exactamente uno marcado tras refrescar', () async {
      final provider = NutritionProvider();
      final backend = [
        {'id': 'p1', 'name': 'Plan A', 'meals': [], 'is_default': true},
        {'id': 'p2', 'name': 'Plan B', 'meals': [], 'is_default': false},
      ];

      await provider.setDefaultMealPlan(
        'p2',
        setDefaultOverride: () async {
          for (final p in backend) {
            p['is_default'] = p['id'] == 'p2';
          }
        },
        fetchOverride: () async => backend,
      );

      expect(provider.mealPlans.where((p) => p['is_default'] == true).length, 1);
      expect(provider.mealPlans.firstWhere((p) => p['id'] == 'p2')['is_default'], isTrue);
      expect(provider.mealPlans.firstWhere((p) => p['id'] == 'p1')['is_default'], isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('errores del fetch inyectado se reflejan en errorMessage sin lanzar', () async {
      final provider = NutritionProvider();

      await provider.fetchMealPlans(fetchOverride: () async => throw Exception('boom'));

      expect(provider.mealPlans, isEmpty);
      expect(provider.errorMessage, contains('boom'));
    });
  });

  group('NutritionProvider.fetchPreferences / savePreferences (T18.2.1)', () {
    test('fetchPreferences devuelve la fila inyectada', () async {
      final provider = NutritionProvider();
      final row = {
        'user_id': 'u-1',
        'allergies': ['maní'],
        'dislikes': ['cebolla'],
        'avoid': [],
        'rarely': ['azúcar'],
        'constraints': {'no_fridge': true},
      };

      final result = await provider.fetchPreferences(fetchOverride: () async => row);

      expect(result, row);
    });

    test('fetchPreferences devuelve null cuando no hay fila', () async {
      final provider = NutritionProvider();

      final result = await provider.fetchPreferences(fetchOverride: () async => null);

      expect(result, isNull);
    });

    test('savePreferences arma el upsert con user_id inyectado', () async {
      final provider = NutritionProvider();
      Map<String, dynamic>? captured;

      await provider.savePreferences(
        {
          'allergies': ['maní'],
          'constraints': {'no_fridge': true},
        },
        userId: 'u-1',
        saveOverride: (payload) async => captured = payload,
      );

      expect(captured, isNotNull);
      expect(captured!['user_id'], 'u-1');
      expect(captured!['allergies'], ['maní']);
      expect(captured!['constraints'], {'no_fridge': true});
    });

    test('error en el override de save se refleja en errorMessage sin lanzar', () async {
      final provider = NutritionProvider();

      await provider.savePreferences(
        {'allergies': []},
        userId: 'u-1',
        saveOverride: (_) async => throw Exception('boom'),
      );

      expect(provider.errorMessage, contains('boom'));
    });
  });

  group('NutritionProvider.searchFoodCatalog (T17.4.1)', () {
    test('con searchOverride devuelve la lista mockeada', () async {
      final provider = NutritionProvider();
      final dishes = [
        {'id': 1, 'name': 'Lomo Saltado', 'calories': 520, 'protein_g': 30, 'carbs_g': 45, 'fat_g': 22},
      ];

      final result = await provider.searchFoodCatalog('lomo', searchOverride: (q) async {
        expect(q, 'lomo');
        return dishes;
      });

      expect(result, dishes);
    });

    test('query vacía devuelve [] sin invocar el override', () async {
      final provider = NutritionProvider();
      var called = false;

      final result = await provider.searchFoodCatalog('  ', searchOverride: (q) async {
        called = true;
        return [{'name': 'x'}];
      });

      expect(result, isEmpty);
      expect(called, isFalse);
    });

    test('error en el override devuelve [] sin lanzar', () async {
      final provider = NutritionProvider();

      final result = await provider.searchFoodCatalog('lomo', searchOverride: (_) async => throw Exception('boom'));

      expect(result, isEmpty);
    });
  });

  group('NutritionProvider.searchIngredients (T18.8.1/T18.5.1)', () {
    test('con searchOverride devuelve la lista mockeada (macros + micros)', () async {
      final provider = NutritionProvider();
      final ingredients = [
        {
          'id': 1,
          'name': 'Pechuga de pollo',
          'category': 'proteina',
          'unit': 'g',
          'calories_per_100': 165,
          'protein_per_100': 31.0,
          'carbs_per_100': 0.0,
          'fat_per_100': 3.6,
          'iron_mg': 0.7,
          'vitamin_c_mg': 0.0,
        },
      ];

      final result = await provider.searchIngredients('pollo', searchOverride: (q) async {
        expect(q, 'pollo');
        return ingredients;
      });

      expect(result, ingredients);
      expect(result.first['protein_per_100'], 31.0);
      expect(result.first['iron_mg'], 0.7);
    });

    test('query vacía devuelve [] sin invocar el override', () async {
      final provider = NutritionProvider();
      var called = false;

      final result = await provider.searchIngredients('  ', searchOverride: (q) async {
        called = true;
        return [{'name': 'x'}];
      });

      expect(result, isEmpty);
      expect(called, isFalse);
    });

    test('error en el override devuelve [] sin lanzar', () async {
      final provider = NutritionProvider();

      final result = await provider.searchIngredients('pollo', searchOverride: (_) async => throw Exception('boom'));

      expect(result, isEmpty);
    });
  });

  group('UserGoals serialización', () {
    test('fromJson mapea metas y macros', () {
      final goals = UserGoals.fromJson({
        'user_id': 'u-1',
        'target_calories': 2217,
        'target_protein_g': 140.0,
        'target_carbs_g': 256.75,
        'target_fat_g': 70.0,
        'goal_type': 'maintenance',
      });
      expect(goals.userId, 'u-1');
      expect(goals.targetCalories, 2217);
      expect(goals.targetProteinG, 140.0);
      expect(goals.targetCarbsG, 256.75);
      expect(goals.targetFatG, 70.0);
      expect(goals.goalType, 'maintenance');
    });

    test('goalType cae a "maintenance" cuando viene null', () {
      final goals = UserGoals.fromJson({
        'user_id': 'u-1',
        'target_calories': 2000,
        'target_protein_g': 150.0,
        'target_carbs_g': 200.0,
        'target_fat_g': 65.0,
        'goal_type': null,
      });
      expect(goals.goalType, 'maintenance');
    });
  });

  group('macrosFromIngredients / dishMacros (T18.8.2)', () {
    // Subconjunto del seed zzzz6_ingredients.sql:
    // 1 pechuga pollo: 165 / 31.0 / 0.0 / 3.6 (por 100 g)
    // 9 arroz blanco cocido: 130 / 2.7 / 28.0 / 0.3 (por 100 g)
    final ingredientsById = {
      1: {
        'calories_per_100': 165,
        'protein_per_100': 31.0,
        'carbs_per_100': 0.0,
        'fat_per_100': 3.6,
      },
      9: {
        'calories_per_100': 130,
        'protein_per_100': 2.7,
        'carbs_per_100': 28.0,
        'fat_per_100': 0.3,
      },
    };

    test('caso conocido: 100 g pechuga + 300 g arroz', () {
      // 100 g pechuga -> 165 / 31.0 / 0.0 / 3.6
      // 300 g arroz  -> 390 / 8.1 / 84.0 / 0.9
      // total        -> 555 / 39.1 / 84.0 / 4.5
      final macros = macrosFromIngredients(
        [
          {'ingredient_id': 1, 'grams': 100},
          {'ingredient_id': 9, 'grams': 300},
        ],
        ingredientsById,
      );
      expect(macros['calories'], closeTo(555.0, 1));
      expect(macros['protein_g'], closeTo(39.1, 1));
      expect(macros['carbs_g'], closeTo(84.0, 1));
      expect(macros['fat_g'], closeTo(4.5, 1));
    });

    test('ignora ingredient_id ausente en el mapa', () {
      final macros = macrosFromIngredients(
        [
          {'ingredient_id': 1, 'grams': 100},
          {'ingredient_id': 999, 'grams': 500},
        ],
        ingredientsById,
      );
      expect(macros['calories'], closeTo(165.0, 1));
    });

    test('dishMacros con composición recalcula', () {
      final dish = {
        'name': 'Arroz con Pollo',
        'calories': 550.0,
        'protein_g': 28.0,
        'carbs_g': 65.0,
        'fat_g': 18.0,
        'ingredients': [
          {'ingredient_id': 1, 'grams': 100},
          {'ingredient_id': 9, 'grams': 300},
        ],
      };
      final macros = dishMacros(dish, ingredientsById);
      expect(macros['calories'], closeTo(555.0, 1));
    });

    test('dishMacros sin composición usa macros planas (fallback)', () {
      final dish = {
        'name': 'Pollo a la Brasa (1/4)',
        'calories': 500.0,
        'protein_g': 40.0,
        'carbs_g': 20.0,
        'fat_g': 28.0,
        'ingredients': null,
      };
      final macros = dishMacros(dish, ingredientsById);
      expect(macros['calories'], 500.0);
      expect(macros['protein_g'], 40.0);
      expect(macros['carbs_g'], 20.0);
      expect(macros['fat_g'], 28.0);
    });
  });

  group('microsFromIngredients (T18.5.2)', () {
    // Subconjunto del seed zzzz6_ingredients.sql (micros por 100 g):
    // 1 pechuga pollo: iron_mg=0.7, calcium_mg=15
    // 9 arroz blanco:  iron_mg=0.2, calcium_mg=10
    // 18 olluco:       sodium_mg=NULL, zinc_mg=NULL, iron_mg=1.1
    final ingredientsById = {
      1: {'iron_mg': 0.7, 'calcium_mg': 15},
      9: {'iron_mg': 0.2, 'calcium_mg': 10},
      18: {'iron_mg': 1.1, 'sodium_mg': null, 'zinc_mg': null},
    };

    test('caso conocido: 200 g pechuga + 100 g arroz', () {
      // iron    -> 2*0.7 + 1*0.2 = 1.6 mg
      // calcium -> 2*15  + 1*10  = 40 mg
      final micros = microsFromIngredients(
        [
          {'ingredient_id': 1, 'grams': 200},
          {'ingredient_id': 9, 'grams': 100},
        ],
        ingredientsById,
      );
      expect(micros['iron_mg'], closeTo(1.6, 0.05));
      expect(micros['calcium_mg'], closeTo(40.0, 0.05));
    });

    test('micro con todos NULL se omite (no 0 engañoso)', () {
      final micros = microsFromIngredients(
        [
          {'ingredient_id': 18, 'grams': 200},
        ],
        ingredientsById,
      );
      // iron presente (aportado por el olluco), sodium/zinc NULL -> ausentes.
      expect(micros.containsKey('iron_mg'), isTrue);
      expect(micros.containsKey('sodium_mg'), isFalse);
      expect(micros.containsKey('zinc_mg'), isFalse);
    });

    test('ignora ingredient_id ausente en el mapa', () {
      final micros = microsFromIngredients(
        [
          {'ingredient_id': 999, 'grams': 500},
        ],
        ingredientsById,
      );
      expect(micros, isEmpty);
    });
  });
}
