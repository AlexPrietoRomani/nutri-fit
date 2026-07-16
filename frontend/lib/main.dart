import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/supabase_config.dart';
import 'core/constants.dart';
import 'features/auth/onboarding_provider.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/nutrition/nutrition_provider.dart';
import 'features/nutrition/diary_screen.dart';
import 'features/training/training_provider.dart';
import 'features/training/workout_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/ai/ai_provider.dart';
import 'features/ai/chat_screen.dart';
import 'features/ai/ai_settings_screen.dart';

void main() async {
  // Asegurar que los bindings de Flutter estén inicializados antes de servicios asíncronos.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase local/remoto.
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Error al inicializar Supabase: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => NutritionProvider()),
        ChangeNotifierProvider(create: (_) => TrainingProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
      ],
      child: const NutriFitApp(),
    ),
  );
}

class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutri-Fit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0F0E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2ED573), // Accent green
          secondary: Color(0xFF2ED573),
          surface: Color(0xFF1E201E),
          background: Color(0xFF0E0F0E),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E201E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E0F0E),
          elevation: 0,
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialCheckScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/diary': (context) => const DiaryScreen(),
        '/training': (context) => const WorkoutScreen(),
        '/chat': (context) => const ChatScreen(),
        '/ai-settings': (context) => const AiSettingsScreen(),
      },
    );
  }
}

/// Screen that checks if the user has completed their onboarding.
class InitialCheckScreen extends StatelessWidget {
  const InitialCheckScreen({super.key});

  Future<bool> _isProfileConfigured() async {
    try {
      final client = SupabaseConfig.client;
      // Sin GoTrue usamos el UUID de dev; con auth real, el id del usuario.
      final userId = client.auth.currentUser?.id ?? AppConstants.devUserId;
      final data = await client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return data != null; // hay perfil -> Dashboard; no hay -> Onboarding
    } catch (e) {
      debugPrint('Error checking profile configuration: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isProfileConfigured(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            ),
          );
        }
        
        final configured = snapshot.data ?? false;
        if (configured) {
          return const DashboardScreen();
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }
}

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutri-Fit Dashboard'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                size: 80,
                color: Color(0xFF2ED573),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Bienvenido a Nutri-Fit!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu perfil físico e ingestas están configurados en Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ED573),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed('/diary');
                },
                icon: const Icon(Icons.restaurant_menu_rounded),
                label: const Text('Ir al Diario Alimenticio'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.grey,
                  side: const BorderSide(color: Color(0xFF2E302E)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Let user redo onboarding for testing/demo purposes
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reconfigurar Perfil (Onboarding)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed('/training');
                },
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Ir a Entrenamientos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
