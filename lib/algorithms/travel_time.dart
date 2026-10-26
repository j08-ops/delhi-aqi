import 'dart:math';

/// Bureau of Public Roads (BPR) function for travel time estimation.
///
/// The BPR function models how travel time increases as traffic volume
/// approaches road capacity. It's the standard formula used in transportation
/// planning and traffic assignment models.
class TravelTime {
  /// Compute travel time on a road segment using the BPR function.
  ///
  /// [freeFlowTime] is the time at free-flow speed (same unit as output).
  /// [volume] is the current traffic volume (vehicles/hour).
  /// [capacity] is the road capacity (vehicles/hour).
  /// [alpha] and [beta] are the BPR coefficients (default 0.15 and 4.0).
  ///
  /// Formula: t = t0 * (1 + alpha * (v/c)^beta)
  static double bpr({
    required double freeFlowTime,
    required double volume,
    required double capacity,
    double alpha = 0.15,
    double beta = 4.0,
  }) {
    if (capacity <= 0) return freeFlowTime * 10; // Avoid division by zero
    final ratio = volume / capacity;
    return freeFlowTime * (1 + alpha * pow(ratio, beta));
  }

  /// BPR with intersection delay for urban roads.
  ///
  /// Adds uniform delay (from signal timing) and incremental delay
  /// (from oversaturation) on top of the base BPR travel time.
  static double bprWithIntersectionDelay({
    required double freeFlowTime,
    required double volume,
    required double capacity,
    required double greenRatio,
    required double cycleLength,
  }) {
    final baseTime = bpr(
      freeFlowTime: freeFlowTime,
      volume: volume,
      capacity: capacity,
    );

    final vcRatio = volume / capacity;

    // Uniform delay (seconds)
    final uniformDelay = _max(
      0.0,
      5.96 * vcRatio -
          0.234 * cycleLength * greenRatio +
          0.21 * cycleLength -
          4.47,
    );

    // Incremental delay (seconds)
    final incrementalDelay = _max(
      0.0,
      2.65 * pow(vcRatio, 8) - 7.3 * greenRatio + 0.338,
    );

    // Convert delay from seconds to same unit as baseTime (assumed minutes)
    final delayMinutes = (uniformDelay + incrementalDelay) / 60.0;
    return baseTime + delayMinutes;
  }

  static double _max(double a, double b) => a > b ? a : b;
}