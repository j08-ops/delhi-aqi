import 'package:flutter/material.dart';

/// Standard US-EPA AQI color scale.
Color aqiColor(int aqi) {
  if (aqi <= 50) return const Color(0xFF00E400);
  if (aqi <= 100) return const Color(0xFFD4C000);
  if (aqi <= 150) return const Color(0xFFFF7E00);
  if (aqi <= 200) return const Color(0xFFFF0000);
  if (aqi <= 300) return const Color(0xFF8F3F97);
  return const Color(0xFF7E0023);
}

/// Color mapping for PM2.5 concentrations in µg/m³.
Color pm25Color(double pm25) {
  if (pm25 <= 12) return const Color(0xFF00E400);
  if (pm25 <= 35.4) return const Color(0xFFD4C000);
  if (pm25 <= 55.4) return const Color(0xFFFF7E00);
  if (pm25 <= 150.4) return const Color(0xFFFF0000);
  if (pm25 <= 250.4) return const Color(0xFF8F3F97);
  return const Color(0xFF7E0023);
}
