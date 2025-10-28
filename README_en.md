# Trace Map

Trace Map is a Flutter application that periodically captures device locations, stores them locally, and visualises the collected trajectory on a map. It supports an offline-friendly OpenStreetMap view and an embedded Tencent Map view with incremental updates.

## Feature Highlights

- **Location sampling** – Uses `geolocator` to request permissions at runtime, collect positions on a schedule, and record accuracy, altitude, heading, speed, and more.
- **Local persistence** – Persists samples and map logs in SQLite (`sqflite`), with automatic retention policies and manual cleanup.
- **Map rendering**
  - OpenStreetMap via `flutter_map`.
  - Tencent Map inside a WebView with a custom JS bridge that avoids flicker and streams logs back to Flutter.
  - Automatic conversion from WGS‑84 to GCJ‑02 ensures consistent positioning on Tencent Map.
- **Logging and export** – All map logs are kept in the database and can be viewed or exported from the app.

## UI Overview

```text
┌───────────────────────────── Trace Map ─────────────────────────────┐
│ ┌──────────────┐  ┌──────────────────────┐  ┌────────────────────┐ │
│ │ Device Page  │  │ Map Page             │  │ Settings Page       │ │
│ │ • Sampling    │  │ • OpenStreetMap view │  │ • Interval & retention││
│ │   status card │  │ • Tencent Map WebView│  │ • Map provider switch ││
│ │ • Device info │  │ • Log viewer/export  │  │ • Tencent key input   ││
│ └──────────────┘  └──────────────────────┘  └────────────────────┘ │
│               ───── Bottom navigation (Device | Map | Settings) ──── │
└────────────────────────────────────────────────────────────────────┘
```

## Architecture

```text
┌──────────────┐     ┌──────────────────┐     ┌────────────────────────┐
│Sensors / OS  │ --> │ geolocator plugin │ --> │ AppState (scheduler &  │
└──────────────┘     └──────────────────┘     │ change notifications)  │
                                               └────────────┬──────────┘
                                                            │
                                                            ▼
        ┌────────────────────────┐             ┌────────────────────────┐
        │ TrackRepository (SQLite)│<---------->│ SettingsStore (Shared   │
        │ • samples table         │             │ Preferences)            │
        │ • map_logs table        │             └────────────────────────┘
        │ • settings table (key)  │
        └────────────┬───────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │ UI layer (Flutter)      │
        │ • Device / Map / Config │
        │ • WebView bridge        │
        │ • Log viewer & export   │
        └────────────────────────┘
```

## Development Environment

| Component   | Requirement                                          |
| ----------- | ---------------------------------------------------- |
| Flutter     | 3.35.7 (Dart 3.9.2) or newer                         |
| Android SDK | Platform 33+, build-tools 35.x                       |
| Java        | JDK 17 (e.g. `brew install openjdk@17`)              |

> On macOS, export `JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"` before building Android artifacts.

## Project Layout

- `lib/core` – application state, models, repositories, utilities.
- `lib/ui` – pages and widgets (device info, map, settings, log viewer).
- `lib/core/utils/coordinate_transform.dart` – WGS‑84 ↔ GCJ‑02 conversion used by Tencent Map.
- `third_party/amap_flutter_*` – Gaode map plugin sources (parked for future use).

## Getting Started

```bash
flutter pub get

# Run in debug
flutter run

# Build Android release with tree-shaken Material Icons
JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home" \
PATH="$JAVA_HOME/bin:$PATH" \
flutter build apk
```

Artifacts are generated under `build/app/outputs/flutter-apk/app-release.apk`.

## Sampling Lifecycle

During startup the app:

1. Loads sampling interval, retention days, and map provider from `SharedPreferences`.
2. Opens the SQLite database and reads historical samples and map logs.
3. Performs an immediate location capture and then schedules periodic sampling (default 30 seconds).

Users can adjust the interval (3–3600 seconds) and retention (1–30 days) on the Settings page.

## Map Rendering Notes

- **OpenStreetMap** – renders raw WGS‑84 coordinates.
- **Tencent Map**
  - WebView loads the Tencent JS SDK; once initialised it only receives incremental point updates.
  - Each sample is projected to GCJ‑02 before it is sent to the JS layer.
  - The JS page streams structured logs back via `LogChannel`; these appear in the in-app Map Log list.
  - The Tencent Map key can be configured at any time from the Settings page and is stored securely in the local database.

## Database Schema

SQLite database `device_track.sqlite` contains:

- `samples` – trajectory points with timestamp, coordinates, accuracy, speed, heading, etc.
- `map_logs` – log entries produced by the WebView bridge and Flutter.
- `settings` – key/value store (currently used for the Tencent Map key).

## Tests

Run all widget tests with:

```bash
flutter test
```

## Troubleshooting

- **Tencent Map fails to load** – verify network access, ensure the key is valid, and review map logs for authentication errors.
- **Large position offsets** – confirm the device is in mainland China; Tencent Map uses GCJ‑02 while OpenStreetMap uses WGS‑84.
- **Android build complains about Java** – install JDK 17 and export the correct `JAVA_HOME`.

## License

No explicit license is provided. All rights reserved. Add an appropriate license file before publishing externally.
