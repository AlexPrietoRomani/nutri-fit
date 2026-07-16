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

  /// URL del microservicio de IA (FastAPI). En el emulador Android usar
  /// 10.0.2.2 vía --dart-define=AI_SERVICE_URL=http://10.0.2.2:8000
  static const String aiServiceUrl = String.fromEnvironment(
    'AI_SERVICE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
