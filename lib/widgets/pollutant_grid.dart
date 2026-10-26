import 'package:flutter/material.dart';
import '../models/aqi_data.dart';

class PollutantGrid extends StatelessWidget {
  final AqiData data;

  const PollutantGrid({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = <_PollutantItem>[
      if (data.pm25 != null)
        _PollutantItem('PM2.5', data.pm25!, 'µg/m³', _pm25Color(data.pm25!)),
      if (data.pm10 != null)
        _PollutantItem('PM10', data.pm10!, 'µg/m³', _pm10Color(data.pm10!)),
      if (data.no2 != null)
        _PollutantItem(
            'NO₂', data.no2!, 'µg/m³', _genericColor(data.no2!, 40, 80)),
      if (data.so2 != null)
        _PollutantItem(
            'SO₂', data.so2!, 'µg/m³', _genericColor(data.so2!, 40, 80)),
      if (data.co != null)
        _PollutantItem(
            'CO', data.co!, 'mg/m³', _genericColor(data.co!, 4, 10)),
      if (data.o3 != null)
        _PollutantItem(
            'O₃', data.o3!, 'µg/m³', _genericColor(data.o3!, 100, 160)),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pollutant Concentrations',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _PollutantCard(item: items[i]),
        ),
      ],
    );
  }

  Color _pm25Color(double v) {
    if (v <= 12) return const Color(0xFF00E400);
    if (v <= 35) return const Color(0xFFFFFF00);
    if (v <= 55) return const Color(0xFFFF7E00);
    return const Color(0xFFFF0000);
  }

  Color _pm10Color(double v) {
    if (v <= 54) return const Color(0xFF00E400);
    if (v <= 154) return const Color(0xFFFFFF00);
    if (v <= 254) return const Color(0xFFFF7E00);
    return const Color(0xFFFF0000);
  }

  Color _genericColor(double v, double warn, double danger) {
    if (v <= warn) return const Color(0xFF00E400);
    if (v <= danger) return const Color(0xFFFF7E00);
    return const Color(0xFFFF0000);
  }
}

class _PollutantItem {
  final String name;
  final double value;
  final String unit;
  final Color color;
  _PollutantItem(this.name, this.value, this.unit, this.color);
}

class _PollutantCard extends StatelessWidget {
  final _PollutantItem item;

  const _PollutantCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  item.value.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(item.unit,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}