import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import 'ai_provider.dart';
import 'ai_settings_screen.dart';
import '../nutrition/nutrition_provider.dart';

/// Pantalla de chat con el asistente de IA.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.embedded = false, this.saveRoutineOverride, this.saveMealPlanOverride});

  /// true cuando se abre dentro de un [showModalBottomSheet] (ChatFab).
  final bool embedded;

  /// Permite inyectar un guardado falso en tests, sin levantar un
  /// [SupabaseClient] real (auth + realtime + isolate de JSON), que en el
  /// entorno de test se cuelga al spawnear el isolate. En producción se usa
  /// el INSERT real contra `training.routines` vía [SupabaseConfig.client].
  final Future<void> Function(String name, Map<String, dynamic> workout)? saveRoutineOverride;

  /// Mismo seam que [saveRoutineOverride] pero para `nutrition.meal_plans`.
  final Future<void> Function(String name, Map<String, dynamic> mealPlan)? saveMealPlanOverride;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();

  // Preferencias del usuario (nutrition.food_preferences) para inyectarlas al
  // chat y que el generador de comidas las respete (T18.2.2). Se cargan una vez
  // de forma best-effort: si no hay NutritionProvider en el árbol (tests) o
  // falla la carga, quedan null y el body del request simplemente no las lleva.
  Map<String, dynamic>? _preferences;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AiProvider>().loadConfig());
    Future.microtask(_loadPreferences);
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await context.read<NutritionProvider>().fetchPreferences();
      if (mounted) setState(() => _preferences = prefs);
    } catch (_) {
      // best-effort: sin provider o sin fila, el chat sigue igual que antes.
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    context.read<AiProvider>().sendMessage(text, preferences: _preferences);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    if (widget.embedded) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Asistente IA',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    tooltip: 'Ajustes de IA',
                    onPressed: _openSettings,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(ai)),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes de IA',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(ai),
    );
  }

  Widget _buildBody(AiProvider ai) {
    return Column(
      children: [
          if (!ai.hasConfig)
            MaterialBanner(
              content: const Text('No hay proveedor de IA configurado.'),
              actions: [
                TextButton(onPressed: _openSettings, child: const Text('Configurar')),
              ],
            ),
          if (ai.error != null)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.15),
              padding: const EdgeInsets.all(8),
              child: Text(ai.error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: ai.messages.length + (ai.isLoading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == ai.messages.length) {
                  return const _ThinkingBubble();
                }
                final m = ai.messages[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF2ED573) : const Color(0xFF1E201E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(color: isUser ? Colors.black : Colors.white),
                        ),
                      ),
                      if (m.workout != null) _buildWorkoutCard(m.workout!),
                      if (m.mealPlan != null) _buildMealPlanCard(m.mealPlan!),
                    ],
                  ),
                );
              },
            ),
          ),
          // Acciones rápidas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Generar plan de comida'),
                  onPressed: ai.isLoading ? null : () => _send('Genérame un plan de comida para hoy según mis metas.'),
                ),
                ActionChip(
                  label: const Text('Generar rutina'),
                  onPressed: ai.isLoading ? null : () => _send('Genérame una rutina de entrenamiento para hoy.'),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu pregunta...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: ai.isLoading ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  /// Guarda la rutina sugerida en `training.routines` (T13.2.1). Pide un
  /// nombre por diálogo y hace el INSERT real; antes de esto el chat solo
  /// mostraba la tarjeta sin ninguna forma de persistirla.
  Future<void> _saveRoutine(Map<String, dynamic> workout) async {
    final now = DateTime.now();
    final nameCtrl = TextEditingController(text: "Rutina IA ${now.day}/${now.month}");
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar rutina'),
        content: TextField(
          key: const Key('save_routine_name_field'),
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre de la rutina'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            key: const Key('save_routine_confirm_button'),
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    try {
      if (widget.saveRoutineOverride != null) {
        await widget.saveRoutineOverride!(name, workout);
      } else {
        final client = SupabaseConfig.client;
        final userId = client.auth.currentUser!.id;
        await client.schema('training').from('routines').insert({
          'user_id': userId,
          'name': name,
          'source': 'ai',
          // Multi-día: guarda {days:[...]} en la columna JSONB para round-trip;
          // plano: la lista tal cual (ver planColumnValue).
          'items': planColumnValue(workout, 'items'),
          'cardio_block': workout['cardio_block'],
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutina guardada — ya aparece en Entrenamiento')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la rutina: $e')),
      );
    }
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final days = normalizePlanDays(workout, 'items');
    return Card(
      color: const Color(0xFF1E201E),
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E302E)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Rutina sugerida',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            _MultiDayPlan(
              days: days,
              dayBuilder: (day) => _workoutDayContent(day, workout),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('save_routine_button'),
                  icon: const Icon(Icons.save_outlined, size: 18, color: Color(0xFF2ED573)),
                  label: const Text('Guardar rutina', style: TextStyle(color: Color(0xFF2ED573))),
                  onPressed: () => _saveRoutine(workout),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contenido de un día de la rutina: ejercicios + bloque de cardio.
  /// El cardio puede venir por día (multi-día) o a nivel raíz (shape viejo).
  Widget _workoutDayContent(Map<String, dynamic> day, Map<String, dynamic> workout) {
    final items = (day['items'] as List?) ?? [];
    final cardioBlock = (day['cardio_block'] ?? workout['cardio_block'])?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
                (item as Map)['name']?.toString() ?? 'Ejercicio #${item['exercise_id']}',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            trailing: Text('${item['sets']}x${item['reps']} · RPE ${item['rpe']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        if (cardioBlock != null && cardioBlock.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.directions_run_rounded, color: Color(0xFF2ED573), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(cardioBlock, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Guarda el plan de comida sugerido en `nutrition.meal_plans` (T16.2.1),
  /// mismo patrón que [_saveRoutine] para `training.routines`.
  Future<void> _saveMealPlan(Map<String, dynamic> mealPlan) async {
    final now = DateTime.now();
    final nameCtrl = TextEditingController(text: "Plan IA ${now.day}/${now.month}");
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar plan'),
        content: TextField(
          key: const Key('save_meal_plan_name_field'),
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre del plan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            key: const Key('save_meal_plan_confirm_button'),
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    try {
      if (widget.saveMealPlanOverride != null) {
        await widget.saveMealPlanOverride!(name, mealPlan);
      } else {
        final client = SupabaseConfig.client;
        final userId = client.auth.currentUser!.id;
        await client.schema('nutrition').from('meal_plans').insert({
          'user_id': userId,
          'name': name,
          'source': 'ai',
          'meals': planColumnValue(mealPlan, 'meals'),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan guardado — ya aparece en Nutrición')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el plan: $e')),
      );
    }
  }

  Widget _buildMealPlanCard(Map<String, dynamic> mealPlan) {
    final days = normalizePlanDays(mealPlan, 'meals');
    return Card(
      color: const Color(0xFF1E201E),
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E302E)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Plan de comidas',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton.icon(
                    key: const Key('save_meal_plan_button'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    icon: const Icon(Icons.save_outlined, size: 18, color: Color(0xFF2ED573)),
                    label: const Text('Guardar plan', style: TextStyle(color: Color(0xFF2ED573))),
                    onPressed: () => _saveMealPlan(mealPlan),
                  ),
                ],
              ),
            ),
            _MultiDayPlan(
              days: days,
              dayBuilder: (day) => _mealDayContent(day),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealDayContent(Map<String, dynamic> day) {
    final meals = (day['meals'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final meal in meals)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text('${(meal as Map)['food_name']}',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(
              '${meal['meal_type']} · ${meal['calories']} kcal · P${meal['protein_g']} C${meal['carbs_g']} G${meal['fat_g']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Renderiza un plan multi-día con un selector de día encima (dropdown) cuando
/// hay más de un día; con un solo día muestra el contenido directo, sin selector
/// (compat: los planes viejos de 1 día se ven idénticos). [days] viene de
/// [normalizePlanDays]; [dayBuilder] pinta el contenido del día elegido.
class _MultiDayPlan extends StatefulWidget {
  const _MultiDayPlan({required this.days, required this.dayBuilder});

  final List<Map<String, dynamic>> days;
  final Widget Function(Map<String, dynamic> day) dayBuilder;

  @override
  State<_MultiDayPlan> createState() => _MultiDayPlanState();
}

class _MultiDayPlanState extends State<_MultiDayPlan> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (_idx >= days.length) _idx = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (days.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: DropdownButton<int>(
              key: const Key('day_selector'),
              value: _idx,
              dropdownColor: const Color(0xFF1E201E),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              isDense: true,
              items: [
                for (int i = 0; i < days.length; i++)
                  DropdownMenuItem(value: i, child: Text('Día ${days[i]['day'] ?? i + 1}')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _idx = v);
              },
            ),
          ),
        widget.dayBuilder(days[_idx]),
      ],
    );
  }
}

/// Burbuja "el asistente está pensando..." mientras se espera la respuesta.
/// Vive en el flujo de mensajes (no como barra aparte) para que el usuario
/// sepa que algo está pasando y no se sienta ignorado durante la espera.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> {
  int _dots = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _dots = (_dots % 3) + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E201E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2ED573)),
            ),
            const SizedBox(width: 10),
            Text('Pensando${'.' * _dots}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
