import 'dart:convert';
import 'package:http/http.dart' as http;
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
  /// Stations whose requests fail or lack PM2.5 fall back to their baseline
  /// sample reading, and [usedFallback] in the result indicates whether any
  /// station fell back.
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
