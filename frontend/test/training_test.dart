import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifit/features/training/training_provider.dart';

void main() {
  group('TrainingProvider Calculations & Metrics Tests', () {
    test('calculateTotalVolume should sum weight * reps for completed sets only', () {
      final sets = [
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 1,
          setNumber: 1,
          weight: 100.0,
          reps: 5,
          rpe: 8.5,
          completed: true,
        ),
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 1,
          setNumber: 2,
          weight: 100.0,
          reps: 4,
          rpe: 9.0,
          completed: true,
        ),
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 1,
          setNumber: 3,
          weight: 100.0,
          reps: 3,
          rpe: 10.0,
          completed: false, // Should NOT be included in volume calculation
        ),
      ];

      final totalVolume = TrainingProvider.calculateTotalVolume(sets);
      // Expected Volume = (100 * 5) + (100 * 4) = 500 + 400 = 900
      expect(totalVolume, 900.0);
    });

    test('calculateAverageRpe should calculate correct average of completed sets with RPE', () {
      final sets = [
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 2,
          setNumber: 1,
          weight: 60.0,
          reps: 10,
          rpe: 7.0,
          completed: true,
        ),
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 2,
          setNumber: 2,
          weight: 60.0,
          reps: 10,
          rpe: 8.0,
          completed: true,
        ),
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 2,
          setNumber: 3,
          weight: 60.0,
          reps: 8,
          rpe: null, // Should be ignored in average RPE
          completed: true,
        ),
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 2,
          setNumber: 4,
          weight: 60.0,
          reps: 6,
          rpe: 9.5,
          completed: false, // Should be ignored because it is not completed
        ),
      ];

      final avgRpe = TrainingProvider.calculateAverageRpe(sets);
      // Expected RPE = (7.0 + 8.0) / 2 = 7.5
      expect(avgRpe, 7.5);
    });

    test('calculateAverageRpe should return 0.0 if there are no completed sets with RPE', () {
      final sets = [
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 3,
          setNumber: 1,
          weight: 40.0,
          reps: 12,
          rpe: null,
          completed: true,
        ),
        WorkoutSet(
          sessionId: 'session-123',
          exerciseId: 3,
          setNumber: 2,
          weight: 40.0,
          reps: 10,
          rpe: 9.0,
          completed: false,
        ),
      ];

      final avgRpe = TrainingProvider.calculateAverageRpe(sets);
      expect(avgRpe, 0.0);
    });
  });

  group('Exercise.fromJson (dataset free-exercise-db)', () {
    test('parsea todos los campos nuevos (arrays + jsonb)', () {
      final exercise = Exercise.fromJson({
        'id': 1,
        'external_id': '3_4_Sit-Up',
        'name': '3/4 Sit-Up',
        'category': 'strength',
        'body_part': 'abdominals',
        'target_muscle': 'abdominals',
        'secondary_muscles': ['hip flexors', 'lower back'],
        'equipment': 'body only',
        'force': 'pull',
        'level': 'beginner',
        'mechanic': 'compound',
        'instructions': {
          'en': ['Lie down', 'Flex', 'Return'],
        },
        'image_urls': [
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/3_4_Sit-Up/0.jpg',
        ],
      });

      expect(exercise.id, 1);
      expect(exercise.externalId, '3_4_Sit-Up');
      expect(exercise.targetMuscle, 'abdominals');
      expect(exercise.secondaryMuscles, ['hip flexors', 'lower back']);
      expect(exercise.instructionsEn.length, 3);
      expect(exercise.instructionsEn.first, 'Lie down');
      expect(exercise.imageUrls.length, 1);
    });

    test('campos ausentes/nulos degradan a listas vacías, no a null', () {
      final exercise = Exercise.fromJson({
        'id': 2,
        'name': 'Sin metadatos',
        'category': 'cardio',
        'secondary_muscles': null,
        'instructions': null,
        'image_urls': null,
        'equipment': null,
      });

      expect(exercise.secondaryMuscles, isEmpty);
      expect(exercise.instructionsEn, isEmpty);
      expect(exercise.imageUrls, isEmpty);
      expect(exercise.equipment, isNull);
    });
  });

  group('TrainingProvider.fetchSavedRoutines (T13.3.1)', () {
    // No se instancia SupabaseClient real: cuelga el proceso de test en este
    // entorno (INC-015, docs/logs/log.md). Se usa el mismo seam/override
    // inyectable ya usado en ChatScreen.saveRoutineOverride.
    test('puebla savedRoutines desde la respuesta inyectada', () async {
      final provider = TrainingProvider();
      final fakeRoutines = [
        {
          'id': 'r1',
          'name': 'Rutina IA Push/Pull',
          'source': 'ai',
          'items': [
            {'exercise_id': 1, 'name': 'Press banca', 'sets': 3, 'reps': 8, 'rpe': 8.0},
          ],
          'cardio_block': null,
        },
      ];

      await provider.fetchSavedRoutines(fetchOverride: () async => fakeRoutines);

      expect(provider.savedRoutines, fakeRoutines);
      expect(provider.errorMessage, isNull);
    });

    test('errores del fetch inyectado se reflejan en errorMessage sin lanzar', () async {
      final provider = TrainingProvider();

      await provider.fetchSavedRoutines(
        fetchOverride: () async => throw Exception('boom'),
      );

      expect(provider.savedRoutines, isEmpty);
      expect(provider.errorMessage, contains('boom'));
    });
  });

  group('TrainingProvider.buildSetsFromRoutineItems (T13.3.1)', () {
    test('crea sum(sets) WorkoutSet con reps/rpe de cada item, no los defaults', () {
      final items = [
        {'exercise_id': 1, 'name': 'Sentadilla', 'sets': 3, 'reps': 12, 'rpe': 7.5},
        {'exercise_id': 2, 'name': 'Peso muerto', 'sets': 2, 'reps': 5, 'rpe': 9.0},
      ];

      final result = TrainingProvider.buildSetsFromRoutineItems('session-abc', items);

      // sum(sets) = 3 + 2 = 5
      expect(result.length, 5);

      final ex1Sets = result.where((s) => s.exerciseId == 1).toList();
      expect(ex1Sets.length, 3);
      expect(ex1Sets.every((s) => s.reps == 12 && s.rpe == 7.5), isTrue);
      expect(ex1Sets.map((s) => s.setNumber).toList(), [1, 2, 3]);

      final ex2Sets = result.where((s) => s.exerciseId == 2).toList();
      expect(ex2Sets.length, 2);
      expect(ex2Sets.every((s) => s.reps == 5 && s.rpe == 9.0), isTrue);

      // No usan los defaults de addSetToActiveExercise (10 reps / 8.0 rpe)
      expect(result.every((s) => s.completed == false), isTrue);
      expect(result.every((s) => s.sessionId == 'session-abc'), isTrue);
    });

    test('usa defaults (sets=1, reps=10) si el item no los especifica', () {
      final items = [
        {'exercise_id': 5, 'name': 'Plancha'},
      ];

      final result = TrainingProvider.buildSetsFromRoutineItems('session-xyz', items);

      expect(result.length, 1);
      expect(result.first.reps, 10);
      expect(result.first.rpe, isNull);
    });
  });
}
