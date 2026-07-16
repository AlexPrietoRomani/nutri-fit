import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutrifit/main.dart';
import 'package:nutrifit/features/auth/auth_screen.dart';
import 'package:nutrifit/features/auth/reset_password_screen.dart';

void main() {
  // No se instancia SupabaseClient real: cuelga el proceso de test en este
  // entorno (INC-015, docs/logs/log.md). Se usa el seam
  // authStateStream/initialAuthState ya agregado a AuthGate para inyectar el
  // AuthState sin tocar SupabaseConfig.client.
  testWidgets('AuthGate renderiza ResetPasswordScreen cuando el evento es passwordRecovery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateStream: const Stream<AuthState>.empty(),
          initialAuthState: AuthState(AuthChangeEvent.passwordRecovery, null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('AuthGate renderiza AuthScreen cuando no hay sesión y el evento no es passwordRecovery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateStream: const Stream<AuthState>.empty(),
          initialAuthState: AuthState(AuthChangeEvent.signedOut, null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
  });
}
