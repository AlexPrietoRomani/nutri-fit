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
}
