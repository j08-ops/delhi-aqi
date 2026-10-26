import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/aqi_data.dart';
import '../env.dart';

class AqiService {
  static const String _baseUrl = 'https://api.waqi.info';

  /// Replace with your own token from https://aqicn.org/api/register
  static  String get _token => Env.waqiToken;

  /// Delhi station IDs:
  /// @9290 = DTU, Delhi
  /// @3715 = ITO, Delhi
  /// A2554 = Mandir Marg, Delhi
  Future<AqiData> fetchByStationId(String stationId) async {
    final url = Uri.parse('$_baseUrl/feed/$stationId/?token=$_token');

    try {
      final response =
      await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw AqiServiceException('Server returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['status'] != 'ok') {
        throw AqiServiceException(
          json['data'] is String
              ? json['data'] as String
              : 'Unknown API error',
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

  Future<AqiData> fetchDelhiCity() async {
    final url = Uri.parse('$_baseUrl/feed/delhi/?token=$_token');

    try {
      final response =
      await http.get(url).timeout(const Duration(seconds: 10));
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['status'] != 'ok') {
        throw AqiServiceException('Delhi data unavailable');
      }

      return AqiData.fromJson(json);
    } catch (e) {
      if (e is AqiServiceException) rethrow;
      throw AqiServiceException('Failed to fetch Delhi AQI: $e');
    }
  }
}

class AqiServiceException implements Exception {
  final String message;
  AqiServiceException(this.message);

  @override
  String toString() => message;
}
