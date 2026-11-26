# delhi_aqi

An application I created as a side project for a hackathon working on top of an existing webpage I had created as 
a placeholder for an application I have previously been planning to build.

The primary purpose behind me working on this thing is to develop skills as a first year student, in order to use those skills on future projects.

## What it does

- Shows live AQI and pollutant concentrations for Delhi monitoring stations (DTU, ITO, Mandir Marg, RK Puram, Punjabi Bagh, Anand Vihar) via the WAQI API.
- Gives short health advice based on your profile (adult, asthmatic, child, elderly, outdoor runner) using Gemini, or falls back to basic AQI rules offline.
- Compares fastest vs. cleanest routes between any two places using OpenStreetMap search and OSRM routing, IDW PM2.5 interpolation, BPR traffic delay, and estimated PM2.5 intake.

## Running locally

```bash
flutter pub get
flutter run
```

## Checks

```bash
flutter analyze --no-fatal-infos
flutter test
```
