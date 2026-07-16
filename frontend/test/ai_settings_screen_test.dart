import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/ai/ai_config.dart';
import 'package:nutrifit/features/ai/ai_provider.dart';
import 'package:nutrifit/features/ai/ai_settings_screen.dart';

void main() {
  Widget wrap(Widget child, {AIConfig? config}) => ChangeNotifierProvider<AiProvider>(
        create: (_) => AiProvider(config: config),
        child: MaterialApp(home: child),
      );

  testWidgets('con ollama y /ollama/models poblado, el desplegable de modelos se llena',
      (tester) async {
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/ollama/models')) {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'gemma4:e4b', 'size': 1},
              {'name': 'qwen2.5:3b', 'size': 2},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(wrap(
      AiSettingsScreen(httpClient: mock),
      config: AIConfig(provider: 'ollama', model: 'gemma4:e4b'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(find.text('qwen2.5:3b'), findsOneWidget);
  });

  testWidgets('si /ollama/models falla, el TextField libre de modelo sigue apareciendo',
      (tester) async {
    final mock = MockClient((req) async => http.Response('error', 503));

    await tester.pumpWidget(wrap(
      AiSettingsScreen(httpClient: mock),
      config: AIConfig(provider: 'ollama', model: 'llama3.1'),
    ));
    await tester.pumpAndSettle();

    // Solo el dropdown de proveedor; el modelo cae a TextField.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Modelo'), findsOneWidget);
  });

  testWidgets('un modelo recomendado ya instalado muestra check, no botón Instalar',
      (tester) async {
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/ollama/models')) {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'gemma4:e4b', 'size': 1},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(wrap(
      AiSettingsScreen(httpClient: mock),
      config: AIConfig(provider: 'ollama', model: 'gemma4:e4b'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('gemma4:e4b'), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // llama3.2:3b y qwen2.5:3b no están instalados -> botones Instalar
    expect(find.widgetWithText(TextButton, 'Instalar'), findsNWidgets(2));
  });

  testWidgets('instalar un modelo no instalado dispara pull y refleja progreso',
      (tester) async {
    var pullCalled = false;
    var statusCalls = 0;
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/ollama/models')) {
        return http.Response(jsonEncode({'models': []}), 200,
            headers: {'content-type': 'application/json'});
      }
      if (req.url.path.endsWith('/ollama/pull')) {
        pullCalled = true;
        return http.Response(
            jsonEncode({'started': true, 'model': 'gemma4:e4b'}), 200,
            headers: {'content-type': 'application/json'});
      }
      if (req.url.path.endsWith('/ollama/pull-status')) {
        statusCalls++;
        final done = statusCalls > 1;
        return http.Response(
          jsonEncode({'status': done ? 'success' : 'downloading', 'done': done}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(wrap(
      AiSettingsScreen(httpClient: mock),
      config: AIConfig(provider: 'ollama', model: 'llama3.1'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Instalar').first);
    await tester.pump();

    expect(pullCalled, isTrue);
    expect(find.text('iniciando...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    expect(find.text('downloading'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pumpAndSettle();
  });
}
