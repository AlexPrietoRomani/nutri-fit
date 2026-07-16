import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ai_config.dart';
import 'ai_provider.dart';

/// Pantalla de Ajustes de IA: elegir proveedor e introducir clave/base_url/modelo.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late String _provider;
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = context.read<AiProvider>().config;
    _provider = existing?.provider ?? kAiProviders.first;
    _apiKeyCtrl.text = existing?.apiKey ?? '';
    _baseUrlCtrl.text = existing?.baseUrl ?? '';
    _modelCtrl.text = existing?.model ?? (kSuggestedModel[_provider] ?? '');
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _onProviderChanged(String? value) {
    if (value == null) return;
    setState(() {
      _provider = value;
      // Sugerir modelo por defecto al cambiar de proveedor.
      _modelCtrl.text = kSuggestedModel[value] ?? '';
    });
  }

  Future<void> _save() async {
    final config = AIConfig(
      provider: _provider,
      apiKey: _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim().isEmpty ? null : _baseUrlCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
    );
    await context.read<AiProvider>().saveConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración de IA guardada')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = _provider == 'ollama' || _provider == 'lmstudio' || _provider == 'vllm';
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de IA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Proveedor', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _provider,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: kAiProviders
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: _onProviderChanged,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: local ? 'API key (opcional para local)' : 'API key',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'base_url (opcional — solo para override)',
              hintText: 'p.ej. http://host.docker.internal:1234/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'Modelo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
