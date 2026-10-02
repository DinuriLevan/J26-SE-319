/// App-wide configuration, read at compile time via `--dart-define`.
///
/// Run the app with e.g.:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// See the root README.md for emulator vs physical-device examples.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
