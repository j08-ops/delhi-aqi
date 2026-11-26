import 'package:flutter/material.dart';
import '../models/aqi_data.dart';
import '../models/delhi_station.dart';
import '../services/ai_advisor_service.dart';
import '../services/aqi_service.dart';
import '../widgets/aqi_display.dart';
import '../widgets/pollutant_grid.dart';
import '../widgets/profile_selector.dart';
import 'route_compare_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _aqiService = AqiService();
  final _aiService = AiAdvisorService();

  AqiData? _data;
  String? _error;
  bool _loading = true;

  String _aiAdvice = '';
  bool _aiLoading = false;

  String _selectedProfile = userProfiles.first;
  String _selectedStationId = DelhiStation.defaults.first.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _aiAdvice = '';
    });

    try {
      final AqiData data;
      if (_selectedStationId == 'city') {
        data = await _aqiService.fetchDelhiCity();
      } else {
        final station = DelhiStation.defaults.firstWhere(
          (s) => s.id == _selectedStationId,
          orElse: () => DelhiStation.defaults.first,
        );
        data = station.waqiId != null
            ? await _aqiService.fetchByStationId(station.waqiId!)
            : await _aqiService.fetchByCoordinates(station.lat, station.lon);
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _fetchAiAdvice();
    } on AqiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _fetchAiAdvice() async {
    if (_data == null) return;
    setState(() {
      _aiLoading = true;
      _aiAdvice = '';
    });

    final advice = await _aiService.getHealthAdvice(
      data: _data!,
      userProfile: _selectedProfile,
    );

    if (!mounted) return;
    setState(() {
      _aiAdvice = advice;
      _aiLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delhi AQI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route),
            tooltip: 'Route Comparison',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RouteCompareScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildStationSelector(theme),
          const SizedBox(height: 32),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RouteCompareScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.alt_route),
                label: const Text('Open Route Comparison'),
              ),
            ],
          ),
        ],
      );
    }

    final data = _data!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildStationSelector(theme),
        const SizedBox(height: 16),
        AqiDisplay(data: data),
        const SizedBox(height: 24),
        ProfileSelector(
          selectedProfile: _selectedProfile,
          onSelected: (profile) {
            setState(() => _selectedProfile = profile);
            _fetchAiAdvice();
          },
        ),
        const SizedBox(height: 12),
        _buildAiAdviceCard(theme),
        const SizedBox(height: 24),
        PollutantGrid(data: data),
        const SizedBox(height: 24),
        _buildTimestamp(theme, data),
      ],
    );
  }

  Widget _buildStationSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Monitoring station', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...DelhiStation.defaults.map((station) {
                  return ChoiceChip(
                    label: Text(station.name),
                    selected: _selectedStationId == station.id,
                    onSelected: (val) {
                      if (!val || _selectedStationId == station.id) return;
                      setState(() => _selectedStationId = station.id);
                      _loadData();
                    },
                  );
                }),
                ChoiceChip(
                  label: const Text('Delhi City'),
                  selected: _selectedStationId == 'city',
                  onSelected: (val) {
                    if (!val || _selectedStationId == 'city') return;
                    setState(() => _selectedStationId = 'city');
                    _loadData();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAdviceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('AI Health Advisor', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (_aiLoading)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Generating personalized advice...'),
                ],
              )
            else if (_aiAdvice.isNotEmpty)
              Text(_aiAdvice, style: theme.textTheme.bodyMedium)
            else
              Text(
                'No advice yet. Pull down to refresh.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(ThemeData theme, AqiData data) {
    final ts = data.timestamp;
    return Center(
      child: Text(
        ts != null
            ? 'Last updated: ${ts.hour.toString().padLeft(2, '0')}:'
                '${ts.minute.toString().padLeft(2, '0')} IST'
            : 'Data from WAQI network',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
