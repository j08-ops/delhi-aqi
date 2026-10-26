import 'dart:math';

/// Inverse Distance Weighting (IDW) for estimating PM2.5 at any point.
///
/// This is a spatial interpolation algorithm that estimates the value at an
/// unknown location based on known values at surrounding stations. Points
/// closer to a station get more weight than points further away.
class AqiInterpolation {
  /// List of monitoring stations. Each entry must have:
  ///   - 'lat': double (latitude)
  ///   - 'lon': double (longitude)
  ///   - 'pm25': num (PM2.5 concentration in µg/m³)
  final List<Map<String, dynamic>> _stations;

  AqiInterpolation(this._stations);

  /// Estimate PM2.5 at (lat, lon) using IDW.
  ///
  /// [power] controls how sharply distance affects weight (default 2).
  /// [maxStations] limits to the nearest N stations for locality.
  ///
  /// Returns estimated PM2.5 in µg/m³.
  double interpolate({
    required double lat,
    required double lon,
    int power = 2,
    int maxStations = 3,
  }) {
    if (_stations.isEmpty) return 0.0;

    // Compute distance from (lat, lon) to every station
    final distances = _stations.map((s) {
      final d = _haversine(
        lat,
        lon,
        s['lat'] as double,
        s['lon'] as double,
      );
      return {
        'station': s,
        'distance': d,
        'pm25': (s['pm25'] as num).toDouble(),
      };
    }).toList();

    // Sort by distance, keep the nearest N
    distances.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

    final nearest = distances.take(maxStations).toList();

    // IDW formula: Z = Σ(w_i * Z_i) / Σ(w_i)
    // where w_i = 1 / d_i^power
    double numerator = 0.0;
    double denominator = 0.0;

    for (final entry in nearest) {
      final d = entry['distance'] as double;

      // Avoid division by zero if the point is exactly at a station
      final weight = d < 0.001 ? 1e6 : 1.0 / pow(d, power);

      numerator += weight * (entry['pm25'] as double);
      denominator += weight;
    }

    return denominator > 0 ? numerator / denominator : 0.0;
  }

  /// Haversine distance between two coordinates, in kilometers.
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Convert degrees to radians.
  double _toRad(double deg) => deg * pi / 180.0;
}