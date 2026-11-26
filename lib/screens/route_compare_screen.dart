import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../algorithms/intake_calculator.dart';
import '../algorithms/route_comparator.dart';
import '../models/delhi_station.dart';
import '../models/route_result.dart';
import '../services/aqi_service.dart';
import '../services/routing_service.dart';
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

enum _MapPickMode { none, origin, destination }

/// Screen that compares fastest vs. cleanest driving routes between any two
/// locations using OpenStreetMap Nominatim search, OSRM road routing,
/// live WAQI station interpolation, BPR traffic modeling, and PM2.5 intake.
class RouteCompareScreen extends StatefulWidget {
  const RouteCompareScreen({super.key});

  @override
  State<RouteCompareScreen> createState() => _RouteCompareScreenState();
}

class _RouteCompareScreenState extends State<RouteCompareScreen> {
  final _aqiService = AqiService();
  final _routingService = RoutingService();

  final _originController = TextEditingController(text: 'DTU, Delhi');
  final _destController = TextEditingController(text: 'Anand Vihar, Delhi');

  LatLng _origin = const LatLng(28.7500, 77.1167);
  LatLng _destination = const LatLng(28.6469, 77.3160);

  List<PlaceSuggestion> _originSuggestions = const [];
  List<PlaceSuggestion> _destSuggestions = const [];
  bool _searchingOrigin = false;
  bool _searchingDest = false;
  _MapPickMode _mapPickMode = _MapPickMode.none;

  List<DelhiStation> _stations = DelhiStation.defaults;
  List<RouteCandidate> _candidates = const [];
  bool _loading = true;
  bool _usingFallbackStations = true;
  bool _usingFallbackRoutes = false;
  String? _routeError;

  String _selectedProfile = userProfiles.first;
  TrafficLevel _trafficLevel = TrafficLevel.moderate;

  RouteResult? _fastest;
  RouteResult? _cleanest;
  List<LatLng> _fastestPoints = const [];
  List<LatLng> _cleanestPoints = const [];

