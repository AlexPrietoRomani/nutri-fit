import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrifit/features/ai/ai_config.dart';
import 'package:nutrifit/features/ai/ai_provider.dart';

void main() {
  group('AIConfig', () {
    test('toJson/fromJson round-trip', () {
      final c = AIConfig(provider: 'claude', apiKey: 'sk', baseUrl: null, model: 'claude-opus-4-8');
      final back = AIConfig.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.provider, 'claude');
      expect(back.apiKey, 'sk');
      expect(back.model, 'claude-opus-4-8');
    });

    test('toJson omite api_key/base_url vacíos', () {
      final json = AIConfig(provider: 'ollama', model: 'llama3.1').toJson();
      expect(json.containsKey('api_key'), isFalse);
      expect(json.containsKey('base_url'), isFalse);
      expect(json['provider'], 'ollama');
    });

    test('defaults() usa el modelo sugerido del proveedor', () {
      expect(AIConfig.defaults('gemini').model, kSuggestedModel['gemini']);
      expect(AIConfig.defaults('openai').model, 'gpt-4o-mini');
    });
  });

  group('AiProvider.sendMessage', () {
    test('POST /chat envía {message, ai} y agrega la respuesta', () async {
      final mock = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.url.path, endsWith('/chat'));
        expect(body['message'], 'hola');
        expect((body['ai'] as Map)['provider'], 'openai');
        return http.Response(jsonEncode({'reply': 'respuesta IA'}), 200,
            headers: {'content-type': 'application/json'});
      });
      final p = AiProvider(
        httpClient: mock,
        config: AIConfig(provider: 'openai', apiKey: 'k', model: 'm'),
      );
      await p.sendMessage('hola');
      expect(p.messages.length, 2);
      expect(p.messages.last.role, 'assistant');
      expect(p.messages.last.text, 'respuesta IA');
      expect(p.error, isNull);
    });

    test('un 503 del backend se refleja como error', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'detail': 'sin proveedor'}), 503,
              headers: {'content-type': 'application/json'}));
      final p = AiProvider(
        httpClient: mock,
        config: AIConfig(provider: 'openai', model: 'm'),
      );
      await p.sendMessage('hola');
      expect(p.error, contains('503'));
    });

    test('sin config, no llama y avisa', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      final p = AiProvider(httpClient: mock); // sin config
      await p.sendMessage('hola');
      expect(called, isFalse);
      expect(p.error, isNotNull);
    });
  });
}
