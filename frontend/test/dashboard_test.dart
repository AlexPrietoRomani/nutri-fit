import 'package:flutter_test/flutter_test.dart';

void main() {
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