  @override
  void initState() {
    super.initState();
    _loadRouteAndStations();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _loadRouteAndStations() async {
    setState(() {
      _loading = true;
      _routeError = null;
    });

    final stationResult =
        await _aqiService.fetchStationsInBounds(_origin, _destination);
    if (!mounted) return;

    List<RouteCandidate> fetchedCandidates = const [];
    bool usedFallbackRoutes = false;
    String? routeError;

    try {
      fetchedCandidates = await _routingService.fetchRoutes(
        origin: _origin,
        destination: _destination,
        stations: stationResult.stations,
      );
    } on RoutingServiceException catch (e) {
      routeError = e.message;
      usedFallbackRoutes = true;
      fetchedCandidates = _buildOfflineFallbackCandidates();
    }

    if (!mounted) return;
    setState(() {
      _stations = stationResult.stations;
      _usingFallbackStations = stationResult.usedFallback;
      _candidates = fetchedCandidates;
      _usingFallbackRoutes = usedFallbackRoutes;
      _routeError = routeError;
      _loading = false;
    });

    _evaluateCandidates();
  }

  Future<void> _searchPlace({required bool isOrigin}) async {
    final query = isOrigin ? _originController.text : _destController.text;
    if (query.trim().isEmpty) return;

    setState(() {
      if (isOrigin) {
        _searchingOrigin = true;
        _originSuggestions = const [];
      } else {
        _searchingDest = true;
        _destSuggestions = const [];
      }
    });

    try {
      final results = await _routingService.searchPlaces(query);
      if (!mounted) return;
      setState(() {
        if (isOrigin) {
          _originSuggestions = results;
          _searchingOrigin = false;
        } else {
          _destSuggestions = results;
          _searchingDest = false;
        }
      });
      if (results.isEmpty) {
        _showMessage('No places found for "$query".');
      }
    } on RoutingServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        if (isOrigin) {
          _searchingOrigin = false;
        } else {
          _searchingDest = false;
        }
      });
      _showMessage(e.message);
    }
  }

  void _selectSuggestion(PlaceSuggestion place, {required bool isOrigin}) {
    setState(() {
      if (isOrigin) {
        _origin = place.location;
        _originController.text = place.shortName;
        _originSuggestions = const [];
      } else {
        _destination = place.location;
        _destController.text = place.shortName;
        _destSuggestions = const [];
      }
      _mapPickMode = _MapPickMode.none;
    });
    _loadRouteAndStations();
  }

  void _swapEndpoints() {
    setState(() {
      final tmpPoint = _origin;
      _origin = _destination;
      _destination = tmpPoint;

      final tmpText = _originController.text;
      _originController.text = _destController.text;
      _destController.text = tmpText;

      _originSuggestions = const [];
      _destSuggestions = const [];
      _mapPickMode = _MapPickMode.none;
    });
    _loadRouteAndStations();
  }

  void _handleMapTap(LatLng point) {
    if (_mapPickMode == _MapPickMode.none) return;

    final coordsLabel =
        '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';

    setState(() {
      if (_mapPickMode == _MapPickMode.origin) {
        _origin = point;
        _originController.text = coordsLabel;
        _originSuggestions = const [];
      } else {
        _destination = point;
        _destController.text = coordsLabel;
        _destSuggestions = const [];
      }
      _mapPickMode = _MapPickMode.none;
    });

    _loadRouteAndStations();
  }

  void _evaluateCandidates() {
    if (_candidates.isEmpty) return;

    final stationMaps = _stations.map((s) => s.toInterpolationMap()).toList();
    final comparator = RouteComparator(stations: stationMaps);
    final breathingRate = IntakeCalculator.getBreathingRate(_selectedProfile);
    const double roadCapacity = 1000.0;

    final evaluated = <({
      RouteCandidate candidate,
      RouteResult fastestScored,
      RouteResult cleanestScored,
    })>[];

    for (var i = 0; i < _candidates.length; i++) {
      final candidate = _candidates[i];
      // Slight congestion gradient across alternatives so peak-hour BPR
      // captures heavier central-corridor delays on the primary route.
      final routeCongestionFactor = i == 0 ? 1.05 : 0.92;
      final adjustedSegments = candidate.segments.map((seg) {
        final adjustedDuration = comparator.estimateSegmentTime(
          freeFlowMinutes: seg['duration']!,
          volume: roadCapacity * _trafficLevel.vcRatio * routeCongestionFactor,
          capacity: roadCapacity,
        );
        return {
          'lat': seg['lat']!,
          'lon': seg['lon']!,
          'duration': adjustedDuration,
          'distance': seg['distance']!,
        };
      }).toList();

      evaluated.add((
        candidate: candidate,
        fastestScored: comparator.evaluateRoute(
          segments: adjustedSegments,
          routeType: 'fastest',
          breathingRate: breathingRate,
        ),
        cleanestScored: comparator.evaluateRoute(
          segments: adjustedSegments,
          routeType: 'cleanest',
          breathingRate: breathingRate,
        ),
      ));
    }

    var bestFast = evaluated.first;
    var bestClean = evaluated.first;

    for (final entry in evaluated.skip(1)) {
      if (entry.fastestScored.travelTimeMinutes <
          bestFast.fastestScored.travelTimeMinutes) {
        bestFast = entry;
      }
      if (entry.cleanestScored.totalIntakeUg <
          bestClean.cleanestScored.totalIntakeUg) {
        bestClean = entry;
      }
    }

    setState(() {
      _fastest = bestFast.fastestScored;
      _cleanest = bestClean.cleanestScored;
      _fastestPoints = bestFast.candidate.points;
      _cleanestPoints = bestClean.candidate.points;
    });
  }

  List<RouteCandidate> _buildOfflineFallbackCandidates() {
    final fastSegs = [
      {'lat': 28.7500, 'lon': 77.1167, 'duration': 5.0, 'distance': 2.0},
      {'lat': 28.6900, 'lon': 77.1500, 'duration': 8.0, 'distance': 4.5},
      {'lat': 28.6667, 'lon': 77.1333, 'duration': 6.0, 'distance': 3.0},
      {'lat': 28.6364, 'lon': 77.2010, 'duration': 12.0, 'distance': 6.0},
      {'lat': 28.6289, 'lon': 77.2410, 'duration': 10.0, 'distance': 5.0},
      {'lat': 28.6469, 'lon': 77.3160, 'duration': 7.0, 'distance': 3.5},
    ];
    final cleanSegs = [
      {'lat': 28.7500, 'lon': 77.1167, 'duration': 5.0, 'distance': 2.0},
      {'lat': 28.6900, 'lon': 77.1300, 'duration': 10.0, 'distance': 5.0},
      {'lat': 28.6200, 'lon': 77.1200, 'duration': 12.0, 'distance': 6.0},
      {'lat': 28.5667, 'lon': 77.1833, 'duration': 9.0, 'distance': 4.5},
      {'lat': 28.5900, 'lon': 77.2400, 'duration': 8.0, 'distance': 4.0},
      {'lat': 28.6469, 'lon': 77.3160, 'duration': 5.0, 'distance': 2.5},
    ];

    return [
      RouteCandidate(
        points: fastSegs.map((s) => LatLng(s['lat']!, s['lon']!)).toList(),
        segments: fastSegs,
        durationMinutes: 48.0,
        distanceKm: 24.0,
      ),
      RouteCandidate(
        points: cleanSegs.map((s) => LatLng(s['lat']!, s['lon']!)).toList(),
        segments: cleanSegs,
        durationMinutes: 49.0,
        distanceKm: 24.0,
      ),
    ];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
            tooltip: 'Recalculate routes & stations',
            onPressed: _loading ? null : _loadRouteAndStations,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocationPicker(theme),
          const SizedBox(height: 12),
          _buildDataSourceStatus(theme),
          if (_routeError != null) ...[
            const SizedBox(height: 8),
            _buildOfflineWarning(theme),
          ],
          const SizedBox(height: 12),
          AqiMap(
            stations: _stations,
            fastestRoute: _fastestPoints,
            cleanestRoute: _cleanestPoints,
            originPoint: _origin,
            destinationPoint: _destination,
            onMapTap: _handleMapTap,
          ),
          if (_mapPickMode != _MapPickMode.none) ...[
            const SizedBox(height: 8),
            _buildMapPickHint(theme),
          ],
          const SizedBox(height: 12),
          ProfileSelector(
            selectedProfile: _selectedProfile,
            onSelected: (profile) {
              setState(() => _selectedProfile = profile);
              _evaluateCandidates();
            },
          ),
          const SizedBox(height: 12),
          _buildTrafficSelector(theme),
          const SizedBox(height: 16),
          if (_loading && _fastest == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_fastest != null && _cleanest != null) ...[
            _buildComparisonBanner(theme),
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
          ],
          const SizedBox(height: 24),
          _buildExplanation(theme),
        ],
      ),
    );
  }

  Widget _buildLocationPicker(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Anywhere-to-anywhere route',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: 'Swap origin & destination',
                  onPressed: _swapEndpoints,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPlaceInput(
              controller: _originController,
              label: 'Origin (address, landmark, or tap map)',
              icon: Icons.trip_origin,
              iconColor: Colors.green.shade700,
              searching: _searchingOrigin,
              pickActive: _mapPickMode == _MapPickMode.origin,
              onSearch: () => _searchPlace(isOrigin: true),
              onPickMap: () => setState(() {
                _mapPickMode = _mapPickMode == _MapPickMode.origin
                    ? _MapPickMode.none
                    : _MapPickMode.origin;
              }),
            ),
            if (_originSuggestions.isNotEmpty)
              _buildSuggestionList(_originSuggestions, isOrigin: true),
            const SizedBox(height: 10),
            _buildPlaceInput(
              controller: _destController,
              label: 'Destination (address, landmark, or tap map)',
              icon: Icons.flag,
              iconColor: Colors.red.shade700,
              searching: _searchingDest,
              pickActive: _mapPickMode == _MapPickMode.destination,
              onSearch: () => _searchPlace(isOrigin: false),
              onPickMap: () => setState(() {
                _mapPickMode = _mapPickMode == _MapPickMode.destination
                    ? _MapPickMode.none
                    : _MapPickMode.destination;
              }),
            ),
            if (_destSuggestions.isNotEmpty)
              _buildSuggestionList(_destSuggestions, isOrigin: false),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _loadRouteAndStations,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions),
                label: Text(_loading ? 'Finding routes...' : 'Find Routes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool searching,
    required bool pickActive,
    required VoidCallback onSearch,
    required VoidCallback onPickMap,
  }) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(icon, color: iconColor),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              tooltip: 'Search place',
              onPressed: searching ? null : onSearch,
            ),
            IconButton(
              icon: Icon(
                Icons.pin_drop,
                color: pickActive ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: 'Pick on map',
              onPressed: onPickMap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList(
    List<PlaceSuggestion> suggestions, {
    required bool isOrigin,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: suggestions.map((place) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place, size: 18),
            title: Text(
              place.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectSuggestion(place, isOrigin: isOrigin),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapPickHint(ThemeData theme) {
    final target =
        _mapPickMode == _MapPickMode.origin ? 'Origin (A)' : 'Destination (B)';
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.touch_app,
                size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap anywhere on the map to set $target.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _mapPickMode = _MapPickMode.none),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourceStatus(ThemeData theme) {
    final IconData icon;
    final String label;
    if (_loading) {
      icon = Icons.sync;
      label = 'Fetching road routes and nearby AQI stations...';
    } else if (_usingFallbackStations) {
      icon = Icons.offline_bolt;
      label =
          'Using baseline sample PM2.5 readings (set WAQI_TOKEN for live stations)';
    } else {
      icon = Icons.cloud_done;
      label =
          'Live WAQI readings (${_stations.length} stations) · ${_candidates.length} route candidate(s)';
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

  Widget _buildOfflineWarning(ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_routeError!} Showing fallback Delhi demo corridor.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
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
                    _evaluateCandidates();
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
    final fastest = _fastest!;
    final cleanest = _cleanest!;
    final sameRoute =
        (fastest.travelTimeMinutes - cleanest.travelTimeMinutes).abs() < 0.05 &&
            (fastest.totalIntakeUg - cleanest.totalIntakeUg).abs() < 0.05;

    final message = sameRoute
        ? 'The fastest route is also the cleanest option found for this corridor.'
        : RouteResult.compare(fastest, cleanest);

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
                  _usingFallbackRoutes ? 'Demo trade-off' : 'The trade-off',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
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
              'Search any origin & destination (or tap the map) to fetch real road alternatives via OSRM.',
            ),
            _bullet(
              theme,
              'PM2.5 along each road segment is estimated via Inverse Distance Weighting from ${_stations.length} monitoring stations.',
            ),
            _bullet(
              theme,
              'Segment travel times scale with traffic congestion using the Bureau of Public Roads (BPR) formula.',
            ),
            _bullet(
              theme,
              'Intake = concentration × time × breathing rate, converted to cigarette equivalents.',
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
