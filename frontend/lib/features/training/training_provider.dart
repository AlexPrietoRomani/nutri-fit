import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

/// Modelo de datos para un Ejercicio.
class Exercise {
  final int id;
  final String name;
  final String category;
  final String? equipment;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.equipment,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      equipment: json['equipment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'equipment': equipment,
    };
  }
}

/// Modelo de datos para una Sesión de Entrenamiento.
class WorkoutSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String name;

  WorkoutSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    required this.name,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String).toLocal()
          : null,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'name': name,
    };
  }
}

/// Modelo de datos para una Serie (Set) de Ejercicio.
class WorkoutSet {
  final int? id;
  final String sessionId;
  final int exerciseId;
  final int setNumber;
  final double weight;
  final int reps;
  final double? rpe;
  final bool completed;

  WorkoutSet({
    this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.rpe,
    this.completed = true,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'] as int?,
      sessionId: json['session_id'] as String,
      exerciseId: json['exercise_id'] as int,
      setNumber: json['set_number'] as int,
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int,
      rpe: json['rpe'] != null ? (json['rpe'] as num).toDouble() : null,
      completed: json['completed'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'completed': completed,
    };
    if (id != null) data['id'] = id;
    if (rpe != null) data['rpe'] = rpe;
    return data;
  }
}

/// Proveedor para gestionar las rutinas, sesiones de entrenamiento en vivo y llamadas a Supabase.
class TrainingProvider extends ChangeNotifier {
  List<Exercise> _exercises = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Sesión activa en vivo
  WorkoutSession? _activeSession;
  final List<WorkoutSet> _activeSets = [];
  final Set<int> _activeExercisesIds = {}; // Ejercicios añadidos en el entrenamiento en curso
  DateTime? _activeStartTime;

  List<Exercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WorkoutSession? get activeSession => _activeSession;
  List<WorkoutSet> get activeSets => _activeSets;
  Set<int> get activeExercisesIds => _activeExercisesIds;
  DateTime? get activeStartTime => _activeStartTime;

  /// Cargar el catálogo de ejercicios de la tabla `training.exercises`.
  Future<void> fetchExercises() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.client;
      // Consultamos el esquema 'training' y la tabla 'exercises'
      final response = await client
          .schema('training')
          .from('exercises')
          .select();

      final List<dynamic> data = response as List<dynamic>;
      _exercises = data.map((json) => Exercise.fromJson(json as Map<String, dynamic>)).toList();
      
