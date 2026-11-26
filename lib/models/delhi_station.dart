/// Represents a Delhi air quality monitoring station with coordinates and
/// baseline/live PM2.5 and AQI readings.
class DelhiStation {
  final String id;
  final String name;
  final String? waqiId;
  final double lat;
  final double lon;
  final double pm25;
  final int? aqi;

  const DelhiStation({
    required this.id,
    required this.name,
    this.waqiId,
    required this.lat,
    required this.lon,
    required this.pm25,
    this.aqi,
  });

  DelhiStation copyWith({
    double? pm25,
    int? aqi,
  }) {
    return DelhiStation(
      id: id,
      name: name,
      waqiId: waqiId,
      lat: lat,
      lon: lon,
      pm25: pm25 ?? this.pm25,
      aqi: aqi ?? this.aqi,
    );
  }

  Map<String, dynamic> toInterpolationMap() => {
        'name': name,
        'lat': lat,
        'lon': lon,
        'pm25': pm25,
        if (aqi != null) 'aqi': aqi,
      };

  /// Predefined Delhi monitoring stations (approximate real coordinates and
  /// fallback sample PM2.5 values when offline or unconfigured).
  static const List<DelhiStation> defaults = [
    DelhiStation(
      id: 'dtu',
      name: 'DTU',
      waqiId: '@9290',
      lat: 28.7500,
      lon: 77.1167,
      pm25: 180.0,
    ),
    DelhiStation(
      id: 'ito',
      name: 'ITO',
      waqiId: '@3715',
      lat: 28.6289,
      lon: 77.2410,
      pm25: 220.0,
    ),
    DelhiStation(
      id: 'mandir_marg',
      name: 'Mandir Marg',
      waqiId: 'A2554',
      lat: 28.6364,
      lon: 77.2010,
      pm25: 195.0,
    ),
    DelhiStation(
      id: 'rk_puram',
      name: 'RK Puram',
      lat: 28.5667,
      lon: 77.1833,
      pm25: 165.0,
    ),
    DelhiStation(
      id: 'punjabi_bagh',
      name: 'Punjabi Bagh',
      lat: 28.6667,
      lon: 77.1333,
      pm25: 210.0,
    ),
    DelhiStation(
      id: 'anand_vihar',
      name: 'Anand Vihar',
      lat: 28.6469,
      lon: 77.3160,
      pm25: 240.0,
    ),
  ];
}
