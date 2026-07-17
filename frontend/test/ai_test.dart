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

  group('normalizePlanDays', () {
    test('plan multi-día con days de N devuelve N días', () {
      final plan = {
        'days': [
          {'day': 1, 'meals': []},
          {'day': 2, 'meals': []},
          {'day': 3, 'meals': []},
        ],
      };
      final days = normalizePlanDays(plan, 'meals');
      expect(days.length, 3);
      expect(days.first['day'], 1);
    });

    test('plan viejo (solo meals) envuelve en 1 día', () {
      final plan = {
        'meals': [
          {'meal_type': 'lunch', 'food_name': 'Pollo'}
        ],
      };
      final days = normalizePlanDays(plan, 'meals');
      expect(days.length, 1);
      expect(days.first['day'], 1);
      expect((days.first['meals'] as List).length, 1);
    });

    test('plan viejo de workout (solo items) envuelve en 1 día', () {
      final plan = {
        'items': [
          {'exercise_id': 3}
        ],
      };
      final days = normalizePlanDays(plan, 'items');
      expect(days.length, 1);
      expect((days.first['items'] as List).first['exercise_id'], 3);
    });

    test('plan sin clave devuelve 1 día con lista vacía', () {
      final days = normalizePlanDays(<String, dynamic>{}, 'meals');
      expect(days.length, 1);
      expect(days.first['meals'], isEmpty);
    });
  });

  group('planColumnValue / planFromRow (round-trip de guardado T18.4.2)', () {
    test('multi-día: guarda {days} y round-trip conserva los N días', () {
      final plan = {
        'days': [
          {'day': 1, 'meals': [{'food_name': 'A'}]},
          {'day': 2, 'meals': [{'food_name': 'B'}]},
        ],
      };
      final col = planColumnValue(plan, 'meals');
      expect(col, {'days': plan['days']}); // se guarda con days para round-trip

      // Simula la fila leída de BD (columna JSONB `meals` = col).
      final days = normalizePlanDays(planFromRow({'meals': col}, 'meals'), 'meals');
      expect(days.length, 2);
      expect((days[1]['meals'] as List).first['food_name'], 'B');
    });

    test('plano (shape viejo): guarda la lista y round-trip da 1 día', () {
      final plan = {
        'items': [{'exercise_id': 3}],
      };
      final col = planColumnValue(plan, 'items');
      expect(col, plan['items']); // lista tal cual, idéntico a antes

      final days = normalizePlanDays(planFromRow({'items': col}, 'items'), 'items');
      expect(days.length, 1);
      expect((days.first['items'] as List).first['exercise_id'], 3);
    });
  });

  group('AiProvider.sendMessage', () {
    test('POST /chat-plan envía {message, ai} y agrega la respuesta', () async {
      final mock = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.url.path, endsWith('/chat-plan'));
        expect(body['message'], 'hola');
        expect((body['ai'] as Map)['provider'], 'openai');
        return http.Response(
            jsonEncode({'reply': 'respuesta IA', 'workout': null, 'meal_plan': null}), 200,
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
      expect(p.messages.last.workout, isNull);
      expect(p.messages.last.mealPlan, isNull);
      expect(p.error, isNull);
    });

    test('cuando la respuesta trae workout/meal_plan, los expone en el ChatMessage', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, endsWith('/chat-plan'));
        return http.Response(
          jsonEncode({
            'reply': 'Aquí tienes tu plan',
            'workout': {
              'items': [
                {'exercise_id': 3, 'sets': 4, 'reps': 10, 'rpe': 8}
              ],
              'cardio_block': '20 min trote suave',
            },
            'meal_plan': {
              'meals': [
                {
                  'meal_type': 'breakfast',
                  'food_name': 'Avena con fruta',
                  'calories': 350,
                  'protein_g': 15,
                  'carbs_g': 50,
                  'fat_g': 8,
                  'serving_size_g': 200,
                }
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = AiProvider(
        httpClient: mock,
        config: AIConfig(provider: 'openai', model: 'm'),
      );
      await p.sendMessage('genera mi plan');
      final last = p.messages.last;
      expect(last.workout, isNotNull);
      expect(last.workout!['items'], isA<List>());
      expect(last.mealPlan, isNotNull);
      expect((last.mealPlan!['meals'] as List).first['food_name'], 'Avena con fruta');
    });

    test('el segundo POST incluye history con el primer intercambio', () async {
      final bodies = <Map<String, dynamic>>[];
      final mock = MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({'reply': 'resp', 'workout': null, 'meal_plan': null}), 200,
            headers: {'content-type': 'application/json'});
      });
      final p = AiProvider(
        httpClient: mock,
        config: AIConfig(provider: 'openai', model: 'm'),
      );
      await p.sendMessage('dame un plan de comida');
      await p.sendMessage('hazlo a 3 semanas');

      // Primer POST: sin historial previo.
      expect(bodies[0]['history'], isEmpty);
      // Segundo POST: historial con el primer intercambio (user + assistant).
      final history = bodies[1]['history'] as List;
      expect(history.length, 2);
      expect(history[0], {'role': 'user', 'text': 'dame un plan de comida'});
      expect(history[1], {'role': 'assistant', 'text': 'resp'});
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
