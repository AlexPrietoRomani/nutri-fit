import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ai_provider.dart';
import 'ai_settings_screen.dart';

/// Pantalla de chat con el asistente de IA.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.embedded = false});

  /// true cuando se abre dentro de un [showModalBottomSheet] (ChatFab).
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AiProvider>().loadConfig());
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
    context.read<AiProvider>().sendMessage(text);
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

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final items = (workout['items'] as List?) ?? [];
    final cardioBlock = workout['cardio_block']?.toString();
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
        ),
      ),
    );
  }

  Widget _buildMealPlanCard(Map<String, dynamic> mealPlan) {
    final meals = (mealPlan['meals'] as List?) ?? [];
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
              child: Text('Plan de comidas',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
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
        ),
      ),
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
