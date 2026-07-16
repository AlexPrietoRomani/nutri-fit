import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'ai_config.dart';

/// Un mensaje del chat (usuario o asistente).
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final Map<String, dynamic>? workout;
  final Map<String, dynamic>? mealPlan;
  ChatMessage(this.role, this.text, {this.workout, this.mealPlan});
}

/// Estado del chat de IA: carga la config, envía mensajes al backend y mantiene
/// el historial en memoria (chat stateless en el servidor — MVP).
class AiProvider extends ChangeNotifier {
  final AIConfigStore _store;
  final http.Client _http;

  AiProvider({AIConfigStore? store, http.Client? httpClient, AIConfig? config})
      : _store = store ?? AIConfigStore(),
        _http = httpClient ?? http.Client(),
        _config = config;

  AIConfig? _config;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  AIConfig? get config => _config;
  bool get hasConfig => _config != null;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConfig() async {
    // El almacenamiento seguro puede no estar disponible en web; degradar sin crash.
    try {
      _config = await _store.load();
    } catch (_) {
      _config = null;
    }
    notifyListeners();
  }

  Future<void> saveConfig(AIConfig config) async {
    // Config en memoria primero: la UI funciona aunque falle la persistencia (web).
    _config = config;
    notifyListeners();
    try {
      await _store.save(config);
    } catch (_) {
      // best-effort: en web sin secure storage la config vive solo en memoria.
    }
  }

  /// Envía un mensaje al endpoint /chat-plan (orquestador F11) con la config del proveedor.
  Future<void> sendMessage(String message, {Map<String, dynamic>? profile}) async {
    if (_config == null) {
      _error = 'Configura un proveedor de IA en Ajustes.';
      notifyListeners();
      return;
    }
    _messages.add(ChatMessage('user', message));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _http.post(
        Uri.parse('${AppConstants.aiServiceUrl}/chat-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          if (profile != null) 'profile': profile,
          'ai': _config!.toJson(),
        }),
      );
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final reply = json['reply'] as String;
        _messages.add(ChatMessage(
          'assistant',
          reply,
          workout: json['workout'] as Map<String, dynamic>?,
          mealPlan: json['meal_plan'] as Map<String, dynamic>?,
        ));
      } else {
        final detail = _extractDetail(resp.body);
        _error = 'Error ${resp.statusCode}: $detail';
      }
    } catch (e) {
      _error = 'No se pudo contactar el servicio de IA: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _extractDetail(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['detail']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}
