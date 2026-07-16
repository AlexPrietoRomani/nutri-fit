import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Proveedores de IA soportados por el backend (F8).
const List<String> kAiProviders = [
  'openai',
  'openrouter',
  'gemini',
  'claude',
  'ollama',
  'lmstudio',
  'vllm',
];

/// Modelo sugerido por proveedor (el `base_url` lo resuelve el backend salvo
/// override). Reduce fricción al rellenar el formulario de Ajustes.
const Map<String, String> kSuggestedModel = {
  'openai': 'gpt-4o-mini',
  'openrouter': 'openai/gpt-4o-mini',
  'gemini': 'gemini-1.5-flash',
  'claude': 'claude-opus-4-8',
  'ollama': 'llama3.1',
  'lmstudio': 'local-model',
  'vllm': 'local-model',
};

/// Configuración de IA elegida por el usuario. Se envía al backend por request.
class AIConfig {
  final String provider;
  final String? apiKey;
  final String? baseUrl;
  final String model;

  AIConfig({
    required this.provider,
    this.apiKey,
    this.baseUrl,
    required this.model,
  });

  /// Config por defecto para un proveedor (modelo sugerido, sin clave).
  factory AIConfig.defaults(String provider) => AIConfig(
        provider: provider,
        model: kSuggestedModel[provider] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        if (apiKey != null && apiKey!.isNotEmpty) 'api_key': apiKey,
        if (baseUrl != null && baseUrl!.isNotEmpty) 'base_url': baseUrl,
        'model': model,
      };

  factory AIConfig.fromJson(Map<String, dynamic> json) => AIConfig(
        provider: json['provider'] as String,
        apiKey: json['api_key'] as String?,
        baseUrl: json['base_url'] as String?,
        model: (json['model'] as String?) ?? '',
      );

  AIConfig copyWith({String? provider, String? apiKey, String? baseUrl, String? model}) =>
      AIConfig(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
      );
}

/// Persistencia de la config en almacenamiento seguro del dispositivo.
class AIConfigStore {
  static const _key = 'ai_config';
  final FlutterSecureStorage _storage;

  AIConfigStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save(AIConfig config) =>
      _storage.write(key: _key, value: jsonEncode(config.toJson()));

  Future<AIConfig?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return AIConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
