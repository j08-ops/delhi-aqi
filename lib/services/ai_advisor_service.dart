import 'package:google_generative_ai/google_generative_ai.dart';
import '../env.dart';
import '../models/aqi_data.dart';

class AiAdvisorService {
  static const String _defaultModel = 'gemini-2.5-flash';

  Future<String> getHealthAdvice({
    required AqiData data,
    required String userProfile,
  }) async {
    if (!Env.hasGeminiKey) {
      return '${AqiData.getHealthAdvice(data.aqi)}\n\n'
          '(AI advice unavailable — pass GEMINI_API_KEY via '
          '--dart-define-from-file=.env.json to enable Gemini insights.)';
    }

    final model = GenerativeModel(
      model: _defaultModel,
      apiKey: Env.geminiApiKey,
      systemInstruction: Content.system(
        'You are a concise air quality health advisor for Delhi. '
        'Give actionable, personalized advice in under 3 sentences. '
        'Consider the user profile carefully.',
      ),
    );

    final prompt = '''
Current AQI: ${data.aqi} (${AqiData.getCategory(data.aqi)})
Dominant pollutant: ${data.dominantPollutant}
Station: ${data.stationName}
PM2.5: ${data.pm25?.toStringAsFixed(1) ?? 'N/A'} µg/m³
PM10: ${data.pm10?.toStringAsFixed(1) ?? 'N/A'} µg/m³
User profile: $userProfile

What should this person do right now?
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? AqiData.getHealthAdvice(data.aqi);
    } catch (e) {
      return '${AqiData.getHealthAdvice(data.aqi)}\n\n'
          '(AI advisor fallback — request failed: $e)';
    }
  }
}
