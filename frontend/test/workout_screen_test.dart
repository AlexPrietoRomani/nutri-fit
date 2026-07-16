import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/training/training_provider.dart';
import 'package:nutrifit/features/training/workout_screen.dart';

// NOTA: WorkoutScreen dispara fetchExercises()/fetchSavedRoutines() en
// initState sin override (usan SupabaseConfig.client). En este entorno de
// test nunca se llama Supabase.initialize(), así que acceder a
// Supabase.instance.client lanza una excepción síncrona que cada método
// atrapa en su try/catch (ver INC-015, docs/logs/log.md) — no cuelga el
// proceso, y no toca _savedRoutines ya poblado antes de montar el widget.
void main() {
  testWidgets('Mis Rutinas muestra estrella llena para is_default=true y vacía para las demás', (tester) async {
    final provider = TrainingProvider();
    await provider.fetchSavedRoutines(fetchOverride: () async => [
          {'id': 'r1', 'name': 'Rutina A', 'items': [], 'cardio_block': null, 'is_default': true},
          {'id': 'r2', 'name': 'Rutina B', 'items': [], 'cardio_block': null, 'is_default': false},
        ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<TrainingProvider>.value(
        value: provider,
        child: const MaterialApp(home: WorkoutScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('set_default_routine_r1')), findsOneWidget);
    expect(find.byKey(const Key('set_default_routine_r2')), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);

    final r1Star = tester.widget<IconButton>(find.byKey(const Key('set_default_routine_r1')));
    expect((r1Star.icon as Icon).icon, Icons.star_rounded);
    final r2Star = tester.widget<IconButton>(find.byKey(const Key('set_default_routine_r2')));
    expect((r2Star.icon as Icon).icon, Icons.star_border_rounded);
  });
}
