import 'package:flutter/material.dart';
import '../algorithms/route_comparator.dart';
import '../models/route_result.dart';
import '../widgets/aqi_map.dart';

/// Demo screen that shows the algorithmic route comparison:
/// fastest route vs cleanest route, evaluated with real Delhi station data.
class RouteCompareScreen extends StatefulWidget {
  const RouteCompareScreen({super.key});

  @override
  State<RouteCompareScreen> createState() => _RouteCompareScreenState();
}

class _RouteCompareScreenState extends State<RouteCompareScreen> {
  // Sample Delhi monitoring stations with realistic PM2.5 values.
  // These coordinates are approximate locations of real stations.
  final List<Map<String, dynamic>> _stations = [
    {'name': 'DTU', 'lat': 28.7500, 'lon': 77.1167, 'pm25': 180.0},
    {'name': 'ITO', 'lat': 28.6289, 'lon': 77.2410, 'pm25': 220.0},
    {'name': 'Mandir Marg', 'lat': 28.6364, 'lon': 77.2010, 'pm25': 195.0},
    {'name': 'RK Puram', 'lat': 28.5667, 'lon': 77.1833, 'pm25': 165.0},
    {'name': 'Punjabi Bagh', 'lat': 28.6667, 'lon': 77.1333, 'pm25': 210.0},
    {'name': 'Anand Vihar', 'lat': 28.6469, 'lon': 77.3160, 'pm25': 240.0},
  ];

  String _selectedProfile = 'General adult';
  static const List<String> _profiles = [
    'General adult',
    'Asthmatic',
    'Child',
    'Elderly',
    'Outdoor runner',
  ];

  RouteResult? _fastest;
  RouteResult? _cleanest;

  @override
  void initState() {
    super.initState();
    _computeRoutes();
  }

  void _computeRoutes() {
    final comparator = RouteComparator(stations: _stations);

    // Two sample routes through Delhi.
    // The "fastest" route goes straight through the polluted center.
    // The "cleanest" route detours through cleaner areas to the south.
    final fastestSegments = _buildFastestRoute();
    final cleanestSegments = _buildCleanestRoute();

    final breathingRate = _getBreathingRate(_selectedProfile);

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
    });
  }

  double _getBreathingRate(String profile) {
    // Mirrors IntakeCalculator.getBreathingRate without importing it
    // (keeps this screen self-contained).
    switch (profile) {
      case 'Asthmatic':
        return 7.5 * 1.2;
      case 'Child':
        return 7.5 * 1.1;
      case 'Elderly':
        return 7.5 * 0.9;
      case 'Outdoor runner':
        return 22.5;
      case 'General adult':
      default:
        return 7.5;
    }
  }

  /// Fastest route: goes directly through central Delhi (high pollution).
  List<Map<String, double>> _buildFastestRoute() {
    return [
      {'lat': 28.7500, 'lon': 77.1167, 'duration': 5.0, 'distance': 2.0}, // DTU
      {'lat': 28.6900, 'lon': 77.1500, 'duration': 8.0, 'distance': 4.5}, // North Delhi
      {'lat': 28.6667, 'lon': 77.1333, 'duration': 6.0, 'distance': 3.0}, // Punjabi Bagh
      {'lat': 28.6364, 'lon': 77.2010, 'duration': 12.0, 'distance': 6.0}, // Mandir Marg
      {'lat': 28.6289, 'lon': 77.2410, 'duration': 10.0, 'distance': 5.0}, // ITO
      {'lat': 28.6000, 'lon': 77.2800, 'duration': 7.0, 'distance': 3.5}, // East Delhi
    ];
  }

  /// Cleanest route: longer detour through southern Delhi (lower pollution).
  List<Map<String, double>> _buildCleanestRoute() {
    return [
      {'lat': 28.7500, 'lon': 77.1167, 'duration': 5.0, 'distance': 2.0}, // DTU
      {'lat': 28.6900, 'lon': 77.1300, 'duration': 10.0, 'distance': 5.0}, // Detour west
      {'lat': 28.6200, 'lon': 77.1200, 'duration': 12.0, 'distance': 6.0}, // West Delhi
      {'lat': 28.5667, 'lon': 77.1833, 'duration': 9.0, 'distance': 4.5}, // RK Puram (cleaner)
      {'lat': 28.5900, 'lon': 77.2400, 'duration': 8.0, 'distance': 4.0}, // South Delhi
      {'lat': 28.6000, 'lon': 77.2800, 'duration': 5.0, 'distance': 2.5}, // East Delhi
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Comparison'),
        centerTitle: true,
      ),
      body: _fastest == null || _cleanest == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileSelector(theme),
                const SizedBox(height: 16),
                _buildComparisonBanner(theme),
                const SizedBox(height: 16),
                const AqiMap(),
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

  Widget _buildProfileSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Your profile', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _profiles.map((profile) {
                return ChoiceChip(
                  label: Text(profile),
                  selected: profile == _selectedProfile,
                  onSelected: (val) {
                    if (!val) return;
                    setState(() => _selectedProfile = profile);
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
    final fastest = _fastest!;
    final cleanest = _cleanest!;
    final timeDiff =
        cleanest.travelTimeMinutes - fastest.travelTimeMinutes;
    final intakeDiff = fastest.totalIntakeUg - cleanest.totalIntakeUg;
    final percentReduction = fastest.totalIntakeUg > 0
        ? (intakeDiff / fastest.totalIntakeUg * 100)
        : 0.0;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights,
                    color: theme.colorScheme.onPrimaryContainer),
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
              'The clean route takes ${timeDiff.toStringAsFixed(1)} more minutes '
              'but cuts PM2.5 intake by ${percentReduction.toStringAsFixed(0)}%.',
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
                Text('How this works',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _bullet(theme,
                'PM2.5 at each point is estimated using Inverse Distance Weighting from 6 Delhi stations.'),
            _bullet(theme,
                'Intake = concentration × time × breathing rate, converted to cigarette equivalents.'),
            _bullet(theme,
                'The fastest route minimizes time. The cleanest route minimizes PM2.5 intake.'),
            _bullet(theme,
                'Change your profile to see how breathing rate affects the trade-off.'),
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
            child: Icon(Icons.circle,
                size: 6, color: theme.colorScheme.primary),
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
