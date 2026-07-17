import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/nutrition/nutrition_provider.dart';
import 'package:nutrifit/features/nutrition/diary_screen.dart';

// NOTA: DiaryScreen dispara loadDailyData()/fetchMealPlans() en initState sin
// override (usan SupabaseConfig.client vía NutritionProvider()). En este
// entorno de test nunca se llama Supabase.initialize(), así que acceder al
// cliente lanza una excepción síncrona atrapada en cada try/catch (ver
// INC-015, docs/logs/log.md) — no cuelga el proceso, y no toca _mealPlans ya
// poblado antes de montar el widget.
//
// `getMealsOfType` lee `_foodLogs`, poblado únicamente por `loadDailyData`
// (sin seam inyectable — no se le agrega uno para no tocar su contrato, ver
// T16.3.1). Para simular `FoodLog`s reales en un widget test se sobreescribe
// `getMealsOfType` en una subclase pública (mismo objeto sigue siendo un
// `NutritionProvider` para `Provider`/`Consumer`).
class _FakeNutritionProvider extends NutritionProvider {
  _FakeNutritionProvider(this._lunchLogs);
  final List<FoodLog> _lunchLogs;

  @override
  List<FoodLog> getMealsOfType(String type) => type == 'lunch' ? _lunchLogs : const [];
}

// Fake para T17.4.1: mockea la búsqueda del catálogo (searchOverride es un
// seam de método, no accesible desde el diálogo, así que se sobreescribe el
// método) y captura los argumentos con que se dispara addFoodLog.
class _CatalogFakeProvider extends NutritionProvider {
  _CatalogFakeProvider(this._catalogResults, {List<Map<String, dynamic>>? ingredients})
      : _ingredients = ingredients ?? const [];
  final List<Map<String, dynamic>> _catalogResults;
  final List<Map<String, dynamic>> _ingredients;
  Map<String, dynamic>? lastAddFoodLog;

  @override
  Future<List<Map<String, dynamic>>> searchFoodCatalog(
    String query, {
    Future<List<Map<String, dynamic>>> Function(String)? searchOverride,
  }) async =>
      _catalogResults;

  @override
  Future<List<Map<String, dynamic>>> fetchIngredientsByIds(
    List<int> ids, {
    Future<List<Map<String, dynamic>>> Function(List<int>)? fetchOverride,
  }) async =>
      _ingredients.where((i) => ids.contains((i['id'] as num).toInt())).toList();

  @override
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
    lastAddFoodLog = {
      'foodName': foodName,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'mealType': mealType,
    };
    return true;
  }
}

FoodLog _lunchLog(double calories) => FoodLog(
      userId: 'u-1',
      loggedAt: DateTime(2026, 7, 16, 13, 0),
      mealType: 'lunch',
      foodName: 'Comida de prueba',
      calories: calories,
      proteinG: 20,
      carbsG: 30,
      fatG: 10,
      servingSizeG: 200,
    );

