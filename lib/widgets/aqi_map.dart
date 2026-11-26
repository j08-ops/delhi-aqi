import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/delhi_station.dart';
import '../utils/aqi_colors.dart';

class AqiMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String label;
  final List<DelhiStation> stations;
  final List<LatLng> fastestRoute;
  final List<LatLng> cleanestRoute;

  const AqiMap({
    super.key,
    this.latitude = 28.6448,
    this.longitude = 77.2167,
    this.label = 'Delhi',
    this.stations = const [],
    this.fastestRoute = const [],
    this.cleanestRoute = const [],
  });

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>[
      if (fastestRoute.length >= 2)
        Polyline(
          points: fastestRoute,
          color: Colors.blue,
          strokeWidth: 4.5,
        ),
      if (cleanestRoute.length >= 2)
        Polyline(
          points: cleanestRoute,
          color: Colors.green,
          strokeWidth: 4.5,
        ),
    ];

    final markers = stations.isNotEmpty
        ? stations.map(_buildStationMarker).toList()
        : [
            Marker(
              point: LatLng(latitude, longitude),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
          ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(latitude, longitude),
                initialZoom: 11.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.delhi_aqi',
                ),
                if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
            if (polylines.isNotEmpty || stations.isNotEmpty)
              Positioned(
                left: 10,
                bottom: 10,
                child: _buildLegend(context, polylines.isNotEmpty),
              ),
          ],
        ),
      ),
    );
  }

  Marker _buildStationMarker(DelhiStation station) {
    final color = pm25Color(station.pm25);
    return Marker(
      point: LatLng(station.lat, station.lon),
      width: 96,
      height: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '${station.name} ${station.pm25.round()}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(Icons.location_on, color: color, size: 18),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, bool showRoutes) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showRoutes) ...[
            _legendItem(Colors.blue, 'Fastest'),
            const SizedBox(width: 10),
            _legendItem(Colors.green, 'Cleanest'),
            const SizedBox(width: 10),
          ],
          _legendItem(Colors.red, 'Station PM2.5'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
