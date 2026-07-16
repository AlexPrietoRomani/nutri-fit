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
  });
}
