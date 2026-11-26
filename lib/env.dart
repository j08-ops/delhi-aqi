/// Compile-time environment configuration.
///
/// Pass secrets at build/run time using `--dart-define-from-file=.env.json`
/// or `--dart-define=WAQI_TOKEN=... --dart-define=GEMINI_API_KEY=...`.
/// Never commit `.env`, `.env.json`, or literal keys into source control.
abstract final class Env {
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String waqiToken = String.fromEnvironment('WAQI_TOKEN');

  static bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;
  static bool get hasWaqiToken => waqiToken.trim().isNotEmpty;
}
