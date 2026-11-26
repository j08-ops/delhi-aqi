import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../algorithms/aqi_interpolation.dart';
import '../models/delhi_station.dart';

class PlaceSuggestion {
  final String displayName;
  final LatLng location;

  const PlaceSuggestion({
    required this.displayName,
    required this.location,
  });

  String get shortName {
    final parts = displayName.split(',');
    return parts.take(2).map((p) => p.trim()).join(', ');
  }
}

class RouteCandidate {
  final List<LatLng> points;
  final List<Map<String, double>> segments;
  final double durationMinutes;
  final double distanceKm;
  final bool isDetourProbe;

  const RouteCandidate({
    required this.points,
    required this.segments,
    required this.durationMinutes,
    required this.distanceKm,
    this.isDetourProbe = false,
  });
}

class RoutingServiceException implements Exception {
  final String message;
  const RoutingServiceException(this.message);

  @override
  String toString() => message;
}

/// Geocoding (OpenStreetMap Nominatim) and road routing (OSRM) service for
/// anywhere-to-anywhere route comparison.
class RoutingService {
  static const Duration _timeout = Duration(seconds: 12);
  static const Map<String, String> _nativeHeaders = {
    'User-Agent': 'delhi_aqi/1.0 (https://github.com/j08-ops/delhi-aqi)',
  };

  Map<String, String> get _headers =>
      kIsWeb ? const <String, String>{} : _nativeHeaders;

