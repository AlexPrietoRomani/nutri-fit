import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifit/features/auth/auth_screen.dart';

void main() {
  Widget wrap() => const MaterialApp(home: AuthScreen());

  testWidgets('Muestra campos de email y password, y el toggle login/signup', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.byKey(const Key('password_field')), findsOneWidget);
    expect(find.byKey(const Key('toggle_mode_button')), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsWidgets);

    // Toggle a modo signup
    await tester.tap(find.byKey(const Key('toggle_mode_button')));
    await tester.pump();
    expect(find.text('Crear cuenta'), findsWidgets);
  });

  testWidgets('Muestra error inline si el email no tiene @ (sin llamar a la red)', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(const Key('email_field')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('password_field')), 'validpass123');
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pump();

    expect(find.byKey(const Key('auth_error_text')), findsOneWidget);
    expect(find.text('Ingresa un email válido.'), findsOneWidget);
  });

  testWidgets('Muestra error inline si el password es muy corto (sin llamar a la red)', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(const Key('email_field')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('password_field')), '123');
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pump();

    expect(find.byKey(const Key('auth_error_text')), findsOneWidget);
    expect(find.text('La contraseña debe tener al menos 6 caracteres.'), findsOneWidget);
  });

  testWidgets('El enlace "¿Olvidaste tu contraseña?" aparece en login y no en signup', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.byKey(const Key('forgot_password_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle_mode_button')));
    await tester.pump();

    expect(find.byKey(const Key('forgot_password_button')), findsNothing);
  });

  testWidgets('El diálogo de recuperación valida el email antes de intentar enviar (sin red)', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.byKey(const Key('forgot_password_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forgot_password_email_field')), findsOneWidget);

    // Email vacío/sin '@': el diálogo se cierra pero no debe intentar la red
    // (no hay Supabase inicializado en test; si se llamara, lanzaría/colgaría).
    await tester.enterText(find.byKey(const Key('forgot_password_email_field')), 'not-an-email');
    await tester.tap(find.byKey(const Key('forgot_password_send_button')));
    await tester.pumpAndSettle();

    // El diálogo se cerró sin error ni excepción no capturada.
    expect(find.byKey(const Key('forgot_password_email_field')), findsNothing);
  });
}
