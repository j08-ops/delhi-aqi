/// Calculates PM2.5 intake along a route.
///
/// The core idea: being on a polluted road for a few minutes matters less
/// than being there for an hour. And a runner inhales far more air than
/// someone sitting still. This class combines concentration, time, and
/// breathing rate into a single "intake" number.
class IntakeCalculator {
  /// Breathing rates in liters per minute (L/min).
  /// Values are based on standard exposure-assessment literature.
  static const double restingBreathingRate = 7.5;   // Sitting, light activity
  static const double moderateExerciseRate = 22.5;  // Walking, slow jog
  static const double heavyExerciseRate = 55.0;     // Running, cycling hard

  /// Compute PM2.5 intake for a route segment.
  ///
  /// [pm25Concentration] in µg/m³
  /// [durationMinutes] time spent on this segment
  /// [breathingRate] in L/min, based on user activity
  ///
  /// Returns intake in micrograms (µg).
  ///
  /// Formula:
  ///   intake (µg) = concentration (µg/m³)
  ///               × breathingRate (L/min)
  ///               × duration (min)
  ///               / 1000 (to convert L to m³)
  static double calculateIntake({
    required double pm25Concentration,
    required double durationMinutes,
    double breathingRate = restingBreathingRate,
  }) {
    return pm25Concentration * breathingRate * durationMinutes / 1000.0;
  }

  /// Convert total PM2.5 intake into a cigarette equivalent.
  ///
  /// Common reference: 22 µg/m³ PM2.5 over a full day (1440 min) ≈ 1 cigarette.
  /// This is a widely cited public-health conversion.
  static double cigaretteEquivalent(double totalIntakeUg) {
    const dailyExposureBaseline = 22.0 * 1440.0 / 1000.0; // ≈ 31.68 µg
    return totalIntakeUg / dailyExposureBaseline;
  }

  /// Breathing rate for a specific user profile.
  /// Asthmatics and children breathe slightly faster;
  /// elderly users breathe slightly slower;
  /// outdoor runners breathe much faster.
  static double getBreathingRate(String profile) {
    switch (profile) {
      case 'Asthmatic':
        return restingBreathingRate * 1.2;
      case 'Child':
        return restingBreathingRate * 1.1;
      case 'Elderly':
        return restingBreathingRate * 0.9;
      case 'Outdoor runner':
        return moderateExerciseRate;
      case 'General adult':
      default:
        return restingBreathingRate;
    }
  }
}