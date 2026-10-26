/// Result of a route comparison between fastest and cleanest options.
///
/// This model holds the aggregate metrics for a single evaluated route:
/// total travel time, total PM2.5 intake, cigarette equivalent, and distance.
class RouteResult {
  /// Total travel time in minutes.
  final double travelTimeMinutes;

  /// Total PM2.5 intake in micrograms (µg).
  final double totalIntakeUg;

  /// Cigarette equivalent of the intake (for intuitive display).
  final double cigaretteEquivalent;

  /// Total route distance in kilometers.
  final double totalDistanceKm;

  /// Label for this route: 'fastest' or 'cleanest'.
  final String routeType;

  RouteResult({
    required this.travelTimeMinutes,
    required this.totalIntakeUg,
    required this.cigaretteEquivalent,
    required this.totalDistanceKm,
    required this.routeType,
  });

  /// Build a human-readable comparison between two routes.
  ///
  /// Example output:
  ///   "Clean route takes 4.2 min longer, but reduces PM2.5 intake by 38%"
  static String compare(RouteResult fastest, RouteResult cleanest) {
    final timeDiff = cleanest.travelTimeMinutes - fastest.travelTimeMinutes;
    final intakeReduction = fastest.totalIntakeUg - cleanest.totalIntakeUg;
    final percentReduction = fastest.totalIntakeUg > 0
        ? (intakeReduction / fastest.totalIntakeUg * 100)
        : 0.0;

    final timeWord = timeDiff >= 0 ? 'longer' : 'shorter';
    final intakeWord = percentReduction >= 0 ? 'reduces' : 'increases';
    final percentAbs = percentReduction.abs().toStringAsFixed(0);

    return 'Clean route takes ${timeDiff.abs().toStringAsFixed(1)} min $timeWord, '
        'but $intakeWord PM2.5 intake by $percentAbs%';
  }
}