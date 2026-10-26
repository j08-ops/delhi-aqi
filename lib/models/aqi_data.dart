class AqiData {
  final int aqi;
  final String dominantPollutant;
  final String stationName;
  final String cityName;
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? so2;
  final double? co;
  final double? o3;
  final DateTime? timestamp;

  AqiData({
    required this.aqi,
    required this.dominantPollutant,
    required this.stationName,
    required this.cityName,
    this.pm25,
    this.pm10,
    this.no2,
    this.so2,
    this.co,
    this.o3,
    this.timestamp,
  });

  factory AqiData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null || data['aqi'] is! int) {
      throw const FormatException('Invalid AQI data structure');
    }

    final iaqi = data['iaqi'] as Map<String, dynamic>? ?? {};
    final timeStr = data['time']?['s'] as String?;

    return AqiData(
      aqi: data['aqi'] as int,
      dominantPollutant: data['dominentpol'] as String? ?? 'pm25',
      stationName: data['city']?['name'] as String? ?? 'Unknown Station',
      cityName: data['city']?['name'] as String? ?? 'Delhi',
      pm25: _parseIaqiValue(iaqi, 'pm25'),
      pm10: _parseIaqiValue(iaqi, 'pm10'),
      no2: _parseIaqiValue(iaqi, 'no2'),
      so2: _parseIaqiValue(iaqi, 'so2'),
      co: _parseIaqiValue(iaqi, 'co'),
      o3: _parseIaqiValue(iaqi, 'o3'),
      timestamp: timeStr != null ? DateTime.tryParse(timeStr) : null,
    );
  }

  static double? _parseIaqiValue(Map<String, dynamic> iaqi, String key) {
    final entry = iaqi[key];
    if (entry == null) return null;
    final v = entry['v'];
    if (v is num) return v.toDouble();
    return null;
  }

  static String getCategory(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  static String getHealthAdvice(int aqi) {
    if (aqi <= 50) return 'Air quality is satisfactory. Enjoy outdoor activities.';
    if (aqi <= 100) {
      return 'Acceptable. Unusually sensitive individuals should limit prolonged outdoor exertion.';
    }
    if (aqi <= 150) {
      return 'Sensitive groups should reduce prolonged outdoor activity.';
    }
    if (aqi <= 200) {
      return 'Everyone should limit outdoor exertion. Sensitive groups stay indoors.';
    }
    if (aqi <= 300) {
      return 'Health alert. Avoid outdoor activities. Keep windows closed.';
    }
    return 'Emergency conditions. Stay indoors with air purification.';
  }
}