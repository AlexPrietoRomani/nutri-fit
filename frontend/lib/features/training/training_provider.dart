import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

/// Modelo de datos para un Ejercicio del catálogo (free-exercise-db).
class Exercise {
  final int id;
  final String? externalId;
  final String name;
  final String category;
  final String? bodyPart;
  final String? targetMuscle;
  final List<String> secondaryMuscles;
  final String? equipment;
  final String? force;
  final String? level;
  final String? mechanic;
  final List<String> instructionsEn;
  final List<String> imageUrls;

  Exercise({
    required this.id,
    this.externalId,
    required this.name,
    required this.category,
    this.bodyPart,
    this.targetMuscle,
    this.secondaryMuscles = const [],
    this.equipment,
    this.force,
    this.level,
    this.mechanic,
    this.instructionsEn = const [],
    this.imageUrls = const [],
  });

  /// Convierte un valor devuelto por PostgREST (`TEXT[]`) en `List<String>`.
  static List<String> _stringList(dynamic value) {
    if (value == null) return const [];
    return (value as List).map((e) => e.toString()).toList();
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // `instructions` es JSONB: {"en": ["paso 1", ...]}
    final dynamic instr = json['instructions'];
    final List<String> steps = (instr is Map && instr['en'] != null)
        ? (instr['en'] as List).map((e) => e.toString()).toList()
        : const [];

    return Exercise(
      id: json['id'] as int,
      externalId: json['external_id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String,
      bodyPart: json['body_part'] as String?,
      targetMuscle: json['target_muscle'] as String?,
      secondaryMuscles: _stringList(json['secondary_muscles']),
      equipment: json['equipment'] as String?,
      force: json['force'] as String?,
      level: json['level'] as String?,
      mechanic: json['mechanic'] as String?,
      instructionsEn: steps,
      imageUrls: _stringList(json['image_urls']),
    );
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

  List<Map<String, dynamic>> _savedRoutines = [];

  List<Exercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WorkoutSession? get activeSession => _activeSession;
  List<WorkoutSet> get activeSets => _activeSets;
  Set<int> get activeExercisesIds => _activeExercisesIds;
  DateTime? get activeStartTime => _activeStartTime;
  List<Map<String, dynamic>> get savedRoutines => List.unmodifiable(_savedRoutines);

  /// Carga las rutinas guardadas por el usuario (`training.routines`).
  ///
  /// [fetchOverride] permite inyectar la respuesta en tests sin levantar un
  /// `SupabaseClient` real (ver INC-015 en docs/logs/log.md: el isolate de
  /// JSON de Supabase cuelga el proceso de test en este entorno). En
  /// producción se omite y se usa el cliente real.
  Future<void> fetchSavedRoutines({
    Future<List<Map<String, dynamic>>> Function()? fetchOverride,
  }) async {
    try {
      if (fetchOverride != null) {
        _savedRoutines = await fetchOverride();
      } else {
        final client = SupabaseConfig.client;
        final data = await client
            .schema('training')
            .from('routines')
            .select()
            .order('created_at', ascending: false);
        _savedRoutines = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

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
      // El catálogo se puebla en el init de Postgres desde free-exercise-db
      // (docker/postgres/zz_exercises_seed.sql); aquí solo se lee.
      _exercises = data.map((json) => Exercise.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Inicia una sesión de entrenamiento activo en Supabase.
  Future<void> startWorkoutSession(String routineName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.client;
      final userId = client.auth.currentUser!.id;

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

  /// Inicia una sesión desde una rutina guardada (`training.routines.items`),
  /// precargando sets/reps/rpe objetivo de cada ejercicio en vez de dejar la
  /// sesión vacía como hace [startWorkoutSession].
  Future<void> startWorkoutSessionFromRoutine(String name, List<dynamic> items) async {
    await startWorkoutSession(name);
    if (_activeSession == null) return;

    for (final raw in items) {
      final exerciseId = (raw as Map<String, dynamic>)['exercise_id'] as int;
      _activeExercisesIds.add(exerciseId);
    }
    _activeSets.addAll(buildSetsFromRoutineItems(_activeSession!.id, items));
    notifyListeners();
  }

  /// Construye los `WorkoutSet` iniciales de una rutina guardada a partir de
  /// sus `items` (`[{exercise_id, name, sets, reps, rpe}]`). Función pura,
  /// separada para poder testearla sin depender de Supabase (ver INC-015).
  @visibleForTesting
  static List<WorkoutSet> buildSetsFromRoutineItems(String sessionId, List<dynamic> items) {
    final result = <WorkoutSet>[];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final exerciseId = item['exercise_id'] as int;
      final sets = (item['sets'] as num?)?.toInt() ?? 1;
      final reps = (item['reps'] as num?)?.toInt() ?? 10;
      final rpe = (item['rpe'] as num?)?.toDouble();
      for (var i = 0; i < sets; i++) {
        result.add(WorkoutSet(
          sessionId: sessionId,
          exerciseId: exerciseId,
          setNumber: i + 1,
          weight: 10.0, // la IA no prescribe peso, el usuario lo ajusta
          reps: reps,
          rpe: rpe,
          completed: false,
        ));
      }
    }
    return result;
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

  List<WorkoutSession> _completedSessions = [];
  List<WorkoutSet> _completedSets = [];

  List<WorkoutSession> get completedSessions => _completedSessions;
  List<WorkoutSet> get completedSets => _completedSets;

  double get todayCaloriesBurned {
    // Estimación: 6 calorías por minuto de entrenamiento realizado.
    double totalCalories = 0.0;
    for (final session in _completedSessions) {
      if (session.endedAt != null) {
        final durationMin = session.endedAt!.difference(session.startedAt).inMinutes;
        // Mínimo 15 min por sesión para evitar estimaciones absurdas por entrenamientos vacíos
        final activeMin = durationMin > 0 ? durationMin : 15;
        totalCalories += activeMin * 6.0;
      }
    }
    return totalCalories;
  }

  Future<void> loadCompletedWorkouts(DateTime date) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.client;
      final userId = client.auth.currentUser!.id;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      final response = await client
          .schema('training')
          .from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .gte('started_at', startOfDay.toUtc().toIso8601String())
          .lte('started_at', endOfDay.toUtc().toIso8601String());

      final List<dynamic> data = response as List<dynamic>;
      _completedSessions = data.map((json) => WorkoutSession.fromJson(json as Map<String, dynamic>)).toList();

      if (_completedSessions.isNotEmpty) {
        final sessionIds = _completedSessions.map((s) => s.id).toList();
        final setsResponse = await client
            .schema('training')
            .from('workout_sets')
            .select()
            .inFilter('session_id', sessionIds);
        
        final List<dynamic> setsData = setsResponse as List<dynamic>;
        _completedSets = setsData.map((json) => WorkoutSet.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        _completedSets.clear();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Puebla el estado de sesión activa directamente, sin pasar por Supabase.
  /// Seam de test análogo a `fetchOverride`/`buildSetsFromRoutineItems`: evita
  /// instanciar un `SupabaseClient` real (INC-015) para montar
  /// `ActiveWorkoutScreen` en widget tests.
  @visibleForTesting
  void debugSetActiveStateForTest({
    required List<Exercise> exercises,
    required WorkoutSession session,
    required List<WorkoutSet> sets,
    required Set<int> exerciseIds,
  }) {
    _exercises = exercises;
    _activeSession = session;
    _activeSets
      ..clear()
      ..addAll(sets);
    _activeExercisesIds
      ..clear()
      ..addAll(exerciseIds);
    _activeStartTime = DateTime.now();
    notifyListeners();
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
