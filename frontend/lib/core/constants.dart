/// Contantes globales de la aplicación Nutri-Fit.
class AppConstants {
  /// URL de Supabase local o producción.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54321',
  );

  /// Clave anónima para inicializar el SDK de Supabase.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgImlhdCI6IDE3MDQwMjg4MDAsICJleHAiOiAyMDIwMDA0ODAwfQ.hfmk6yqP8MsHHLmydBVovkDr8f_7UZHcV5vNnryS2gw',
  );

  /// UUID de usuario de desarrollo (bypass de auth sin GoTrue).
  /// Debe ser ÚNICO en toda la app: onboarding lo escribe y el resto lo lee.
  static const String devUserId = '00000000-0000-0000-0000-000000000000';
}
