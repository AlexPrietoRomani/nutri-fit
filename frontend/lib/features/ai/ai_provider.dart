import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'ai_config.dart';

/// Normaliza un plan (workout o meal_plan) a una lista de días uniforme.
///
/// [key] es 'items' (workout) o 'meals' (meal_plan). Si el plan trae `days`
/// (shape multi-día, T18.4.1) lo devuelve tal cual; si es el shape viejo de 1
/// día (solo `items`/`meals` plano) lo envuelve en `[{day:1, key: <contenido>}]`.
/// Función pura: la consumirá la UI de T18.4.2.
List<Map<String, dynamic>> normalizePlanDays(Map<String, dynamic> plan, String key) {
  final days = plan['days'];
  if (days is List) {
    return days.whereType<Map>().map((d) => Map<String, dynamic>.from(d)).toList();
  }
  return [
    {'day': 1, key: plan[key] ?? []},
  ];
}

/// Valor a guardar en la columna JSONB [key] (`items`/`meals`) de un plan.
///
/// Si el plan es multi-día (`days`) guarda `{days:[...]}` para que round-trip;
/// si es plano (shape viejo) guarda la lista tal cual, idéntico a antes.
/// Inversa de [planFromRow]. No hay columna `days` en BD (T18.4.1), por eso
/// lo multi-día se serializa dentro de la misma columna.
Object? planColumnValue(Map<String, dynamic> plan, String key) {
  return plan['days'] != null ? {'days': plan['days']} : plan[key];
}

/// Reconstruye el mapa-plan a partir de una fila guardada cuyo contenido se
/// serializó en la columna JSONB [key]. Si la columna trae `{days:[...]}`
/// (multi-día) usa ese mapa; si es la lista plana vieja, la reenvuelve.
/// Pásalo por [normalizePlanDays] para pintar la UI. Inversa de [planColumnValue].
Map<String, dynamic> planFromRow(Map<String, dynamic> row, String key) {
  final col = row[key];
  if (col is Map && col['days'] is List) return Map<String, dynamic>.from(col);
  return {key: col ?? []};
}

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
    // Historial PREVIO (antes de añadir el mensaje actual), últimos 10 turnos.
    // El servidor es stateless: el historial viaja por request para que
    // _extract_intent resuelva referencias como "hazlo a 3 semanas" (T18.1.1).
    final history = _messages
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    final recentHistory =
        history.length > 10 ? history.sublist(history.length - 10) : history;

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
          'history': recentHistory,
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
