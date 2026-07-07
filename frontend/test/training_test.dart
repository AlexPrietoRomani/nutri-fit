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
}
