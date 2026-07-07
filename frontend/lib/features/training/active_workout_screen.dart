import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'training_provider.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  Timer? _timer;
  String _timeString = '00:00';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final startTime = context.read<TrainingProvider>().activeStartTime ?? DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = DateTime.now().difference(startTime);
      final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      final hours = diff.inHours > 0 ? '${diff.inHours.toString().padLeft(2, '0')}:' : '';
      
      if (mounted) {
        setState(() {
          _timeString = '$hours$minutes:$seconds';
        });
      }
    });
  }

  void _showAddExerciseModal(BuildContext context) {
    final provider = context.read<TrainingProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E201E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Seleccionar Ejercicio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: provider.exercises.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay ejercicios en el catálogo.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: provider.exercises.length,
                          separatorBuilder: (context, index) => const Divider(color: Colors.grey),
                          itemBuilder: (context, index) {
                            final exercise = provider.exercises[index];
                            final isAdded = provider.activeExercisesIds.contains(exercise.id);
                            return ListTile(
                              title: Text(
                                exercise.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${exercise.category} • ${exercise.equipment ?? "Cuerpo"}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              trailing: isAdded
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2ED573))
                                  : const Icon(Icons.add_circle_outline_rounded, color: Colors.grey),
                              onTap: () {
                                if (isAdded) {
                                  provider.removeExerciseFromActiveWorkout(exercise.id);
                                } else {
                                  provider.addExerciseToActiveWorkout(exercise.id);
                                }
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _finishWorkout() async {
    final provider = context.read<TrainingProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E201E),
        title: const Text('¿Finalizar Entrenamiento?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se guardarán todas las series que hayas marcado como completadas en Supabase.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await provider.finishWorkoutSession();
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Entrenamiento guardado con éxito!', style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF2ED573),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar el entrenamiento: ${provider.errorMessage}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _cancelWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E201E),
        title: const Text('¿Descartar Entrenamiento?', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que quieres descartar esta sesión? Se perderán todos los datos actuales.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, continuar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, descartar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      context.read<TrainingProvider>().cancelActiveWorkout();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrainingProvider>();
    final activeSession = provider.activeSession;

    if (activeSession == null) {
      return const Scaffold(
        body: Center(
          child: Text('No hay ningún entrenamiento activo actualmente.'),
        ),
      );
    }

    // Calcular Volumen y RPE promedio al vuelo
    final totalVolume = TrainingProvider.calculateTotalVolume(provider.activeSets);
    final avgRpe = TrainingProvider.calculateAverageRpe(provider.activeSets);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _cancelWorkout,
        ),
        title: Text(activeSession.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text(
              'Finalizar',
              style: TextStyle(color: Color(0xFF2ED573), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            )
          : Column(
              children: [
                // Panel del Tracker en Vivo: Cronómetro y métricas de volumen/RPE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  color: const Color(0xFF1E201E),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cronómetro
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TIEMPO EN VIVO', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _timeString,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ED573),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      // Volumen
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('VOLUMEN TOTAL', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${totalVolume.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      // RPE Promedio
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('RPE PROMEDIO', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            avgRpe > 0 ? avgRpe.toStringAsFixed(1) : '-',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Lista de Ejercicios en vivo
                Expanded(
                  child: provider.activeExercisesIds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center_rounded, size: 64, color: Colors.grey[800]),
                              const SizedBox(height: 16),
                              const Text(
                                'Empieza agregando un ejercicio a tu rutina.',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: provider.activeExercisesIds.length,
                          itemBuilder: (context, exIndex) {
                            final exId = provider.activeExercisesIds.elementAt(exIndex);
                            final exercise = provider.exercises.firstWhere((e) => e.id == exId);
                            
                            // Sets correspondientes a este ejercicio
                            final exerciseSets = provider.activeSets.where((s) => s.exerciseId == exId).toList();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Encabezado del Ejercicio
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            exercise.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                          onPressed: () => provider.removeExerciseFromActiveWorkout(exId),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Encabezados de Tabla de Sets
                                    Row(
                                      children: const [
                                        SizedBox(width: 32, child: Text('SERIE', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                                        Expanded(child: Text('PESO (kg)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                                        Expanded(child: Text('REPS', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                                        Expanded(child: Text('RPE', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                                        SizedBox(width: 48, child: Text('HECHO', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                    const Divider(color: Colors.grey),

                                    // Listado de Sets del ejercicio
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: exerciseSets.length,
                                      itemBuilder: (context, setIndex) {
                                        final workoutSet = exerciseSets[setIndex];
                                        // Índice global del set en la lista principal del provider
                                        final globalIndex = provider.activeSets.indexOf(workoutSet);

                                        return Dismissible(
                                          key: UniqueKey(),
                                          direction: DismissDirection.endToStart,
                                          background: Container(
                                            color: Colors.redAccent,
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 16.0),
                                            child: const Icon(Icons.delete, color: Colors.white),
                                          ),
                                          onDismissed: (direction) {
                                            provider.removeSetFromActiveExercise(exId, setIndex);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              children: [
                                                // Número de Serie
                                                SizedBox(
                                                  width: 32,
                                                  child: CircleAvatar(
                                                    radius: 12,
                                                    backgroundColor: workoutSet.completed ? const Color(0xFF2ED573).withOpacity(0.2) : Colors.grey[800],
                                                    child: Text(
                                                      '${workoutSet.setNumber}',
                                                      style: TextStyle(
                                                        color: workoutSet.completed ? const Color(0xFF2ED573) : Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Peso
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: TextFormField(
                                                      initialValue: workoutSet.weight.toString(),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(fontSize: 14, color: Colors.white),
                                                      decoration: const InputDecoration(
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      onChanged: (val) {
                                                        final parsed = double.tryParse(val);
                                                        if (parsed != null) {
                                                          provider.updateSetData(globalIndex, weight: parsed);
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // Repeticiones
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: TextFormField(
                                                      initialValue: workoutSet.reps.toString(),
                                                      keyboardType: TextInputType.number,
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(fontSize: 14, color: Colors.white),
                                                      decoration: const InputDecoration(
                                                        isDense: true,
                                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      onChanged: (val) {
                                                        final parsed = int.tryParse(val);
                                                        if (parsed != null) {
                                                          provider.updateSetData(globalIndex, reps: parsed);
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // RPE
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: TextFormField(
                                                      initialValue: workoutSet.rpe?.toString() ?? '',
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(fontSize: 14, color: Colors.white),
                                                      decoration: const InputDecoration(
                                                        isDense: true,
                                                        hintText: '-',
                                                        hintStyle: TextStyle(color: Colors.grey),
                                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      onChanged: (val) {
                                                        final parsed = double.tryParse(val);
                                                        provider.updateSetData(globalIndex, rpe: parsed);
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // Hecho Checkbox
                                                SizedBox(
                                                  width: 48,
                                                  child: Checkbox(
                                                    value: workoutSet.completed,
                                                    activeColor: const Color(0xFF2ED573),
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        provider.updateSetData(globalIndex, completed: val);
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    // Botón para agregar una nueva serie a este ejercicio
                                    Center(
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                        onPressed: () => provider.addSetToActiveExercise(exId),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Agregar Serie', style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // Botón inferior para agregar ejercicios
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF1E201E),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showAddExerciseModal(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Ejercicio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
