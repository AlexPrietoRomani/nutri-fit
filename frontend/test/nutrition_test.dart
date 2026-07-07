import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutrifit/features/nutrition/nutrition_provider.dart';

// Minimal mock implementation for Supabase client chain
class MockSupabaseClient extends Fake implements SupabaseClient {
  final MockPostgrestSchema _schema = MockPostgrestSchema();

  @override
  PostgrestSchema schema(String schema) => _schema;

  @override
  GoTrueClient get auth => MockAuth();
}

class MockAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => User(
        id: 'test-user-uuid',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
}

class MockPostgrestSchema extends Fake implements PostgrestSchema {
  final MockPostgrestQueryBuilder _queryBuilder = MockPostgrestQueryBuilder();

  @override
  PostgrestQueryBuilder from(String relation) {
    _queryBuilder.relation = relation;
    return _queryBuilder;
  }
}

class MockPostgrestQueryBuilder extends Fake implements PostgrestQueryBuilder {
  String relation = '';
  final MockPostgrestFilterBuilder _filterBuilder = MockPostgrestFilterBuilder();

  @override
  PostgrestFilterBuilder select([String columns = '*']) {
    _filterBuilder.relation = relation;
    _filterBuilder.operation = 'select';
    return _filterBuilder;
  }

  @override
  PostgrestFilterBuilder insert(Object values) {
    _filterBuilder.relation = relation;
    _filterBuilder.operation = 'insert';
    _filterBuilder.insertedValues = values;
    return _filterBuilder;
  }

  @override
  PostgrestFilterBuilder upsert(Object values, {Object? onConflict, bool ignoreDuplicates = false}) {
    _filterBuilder.relation = relation;
    _filterBuilder.operation = 'upsert';
    _filterBuilder.upsertedValues = values;
    return _filterBuilder;
  }

  @override
  PostgrestFilterBuilder delete() {
    _filterBuilder.relation = relation;
    _filterBuilder.operation = 'delete';
    return _filterBuilder;
  }
}

class MockPostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder {
  String relation = '';
  String operation = '';
  Object? insertedValues;
  Object? upsertedValues;
  Map<String, dynamic> filters = {};

