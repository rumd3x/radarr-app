# Architecture

```
lib/
  main.dart                 App entry, theme, routes Setup vs Home based on AppState
  services/
    settings.dart           ServerConfig + SettingsStore (shared_preferences)
    demo_client.dart        DemoServer: in-memory fake Radarr (MockClient) behind "Try demo"; ServerConfig.demo selects it
    api.dart                RadarrApi: HTTP client, failover, version detection, endpoints
    app_state.dart          AppState (ChangeNotifier via provider): config, api, movie cache, manual searches, queue count (badge)
  screens/                  One file per screen (see FEATURES.md); movie_detail_screen embeds ManualSearchView; activity_screen opens manual_import_screen; home_screen polls the queue count; wanted_screen has Missing/Cutoff tabs
  widgets/common.dart       Shared widgets and formatting helpers (Poster, AsyncBody, ManualSearchButton, openMovie…)
test/api_test.dart          URL normalization, failover, 401 handling, demo mode, commands, wanted/queue requests (MockClient)
```

- Data is handled as `Json` (`Map<String, dynamic>`) — no generated models. Updates send back the full object received from Radarr, changing only the needed fields.
- State: `provider` for `AppState`; screens own their local state / `AsyncBody` futures. Long-running work (manual search, keyed by movie id) lives in `AppState` so it survives navigation.
- Queue badge: `HomeScreen` (bottom nav) polls `AppState.refreshQueueCount()` every 30 s while foregrounded (`WidgetsBindingObserver`) and the queue tab refreshes it after each load; polling pauses only on `paused` and restarts on `resumed`. `AsyncBodyState.reload(silent: true)` refreshes without a spinner.
- Calendar: `GET /calendar` returns movies; the screen shows a movie once per release date (cinema / digital / physical) inside the window.
- Wanted: `GET /wanted/missing|cutoff` return movie records directly (no embedded movie); sorted client-side by `sortTitle`.
- Demo mode: `RadarrApi` builds its HTTP client from `DemoServer().client()` (an `http/testing.dart` `MockClient`) when `config.isDemo`. `DemoServer` implements the same paths as Radarr with mutable in-memory state. Dates are relative to now, so the calendar is never empty. Posters are generated gradients.
- Dependencies: `http`, `shared_preferences`, `provider`, `cached_network_image`, `intl`.

## Commands
```
flutter pub get
flutter analyze
flutter test
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug
```

## Run on the emulator
```bash
# AVD radarr_pixel only; if Gradle fails with "problem starting process flutter": (cd android && ./gradlew --stop)
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter run -d emulator-5554 --debug --no-resident
```

## CI/CD
Same central `release.groovy` pipeline (`jenkins-app-release` repo) and signing setup as `sonarr-app`/`lidarr-app`; see PLAYBOOK.md. Store listing texts live in `android/app/src/main/play/listings/en-US/`.
