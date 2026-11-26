import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/delhi_station.dart';
import '../utils/aqi_colors.dart';

class AqiMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String label;
  final List<DelhiStation> stations;
  final List<LatLng> fastestRoute;
  final List<LatLng> cleanestRoute;
  final LatLng? originPoint;
  final LatLng? destinationPoint;
  final ValueChanged<LatLng>? onMapTap;

  const AqiMap({
    super.key,
    this.latitude = 28.6448,
    this.longitude = 77.2167,
    this.label = 'Delhi',
    this.stations = const [],
    this.fastestRoute = const [],
    this.cleanestRoute = const [],
    this.originPoint,
    this.destinationPoint,
    this.onMapTap,
  });

  @override
  State<AqiMap> createState() => _AqiMapState();
}

class _AqiMapState extends State<AqiMap> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRoute());
  }

  @override
  void didUpdateWidget(covariant AqiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = oldWidget.originPoint != widget.originPoint ||
        oldWidget.destinationPoint != widget.destinationPoint ||
        oldWidget.fastestRoute.length != widget.fastestRoute.length ||
        oldWidget.cleanestRoute.length != widget.cleanestRoute.length ||
        (widget.fastestRoute.isNotEmpty &&
            oldWidget.fastestRoute.isNotEmpty &&
            oldWidget.fastestRoute.first != widget.fastestRoute.first);

    if (routeChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRoute());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitToRoute() {
    if (!mounted) return;
    final focusPoints = <LatLng>[
      ...widget.fastestRoute,
      ...widget.cleanestRoute,
      if (widget.originPoint != null) widget.originPoint!,
      if (widget.destinationPoint != null) widget.destinationPoint!,
    ];

    if (focusPoints.isEmpty) return;

    if (focusPoints.length == 1) {
      _mapController.move(focusPoints.first, 12.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(focusPoints);
    if (bounds.southWest == bounds.northEast) {
      _mapController.move(focusPoints.first, 12.5);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(42),
        maxZoom: 15.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>[
      if (widget.fastestRoute.length >= 2)
        Polyline(
          points: widget.fastestRoute,
          color: Colors.blue,
          strokeWidth: 4.5,
        ),
      if (widget.cleanestRoute.length >= 2)
        Polyline(
          points: widget.cleanestRoute,
          color: Colors.green,
          strokeWidth: 4.5,
        ),
    ];

    final markers = <Marker>[
      if (widget.stations.isNotEmpty)
        ...widget.stations.map(_buildStationMarker)
      else if (widget.originPoint == null && widget.destinationPoint == null)
        Marker(
          point: LatLng(widget.latitude, widget.longitude),
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      if (widget.originPoint != null)
        _buildEndpointMarker(widget.originPoint!, 'A', Colors.green.shade700),
      if (widget.destinationPoint != null)
        _buildEndpointMarker(
          widget.destinationPoint!,
          'B',
          Colors.red.shade700,
        ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(widget.latitude, widget.longitude),
                initialZoom: 11.0,
                onTap: widget.onMapTap == null
                    ? null
                    : (_, point) => widget.onMapTap!(point),
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
            if (polylines.isNotEmpty || widget.stations.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _buildLegend(context, polylines.isNotEmpty),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _buildEndpointMarker(LatLng point, String letter, Color color) {
    return Marker(
      point: point,
      width: 34,
      height: 34,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
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
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          if (showRoutes) ...[
            _legendItem(Colors.blue, 'Fastest'),
            _legendItem(Colors.green, 'Cleanest'),
          ],
          _legendItem(Colors.orange, 'Station PM2.5'),
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
