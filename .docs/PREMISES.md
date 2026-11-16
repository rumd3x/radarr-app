# Premises

- **Name:** Radarr (unofficial). Flutter, Android only (`com.rumd3x.radarr`). Sibling of `sonarr-app` and `lidarr-app`; same architecture, with movies instead of series/episodes.
- **Goal:** let Radarr administrators manage their own Radarr instance from a phone, with an elegant mobile UI.
- **No accounts:** no login, no registration, no backend of our own, no database.
- **Local storage only:** `shared_preferences` holds the connection settings and a small cache of the movie list. Nothing else is persisted (demo mode only stores the demo config marker). "Disconnect" wipes it all.
- **Privacy policy:** `PRIVACY_POLICY.txt` (repo root) states the app collects nothing and sends data only to the user's own server. Any change to stored data, network targets, permissions or third-party SDKs must update it (and its "Last updated" date) in the same change.
- **First launch:** the app must ask for **primary URL**, **secondary URL** (optional fallback) and the **Radarr API key**. The connection is verified (`GET /system/status`) before saving. A **Try demo** button skips this and uses built-in sample data (see Demo mode).
- **Demo mode:** the Setup screen has a **Try demo** button that stores `ServerConfig.demo` (URL `http://demo.radarr.local`) and serves every request from an in-memory fake server (`lib/services/demo_client.dart`). It exists because Google Play reviewers need a way into an app that otherwise requires a self-hosted server. It must keep working with every screen/endpoint the app uses; when you add an API call, add it to `DemoServer`. No data leaves the device in demo mode.
- **URL failover:** every request tries the last working URL first, then the other one. Only network failures trigger failover; HTTP errors (e.g. 401) do not.
- **Auth:** API key sent as `X-Api-Key` header; image URLs served by Radarr use the `apikey` query parameter.
- **API version:** Radarr exposes `/api/v3`. The version is still detected at runtime via `GET /api` (`current` field), defaulting to `v3`. API reference: https://radarr.video/docs/api/ · OpenAPI: https://raw.githubusercontent.com/Radarr/Radarr/develop/src/Radarr.Api.V3/openapi.json. **Check the spec before adding or changing an endpoint** (e.g. wanted endpoints have no `include*` flags and return movies directly).
- **Cleartext HTTP is allowed** (`usesCleartextTraffic`), because Radarr is commonly reached over LAN.
- **Theme:** Material 3, dark by default, seed colour `#FFC230` (Radarr yellow).
- **Not affiliated** with the Radarr project; the app says so in the More screen.
- **Branding:** the official Radarr logo (open-source Radarr repo, `Logo/1024.png`) is used for the launcher icon, setup screen, More screen and README. Sources live in `assets/branding/` (`logo.png` 512px, `logo.svg`, `logo_foreground.png` = logo padded to 66% for the adaptive icon; adaptive background `#EDEDED`). Regenerate launcher icons with `dart run flutter_launcher_icons`.
- **Tooling note:** Gradle fails on JDK 25; build with JDK 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`).