  @override
  PostgrestFilterBuilder eq(String column, Object value) {
    filters[column] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder gte(String column, Object value) {
    filters['$column >='] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder lte(String column, Object value) {
    filters['$column <='] = value;
    return this;
  }

  @override
  PostgrestTransformBuilder order(String column, {bool ascending = false, bool nullsFirst = false, String? referencedTable}) {
    return MockPostgrestTransformBuilder(relation: relation, operation: operation, insertedValues: insertedValues, upsertedValues: upsertedValues);
  }

  @override
  Future<PostgrestResponse> execute() async {
    return PostgrestResponse(data: _mockData());
  }

  @override
  PostgrestTransformBuilder<T> select<T>([String columns = '*']) {
    return MockPostgrestTransformBuilder<T>(relation: relation, operation: operation, insertedValues: insertedValues, upsertedValues: upsertedValues);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return MockPostgrestTransformBuilder<Map<String, dynamic>?>(relation: relation, operation: operation, single: true, insertedValues: insertedValues, upsertedValues: upsertedValues);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() {
    return MockPostgrestTransformBuilder<Map<String, dynamic>>(relation: relation, operation: operation, single: true, insertedValues: insertedValues, upsertedValues: upsertedValues);
  }

  // Support thenable futures
  @override
  Future<T> then<T>(FutureOr<T> Function(dynamic) onValue, {Function? onError}) {
    final data = _mockData();
    return Future.value(onValue(data));
  }

  dynamic _mockData() {
    if (relation == 'user_goals') {
      return {
        'user_id': 'test-user-uuid',
        'target_calories': 2200,
        'target_protein_g': 160.0,
        'target_carbs_g': 240.0,
        'target_fat_g': 70.0,
        'goal_type': 'maintenance',
      };
    } else if (relation == 'food_logs') {
      if (operation == 'select') {
        return [
          {
            'id': 1,
            'user_id': 'test-user-uuid',
            'logged_at': DateTime.now().toIso8601String(),
            'meal_type': 'breakfast',
            'food_name': 'Huevo Estrellado',
            'calories': 140.0,
            'protein_g': 12.0,
            'carbs_g': 1.0,
            'fat_g': 10.0,
            'serving_size_g': 100.0,
          },
          {
            'id': 2,
            'user_id': 'test-user-uuid',
            'logged_at': DateTime.now().toIso8601String(),
            'meal_type': 'lunch',
            'food_name': 'Pollo con Arroz',
            'calories': 450.0,
            'protein_g': 35.0,
            'carbs_g': 40.0,
            'fat_g': 8.0,
            'serving_size_g': 300.0,
          }
        ];
      } else if (operation == 'insert') {
        return insertedValues;
      }
    } else if (relation == 'food_cache') {
      return null; // Simulate cache miss
    }
    return null;
  }
}

class MockPostgrestTransformBuilder<T> extends Fake implements PostgrestTransformBuilder<T> {
  final String relation;
  final String operation;
  final bool single;
  final Object? insertedValues;
  final Object? upsertedValues;

  MockPostgrestTransformBuilder({
    required this.relation,
    required this.operation,
    this.single = false,
    this.insertedValues,
    this.upsertedValues,
  });

  @override
  Future<T> then<T2>(FutureOr<T2> Function(T) onValue, {Function? onError}) {
    dynamic data;
    if (relation == 'user_goals') {
      data = {
        'user_id': 'test-user-uuid',
        'target_calories': 2200,
        'target_protein_g': 160.0,
        'target_carbs_g': 240.0,
        'target_fat_g': 70.0,
        'goal_type': 'maintenance',
      };
    } else if (relation == 'food_logs') {
      if (operation == 'insert') {
        final map = insertedValues as Map<String, dynamic>;
        data = {
          'id': 42,
          ...map,
        };
      } else if (operation == 'select') {
        data = [
          {
            'id': 1,
            'user_id': 'test-user-uuid',
            'logged_at': DateTime.now().toIso8601String(),
            'meal_type': 'breakfast',
            'food_name': 'Huevo Estrellado',
            'calories': 140.0,
            'protein_g': 12.0,
            'carbs_g': 1.0,
            'fat_g': 10.0,
            'serving_size_g': 100.0,
          }
        ];
      }
    } else if (relation == 'food_cache') {
      if (operation == 'upsert') {
        data = upsertedValues;
      } else {
        data = null;
      }
    }
    return Future.value(onValue(data as T));
  }
}

void main() {
  group('NutritionProvider Tests', () {
    late MockSupabaseClient mockClient;
    late NutritionProvider provider;

    setUp(() {
      mockClient = MockSupabaseClient();
      provider = NutritionProvider(client: mockClient);
    });

    test('loadDailyData should fetch user goals and food logs correctly', () async {
      await provider.loadDailyData(DateTime.now());

      // Goals verification
      expect(provider.goals, isNotNull);
      expect(provider.goals!.targetCalories, 2200);
      expect(provider.goals!.targetProteinG, 160.0);

      // Food logs verification
      expect(provider.foodLogs.length, 2);
      expect(provider.foodLogs[0].foodName, 'Huevo Estrellado');
      expect(provider.foodLogs[1].foodName, 'Pollo con Arroz');

      // Totals calculation verification
      // Calories: 140 + 450 = 590
      expect(provider.totalCalories, 590.0);
      // Protein: 12 + 35 = 47
      expect(provider.totalProtein, 47.0);
      // Carbs: 1 + 40 = 41
      expect(provider.totalCarbs, 41.0);
      // Fat: 10 + 8 = 18
      expect(provider.totalFat, 18.0);
    });

    test('addFoodLog should successfully insert food log and update totals', () async {
      // First load empty/existing
      await provider.loadDailyData(DateTime.now());
      final initialLogsCount = provider.foodLogs.length;

      final success = await provider.addFoodLog(
        foodName: 'Plátano',
        calories: 90.0,
        proteinG: 1.0,
        carbsG: 22.0,
        fatG: 0.3,
        servingSizeG: 100.0,
        mealType: 'snack',
        date: DateTime.now(),
      );

      expect(success, isTrue);
      expect(provider.foodLogs.length, initialLogsCount + 1);
      expect(provider.foodLogs.last.foodName, 'Plátano');
      expect(provider.foodLogs.last.calories, 90.0);
    });

    test('deleteFoodLog should successfully remove food log', () async {
      await provider.loadDailyData(DateTime.now());
      expect(provider.foodLogs.any((item) => item.id == 1), isTrue);

      final success = await provider.deleteFoodLog(1);

      expect(success, isTrue);
      expect(provider.foodLogs.any((item) => item.id == 1), isFalse);
    });

    test('searchBarcode should perform lookup, simulate OpenFoodFacts and cache result', () async {
      final result = await provider.searchBarcode('7501055310884');

      expect(result, isNotNull);
      expect(result!['food_name'], 'Atún en Agua Tuny (Lata)');
      expect(result['calories'], 116.0);
      expect(result['protein_g'], 25.0);
    });
  });
}
