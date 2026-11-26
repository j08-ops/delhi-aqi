import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../algorithms/intake_calculator.dart';
import '../algorithms/route_comparator.dart';
import '../models/delhi_station.dart';
import '../models/route_result.dart';
import '../services/aqi_service.dart';
import '../widgets/aqi_map.dart';
import '../widgets/profile_selector.dart';

enum TrafficLevel {
  freeFlow('Free-flow', 0.4),
  moderate('Moderate', 0.85),
  peak('Peak hour', 1.25);

  final String label;
  final double vcRatio;
  const TrafficLevel(this.label, this.vcRatio);
}

/// Screen that compares the fastest route vs cleanest route across Delhi
/// using spatial PM2.5 interpolation, BPR traffic delay, and user-profile
/// breathing rates.
class RouteCompareScreen extends StatefulWidget {
  const RouteCompareScreen({super.key});

  @override
  State<RouteCompareScreen> createState() => _RouteCompareScreenState();
}

class _RouteCompareScreenState extends State<RouteCompareScreen> {
  final _aqiService = AqiService();

  List<DelhiStation> _stations = DelhiStation.defaults;
  bool _loadingStations = true;
  bool _usingFallback = true;

  String _selectedProfile = userProfiles.first;
  TrafficLevel _trafficLevel = TrafficLevel.moderate;

  RouteResult? _fastest;
  RouteResult? _cleanest;
  List<LatLng> _fastestPoints = const [];
  List<LatLng> _cleanestPoints = const [];

  @override
  void initState() {
    super.initState();
    _computeRoutes();
    _loadLiveStations();
  }

  Future<void> _loadLiveStations() async {
    setState(() => _loadingStations = true);
    final result = await _aqiService.fetchDelhiStations();
    if (!mounted) return;
    setState(() {
      _stations = result.stations;
      _usingFallback = result.usedFallback;
      _loadingStations = false;
    });
    _computeRoutes();
  }

  void _computeRoutes() {
    final stationMaps = _stations.map((s) => s.toInterpolationMap()).toList();
    final comparator = RouteComparator(stations: stationMaps);

    final fastestSegments = _applyTraffic(_buildFastestRoute(), comparator);
    final cleanestSegments = _applyTraffic(_buildCleanestRoute(), comparator);
    final breathingRate = IntakeCalculator.getBreathingRate(_selectedProfile);

    setState(() {
      _fastest = comparator.evaluateRoute(
        segments: fastestSegments,
        routeType: 'fastest',
        breathingRate: breathingRate,
      );
      _cleanest = comparator.evaluateRoute(
        segments: cleanestSegments,
        routeType: 'cleanest',
        breathingRate: breathingRate,
      );
      _fastestPoints = fastestSegments
          .map((s) => LatLng(s['lat']!, s['lon']!))
          .toList();
      _cleanestPoints = cleanestSegments
          .map((s) => LatLng(s['lat']!, s['lon']!))
          .toList();
    });
  }

  List<Map<String, double>> _applyTraffic(
    List<Map<String, double>> baseSegments,
    RouteComparator comparator,
  ) {
    const double roadCapacity = 1000.0;
    return baseSegments.map((seg) {
      final trafficFactor = seg['congestion'] ?? 1.0;
      final adjustedDuration = comparator.estimateSegmentTime(
        freeFlowMinutes: seg['duration']!,
        volume: roadCapacity * _trafficLevel.vcRatio * trafficFactor,
        capacity: roadCapacity,
      );
      return {
        'lat': seg['lat']!,
        'lon': seg['lon']!,
        'duration': adjustedDuration,
        'distance': seg['distance']!,
      };
    }).toList();
  }

  /// Fastest route: goes directly through central Delhi (higher congestion).
  List<Map<String, double>> _buildFastestRoute() {
    return [
      {'lat': 28.7500, 'lon': 77.1167, 'duration': 5.0, 'distance': 2.0, 'congestion': 0.9},
      {'lat': 28.6900, 'lon': 77.1500, 'duration': 8.0, 'distance': 4.5, 'congestion': 1.0},
      {'lat': 28.6667, 'lon': 77.1333, 'duration': 6.0, 'distance': 3.0, 'congestion': 1.1},
      {'lat': 28.6364, 'lon': 77.2010, 'duration': 12.0, 'distance': 6.0, 'congestion': 1.15},
      {'lat': 28.6289, 'lon': 77.2410, 'duration': 10.0, 'distance': 5.0, 'congestion': 1.2},
      {'lat': 28.6000, 'lon': 77.2800, 'duration': 7.0, 'distance': 3.5, 'congestion': 1.0},
    ];
  }

