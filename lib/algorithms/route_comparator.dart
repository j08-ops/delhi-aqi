import 'aqi_interpolation.dart';
import 'intake_calculator.dart';
import 'travel_time.dart';
import '../models/route_result.dart';

/// Compares fastest vs cleanest routes using two different cost functions.
///
/// The fastest route minimizes travel time (using the BPR function).
/// The cleanest route minimizes PM2.5 intake (concentration × duration ×
/// breathing rate).
///
/// For the demo, we evaluate pre-defined route segments rather than a full
/// road graph. This keeps the algorithm self-contained and demonstrable
/// without requiring OSM data downloads.
class RouteComparator {
  final AqiInterpolation _aqiInterp;

  RouteComparator({required List<Map<String, dynamic>> stations})
      : _aqiInterp = AqiInterpolation(stations);

  /// Evaluate a route defined as a list of segments.
  ///
  /// Each segment must contain:
  ///   - 'lat': double — latitude of the segment midpoint
  ///   - 'lon': double — longitude of the segment midpoint
  ///   - 'duration': double — time spent on this segment (minutes)
  ///   - 'distance': double — distance of this segment (km)
  ///
  /// Returns a RouteResult with totals for time, intake, and cigarettes.
  RouteResult evaluateRoute({
    required List<Map<String, double>> segments,
    required String routeType,
    double breathingRate = IntakeCalculator.restingBreathingRate,
  }) {
    double totalTime = 0.0;
    double totalDistance = 0.0;
    double totalIntake = 0.0;

    for (final seg in segments) {
      final lat = seg['lat']!;
      final lon = seg['lon']!;
      final duration = seg['duration']!;
      final distance = seg['distance'] ?? 0.0;

      final pm25 = _aqiInterp.interpolate(lat: lat, lon: lon);

      totalIntake += IntakeCalculator.calculateIntake(
        pm25Concentration: pm25,
        durationMinutes: duration,
        breathingRate: breathingRate,
      );

      totalTime += duration;
      totalDistance += distance;
    }

    return RouteResult(
      travelTimeMinutes: totalTime,
      totalIntakeUg: totalIntake,
      cigaretteEquivalent: IntakeCalculator.cigaretteEquivalent(totalIntake),
      totalDistanceKm: totalDistance,
      routeType: routeType,
    );
  }

  /// A* cost for the fastest route: sum of travel times.
  double fastestCost(List<Map<String, double>> segments) {
    double cost = 0.0;
    for (final seg in segments) {
      cost += seg['duration']!;
    }
    return cost;
  }

  /// A* cost for the cleanest route: sum of PM2.5 intake.
  double cleanestCost(
    List<Map<String, double>> segments, {
    double breathingRate = IntakeCalculator.restingBreathingRate,
  }) {
    double cost = 0.0;
    for (final seg in segments) {
      final lat = seg['lat']!;
      final lon = seg['lon']!;
      final duration = seg['duration']!;

      final pm25 = _aqiInterp.interpolate(lat: lat, lon: lon);
      cost += IntakeCalculator.calculateIntake(
        pm25Concentration: pm25,
        durationMinutes: duration,
        breathingRate: breathingRate,
      );
    }
    return cost;
  }

  /// Convenience: estimate travel time for a segment using the BPR function.
  /// Useful when building demo routes from raw distance and traffic data.
  double estimateSegmentTime({
    required double freeFlowMinutes,
    required double volume,
    required double capacity,
  }) {
    return TravelTime.bpr(
      freeFlowTime: freeFlowMinutes,
      volume: volume,
      capacity: capacity,
    );
  }
}