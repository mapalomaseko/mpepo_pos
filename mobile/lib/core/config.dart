/// Centralised app configuration values.
class Config {
  /// Backend base URL. Override at build time with `--dart-define=API_BASE_URL=http://...`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
