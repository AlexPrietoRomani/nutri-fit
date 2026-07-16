import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/nutrition/nutrition_provider.dart';
import 'package:nutrifit/features/training/training_provider.dart';
import 'package:nutrifit/features/auth/onboarding_provider.dart';
import 'package:nutrifit/features/dashboard/dashboard_screen.dart';

// El Dashboard dispara loadProfile/loadDailyData/fetchMealPlans/
// loadCompletedWorkouts/fetchSavedRoutines en initState sin override; sin
// Supabase.initialize() acceder al cliente lanza excepción síncrona atrapada
// (INC-015) sin tocar el estado ya poblado antes de montar el widget.
class _FakeTrainingProvider extends TrainingProvider {
  _FakeTrainingProvider(this._sessions);
  final List<WorkoutSession> _sessions;

  @override
  List<WorkoutSession> get completedSessions => _sessions;
}

class _FakeNutritionProvider extends NutritionProvider {
  _FakeNutritionProvider(this._consumed);
  final double _consumed;

  @override
  double get totalCalories => _consumed;
}

WorkoutSession _session({required bool endedToday}) {
  final now = DateTime.now();
  return WorkoutSession(
    id: 's1',
    userId: 'u1',
    startedAt: now,
    endedAt: endedToday ? now : null,
    name: 'Sesión',
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required TrainingProvider training,
  required NutritionProvider nutrition,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<OnboardingProvider>(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider<NutritionProvider>.value(value: nutrition),
        ChangeNotifierProvider<TrainingProvider>.value(value: training),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Plan de Hoy'),
    300,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Plan de Hoy (T16.5.1)', () {
    testWidgets('rutina default + sesión completada hoy → "Hecho hoy"', (tester) async {
      final training = _FakeTrainingProvider([_session(endedToday: true)]);
      await training.fetchSavedRoutines(fetchOverride: () async => [
            {'id': 'r1', 'name': 'Full Body', 'is_default': true},
          ]);
      await _pumpDashboard(tester, training: training, nutrition: NutritionProvider());

      expect(find.text('Full Body'), findsOneWidget);
      expect(find.text('Hecho hoy'), findsOneWidget);
    });

    testWidgets('rutina default sin sesión hoy → "Pendiente hoy"', (tester) async {
      final training = _FakeTrainingProvider([_session(endedToday: false)]);
      await training.fetchSavedRoutines(fetchOverride: () async => [
            {'id': 'r1', 'name': 'Full Body', 'is_default': true},
          ]);
      await _pumpDashboard(tester, training: training, nutrition: NutritionProvider());

      expect(find.text('Full Body'), findsOneWidget);
      expect(find.text('Pendiente hoy'), findsOneWidget);
    });

    testWidgets('sin rutina default → texto discreto', (tester) async {
      final training = _FakeTrainingProvider([]);
      await training.fetchSavedRoutines(fetchOverride: () async => [
            {'id': 'r1', 'name': 'Full Body', 'is_default': false},
          ]);
      await _pumpDashboard(tester, training: training, nutrition: NutritionProvider());

      expect(find.textContaining('Sin rutina predeterminada'), findsOneWidget);
    });

    testWidgets('plan de comida default suma meals y compara con consumido', (tester) async {
      final nutrition = _FakeNutritionProvider(1900);
      await nutrition.fetchMealPlans(fetchOverride: () async => [
            {
              'id': 'p1',
              'name': 'Plan Volumen',
              'is_default': true,
              'meals': [
                {'meal_type': 'lunch', 'food_name': 'A', 'calories': 1200},
                {'meal_type': 'dinner', 'food_name': 'B', 'calories': 800},
              ],
            },
          ]);
      await _pumpDashboard(tester, training: _FakeTrainingProvider([]), nutrition: nutrition);

      expect(
        find.textContaining('Plan: Plan Volumen · planificado 2000 kcal · consumido 1900 kcal'),
        findsOneWidget,
      );
      expect(find.text('En línea con el plan'), findsOneWidget);
    });
  });

  group('Pruebas de Balance Calórico y Fórmulas', () {
    test('Cálculo correcto de Calorías Restantes y Balance', () {
      const int targetCalories = 2000;
      const double consumedCalories = 1500;
      const double burnedCalories = 300;

      // remaining = target - (consumed - burned)
      // remaining = target - consumed + burned
      final double remaining = targetCalories - consumedCalories + burnedCalories;
      
      expect(remaining, 800);
      
      final double netIntake = consumedCalories - burnedCalories;
      final bool isDeficit = netIntake < targetCalories;
      
      expect(netIntake, 1200);
      expect(isDeficit, isTrue);
    });

    test('Identificación correcta de Superávit Calórico', () {
      const int targetCalories = 1800;
      const double consumedCalories = 2200;
      const double burnedCalories = 100;

      final double remaining = targetCalories - consumedCalories + burnedCalories;
      
      expect(remaining, -300);
      
      final double netIntake = consumedCalories - burnedCalories;
      final bool isDeficit = netIntake < targetCalories;
      
      expect(netIntake, 2100);
      expect(isDeficit, isFalse); // Superávit
    });
  });
}
