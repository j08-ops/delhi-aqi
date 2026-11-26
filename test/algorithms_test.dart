import 'package:delhi_aqi/algorithms/aqi_interpolation.dart';
import 'package:delhi_aqi/algorithms/intake_calculator.dart';
import 'package:delhi_aqi/algorithms/route_comparator.dart';
import 'package:delhi_aqi/algorithms/travel_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AqiInterpolation', () {
    final stations = [
      {'lat': 28.75, 'lon': 77.12, 'pm25': 100.0},
      {'lat': 28.60, 'lon': 77.25, 'pm25': 200.0},
    ];

    test('returns 0.0 when stations list is empty', () {
      final interp = AqiInterpolation(const []);
      expect(interp.interpolate(lat: 28.65, lon: 77.20), 0.0);
    });

    test('returns exact station value when query matches station coordinates', () {
      final interp = AqiInterpolation(stations);
      expect(
        interp.interpolate(lat: 28.75, lon: 77.12),
        closeTo(100.0, 0.01),
      );
    });

    test('weights closer station higher than farther station', () {
      final interp = AqiInterpolation(stations);
      final nearFirst = interp.interpolate(lat: 28.74, lon: 77.13);
      expect(nearFirst, lessThan(130.0));
      expect(nearFirst, greaterThan(100.0));
    });
  });

  group('IntakeCalculator', () {
    test('calculates intake in micrograms correctly', () {
      final intake = IntakeCalculator.calculateIntake(
        pm25Concentration: 200.0,
        durationMinutes: 10.0,
        breathingRate: 10.0,
      );
      expect(intake, closeTo(20.0, 1e-6));
    });

    test('converts intake to cigarette equivalents', () {
      const oneCigUg = 22.0 * 1440.0 / 1000.0;
      expect(IntakeCalculator.cigaretteEquivalent(oneCigUg), closeTo(1.0, 1e-6));
    });

    test('returns higher breathing rate for runner and asthmatic profiles', () {
      final base = IntakeCalculator.getBreathingRate('General adult');
      expect(IntakeCalculator.getBreathingRate('Asthmatic'), greaterThan(base));
      expect(
        IntakeCalculator.getBreathingRate('Outdoor runner'),
        greaterThan(IntakeCalculator.getBreathingRate('Asthmatic')),
      );
    });
  });

  group('TravelTime', () {
    test('increases travel time as volume approaches and exceeds capacity', () {
      final freeFlow = TravelTime.bpr(
        freeFlowTime: 10.0,
        volume: 200.0,
        capacity: 1000.0,
      );
      final congested = TravelTime.bpr(
        freeFlowTime: 10.0,
        volume: 1200.0,
        capacity: 1000.0,
      );
      expect(freeFlow, closeTo(10.0024, 0.001));
      expect(congested, greaterThan(13.0));
    });

    test('handles zero capacity safely without NaN', () {
      final result = TravelTime.bpr(
        freeFlowTime: 5.0,
        volume: 100.0,
        capacity: 0.0,
      );
      expect(result, 50.0);
    });
  });

  group('RouteComparator', () {
    test('evaluates route totals and cigarette equivalents', () {
      final comparator = RouteComparator(stations: [
        {'lat': 28.70, 'lon': 77.15, 'pm25': 200.0},
      ]);

      final result = comparator.evaluateRoute(
        routeType: 'fastest',
        breathingRate: 10.0,
        segments: [
          {'lat': 28.70, 'lon': 77.15, 'duration': 15.0, 'distance': 6.0},
          {'lat': 28.70, 'lon': 77.15, 'duration': 5.0, 'distance': 2.0},
        ],
      );

      expect(result.travelTimeMinutes, 20.0);
      expect(result.totalDistanceKm, 8.0);
      expect(result.totalIntakeUg, closeTo(40.0, 0.01));
      expect(result.cigaretteEquivalent, greaterThan(1.0));
    });
  });
}
