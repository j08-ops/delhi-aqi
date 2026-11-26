# Delhi AQI

A Flutter application for monitoring real-time Delhi Air Quality Index (AQI), generating personalized health guidance, and comparing **fastest vs. cleanest** commute routes using spatial PM2.5 interpolation, BPR traffic modeling, and inhalation intake calculations.

## Features

- **Live Delhi Station AQI**: Switch between Delhi monitoring stations (DTU, ITO, Mandir Marg, RK Puram, Punjabi Bagh, Anand Vihar) or Delhi City overall via the WAQI API.
- **Personalized Health Advisor**: Profile-aware advice (`General adult`, `Asthmatic`, `Child`, `Elderly`, `Outdoor runner`) powered by Gemini with automatic deterministic fallback when offline or unconfigured.
- **Fastest vs. Cleanest Route Comparison**:
  - Spatial PM2.5 estimation via Inverse Distance Weighting (`lib/algorithms/aqi_interpolation.dart`).
  - Traffic-adjusted segment travel times via the Bureau of Public Roads (BPR) model (`lib/algorithms/travel_time.dart`).
  - Profile-adjusted PM2.5 inhalation intake and cigarette equivalents (`lib/algorithms/intake_calculator.dart`).
  - Interactive OpenStreetMap view (`lib/widgets/aqi_map.dart`) displaying stations and route polylines.

## Setup & Running Locally

### 1. Prerequisites
- Flutter SDK (`>= 3.0.0`)

### 2. Configure API Keys Safely
This repository never stores API keys in source control. Secrets are passed at build/run time via `--dart-define` or `--dart-define-from-file`.

1. Copy the template config:
   ```bash
   cp .env.example.json .env.json
   ```
2. Fill in your keys in `.env.json` (which is gitignored):
   - **WAQI Token**: register free at https://aqicn.org/api/register
   - **Gemini API Key** (optional): generate at https://aistudio.google.com/apikey
3. Run the app:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=.env.json
   ```

> **Note:** The app compiles and runs without `.env.json` too—`Route Comparison` falls back to baseline Delhi station readings and `AiAdvisorService` falls back to rule-based AQI health advice.

## Testing

```bash
flutter analyze
flutter test
```

## Security Notes

See [SECURITY.md](SECURITY.md) for guidelines on API key handling, key restrictions, and production backend-proxy recommendations before publishing compiled builds.