      // Si la tabla de ejercicios está vacía, precargamos algunos ejercicios por defecto para testing/demo.
      if (_exercises.isEmpty) {
        await _seedInitialExercises();
        final reloadResponse = await client
            .schema('training')
            .from('exercises')
            .select();
        final List<dynamic> reloadData = reloadResponse as List<dynamic>;
        _exercises = reloadData.map((json) => Exercise.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Precargar ejercicios base si la tabla está vacía.
  Future<void> _seedInitialExercises() async {
    final client = SupabaseConfig.client;
    final defaultExercises = [
      {'id': 1, 'name': 'Sentadilla libre', 'category': 'Pierna', 'equipment': 'Barra'},
      {'id': 2, 'name': 'Press de Banca', 'category': 'Empuje', 'equipment': 'Barra'},
      {'id': 3, 'name': 'Peso Muerto', 'category': 'Tracción', 'equipment': 'Barra'},
      {'id': 4, 'name': 'Dominadas', 'category': 'Tracción', 'equipment': 'Ninguno'},
      {'id': 5, 'name': 'Flexiones de Pecho', 'category': 'Empuje', 'equipment': 'Ninguno'},
      {'id': 6, 'name': 'Prensa de Piernas', 'category': 'Pierna', 'equipment': 'Máquina'},
      {'id': 7, 'name': 'Curl de Bíceps', 'category': 'Tracción', 'equipment': 'Mancuerna'},
      {'id': 8, 'name': 'Press Militar', 'category': 'Empuje', 'equipment': 'Mancuerna'},
    ];

    try {
      await client.schema('training').from('exercises').insert(defaultExercises);
    } catch (e) {
      debugPrint('Error al precargar ejercicios: $e');
    }
  }

  /// Inicia una sesión de entrenamiento activo en Supabase.
  Future<void> startWorkoutSession(String routineName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.client;
      // Obtener o crear userId para pruebas locales
      String userId;
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        userId = currentUser.id;
      } else {
        userId = '00000000-0000-0000-0000-000000000000'; // Fallback uuid
      }

      _activeStartTime = DateTime.now();

      // Insert en `training.workout_sessions`
      final response = await client
          .schema('training')
          .from('workout_sessions')
          .insert({
            'user_id': userId,
            'started_at': _activeStartTime!.toUtc().toIso8601String(),
            'name': routineName,
          })
          .select()
          .single();

      _activeSession = WorkoutSession.fromJson(response);
      _activeSets.clear();
      _activeExercisesIds.clear();
    } catch (e) {
      _errorMessage = e.toString();
      _activeSession = null;
      _activeStartTime = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Añadir un ejercicio a la sesión de entrenamiento activo en curso.
  void addExerciseToActiveWorkout(int exerciseId) {
    if (_activeSession == null) return;
    _activeExercisesIds.add(exerciseId);
    
    // Añadimos una serie inicial vacía para este ejercicio
    addSetToActiveExercise(exerciseId);
  }

  /// Eliminar un ejercicio y todas sus series de la sesión activa en curso.
  void removeExerciseFromActiveWorkout(int exerciseId) {
    _activeExercisesIds.remove(exerciseId);
    _activeSets.removeWhere((set) => set.exerciseId == exerciseId);
    notifyListeners();
  }

  /// Añadir una serie vacía o con valores base a un ejercicio de la sesión activa.
  void addSetToActiveExercise(int exerciseId) {
    if (_activeSession == null) return;

    final existingSets = _activeSets.where((s) => s.exerciseId == exerciseId).toList();
    final nextSetNumber = existingSets.length + 1;
    
    // Tomar peso y reps del set anterior si existe
    double defaultWeight = 10.0;
    int defaultReps = 10;
    double? defaultRpe = 8.0;
    if (existingSets.isNotEmpty) {
      defaultWeight = existingSets.last.weight;
      defaultReps = existingSets.last.reps;
      defaultRpe = existingSets.last.rpe;
    }

    final newSet = WorkoutSet(
      sessionId: _activeSession!.id,
      exerciseId: exerciseId,
      setNumber: nextSetNumber,
      weight: defaultWeight,
      reps: defaultReps,
      rpe: defaultRpe,
      completed: false, // Inicia sin marcar (completed = false)
    );

    _activeSets.add(newSet);
    notifyListeners();
  }

  /// Actualizar datos de un set localmente.
  void updateSetData(int index, {double? weight, int? reps, double? rpe, bool? completed}) {
    if (index < 0 || index >= _activeSets.length) return;
    final original = _activeSets[index];
    _activeSets[index] = WorkoutSet(
      id: original.id,
      sessionId: original.sessionId,
      exerciseId: original.exerciseId,
      setNumber: original.setNumber,
      weight: weight ?? original.weight,
      reps: reps ?? original.reps,
      rpe: rpe ?? original.rpe,
      completed: completed ?? original.completed,
    );
    notifyListeners();
  }

  /// Elimina un set específico de la lista activa.
  void removeSetFromActiveExercise(int exerciseId, int setIndexInExercise) {
    final setsForExercise = _activeSets.where((s) => s.exerciseId == exerciseId).toList();
    if (setIndexInExercise < 0 || setIndexInExercise >= setsForExercise.length) return;
    
    final setToRemove = setsForExercise[setIndexInExercise];
    _activeSets.remove(setToRemove);

    // Reordenar los números de serie restantes para este ejercicio
    final remainingSets = _activeSets.where((s) => s.exerciseId == exerciseId).toList();
    for (int i = 0; i < remainingSets.length; i++) {
      final oldSet = remainingSets[i];
      final globalIndex = _activeSets.indexOf(oldSet);
      _activeSets[globalIndex] = WorkoutSet(
        id: oldSet.id,
        sessionId: oldSet.sessionId,
        exerciseId: oldSet.exerciseId,
        setNumber: i + 1,
        weight: oldSet.weight,
        reps: oldSet.reps,
        rpe: oldSet.rpe,
        completed: oldSet.completed,
      );
    }

    notifyListeners();
  }

  /// Finaliza el entrenamiento activo, guarda todos los sets completados en Supabase y actualiza la sesión con ended_at.
  Future<bool> finishWorkoutSession() async {
    if (_activeSession == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.client;
      final endedAt = DateTime.now();

      // 1. Guardar la fecha de finalización en `training.workout_sessions`
      await client
          .schema('training')
          .from('workout_sessions')
          .update({
            'ended_at': endedAt.toUtc().toIso8601String(),
          })
          .eq('id', _activeSession!.id);

      // 2. Guardar únicamente las series completadas (o todas, pero el RLS y diseño dice que las series realizadas se guardan)
      // Filtramos las series marcadas como completadas.
      final completedSets = _activeSets.where((set) => set.completed).toList();

      if (completedSets.isNotEmpty) {
        final setsJson = completedSets.map((set) => set.toJson()).toList();
        await client
            .schema('training')
            .from('workout_sets')
            .insert(setsJson);
      }

      // Limpiar estado activo
      _activeSession = null;
      _activeSets.clear();
      _activeExercisesIds.clear();
      _activeStartTime = null;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancelar el entrenamiento actual sin guardar.
  void cancelActiveWorkout() {
    _activeSession = null;
    _activeSets.clear();
    _activeExercisesIds.clear();
    _activeStartTime = null;
    notifyListeners();
  }

  // ============================================================================
  // CÁLCULOS METRICOS DE ENTRENAMIENTO (Requeridos para Pruebas Unitarias)
  // ============================================================================

  /// Calcula el volumen total de entrenamiento por sesión (suma de: peso * reps de sets completados).
  static double calculateTotalVolume(List<WorkoutSet> sets) {
    double total = 0.0;
    for (final set in sets) {
      if (set.completed) {
        total += set.weight * set.reps;
      }
    }
    return total;
  }

  /// Calcula el RPE (esfuerzo percibido) promedio de los sets completados que tengan RPE asignado.
  static double calculateAverageRpe(List<WorkoutSet> sets) {
    final completedWithRpe = sets.where((set) => set.completed && set.rpe != null).toList();
    if (completedWithRpe.isEmpty) return 0.0;
    final totalRpe = completedWithRpe.map((set) => set.rpe!).reduce((a, b) => a + b);
    return totalRpe / completedWithRpe.length;
  }
}
