import 'package:delhi_aqi/models/delhi_station.dart';
import 'package:delhi_aqi/services/routing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('RoutingService', () {
    test('parses valid OSRM GeoJSON route into segments', () {
      final candidate = RoutingService.parseOsrmRoute({
        'duration': 1800.0,
        'distance': 12000.0,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [77.1167, 28.7500],
            [77.1800, 28.6900],
            [77.2410, 28.6289],
          ],
        },
      });

      expect(candidate, isNotNull);
      expect(candidate!.durationMinutes, closeTo(30.0, 1e-6));
      expect(candidate.distanceKm, closeTo(12.0, 1e-6));
      expect(candidate.points.length, 3);
      expect(candidate.segments.length, 2);

      final sumDuration = candidate.segments
          .fold<double>(0.0, (acc, s) => acc + s['duration']!);
      final sumDistance = candidate.segments
          .fold<double>(0.0, (acc, s) => acc + s['distance']!);
      expect(sumDuration, closeTo(30.0, 1e-6));
      expect(sumDistance, closeTo(12.0, 1e-6));
    });

    test('returns null for malformed OSRM route', () {
      expect(RoutingService.parseOsrmRoute({'duration': 100}), isNull);
    });

    test('downsamples dense polylines while preserving total time and distance',
        () {
      final densePoints = List.generate(
        60,
        (i) => LatLng(28.60 + i * 0.002, 77.10 + i * 0.002),
      );

      final segments = RoutingService.buildSegmentsFromPolyline(
        points: densePoints,
        totalDurationMinutes: 45.0,
        totalDistanceKm: 18.0,
        maxSamples: 15,
      );

      expect(segments.length, 14);
      final totalDuration =
          segments.fold<double>(0.0, (sum, s) => sum + s['duration']!);
      final totalDistance =
          segments.fold<double>(0.0, (sum, s) => sum + s['distance']!);
      expect(totalDuration, closeTo(45.0, 1e-6));
      expect(totalDistance, closeTo(18.0, 1e-6));
    });
  });

  group('PlaceSuggestion', () {
    test('formats concise shortName from full Nominatim display_name', () {
      const suggestion = PlaceSuggestion(
        displayName: 'Connaught Place, New Delhi, Delhi, 110001, India',
        location: LatLng(28.6315, 77.2167),
      );
      expect(suggestion.shortName, 'Connaught Place, New Delhi');
    });
  });

  group('Clean detour waypoint selection', () {
    test('picks cleaner perpendicular offset and cleanest station in corridor',
        () {
      final waypoints = RoutingService.pickCleanWaypoints(
        const LatLng(28.7500, 77.1167),
        const LatLng(28.6469, 77.3160),
        DelhiStation.defaults,
      );

      expect(waypoints, isNotEmpty);
      expect(waypoints.length, lessThanOrEqualTo(2));
    });

    test('deduplicates nearly identical routes', () {
      const p1 = LatLng(28.75, 77.12);
      const p2 = LatLng(28.65, 77.30);
      const a = RouteCandidate(
        points: [p1, LatLng(28.70, 77.21), p2],
        segments: [],
        durationMinutes: 30.0,
        distanceKm: 20.0,
      );
      const b = RouteCandidate(
        points: [p1, LatLng(28.701, 77.211), p2],
        segments: [],
        durationMinutes: 30.2,
        distanceKm: 20.1,
      );
      const c = RouteCandidate(
        points: [p1, LatLng(28.58, 77.18), p2],
        segments: [],
        durationMinutes: 35.0,
        distanceKm: 23.0,
        isDetourProbe: true,
      );

      final deduped = RoutingService.deduplicateRoutes([a, b, c]);
      expect(deduped.length, 2);
    });
  });
}
