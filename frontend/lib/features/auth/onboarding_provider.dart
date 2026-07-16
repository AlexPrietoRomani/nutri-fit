import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/constants.dart';

class OnboardingProvider extends ChangeNotifier {
  // Form fields
  String _name = '';
  DateTime _birthDate = DateTime(1995, 1, 1);
  String _gender = 'M'; // 'M' or 'F'
  double _heightCm = 170.0;
  double _weightKg = 70.0;
  String _bodyType = 'mesomorph'; // 'ectomorph', 'mesomorph', 'endomorph'
  double _palLevel = 1.375; // Default to Lightly Active
  String _goalType = 'maintenance'; // 'deficit', 'maintenance', 'surplus'

  // Calculated results
  int _age = 30;
  double _bmi = 24.2;
  double _bmr = 1600.0;
  double _tdee = 2200.0;
  int _targetCalories = 2200;
  double _targetProtein = 140.0;
  double _targetCarbs = 250.0;
  double _targetFat = 70.0;

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String get name => _name;
  DateTime get birthDate => _birthDate;
  String get gender => _gender;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;
  String get bodyType => _bodyType;
  double get palLevel => _palLevel;
  String get goalType => _goalType;

  int get age => _age;
  double get bmi => _bmi;
  double get bmr => _bmr;
  double get tdee => _tdee;
  int get targetCalories => _targetCalories;
  double get targetProtein => _targetProtein;
  double get targetCarbs => _targetCarbs;
  double get targetFat => _targetFat;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Setters
  void setName(String val) {
    _name = val;
    notifyListeners();
  }

  void setBirthDate(DateTime val) {
    _birthDate = val;
    notifyListeners();
  }

  void setGender(String val) {
    _gender = val;
    notifyListeners();
  }

  void setHeight(double val) {
    _heightCm = val;
    notifyListeners();
  }

  void setWeight(double val) {
    _weightKg = val;
    notifyListeners();
  }

  void setBodyType(String val) {
    _bodyType = val;
    notifyListeners();
  }

  void setPalLevel(double val) {
    _palLevel = val;
    notifyListeners();
  }

  void setGoalType(String val) {
    _goalType = val;
    calculateNutrition();
  }

  /// Calculates age, BMI, BMR, TDEE and daily target macros.
  void calculateNutrition() {
    final today = DateTime.now();
    int calculatedAge = today.year - _birthDate.year;
    if (today.month < _birthDate.month || 
        (today.month == _birthDate.month && today.day < _birthDate.day)) {
      calculatedAge--;
    }
    _age = calculatedAge < 0 ? 0 : calculatedAge;

    // BMR (Mifflin-St Jeor)
    // Men: BMR = 10 * weight (kg) + 6.25 * height (cm) - 5 * age (y) + 5
    // Women: BMR = 10 * weight (kg) + 6.25 * height (cm) - 5 * age (y) - 161
    double bmrVal;
    if (_gender == 'M') {
      bmrVal = (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) + 5;
    } else {
      bmrVal = (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) - 161;
    }
    _bmr = bmrVal;

    // TDEE
    _tdee = bmrVal * _palLevel;

    // BMI (IMC) = weight (kg) / height^2 (m)
    double heightM = _heightCm / 100;
    _bmi = _weightKg / (heightM * heightM);

    // Goal adjustments
    double calGoal = _tdee;
    if (_goalType == 'deficit') {
      calGoal = _tdee - 500;
    } else if (_goalType == 'surplus') {
      calGoal = _tdee + 500;
    }
    if (calGoal < 1200) calGoal = 1200; // Floor limit for safety
    _targetCalories = calGoal.round();

    // Macro calculation:
    // Protein: 2.0g per kg of bodyweight
    _targetProtein = 2.0 * _weightKg;
    // Fat: 1.0g per kg of bodyweight
    _targetFat = 1.0 * _weightKg;
    // Carbs: rest of calories (1g carb = 4 kcal, 1g protein = 4 kcal, 1g fat = 9 kcal)
    double proteinKcal = _targetProtein * 4;
    double fatKcal = _targetFat * 9;
    double carbsKcal = _targetCalories - proteinKcal - fatKcal;
    if (carbsKcal < 0) carbsKcal = 0;
    _targetCarbs = carbsKcal / 4;

    notifyListeners();
  }

  /// Carga el perfil persistido (public.users + nutrition.user_goals) para que
  /// el Dashboard muestre datos reales tras un arranque en frío (no defaults).
  Future<void> loadProfile() async {
    try {
      final client = SupabaseConfig.client;
      final userId = client.auth.currentUser?.id ?? AppConstants.devUserId;

      final u = await client.from('users').select().eq('id', userId).maybeSingle();
      if (u != null) {
        _name = (u['name'] as String?) ?? _name;
        _gender = (u['gender'] as String?) ?? _gender;
        _heightCm = (u['height_cm'] as num?)?.toDouble() ?? _heightCm;
        _bodyType = (u['body_type'] as String?) ?? _bodyType;
        _palLevel = (u['pal_level'] as num?)?.toDouble() ?? _palLevel;
        final bd = u['birth_date'] as String?;
        if (bd != null && bd.isNotEmpty) {
          _birthDate = DateTime.tryParse(bd) ?? _birthDate;
        }
      }

      final g = await client
          .schema('nutrition')
          .from('user_goals')
          .select('goal_type')
          .eq('user_id', userId)
          .maybeSingle();
      if (g != null) {
        _goalType = (g['goal_type'] as String?) ?? _goalType;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar el perfil: $e');
    }
  }

  /// Inserts/saves the onboarding configuration to Supabase db.
  Future<bool> saveProfile(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.client;
      
      // In dev mode without GoTrue, use a deterministic user ID.
      // This avoids calls to /auth/v1/ which don't exist in our stack.
      const userId = AppConstants.devUserId;

      // 1. Insert into public.users
      await client.from('users').upsert({
        'id': userId,
        'name': _name.isEmpty ? 'Usuario' : _name,
        'birth_date': _birthDate.toIso8601String().substring(0, 10), // YYYY-MM-DD
        'gender': _gender,
        'height_cm': _heightCm,
        'body_type': _bodyType,
        'pal_level': _palLevel,
      });

      // 2. Insert into nutrition.user_goals
      await client.schema('nutrition').from('user_goals').upsert({
        'user_id': userId,
        'target_calories': _targetCalories,
        'target_protein_g': _targetProtein,
        'target_carbs_g': _targetCarbs,
        'target_fat_g': _targetFat,
        'goal_type': _goalType,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