void main() {
  testWidgets('Mis Planes de Comida muestra estrella llena para is_default=true y vacía para las demás',
      (tester) async {
    final provider = NutritionProvider();
    await provider.fetchMealPlans(fetchOverride: () async => [
          {'id': 'p1', 'name': 'Plan A', 'meals': [], 'is_default': true},
          {'id': 'p2', 'name': 'Plan B', 'meals': [], 'is_default': false},
        ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<NutritionProvider>.value(
        value: provider,
        child: const MaterialApp(home: DiaryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // La sección va al final del ListView del diario (tras las 4 comidas);
    // en el tamaño de superficie de test queda fuera del viewport inicial —
    // hay que desplazarse para que el Sliver la construya.
    await tester.scrollUntilVisible(
      find.text('Mis Planes de Comida'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mis Planes de Comida'), findsOneWidget);
    expect(find.byKey(const Key('set_default_meal_plan_p1')), findsOneWidget);
    expect(find.byKey(const Key('set_default_meal_plan_p2')), findsOneWidget);

    final p1Star = tester.widget<IconButton>(find.byKey(const Key('set_default_meal_plan_p1')));
    expect((p1Star.icon as Icon).icon, Icons.star_rounded);
    final p2Star = tester.widget<IconButton>(find.byKey(const Key('set_default_meal_plan_p2')));
    expect((p2Star.icon as Icon).icon, Icons.star_border_rounded);
  });

  group('Planificado vs. real por comida (T16.3.1)', () {
    final defaultPlan = [
      {
        'id': 'p1',
        'name': 'Plan A',
        'is_default': true,
        'meals': [
          {'meal_type': 'lunch', 'food_name': 'Pollo con Arroz', 'calories': 500},
        ],
      },
    ];

    Future<void> _pump(WidgetTester tester, NutritionProvider provider) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin logs reales muestra "Aún no registrado"', (tester) async {
      final provider = _FakeNutritionProvider([]);
      await provider.fetchMealPlans(fetchOverride: () async => defaultPlan);
      await _pump(tester, provider);

      expect(find.textContaining('Planificado: Pollo con Arroz · 500 kcal'), findsOneWidget);
      expect(find.text('Aún no registrado'), findsOneWidget);
    });

    testWidgets('logs dentro de ±10% muestra "En línea con el plan"', (tester) async {
      final provider = _FakeNutritionProvider([_lunchLog(500)]);
      await provider.fetchMealPlans(fetchOverride: () async => defaultPlan);
      await _pump(tester, provider);

      expect(find.text('En línea con el plan'), findsOneWidget);
    });

    testWidgets('logs >10% por encima muestra "de más"', (tester) async {
      final provider = _FakeNutritionProvider([_lunchLog(700)]);
      await provider.fetchMealPlans(fetchOverride: () async => defaultPlan);
      await _pump(tester, provider);

      expect(find.text('200 kcal de más'), findsOneWidget);
    });

    testWidgets('logs >10% por debajo (con logs presentes) muestra "de menos"', (tester) async {
      final provider = _FakeNutritionProvider([_lunchLog(300)]);
      await provider.fetchMealPlans(fetchOverride: () async => defaultPlan);
      await _pump(tester, provider);

      expect(find.text('200 kcal de menos'), findsOneWidget);
    });

    testWidgets('sin defaultMealPlan la sección de comida no muestra bloque nuevo', (tester) async {
      final provider = _FakeNutritionProvider([_lunchLog(500)]);
      await provider.fetchMealPlans(fetchOverride: () async => [
            {'id': 'p1', 'name': 'Plan A', 'is_default': false, 'meals': []},
          ]);
      await _pump(tester, provider);

      expect(find.textContaining('Planificado:'), findsNothing);
      expect(find.text('Aún no registrado'), findsNothing);
      expect(find.text('En línea con el plan'), findsNothing);
    });
  });

  group('Buscar en catálogo (T17.4.1)', () {
    testWidgets('existe la vía "Buscar en catálogo" en la sección de comida', (tester) async {
      final provider = _CatalogFakeProvider(const []);
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Buscar en catálogo'), findsWidgets);
    });

    testWidgets('elegir un plato dispara addFoodLog con sus macros', (tester) async {
      final provider = _CatalogFakeProvider(const [
        {'id': 1, 'name': 'Lomo Saltado', 'calories': 520, 'protein_g': 30, 'carbs_g': 45, 'fat_g': 22},
      ]);
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Abre el diálogo de catálogo de la primera sección (Desayuno).
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buscar en catálogo').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('food_catalog_field')), 'lomo');
      await tester.tap(find.byKey(const Key('food_catalog_search_btn')));
      await tester.pumpAndSettle();

      // Toca el primer resultado → abre el borrador reutilizado.
      await tester.tap(find.byKey(const Key('food_catalog_item_0')));
      await tester.pumpAndSettle();

      // Confirma en el borrador → dispara addFoodLog.
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(provider.lastAddFoodLog, isNotNull);
      expect(provider.lastAddFoodLog!['foodName'], 'Lomo Saltado');
      expect(provider.lastAddFoodLog!['calories'], 520.0);
      expect(provider.lastAddFoodLog!['proteinG'], 30.0);
      expect(provider.lastAddFoodLog!['carbsG'], 45.0);
      expect(provider.lastAddFoodLog!['fatG'], 22.0);
      expect(provider.lastAddFoodLog!['mealType'], 'breakfast');
    });
  });

  group('Plato componible — editar porciones (T18.8.3)', () {
    final ingredients = [
      {'id': 1, 'name': 'Arroz', 'calories_per_100': 130, 'protein_per_100': 2.7, 'carbs_per_100': 28, 'fat_per_100': 0.3},
      {'id': 2, 'name': 'Pollo', 'calories_per_100': 165, 'protein_per_100': 31, 'carbs_per_100': 0, 'fat_per_100': 3.6},
    ];
    final dishWithComp = {
      'id': 1,
      'name': 'Arroz con Pollo',
      'calories': 999, // macros planas que NO deben usarse
      'protein_g': 0, 'carbs_g': 0, 'fat_g': 0,
      'ingredients': [
        {'ingredient_id': 1, 'grams': 100},
        {'ingredient_id': 2, 'grams': 100},
      ],
    };

    Future<void> _openComposable(WidgetTester tester, _CatalogFakeProvider provider) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buscar en catálogo').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food_catalog_field')), 'arroz');
      await tester.tap(find.byKey(const Key('food_catalog_search_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food_catalog_item_0')));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra ingredientes; reducir gramos baja los macros', (tester) async {
      final provider = _CatalogFakeProvider([dishWithComp], ingredients: ingredients);
      await _openComposable(tester, provider);

      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('Pollo'), findsOneWidget);
      // 130 + 165 = 295 kcal iniciales.
      expect(find.text('295 kcal · P 34g · C 28g · G 4g'), findsOneWidget);

      // Reduce el arroz (primer ingrediente) de 100 a 50 g → 65 + 165 = 230.
      await tester.enterText(find.byKey(const Key('composable_grams_0')), '50');
      await tester.pumpAndSettle();
      expect(find.text('230 kcal · P 32g · C 14g · G 4g'), findsOneWidget);
    });

    testWidgets('quitar un ingrediente reduce los macros', (tester) async {
      final provider = _CatalogFakeProvider([dishWithComp], ingredients: ingredients);
      await _openComposable(tester, provider);

      expect(find.text('295 kcal · P 34g · C 28g · G 4g'), findsOneWidget);
      // Quita el pollo (segundo ingrediente) → queda solo arroz 130 kcal.
      await tester.tap(find.byKey(const Key('composable_remove_1')));
      await tester.pumpAndSettle();
      expect(find.text('130 kcal · P 3g · C 28g · G 0g'), findsOneWidget);
      expect(find.text('Pollo'), findsNothing);
    });

    testWidgets('confirmar registra con los macros recalculados y el nombre del plato', (tester) async {
      final provider = _CatalogFakeProvider([dishWithComp], ingredients: ingredients);
      await _openComposable(tester, provider);

      await tester.tap(find.byKey(const Key('composable_remove_1'))); // quita pollo
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composable_save')));
      await tester.pumpAndSettle();

      expect(provider.lastAddFoodLog, isNotNull);
      expect(provider.lastAddFoodLog!['foodName'], 'Arroz con Pollo');
      expect(provider.lastAddFoodLog!['calories'], 130.0);
    });

    testWidgets('plato SIN composición usa el borrador simple, sin lista de ingredientes', (tester) async {
      final provider = _CatalogFakeProvider(const [
        {'id': 9, 'name': 'Manzana', 'calories': 95, 'protein_g': 0, 'carbs_g': 25, 'fat_g': 0},
      ]);
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buscar en catálogo').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food_catalog_field')), 'manzana');
      await tester.tap(find.byKey(const Key('food_catalog_search_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food_catalog_item_0')));
      await tester.pumpAndSettle();

      // Es el borrador simple (T17.4.1): no aparece la UI componible.
      expect(find.byKey(const Key('composable_add_ingredient')), findsNothing);
      expect(find.text('Borrador detectado'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(provider.lastAddFoodLog!['foodName'], 'Manzana');
      expect(provider.lastAddFoodLog!['calories'], 95.0);
    });
  });

  group('Diálogo de escaneo de código (T16.4.1)', () {
    testWidgets('ofrece AMBAS vías: botón cámara + campo manual', (tester) async {
      final provider = NutritionProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // El botón "Escanear" está en la primera sección de comida (Desayuno).
      await tester.tap(find.widgetWithText(ElevatedButton, 'Escanear').first);
      await tester.pumpAndSettle();

      // Vía 1: escaneo con cámara real (nuevo). Vía 2: entrada manual (conservada).
      expect(find.byKey(const Key('scan_with_camera_btn')), findsOneWidget);
      expect(find.text('Escanear con cámara'), findsOneWidget);
      expect(find.byKey(const Key('manual_barcode_field')), findsOneWidget);
      expect(find.byKey(const Key('manual_barcode_search_btn')), findsOneWidget);

      // El dropdown de códigos mock fue eliminado.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('la entrada manual dispara la búsqueda del código tecleado', (tester) async {
      final provider = NutritionProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<NutritionProvider>.value(
          value: provider,
          child: const MaterialApp(home: DiaryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Escanear').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('manual_barcode_field')), '7501234567890');
      await tester.tap(find.byKey(const Key('manual_barcode_search_btn')));
      // Deja que la transición de pop del diálogo termine (no pumpAndSettle:
      // el loading de _searchAndShowBarcodeResult nunca se estabiliza).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // El diálogo de escaneo se cerró y arrancó el flujo existente
      // (_searchAndShowBarcodeResult muestra un CircularProgressIndicator).
      expect(find.byKey(const Key('manual_barcode_field')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
