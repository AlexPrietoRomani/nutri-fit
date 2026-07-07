import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'training_provider.dart';
import 'active_workout_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar catálogo de ejercicios de Supabase al entrar
    Future.microtask(() {
      context.read<TrainingProvider>().fetchExercises();
    });
  }

  // Rutinas por defecto predefinidas
  final List<Map<String, dynamic>> _predefinedRoutines = [
    {
      'name': 'Rutina de Gimnasio (Push/Pull/Leg)',
      'description': 'Entrenamiento enfocado en hipertrofia usando barras, mancuernas y poleas.',
      'type': 'gimnasio',
      'icon': Icons.fitness_center_rounded,
      'color': const Color(0xFF2ED573),
    },
    {
      'name': 'Rutina en Casa (Cuerpo Completo)',
      'description': 'Ideal para realizar con bandas elásticas y peso corporal.',
      'type': 'casa',
      'icon': Icons.home_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'name': 'Rutina de Calistenia (Básico/Medio)',
      'description': 'Entrenamiento basado puramente en dominio de peso corporal.',
      'type': 'calistenia',
      'icon': Icons.sports_gymnastics_rounded,
      'color': Colors.cyanAccent,
    },
  ];

  void _startWorkout(String routineName) async {
    final provider = context.read<TrainingProvider>();
    await provider.startWorkoutSession(routineName);

    if (provider.activeSession != null) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ActiveWorkoutScreen(),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al iniciar sesión: ${provider.errorMessage ?? "Error desconocido"}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.fetchExercises(),
          ),
        ],
      ),
      body: provider.isLoading && provider.exercises.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botón Iniciar entrenamiento vacío
                  Card(
                    color: const Color(0xFF1E201E),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _startWorkout('Entrenamiento Libre / Vacío'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ED573).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 36,
                                color: Color(0xFF2ED573),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Iniciar Entrenamiento Vacío',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Registra series sobre la marcha sin rutina previa.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Rutinas Predefinidas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Lista de rutinas
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _predefinedRoutines.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final routine = _predefinedRoutines[index];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _startWorkout(routine['name'] as String),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (routine['color'] as Color).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    routine['icon'] as IconData,
                                    color: routine['color'] as Color,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        routine['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        routine['description'] as String,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey,
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
