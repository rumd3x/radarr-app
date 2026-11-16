# Features

Navigation: bottom bar with **Movies · Calendar · Activity · Wanted · More**. The Activity item shows a badge with the number of queue items (hidden when 0); refreshed every 30 s in the foreground, on resume and whenever the queue loads (`GET /queue/status` → `totalCount`).

## Setup / Connection (`setup_screen.dart`)
- Radarr logo header, primary URL, secondary URL (fallback), API key (hidden, toggle visibility). URLs are normalized and validated.
- **Try demo** button: runs the whole app against the built-in fake Radarr (`services/demo_client.dart`). No network or credentials; edits stay in memory. "Disconnect & clear data" leaves demo mode.
- Connection test (`GET /system/status`) before saving. Reused (editing mode) from More → Connection settings.

## Movies (`movies_screen.dart`)
- Library as poster grid or list; status bar per movie (green = downloaded, red = monitored but missing, grey = unmonitored).
- Text filter, filter menu (All / Monitored / Unmonitored / Downloaded / Missing), pull-to-refresh. Cache-first: cached list shows instantly, then refreshes.
- `GET /movie`

## Movie detail (`movie_detail_screen.dart`)
Three tabs; the app-bar menu has **Refresh & scan** and **Delete movie** (optionally with files / import exclusion).
- **Details:** poster, chips (year, runtime, certification, status, rating), genres, studio, overview, cinema/digital/physical dates, monitor toggle, auto search, file card (name, quality, size, release group, languages, video/audio/subtitle info, date added) with delete file, path.
- **History:** grab/import/failure/delete/rename events with release title, quality, indexer and download client.
- **Search:** manual search (below), embedded as `ManualSearchView`.
- `GET/PUT/DELETE /movie/{id}`, `DELETE /moviefile/{id}`, `GET /history/movie?movieId=`, `POST /command` (`MoviesSearch`, `RefreshMovie`)

## Add movie (`add_movie_screen.dart`)
- Lookup by title, `tmdb:ID` or `imdb:ttID`; already-added results are marked.
- Bottom sheet: root folder, quality profile, monitor (movie only / movie and collection / none), minimum availability, start search on add.
- `GET /movie/lookup`, `GET /rootfolder`, `GET /qualityprofile`, `POST /movie`

## Manual search (`manual_search_screen.dart`)
- Starts only when the user taps "Search indexers". Lists releases with quality, size, age, indexer, seeders/leechers or usenet, languages, custom-format score and rejection reasons. Rejected releases are hidden by default (toggle); grabbing one asks for confirmation.
- Runs in `AppState` (survives leaving the screen); 5 min timeout. The search icon on Wanted shows a spinner/badge.
- `GET /release?movieId=`, `POST /release`

## Calendar (`calendar_screen.dart`)
- Month grid (Sunday-first, swipe or arrows, ±12 months, Today button); days with releases are highlighted and the selected day lists its movies, one entry per cinema / digital / physical release date. One `GET /calendar?unmonitored=false` call covers the whole ±12-month range. Ported from lidarr-app.

## Activity (`activity_screen.dart`)
- **Queue** (auto-refresh every 10 s while visible): progress, size, time left, client; remove (optionally blocklist); **manual import** for items waiting for the user (see below). `GET /queue` (`includeMovie`, `includeUnknownMovieItems`), `DELETE /queue/{id}`.
- **History:** latest 50 events. `GET /history?includeMovie=true`.

## Manual import (`manual_import_screen.dart`)
- Mobile "Interactive Import" for a queue item: `GET /manualimport?downloadId=` (falls back to `folder=<outputPath>`), pre-fills the movie from the queue item (`movie` → `movieId` → `GET /parse`), lets you pick movie, quality and languages, shows the queue status messages per file, then `POST /command` `ManualImport` (`path`, `movieId`, `quality`, `languages`, `releaseGroup`, `downloadId`, `indexerFlags`).

## Wanted (`wanted_screen.dart`)
- **Missing** and **Cutoff unmet** tabs, with automatic search per movie, manual search, and an app-bar "search all" for the current tab (`MissingMoviesSearch` / `CutoffUnmetMoviesSearch`). `GET /wanted/missing|cutoff?monitored=true`.

## More (`more_screen.dart`)
- Server version, health checks, disk space, connection settings, disconnect & clear data, disclaimer. `GET /system/status`, `/health`, `/diskspace`.
