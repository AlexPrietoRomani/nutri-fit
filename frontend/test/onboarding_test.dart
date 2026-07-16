import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifit/features/auth/onboarding_provider.dart';

void main() {
  group('OnboardingProvider Calculations Tests', () {
    test('Should calculate correct BMR, TDEE, BMI and macros for a Male', () {
      final provider = OnboardingProvider();

      // Configure test data
      provider.setName('Carlos');
      // Set birth date so that age is 30
      final today = DateTime.now();
      provider.setBirthDate(DateTime(today.year - 30, today.month, today.day));
      provider.setGender('M');
      provider.setHeight(180.0);
      provider.setWeight(80.0);
      provider.setPalLevel(1.375); // Lightly Active
      provider.setGoalType('maintenance');

      provider.calculateNutrition();

      // Assertions
      expect(provider.age, 30);
      
      // BMR = 10 * 80 + 6.25 * 180 - 5 * 30 + 5 = 800 + 1125 - 150 + 5 = 1780
      expect(provider.bmr, 1780.0);

      // TDEE = 1780 * 1.375 = 2447.5
      expect(provider.tdee, 2447.5);
      expect(provider.targetCalories, 2448); // Rounded

      // BMI = 80 / (1.8 * 1.8) = 24.6913...
      expect(provider.bmi, closeTo(24.69, 0.1));

      // Macros
      // Protein: 2.0 * 80 = 160g
      expect(provider.targetProtein, 160.0);
      // Fat: 1.0 * 80 = 80g
      expect(provider.targetFat, 80.0);
      // Carbs: (2448 - (160 * 4 + 80 * 9)) / 4 = (2448 - (640 + 720)) / 4 = (2448 - 1360) / 4 = 1088 / 4 = 272g
      expect(provider.targetCarbs, 272.0);
    });

    test('Should calculate correct BMR, TDEE, BMI and macros for a Female with Deficit', () {
      final provider = OnboardingProvider();

      provider.setName('Ana');
      final today = DateTime.now();
      provider.setBirthDate(DateTime(today.year - 25, today.month, today.day));
      provider.setGender('F');
      provider.setHeight(160.0);
      provider.setWeight(60.0);
      provider.setPalLevel(1.2); // Sedentary
      provider.setGoalType('deficit'); // 500 kcal deficit

      provider.calculateNutrition();

      expect(provider.age, 25);

      // BMR = 10 * 60 + 6.25 * 160 - 5 * 25 - 161 = 600 + 1000 - 125 - 161 = 1314
      expect(provider.bmr, 1314.0);

      // TDEE = 1314 * 1.2 = 1576.8
      expect(provider.tdee, 1576.8);

      // Target Calories (Deficit: TDEE - 500 = 1576.8 - 500 = 1076.8, but floor is 1200)
      expect(provider.targetCalories, 1200);

      // BMI = 60 / (1.6 * 1.6) = 23.4375
      expect(provider.bmi, closeTo(23.44, 0.1));

      // Macros
      // Protein: 2.0 * 60 = 120g (480 kcal)
      expect(provider.targetProtein, 120.0);
      // Fat: 1.0 * 60 = 60g (540 kcal)
      expect(provider.targetFat, 60.0);
      // Carbs: (1200 - (480 + 540)) / 4 = 180 / 4 = 45g
      expect(provider.targetCarbs, 45.0);
    });
    test('buildUserPayload incluye weight_kg (T17.2.1)', () {
      final provider = OnboardingProvider();
      provider.setWeight(82.5);
      final payload = provider.buildUserPayload('user-1');
      expect(payload['weight_kg'], 82.5);
      expect(payload['id'], 'user-1');
    });

    group('Database operations mock testing outline', () {
      // Standard integration mocks or database calls would be verified here.
    });
  });
}
