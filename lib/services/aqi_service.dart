import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../env.dart';
import '../models/aqi_data.dart';
import '../models/delhi_station.dart';

class AqiService {
  static const String _baseUrl = 'https://api.waqi.info';
  static const Duration _timeout = Duration(seconds: 10);

  String get _token {
    if (!Env.hasWaqiToken) {
      throw AqiServiceException(
        'WAQI_TOKEN is not configured. Run with '
        '--dart-define-from-file=.env.json (see README.md).',
      );
    }
    return Env.waqiToken;
  }

  Future<AqiData> fetchByStationId(String stationId) async {
    final token = _token;
    final url = Uri.parse('$_baseUrl/feed/$stationId/?token=$token');
    return _fetchFeed(url);
  }

  Future<AqiData> fetchByCoordinates(double lat, double lon) async {
    final token = _token;
    final url = Uri.parse('$_baseUrl/feed/geo:$lat;$lon/?token=$token');
    return _fetchFeed(url);
  }

  Future<AqiData> fetchDelhiCity() async {
    final token = _token;
    final url = Uri.parse('$_baseUrl/feed/delhi/?token=$token');
    return _fetchFeed(url);
  }

  /// Fetch live PM2.5/AQI readings for all predefined Delhi stations.
  Future<({List<DelhiStation> stations, bool usedFallback})>
      fetchDelhiStations() async {
    if (!Env.hasWaqiToken) {
      return (stations: DelhiStation.defaults, usedFallback: true);
    }

    var anyFallback = false;
    final futures = DelhiStation.defaults.map((station) async {
      try {
        final data = station.waqiId != null
            ? await fetchByStationId(station.waqiId!)
            : await fetchByCoordinates(station.lat, station.lon);
        final pm25 = data.pm25 ?? station.pm25;
        return station.copyWith(pm25: pm25, aqi: data.aqi);
      } catch (_) {
        anyFallback = true;
        return station;
      }
    });

    final results = await Future.wait(futures);
    return (stations: results, usedFallback: anyFallback);
  }

  /// Fetch live WAQI stations inside a padded bounding box covering [origin]
  /// and [destination] so route exposure works anywhere in the world.
  ///
  /// Falls back to [DelhiStation.defaults] if `WAQI_TOKEN` is missing, the
  /// request fails, or no valid stations are found in the region.
  Future<({List<DelhiStation> stations, bool usedFallback})>
      fetchStationsInBounds(LatLng origin, LatLng destination) async {
    if (!Env.hasWaqiToken) {
      return (stations: DelhiStation.defaults, usedFallback: true);
    }

    const pad = 0.15;
    final minLat = min(origin.latitude, destination.latitude) - pad;
    final maxLat = max(origin.latitude, destination.latitude) + pad;
    final minLon = min(origin.longitude, destination.longitude) - pad;
    final maxLon = max(origin.longitude, destination.longitude) + pad;

    final url = Uri.parse(
      '$_baseUrl/map/bounds/?latlng=$minLat,$minLon,$maxLat,$maxLon&token=$_token',
    );

    try {
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode != 200) {
        return fetchDelhiStations();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'ok' || json['data'] is! List) {
        return fetchDelhiStations();
      }

      final stations = <DelhiStation>[];
      for (final raw in json['data'] as List) {
        if (raw is! Map<String, dynamic>) continue;
        final lat = (raw['lat'] as num?)?.toDouble();
        final lon = (raw['lon'] as num?)?.toDouble();
        final aqi = switch (raw['aqi']) {
          int v => v,
          num v => v.round(),
          String s => int.tryParse(s),
          _ => null,
        };
        if (lat == null || lon == null || aqi == null || aqi <= 0) continue;

        final stationInfo = raw['station'] as Map<String, dynamic>?;
        final fullName = (stationInfo?['name'] as String?) ?? 'Station';
        final shortName = fullName.split(',').first.trim();
        final uid = raw['uid']?.toString() ?? '${lat}_$lon';

        stations.add(
          DelhiStation(
            id: uid,
            name: shortName.isEmpty ? 'Station' : shortName,
            waqiId: '@$uid',
            lat: lat,
            lon: lon,
            pm25: AqiData.aqiToPm25(aqi),
            aqi: aqi,
          ),
        );
      }

      if (stations.isEmpty) {
        return (stations: DelhiStation.defaults, usedFallback: true);
      }

      // Limit marker clutter on very large routes while preserving coverage.
      return (stations: stations.take(25).toList(), usedFallback: false);
    } catch (_) {
      return fetchDelhiStations();
    }
  }

  Future<AqiData> _fetchFeed(Uri url) async {
    try {
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode != 200) {
        throw AqiServiceException('Server returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['status'] != 'ok') {
        throw AqiServiceException(
          json['data'] is String
              ? json['data'] as String
              : 'Unknown WAQI API error',
        );
      }

      return AqiData.fromJson(json);
    } on FormatException catch (e) {
      throw AqiServiceException('Data format error: ${e.message}');
    } catch (e) {
      if (e is AqiServiceException) rethrow;
      throw AqiServiceException('Network error: $e');
    }
  }
}

class AqiServiceException implements Exception {
  final String message;
  AqiServiceException(this.message);

  @override
  String toString() => message;
}
