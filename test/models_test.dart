import 'package:delhi_aqi/models/aqi_data.dart';
import 'package:delhi_aqi/models/delhi_station.dart';
import 'package:delhi_aqi/models/route_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AqiData', () {
    test('parses valid WAQI payload', () {
      final data = AqiData.fromJson({
        'status': 'ok',
        'data': {
          'aqi': 215,
          'dominentpol': 'pm25',
          'city': {'name': 'DTU, Delhi'},
          'iaqi': {
            'pm25': {'v': 185.5},
            'pm10': {'v': 240},
          },
          'time': {'s': '2026-11-26 10:00:00'},
        },
      });

      expect(data.aqi, 215);
      expect(data.dominantPollutant, 'pm25');
      expect(data.stationName, 'DTU, Delhi');
      expect(data.pm25, 185.5);
      expect(data.pm10, 240.0);
      expect(data.timestamp, isNotNull);
    });

    test('throws FormatException when WAQI returns unavailable "-" AQI', () {
      expect(
        () => AqiData.fromJson({
          'status': 'ok',
          'data': {'aqi': '-'},
        }),
        throwsFormatException,
      );
    });

    test('maps AQI categories accurately', () {
      expect(AqiData.getCategory(40), 'Good');
      expect(AqiData.getCategory(85), 'Moderate');
      expect(AqiData.getCategory(140), 'Unhealthy for Sensitive');
      expect(AqiData.getCategory(180), 'Unhealthy');
      expect(AqiData.getCategory(260), 'Very Unhealthy');
      expect(AqiData.getCategory(350), 'Hazardous');
    });

    test('converts composite AQI to approximate PM2.5 monotonically', () {
      expect(AqiData.aqiToPm25(0), 0.0);
      expect(AqiData.aqiToPm25(50), closeTo(12.0, 0.01));
      expect(AqiData.aqiToPm25(100), closeTo(35.4, 0.01));
      expect(AqiData.aqiToPm25(200), closeTo(150.4, 0.01));
      expect(AqiData.aqiToPm25(300), closeTo(250.4, 0.01));
    });
  });

  group('RouteResult', () {
    test('formats clean vs fast comparison', () {
      final fastest = RouteResult(
        travelTimeMinutes: 30.0,
        totalIntakeUg: 100.0,
        cigaretteEquivalent: 3.1,
        totalDistanceKm: 18.0,
        routeType: 'fastest',
      );
      final cleanest = RouteResult(
        travelTimeMinutes: 34.2,
        totalIntakeUg: 62.0,
        cigaretteEquivalent: 1.9,
        totalDistanceKm: 20.5,
        routeType: 'cleanest',
      );

      expect(
        RouteResult.compare(fastest, cleanest),
        'Clean route takes 4.2 min longer, but reduces PM2.5 intake by 38%',
      );
    });
  });

  group('DelhiStation', () {
    test('provides default stations with valid coordinates', () {
      expect(DelhiStation.defaults, isNotEmpty);
      for (final station in DelhiStation.defaults) {
        expect(station.lat, inInclusiveRange(28.0, 29.5));
        expect(station.lon, inInclusiveRange(76.5, 78.0));
        expect(station.pm25, greaterThan(0));
      }
    });
  });
}
