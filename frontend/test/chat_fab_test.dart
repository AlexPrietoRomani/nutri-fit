import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/ai/ai_config.dart';
import 'package:nutrifit/features/ai/ai_provider.dart';
import 'package:nutrifit/features/ai/chat_fab.dart';
import 'package:nutrifit/features/ai/chat_screen.dart';

void main() {
  Widget wrap(Widget child) => ChangeNotifierProvider<AiProvider>(
        create: (_) => AiProvider(),
        child: MaterialApp(
          home: Scaffold(floatingActionButton: child),
        ),
      );

  testWidgets('ChatFab abre un showModalBottomSheet con ChatScreen embebido', (tester) async {
    await tester.pumpWidget(wrap(const ChatFab()));

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chatScreen.embedded, isTrue);
  });

  testWidgets('ChatScreen renderiza tarjetas "Rutina sugerida"/"Plan de comidas" cuando el mensaje trae workout/mealPlan',
      (tester) async {
    final mock = MockClient((req) async => http.Response(
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
        ));
    final ai = AiProvider(
      httpClient: mock,
      config: AIConfig(provider: 'openai', model: 'm'),
    );
    await ai.sendMessage('genera mi plan');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AiProvider>.value(
          value: ai,
          child: const Scaffold(body: ChatScreen(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rutina sugerida'), findsOneWidget);
    expect(find.text('Plan de comidas'), findsOneWidget);
    expect(find.byKey(const Key('save_routine_button')), findsOneWidget);
    expect(find.byKey(const Key('save_meal_plan_button')), findsOneWidget);
  });

  testWidgets(
      'Guardar rutina: al confirmar el nombre dispara un INSERT en training.routines con el shape esperado',
      (tester) async {
    final chatMock = MockClient((req) async => http.Response(
          jsonEncode({
            'reply': 'Aquí tienes tu rutina',
            'workout': {
              'items': [
                {'exercise_id': 3, 'sets': 4, 'reps': 10, 'rpe': 8, 'name': 'Sentadilla'}
              ],
              'cardio_block': '20 min trote suave',
            },
            'meal_plan': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final ai = AiProvider(
      httpClient: chatMock,
      config: AIConfig(provider: 'openai', model: 'm'),
    );
    await ai.sendMessage('genera mi rutina');

    // El INSERT real usa `SupabaseConfig.client` (singleton no inicializable
    // en test sin levantar auth/realtime real); en vez de eso se inyecta
    // `saveRoutineOverride`, el mismo seam que produce el request real
    // (mismo `name`/`workout` que el botón pasaría a
    // `client.schema('training').from('routines').insert({...})`), y así se
    // verifica el shape sin depender de la red.
    String? capturedName;
    Map<String, dynamic>? capturedWorkout;
    Future<void> fakeSave(String name, Map<String, dynamic> workout) async {
      capturedName = name;
      capturedWorkout = workout;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AiProvider>.value(
          value: ai,
          child: Scaffold(body: ChatScreen(embedded: true, saveRoutineOverride: fakeSave)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_routine_button')));
    await tester.pumpAndSettle();

    // El diálogo trae un nombre prellenado tipo "Rutina IA d/m".
    expect(find.byKey(const Key('save_routine_name_field')), findsOneWidget);
    final now = DateTime.now();
    expect(find.text('Rutina IA ${now.day}/${now.month}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save_routine_confirm_button')));
    await tester.pumpAndSettle();

    expect(capturedName, 'Rutina IA ${now.day}/${now.month}');
    expect(capturedWorkout, isNotNull);
    expect(capturedWorkout!['items'], [
      {'exercise_id': 3, 'sets': 4, 'reps': 10, 'rpe': 8, 'name': 'Sentadilla'}
    ]);
    expect(capturedWorkout!['cardio_block'], '20 min trote suave');

    expect(find.text('Rutina guardada — ya aparece en Entrenamiento'), findsOneWidget);
  });

  testWidgets(
      'Guardar plan: al confirmar el nombre dispara un INSERT en nutrition.meal_plans con el shape esperado',
      (tester) async {
    final chatMock = MockClient((req) async => http.Response(
          jsonEncode({
            'reply': 'Aquí tienes tu plan',
            'workout': null,
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
        ));
    final ai = AiProvider(
      httpClient: chatMock,
      config: AIConfig(provider: 'openai', model: 'm'),
    );
    await ai.sendMessage('genera mi plan');

    // Mismo seam que saveRoutineOverride (ver INC-015): saveMealPlanOverride
    // evita instanciar un SupabaseClient real y captura el shape del INSERT.
    String? capturedName;
    Map<String, dynamic>? capturedMealPlan;
    Future<void> fakeSave(String name, Map<String, dynamic> mealPlan) async {
      capturedName = name;
      capturedMealPlan = mealPlan;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AiProvider>.value(
          value: ai,
          child: Scaffold(body: ChatScreen(embedded: true, saveMealPlanOverride: fakeSave)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_meal_plan_button')));
    await tester.pumpAndSettle();

    // El diálogo trae un nombre prellenado tipo "Plan IA d/m".
    expect(find.byKey(const Key('save_meal_plan_name_field')), findsOneWidget);
    final now = DateTime.now();
    expect(find.text('Plan IA ${now.day}/${now.month}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save_meal_plan_confirm_button')));
    await tester.pumpAndSettle();

    expect(capturedName, 'Plan IA ${now.day}/${now.month}');
    expect(capturedMealPlan, isNotNull);
    expect(capturedMealPlan!['meals'], [
      {
        'meal_type': 'breakfast',
        'food_name': 'Avena con fruta',
        'calories': 350,
        'protein_g': 15,
        'carbs_g': 50,
        'fat_g': 8,
        'serving_size_g': 200,
      }
    ]);

    expect(find.text('Plan guardado — ya aparece en Nutrición'), findsOneWidget);
  });

  testWidgets(
      'Plan multi-día: muestra el selector de día y al cambiar de día muestra contenido distinto',
      (tester) async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'reply': 'Plan de 2 días',
            'workout': null,
            'meal_plan': {
              'days': [
                {
                  'day': 1,
                  'meals': [
                    {'meal_type': 'breakfast', 'food_name': 'Avena', 'calories': 300, 'protein_g': 10, 'carbs_g': 40, 'fat_g': 5}
                  ],
                },
                {
                  'day': 2,
                  'meals': [
                    {'meal_type': 'breakfast', 'food_name': 'Huevos', 'calories': 250, 'protein_g': 20, 'carbs_g': 2, 'fat_g': 18}
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final ai = AiProvider(httpClient: mock, config: AIConfig(provider: 'openai', model: 'm'));
    await ai.sendMessage('plan 2 días');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AiProvider>.value(
          value: ai,
          child: const Scaffold(body: ChatScreen(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Selector presente y día 1 visible.
    expect(find.byKey(const Key('day_selector')), findsOneWidget);
    expect(find.text('Avena'), findsOneWidget);
    expect(find.text('Huevos'), findsNothing);

    // Cambia al día 2.
    await tester.tap(find.byKey(const Key('day_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día 2').last);
    await tester.pumpAndSettle();

    expect(find.text('Huevos'), findsOneWidget);
    expect(find.text('Avena'), findsNothing);
  });

  testWidgets('Plan de 1 día (shape viejo) se renderiza SIN selector', (tester) async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'reply': 'Plan simple',
            'workout': null,
            'meal_plan': {
              'meals': [
                {'meal_type': 'breakfast', 'food_name': 'Avena', 'calories': 300, 'protein_g': 10, 'carbs_g': 40, 'fat_g': 5}
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final ai = AiProvider(httpClient: mock, config: AIConfig(provider: 'openai', model: 'm'));
    await ai.sendMessage('plan');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AiProvider>.value(
          value: ai,
          child: const Scaffold(body: ChatScreen(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('day_selector')), findsNothing);
    expect(find.text('Avena'), findsOneWidget);
  });

  testWidgets('Guardar plan multi-día: el objeto guardado conserva days', (tester) async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'reply': 'Plan de 2 días',
            'workout': null,
            'meal_plan': {
              'days': [
                {'day': 1, 'meals': [{'meal_type': 'breakfast', 'food_name': 'Avena', 'calories': 300}]},
                {'day': 2, 'meals': [{'meal_type': 'breakfast', 'food_name': 'Huevos', 'calories': 250}]},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final ai = AiProvider(httpClient: mock, config: AIConfig(provider: 'openai', model: 'm'));
    await ai.sendMessage('plan 2 días');

    Map<String, dynamic>? captured;
    Future<void> fakeSave(String name, Map<String, dynamic> mealPlan) async => captured = mealPlan;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AiProvider>.value(
          value: ai,
          child: Scaffold(body: ChatScreen(embedded: true, saveMealPlanOverride: fakeSave)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_meal_plan_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_meal_plan_confirm_button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['days'], isA<List>());
    expect((captured!['days'] as List).length, 2);
    // El valor de columna (planColumnValue) conserva days para round-trip.
    expect(planColumnValue(captured!, 'meals'), {'days': captured!['days']});
  });
}
