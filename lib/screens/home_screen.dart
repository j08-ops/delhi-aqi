import 'package:flutter/material.dart';
import '../models/aqi_data.dart';
import '../services/aqi_service.dart';
import '../services/ai_advisor_service.dart';
import '../widgets/aqi_display.dart';
import '../widgets/pollutant_grid.dart';
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

  String _selectedProfile = 'General adult';

  static const List<String> _profiles = [
    'General adult',
    'Asthmatic',
    'Child',
    'Elderly',
    'Outdoor runner',
  ];

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
      final data = await _aqiService.fetchByStationId('@9290');
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
             tooltip: 'Route Comparision',
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        AqiDisplay(data: data),
        const SizedBox(height: 24),
        _buildProfileSelector(theme),
        const SizedBox(height: 12),
        _buildAiAdviceCard(theme),
        const SizedBox(height: 24),
        PollutantGrid(data: data),
        const SizedBox(height: 24),
        _buildTimestamp(theme, data),
      ],
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
                Text('Your profile',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _profiles.map((profile) {
                final selected = profile == _selectedProfile;
                return ChoiceChip(
                  label: Text(profile),
                  selected: selected,
                  onSelected: (val) {
                    if (!val) return;
                    setState(() => _selectedProfile = profile);
                    _fetchAiAdvice();
                  },
                );
              }).toList(),
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
                Icon(Icons.auto_awesome,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('AI Health Advisor',
                    style: theme.textTheme.titleMedium),
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