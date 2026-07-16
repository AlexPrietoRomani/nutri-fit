import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ai_provider.dart';
import 'ai_settings_screen.dart';

/// Pantalla de chat con el asistente de IA.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
      body: Column(
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
              itemCount: ai.messages.length,
              itemBuilder: (context, i) {
                final m = ai.messages[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
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
                );
              },
            ),
          ),
          if (ai.isLoading) const LinearProgressIndicator(),
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
      ),
    );
  }
}
