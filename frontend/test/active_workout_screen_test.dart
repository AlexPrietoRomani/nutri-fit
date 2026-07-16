import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/training/active_workout_screen.dart';
import 'package:nutrifit/features/training/training_provider.dart';

void main() {
  Exercise buildExercise({required int id, required String name, List<String> imageUrls = const []}) {
    return Exercise(
      id: id,
      name: name,
      category: 'strength',
      targetMuscle: 'chest',
      equipment: 'barbell',
      instructionsEn: const ['Paso 1', 'Paso 2'],
      imageUrls: imageUrls,
    );
  }

  TrainingProvider buildProvider({
    required List<Exercise> exercises,
    required List<WorkoutSet> sets,
  }) {
    final provider = TrainingProvider();
    final session = WorkoutSession(
      id: 'session-1',
      userId: 'user-1',
      startedAt: DateTime.now(),
      name: 'Sesión de prueba',
    );
    provider.debugSetActiveStateForTest(
      exercises: exercises,
      session: session,
      sets: sets,
      exerciseIds: exercises.map((e) => e.id).toSet(),
    );
    return provider;
  }

  Widget wrap(TrainingProvider provider) => ChangeNotifierProvider<TrainingProvider>.value(
        value: provider,
        child: const MaterialApp(home: ActiveWorkoutScreen()),
      );

  testWidgets('la tarjeta del ejercicio activo muestra la miniatura (_ExerciseThumbnail)', (tester) async {
    final exercise = buildExercise(id: 1, name: 'Press Banca', imageUrls: const ['https://example.com/a.jpg']);
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 1, setNumber: 1, weight: 10, reps: 10, completed: false),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    // La miniatura se renderiza como ClipRRect+Image.network dentro de la tarjeta
    // del ejercicio (mismo widget que ya usa la hoja "Agregar Ejercicio").
    expect(
      find.descendant(of: find.byType(Card), matching: find.byType(ClipRRect)),
      findsOneWidget,
    );
  });

  testWidgets('tocar el nombre del ejercicio abre el diálogo de detalle', (tester) async {
    final exercise = buildExercise(id: 1, name: 'Press Banca');
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 1, setNumber: 1, weight: 10, reps: 10, completed: false),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    // La miniatura del ejercicio está presente en la tarjeta activa.
    expect(find.text('Press Banca'), findsOneWidget);

    await tester.tap(find.text('Press Banca'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    // El nombre aparece duplicado: en la tarjeta y en el diálogo.
    expect(find.text('Press Banca'), findsNWidgets(2));
  });

  testWidgets('el diálogo de detalle con 2 imágenes renderiza un PageView con itemCount 2 y el texto de deslizar',
      (tester) async {
    final exercise = buildExercise(
      id: 2,
      name: 'Sentadilla',
      imageUrls: const ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
    );
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 2, setNumber: 1, weight: 10, reps: 10, completed: false),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    await tester.tap(find.text('Sentadilla'));
    await tester.pump();
    await tester.pump();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect((pageView.childrenDelegate as SliverChildBuilderDelegate).childCount, 2);
    expect(find.textContaining('imágenes — desliza'), findsOneWidget);
  });

  testWidgets('el diálogo de detalle con 1 imagen no muestra el texto de deslizar', (tester) async {
    final exercise = buildExercise(
      id: 3,
      name: 'Remo',
      imageUrls: const ['https://example.com/a.jpg'],
    );
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 3, setNumber: 1, weight: 10, reps: 10, completed: false),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    await tester.tap(find.text('Remo'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.textContaining('desliza'), findsNothing);
  });

  testWidgets('el diálogo de detalle sin imágenes cae al ícono de fallback', (tester) async {
    final exercise = buildExercise(id: 4, name: 'Plancha', imageUrls: const []);
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 4, setNumber: 1, weight: 10, reps: 10, completed: false),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    await tester.tap(find.text('Plancha'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageView), findsNothing);
    // Un ícono de fallback en la tarjeta (miniatura) y otro en el diálogo.
    expect(find.byIcon(Icons.fitness_center_rounded), findsNWidgets(2));
  });

  testWidgets('ejercicio con todos los sets completados muestra el indicador visual de "hecho"',
      (tester) async {
    final exercise = buildExercise(id: 5, name: 'Curl Bíceps');
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 5, setNumber: 1, weight: 10, reps: 10, completed: true),
        WorkoutSet(sessionId: 'session-1', exerciseId: 5, setNumber: 2, weight: 10, reps: 10, completed: true),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    // El ícono de check junto al nombre solo aparece cuando allDone es true;
    // se busca en el encabezado de la tarjeta (no en el checkbox de sets).
    final headerCheckIcon = find.descendant(
      of: find.byType(Card),
      matching: find.byIcon(Icons.check_circle_rounded),
    );
    expect(headerCheckIcon, findsOneWidget);

    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape as RoundedRectangleBorder;
    expect(shape.side.color, const Color(0xFF2ED573));
  });

  testWidgets('ejercicio con al menos un set incompleto NO muestra el indicador visual de "hecho"',
      (tester) async {
    final exercise = buildExercise(id: 6, name: 'Extensión Tríceps');
    final provider = buildProvider(
      exercises: [exercise],
      sets: [
        WorkoutSet(sessionId: 'session-1', exerciseId: 6, setNumber: 1, weight: 10, reps: 10, completed: true),
        WorkoutSet(sessionId: 'session-1', exerciseId: 6, setNumber: 2, weight: 10, reps: 10, completed: false),
      ],
    );

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    final headerCheckIcon = find.descendant(
      of: find.byType(Card),
      matching: find.byIcon(Icons.check_circle_rounded),
    );
    expect(headerCheckIcon, findsNothing);

    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape as RoundedRectangleBorder;
    expect(shape.side.color, Colors.transparent);
  });
}
