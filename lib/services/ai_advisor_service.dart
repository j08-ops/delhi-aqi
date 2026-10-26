import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/aqi_data.dart';

class AiAdvisorService {
  /// Get your free API key from https://aistudio.google.com/apikey
  /// Replace this placeholder with your actual key.
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';

  Future<String> getHealthAdvice({
    required AqiData data,
    required String userProfile,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      // Fallback when no key is configured
      return '${AqiData.getHealthAdvice(data.aqi)}\n\n'
          '(AI advice unavailable — API key not configured. '
          'Set your Gemini key in ai_advisor_service.dart.)';
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: _apiKey,
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
      return response.text ?? 'No advice available.';
    } catch (e) {
      return '${AqiData.getHealthAdvice(data.aqi)}\n\n'
          '(AI unavailable: $e)';
    }
  }
}