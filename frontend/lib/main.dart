import 'package:flutter/material.dart';
import 'core/supabase_config.dart';

void main() async {
  // Asegurar que los bindings de Flutter estén inicializados antes de servicios asíncronos.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase local/remoto.
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Error al inicializar Supabase: $e');
  }

  runApp(const NutriFitApp());
}

class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutri-Fit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardPlaceholder(),
    );
  }
}

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutri-Fit'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center_rounded,
              size: 80,
              color: Color(0xFF6200EE),
            ),
            const SizedBox(height: 20),
            Text(
              'Bienvenido a Nutri-Fit',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Estructura modular inicializada correctamente.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conexión con Supabase configurada en core/'),
                  ),
                );
              },
              icon: const Icon(Icons.bolt),
              label: const Text('Comprobar Configuración'),
            ),
          ],
        ),
      ),
    );
  }
}