  /// Cleanest route: longer detour through southern Delhi (lower pollution).
  List<Map<String, double>> _buildCleanestRoute() {
    return [
      {'lat': 28.7500, 'lon': 77.1167, 'duration': 5.0, 'distance': 2.0, 'congestion': 0.9},
      {'lat': 28.6900, 'lon': 77.1300, 'duration': 10.0, 'distance': 5.0, 'congestion': 0.95},
      {'lat': 28.6200, 'lon': 77.1200, 'duration': 12.0, 'distance': 6.0, 'congestion': 0.9},
      {'lat': 28.5667, 'lon': 77.1833, 'duration': 9.0, 'distance': 4.5, 'congestion': 0.85},
      {'lat': 28.5900, 'lon': 77.2400, 'duration': 8.0, 'distance': 4.0, 'congestion': 0.9},
      {'lat': 28.6000, 'lon': 77.2800, 'duration': 5.0, 'distance': 2.5, 'congestion': 0.95},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Comparison'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh station readings',
            onPressed: _loadingStations ? null : _loadLiveStations,
          ),
        ],
      ),
      body: _fastest == null || _cleanest == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDataSourceStatus(theme),
                const SizedBox(height: 12),
                ProfileSelector(
                  selectedProfile: _selectedProfile,
                  onSelected: (profile) {
                    setState(() => _selectedProfile = profile);
                    _computeRoutes();
                  },
                ),
                const SizedBox(height: 12),
                _buildTrafficSelector(theme),
                const SizedBox(height: 16),
                _buildComparisonBanner(theme),
                const SizedBox(height: 16),
                AqiMap(
                  stations: _stations,
                  fastestRoute: _fastestPoints,
                  cleanestRoute: _cleanestPoints,
                ),
                const SizedBox(height: 16),
                _buildRouteCard(
                  theme,
                  title: 'Fastest Route',
                  icon: Icons.speed,
                  color: Colors.blue,
                  result: _fastest!,
                ),
                const SizedBox(height: 12),
                _buildRouteCard(
                  theme,
                  title: 'Cleanest Route',
                  icon: Icons.eco,
                  color: Colors.green,
                  result: _cleanest!,
                ),
                const SizedBox(height: 24),
                _buildExplanation(theme),
              ],
            ),
    );
  }

  Widget _buildDataSourceStatus(ThemeData theme) {
    final IconData icon;
    final String label;
    if (_loadingStations) {
      icon = Icons.sync;
      label = 'Fetching live WAQI station readings...';
    } else if (_usingFallback) {
      icon = Icons.offline_bolt;
      label = 'Using sample Delhi PM2.5 readings (live WAQI unavailable)';
    } else {
      icon = Icons.cloud_done;
      label = 'Using live WAQI PM2.5 readings across ${_stations.length} stations';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.traffic, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Traffic conditions', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TrafficLevel.values.map((level) {
                return ChoiceChip(
                  label: Text(level.label),
                  selected: level == _trafficLevel,
                  onSelected: (val) {
                    if (!val) return;
                    setState(() => _trafficLevel = level);
                    _computeRoutes();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBanner(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'The trade-off',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              RouteResult.compare(_fastest!, _cleanest!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Color color,
    required RouteResult result,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStat(
                    theme,
                    label: 'Time',
                    value: '${result.travelTimeMinutes.toStringAsFixed(1)} min',
                    icon: Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildStat(
                    theme,
                    label: 'Distance',
                    value: '${result.totalDistanceKm.toStringAsFixed(1)} km',
                    icon: Icons.straighten,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStat(
                    theme,
                    label: 'PM2.5 intake',
                    value: '${result.totalIntakeUg.toStringAsFixed(1)} µg',
                    icon: Icons.air,
                  ),
                ),
                Expanded(
                  child: _buildStat(
                    theme,
                    label: 'Equivalent',
                    value:
                        '${result.cigaretteEquivalent.toStringAsFixed(2)} cigs',
                    icon: Icons.smoking_rooms,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanation(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('How this works', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _bullet(
              theme,
              'PM2.5 at each point is estimated using Inverse Distance Weighting from ${_stations.length} Delhi stations.',
            ),
            _bullet(
              theme,
              'Segment travel times scale with traffic congestion using the Bureau of Public Roads (BPR) formula.',
            ),
            _bullet(
              theme,
              'Intake = concentration × time × breathing rate, converted to cigarette equivalents.',
            ),
            _bullet(
              theme,
              'Change your profile or traffic conditions to see how exposure and travel time shift.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