  /// Search places anywhere in the world using OpenStreetMap Nominatim.
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '5',
    });

    try {
      final response =
          await http.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) {
        throw RoutingServiceException(
          'Place search failed (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final results = <PlaceSuggestion>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        final name = item['display_name'] as String?;
        if (lat == null || lon == null || name == null) continue;
        results.add(
          PlaceSuggestion(
            displayName: name,
            location: LatLng(lat, lon),
          ),
        );
      }
      return results;
    } on RoutingServiceException {
      rethrow;
    } catch (e) {
      throw RoutingServiceException('Place search error: $e');
    }
  }

  /// Fetch real road route candidates between [origin] and [destination]
  /// via OSRM, and always probe AQI-aware clean-air detour waypoints when
  /// [stations] are provided so alternative lower-pollution corridors are
  /// evaluated alongside the fastest corridor.
  Future<List<RouteCandidate>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    List<DelhiStation> stations = const [],
  }) async {
    final primaryUrl = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?alternatives=3&geometries=geojson&overview=full',
    );

    final detourWaypoints = stations.isEmpty
        ? const <LatLng>[]
        : pickCleanWaypoints(origin, destination, stations);

    final primaryFuture = _queryOsrm(primaryUrl, isDetourProbe: false);
    final detourFutures = detourWaypoints.map((via) {
      final detourUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${via.longitude},${via.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?geometries=geojson&overview=full',
      );
      return _queryOsrm(detourUrl, isDetourProbe: true).catchError(
        (_) => const <RouteCandidate>[],
      );
    }).toList();

    final primaryCandidates = await primaryFuture;
    if (primaryCandidates.isEmpty) {
      throw const RoutingServiceException(
        'No driving route found between these locations.',
      );
    }

    final detourResults = await Future.wait(detourFutures);
    final all = <RouteCandidate>[...primaryCandidates];
    for (final list in detourResults) {
      all.addAll(list);
    }

    return deduplicateRoutes(all);
  }

  Future<List<RouteCandidate>> _queryOsrm(
    Uri url, {
    required bool isDetourProbe,
  }) async {
    try {
      final response =
          await http.get(url, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) {
        throw RoutingServiceException(
          'Routing server returned ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok' || json['routes'] is! List) {
        throw RoutingServiceException(
          json['message'] as String? ?? 'Could not compute route',
        );
      }

      final candidates = <RouteCandidate>[];
      for (final rawRoute in json['routes'] as List) {
        if (rawRoute is! Map<String, dynamic>) continue;
        final candidate =
            parseOsrmRoute(rawRoute, isDetourProbe: isDetourProbe);
        if (candidate != null) candidates.add(candidate);
      }
      return candidates;
    } on RoutingServiceException {
      rethrow;
    } catch (e) {
      throw RoutingServiceException('Routing network error: $e');
    }
  }

  /// Parse a single OSRM route GeoJSON object into a [RouteCandidate].
  static RouteCandidate? parseOsrmRoute(
    Map<String, dynamic> routeJson, {
    bool isDetourProbe = false,
  }) {
    final durationSec = (routeJson['duration'] as num?)?.toDouble();
    final distanceMeters = (routeJson['distance'] as num?)?.toDouble();
    final geometry = routeJson['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;

    if (durationSec == null ||
        distanceMeters == null ||
        coords == null ||
        coords.length < 2) {
      return null;
    }

    final points = <LatLng>[];
    for (final coord in coords) {
      if (coord is! List || coord.length < 2) continue;
      final lon = (coord[0] as num?)?.toDouble();
      final lat = (coord[1] as num?)?.toDouble();
      if (lat != null && lon != null) {
        points.add(LatLng(lat, lon));
      }
    }
    if (points.length < 2) return null;

    final totalDurationMin = durationSec / 60.0;
    final totalDistanceKm = distanceMeters / 1000.0;

    final segments = buildSegmentsFromPolyline(
      points: points,
      totalDurationMinutes: totalDurationMin,
      totalDistanceKm: totalDistanceKm,
    );

    return RouteCandidate(
      points: points,
      segments: segments,
      durationMinutes: totalDurationMin,
      distanceKm: totalDistanceKm,
      isDetourProbe: isDetourProbe,
    );
  }

  /// Convert a route polyline into evenly sampled evaluation segments for
  /// `RouteComparator`, distributing [totalDurationMinutes] and [totalDistanceKm]
  /// proportionally by segment length.
  static List<Map<String, double>> buildSegmentsFromPolyline({
    required List<LatLng> points,
    required double totalDurationMinutes,
    required double totalDistanceKm,
    int maxSamples = 25,
  }) {
    if (points.length < 2) return const [];

    final sampled = <LatLng>[];
    if (points.length <= maxSamples) {
      sampled.addAll(points);
    } else {
      final step = (points.length - 1) / (maxSamples - 1);
      for (var i = 0; i < maxSamples - 1; i++) {
        sampled.add(points[(i * step).round()]);
      }
      sampled.add(points.last);
    }

    final rawLengths = <double>[];
    double totalRawLen = 0.0;
    for (var i = 0; i < sampled.length - 1; i++) {
      final len = _haversineKm(sampled[i], sampled[i + 1]);
      rawLengths.add(len);
      totalRawLen += len;
    }

    final segments = <Map<String, double>>[];
    final fallbackCount = sampled.length - 1;
    for (var i = 0; i < sampled.length - 1; i++) {
      final p1 = sampled[i];
      final p2 = sampled[i + 1];
      final fraction =
          totalRawLen > 0 ? rawLengths[i] / totalRawLen : 1.0 / fallbackCount;
      segments.add({
        'lat': (p1.latitude + p2.latitude) / 2.0,
        'lon': (p1.longitude + p2.longitude) / 2.0,
        'duration': totalDurationMinutes * fraction,
        'distance': totalDistanceKm * fraction,
      });
    }
    return segments;
  }

  /// Select up to two candidate detour waypoints biased toward cleaner air:
  /// 1) The cleaner perpendicular corridor offset around the trip midpoint.
  /// 2) The lowest-PM2.5 monitoring station within a reasonable detour factor.
  static List<LatLng> pickCleanWaypoints(
    LatLng origin,
    LatLng destination,
    List<DelhiStation> stations,
  ) {
    final directKm = _haversineKm(origin, destination);
    if (directKm < 1.0 || stations.isEmpty) return const [];

    final waypoints = <LatLng>[];

    // 1. Perpendicular offset (~28% of span) toward the lower-PM2.5 side.
    final midLat = (origin.latitude + destination.latitude) / 2.0;
    final midLon = (origin.longitude + destination.longitude) / 2.0;
    final dLat = destination.latitude - origin.latitude;
    final dLon = destination.longitude - origin.longitude;

    const offsetScale = 0.28;
    final left = LatLng(midLat - dLon * offsetScale, midLon + dLat * offsetScale);
    final right =
        LatLng(midLat + dLon * offsetScale, midLon - dLat * offsetScale);

    final interp = AqiInterpolation(
      stations.map((s) => s.toInterpolationMap()).toList(),
    );
    final leftPm = interp.interpolate(lat: left.latitude, lon: left.longitude);
    final rightPm =
        interp.interpolate(lat: right.latitude, lon: right.longitude);
    waypoints.add(leftPm <= rightPm ? left : right);

    // 2. Cleanest monitoring station within a reasonable detour budget.
    DelhiStation? bestStation;
    for (final station in stations) {
      final sPoint = LatLng(station.lat, station.lon);
      final fromOrigin = _haversineKm(origin, sPoint);
      final toDest = _haversineKm(sPoint, destination);
      if (fromOrigin < 0.8 || toDest < 0.8) continue;
      if (fromOrigin + toDest > directKm * 1.65) continue;

      if (bestStation == null || station.pm25 < bestStation.pm25) {
        bestStation = station;
      }
    }
    if (bestStation != null) {
      final stationPoint = LatLng(bestStation.lat, bestStation.lon);
      if (_haversineKm(stationPoint, waypoints.first) > 1.0) {
        waypoints.add(stationPoint);
      }
    }

    return waypoints;
  }

  /// Remove duplicate routes that follow virtually the same corridor.
  static List<RouteCandidate> deduplicateRoutes(List<RouteCandidate> routes) {
    final unique = <RouteCandidate>[];
    for (final route in routes) {
      final mid = route.points[route.points.length ~/ 2];
      final isDuplicate = unique.any((existing) {
        final existingMid = existing.points[existing.points.length ~/ 2];
        final sameDistance =
            (existing.distanceKm - route.distanceKm).abs() < 0.3;
        final sameDuration =
            (existing.durationMinutes - route.durationMinutes).abs() < 0.5;
        final closeMidpoint = _haversineKm(existingMid, mid) < 0.4;
        return sameDistance && sameDuration && closeMidpoint;
      });
      if (!isDuplicate) unique.add(route);
    }
    return unique;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180.0;
    final dLon = (b.longitude - a.longitude) * pi / 180.0;
    final lat1 = a.latitude * pi / 180.0;
    final lat2 = b.latitude * pi / 180.0;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }
}
