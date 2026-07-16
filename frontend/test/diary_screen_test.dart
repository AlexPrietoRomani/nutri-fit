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
}
