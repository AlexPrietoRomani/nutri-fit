import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import 'ai_config.dart';
import 'ai_provider.dart';

/// Pantalla de Ajustes de IA: elegir proveedor e introducir clave/base_url/modelo.
class AiSettingsScreen extends StatefulWidget {
  /// Cliente HTTP inyectable para tests (T12.3.1/T12.3.2 consultan /ollama/*).
  final http.Client? httpClient;

  const AiSettingsScreen({super.key, this.httpClient});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late String _provider;
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  late final http.Client _http = widget.httpClient ?? http.Client();

  /// null = aún no se consultó o no aplica; lista (vacía o no) = ya se consultó.
  List<String>? _installedModels;
  Timer? _baseUrlDebounce;

  /// Estado de instalación por modelo recomendado: texto de status o null si no se instala.
  final Map<String, String?> _pullingStatus = {};
  final Map<String, Timer> _pullTimers = {};

  @override
  void initState() {
    super.initState();
    final existing = context.read<AiProvider>().config;
    _provider = existing?.provider ?? kAiProviders.first;
    _apiKeyCtrl.text = existing?.apiKey ?? '';
    _baseUrlCtrl.text = existing?.baseUrl ?? '';
    _modelCtrl.text = existing?.model ?? (kSuggestedModel[_provider] ?? '');
    _baseUrlCtrl.addListener(_onBaseUrlChanged);
    if (_provider == 'ollama') _fetchInstalledModels();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.removeListener(_onBaseUrlChanged);
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _baseUrlDebounce?.cancel();
    for (final t in _pullTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _onBaseUrlChanged() {
    if (_provider != 'ollama') return;
    _baseUrlDebounce?.cancel();
    _baseUrlDebounce = Timer(const Duration(milliseconds: 500), _fetchInstalledModels);
  }

  Future<void> _fetchInstalledModels() async {
    try {
      final uri = Uri.parse('${AppConstants.aiServiceUrl}/ollama/models').replace(
        queryParameters:
            _baseUrlCtrl.text.trim().isEmpty ? null : {'base_url': _baseUrlCtrl.text.trim()},
      );
      final resp = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final names = (data['models'] as List).map((m) => m['name'] as String).toList();
        if (mounted) setState(() => _installedModels = names);
        return;
      }
    } catch (_) {
      // fallback silencioso a TextField libre
    }
    if (mounted) setState(() => _installedModels = null);
  }

  /// Compara ignorando el tag por defecto (Ollama normaliza `:latest`).
  bool _isInstalled(String name) {
    final installed = _installedModels;
    if (installed == null) return false;
    return installed.any((m) => m == name || m.split(':').first == name.split(':').first);
  }

  Future<void> _installModel(String name) async {
    setState(() => _pullingStatus[name] = 'iniciando...');
    try {
      await _http.post(
        Uri.parse('${AppConstants.aiServiceUrl}/ollama/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': name,
          if (_baseUrlCtrl.text.trim().isNotEmpty) 'base_url': _baseUrlCtrl.text.trim(),
        }),
      );
    } catch (_) {
      if (mounted) setState(() => _pullingStatus[name] = null);
      return;
    }
    _pullTimers[name]?.cancel();
    _pullTimers[name] = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final resp = await _http.get(
          Uri.parse('${AppConstants.aiServiceUrl}/ollama/pull-status?model=$name'),
        );
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final done = data['done'] == true;
        if (mounted) setState(() => _pullingStatus[name] = data['status']?.toString());
        if (done) {
          timer.cancel();
          _pullTimers.remove(name);
          if (mounted) setState(() => _pullingStatus[name] = null);
          await _fetchInstalledModels();
        }
      } catch (_) {
        timer.cancel();
        _pullTimers.remove(name);
        if (mounted) setState(() => _pullingStatus[name] = null);
      }
    });
  }

  void _onProviderChanged(String? value) {
    if (value == null) return;
    setState(() {
      _provider = value;
      // Sugerir modelo por defecto al cambiar de proveedor.
      _modelCtrl.text = kSuggestedModel[value] ?? '';
      _installedModels = null;
    });
    if (value == 'ollama') _fetchInstalledModels();
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

  Widget _buildModelField() {
    final models = _installedModels;
    if (_provider == 'ollama' && models != null && models.isNotEmpty) {
      final items = List<String>.from(models);
      if (_modelCtrl.text.isNotEmpty && !items.contains(_modelCtrl.text)) {
        items.insert(0, _modelCtrl.text);
      }
      return DropdownButtonFormField<String>(
        value: items.contains(_modelCtrl.text) ? _modelCtrl.text : items.first,
        decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
        items: items.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() => _modelCtrl.text = v);
        },
      );
    }
    return TextField(
      controller: _modelCtrl,
      decoration: const InputDecoration(
        labelText: 'Modelo',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildRecommendedModels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Modelos recomendados', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final name in kRecommendedOllamaModels)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            subtitle: _pullingStatus[name] != null ? Text(_pullingStatus[name]!) : null,
            trailing: _pullingStatus.containsKey(name) && _pullingStatus[name] != null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _isInstalled(name)
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : TextButton(
                        onPressed: () => _installModel(name),
                        child: const Text('Instalar'),
                      ),
          ),
      ],
    );
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
          _buildModelField(),
          if (_provider == 'ollama') _buildRecommendedModels(),
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
