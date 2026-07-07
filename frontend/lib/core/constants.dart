/// Contantes globales de la aplicación Nutri-Fit.
class AppConstants {
  /// URL de Supabase local o producción.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54322',
  );

  /// Clave anónima para inicializar el SDK de Supabase.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51dHJpZml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDQwMjg4MDAsImV4cCI6MjAyMDAwNDgwMH0.placeholderAnonKey',
  );
}
