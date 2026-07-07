import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

/// Clase encargada de la inicialización y acceso a Supabase.
class SupabaseConfig {
  /// Inicializa la conexión con el servidor Supabase.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      debug: true, // Habilitar logs en consola durante el desarrollo
    );
  }

  /// Retorna la instancia única del cliente Supabase.
  static SupabaseClient get client => Supabase.instance.client;
}
