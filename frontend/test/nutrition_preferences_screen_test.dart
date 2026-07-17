import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit/features/nutrition/nutrition_provider.dart';
import 'package:nutrifit/features/nutrition/nutrition_preferences_screen.dart';

// Widget test de la pantalla de preferencias (T18.2.2). No toca Supabase: usa
// los seams fetchOverride/saveOverride que la pantalla reenvía al provider
// (mismo patrón que ChatScreen.saveMealPlanOverride, INC-015).
void main() {
  Widget wrap(Widget child) => ChangeNotifierProvider<NutritionProvider>(
        create: (_) => NutritionProvider(),
        child: MaterialApp(home: child),
      );

  // Ventana alta para que todo el formulario (chips + switch + botón) quede
  // dentro del viewport y no haya que hacer scroll en cada assert.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('carga los valores existentes vía fetchOverride', (tester) async {
    useTallSurface(tester);
    Future<Map<String, dynamic>?> fakeFetch() async => {
          'allergies': ['maní', 'mariscos'],
          'dislikes': ['hígado'],
          'avoid': ['coliflor'],
          'rarely': ['azúcar'],
          'constraints': {'no_fridge': true, 'missing_utensils': ['horno']},
        };

    await tester.pumpWidget(wrap(
      NutritionPreferencesScreen(fetchOverride: fakeFetch),
    ));
    await tester.pumpAndSettle();

    expect(find.text('maní'), findsOneWidget);
    expect(find.text('mariscos'), findsOneWidget);
    expect(find.text('hígado'), findsOneWidget);
    expect(find.text('coliflor'), findsOneWidget);
    expect(find.text('azúcar'), findsOneWidget);
    expect(find.text('horno'), findsOneWidget);

    final switchTile = tester.widget<SwitchListTile>(find.byKey(const Key('pref_no_fridge')));
    expect(switchTile.value, isTrue);
  });

  testWidgets('al guardar llama savePreferences con el payload correcto', (tester) async {
    useTallSurface(tester);
    Future<Map<String, dynamic>?> fakeFetch() async => {
          'allergies': ['maní'],
          'dislikes': <String>[],
          'avoid': <String>[],
          'rarely': <String>[],
          'constraints': {'no_fridge': false, 'missing_utensils': <String>[]},
        };

    Map<String, dynamic>? captured;
    Future<void> fakeSave(Map<String, dynamic> payload) async => captured = payload;

    await tester.pumpWidget(wrap(
      NutritionPreferencesScreen(
          fetchOverride: fakeFetch, saveOverride: fakeSave, userIdOverride: 'u-test'),
    ));
    await tester.pumpAndSettle();

    // Enciende "No tengo refrigerador".
    await tester.tap(find.byKey(const Key('pref_no_fridge')));
    await tester.pumpAndSettle();

    // Añade un dislike escribiendo en el editor de chips correspondiente.
    final dislikesField = find.descendant(
      of: find.byKey(const Key('pref_dislikes')),
      matching: find.byType(TextField),
    );
    await tester.enterText(dislikesField, 'brócoli');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pref_save_button')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['allergies'], ['maní']);
    expect(captured!['dislikes'], ['brócoli']);
    expect(captured!['avoid'], isEmpty);
    expect(captured!['rarely'], isEmpty);
    expect((captured!['constraints'] as Map)['no_fridge'], isTrue);
    expect((captured!['constraints'] as Map)['missing_utensils'], isEmpty);
  });
}
