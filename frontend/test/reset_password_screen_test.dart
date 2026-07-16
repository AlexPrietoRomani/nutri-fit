import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifit/features/auth/reset_password_screen.dart';

void main() {
  Widget wrap() => const MaterialApp(home: ResetPasswordScreen());

  testWidgets('Muestra error inline si el password es muy corto (sin llamar a la red)', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(const Key('new_password_field')), '123');
    await tester.tap(find.byKey(const Key('save_password_button')));
    await tester.pump();

    expect(find.byKey(const Key('reset_password_error_text')), findsOneWidget);
    expect(find.text('La contraseña debe tener al menos 6 caracteres.'), findsOneWidget);
    // No debe haber intentado la red (no hay mensaje de éxito ni excepción).
    expect(find.byKey(const Key('reset_password_success_text')), findsNothing);
  });

  testWidgets('El botón de ojo alterna la visibilidad de la contraseña', (tester) async {
    await tester.pumpWidget(wrap());

    final field = tester.widget<TextField>(find.byKey(const Key('new_password_field')));
    expect(field.obscureText, isTrue);

    await tester.tap(find.byKey(const Key('toggle_new_password_visibility')));
    await tester.pump();

    final toggledField = tester.widget<TextField>(find.byKey(const Key('new_password_field')));
    expect(toggledField.obscureText, isFalse);
  });
}
