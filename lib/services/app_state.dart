import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'settings.dart';

enum ManualSearchStatus { running, done, failed }

/// A manual (interactive) release search that runs in the background, so the
/// user can leave the screen and come back to the results later.
class ManualSearch {
  final int key;
  final String label;
  ManualSearchStatus status = ManualSearchStatus.running;
  List<Json> releases = [];
  Object? error;
  ManualSearch(this.key, this.label);
}

class AppState extends ChangeNotifier {
  /// Keyed by movie id.
  final Map<int, ManualSearch> manualSearches = {};

  /// Starts (or returns the existing) manual search for a movie.
  ManualSearch manualSearch(int movieId, String label, {bool restart = false}) {
    final existing = manualSearches[movieId];
    if (existing != null &&
        !restart &&
        existing.status != ManualSearchStatus.failed) {
      return existing;
    }
    final search = ManualSearch(movieId, label);
    manualSearches[movieId] = search;
    api!
        .releases(movieId)
        .then((r) {
          search.releases = r;
          search.status = ManualSearchStatus.done;
        })
        .catchError((Object e) {
          search.error = e;
          search.status = ManualSearchStatus.failed;
        })
        .whenComplete(notifyListeners);
    notifyListeners();
    return search;
  }

  void clearManualSearch(int movieId) {
    manualSearches.remove(movieId);
    notifyListeners();
  }

  int queueCount = 0;

  /// Refreshes the number of items in the download queue (Activity badge).
  Future<void> refreshQueueCount() async {
    final client = api;
    if (client == null) return;
    try {
      final n = await client.queueCount();
      if (n != queueCount && api == client) {
        queueCount = n;
        notifyListeners();
      }
    } catch (_) {}
  }

  final SettingsStore store;
  ServerConfig? config;
  RadarrApi? api;
  bool loaded = false;

  AppState(this.store);

  Future<void> init() async {
    config = await store.load();
    if (config != null) api = RadarrApi(config!);
    loaded = true;
    notifyListeners();
  }

  Future<void> setConfig(ServerConfig c) async {
    await store.save(c);
    config = await store.load();
    api?.dispose();
    api = config == null ? null : RadarrApi(config!);
    notifyListeners();
  }

  Future<void> reset() async {
    await store.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_moviesCacheKey);
    manualSearches.clear();
    api?.dispose();
    api = null;
    config = null;
    notifyListeners();
  }

  // Local cache of the movie list so the library opens instantly / offline.
  static const _moviesCacheKey = 'cache_movies';

  Future<List<Json>?> cachedMovies() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_moviesCacheKey);
    if (s == null) return null;
    try {
      return (jsonDecode(s) as List).map((e) => Json.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheMovies(List<Json> list) async {
    final p = await SharedPreferences.getInstance();
    // Drop bulky fields not needed for the list view.
    final slim = list
        .map(
          (m) => {
            for (final k in [
              'id',
              'title',
              'year',
              'status',
              'monitored',
              'images',
              'studio',
              'hasFile',
              'movieFile',
              'sizeOnDisk',
              'inCinemas',
              'digitalRelease',
              'physicalRelease',
              'ratings',
              'runtime',
              'sortTitle',
              'added',
            ])
              if (m.containsKey(k)) k: m[k],
          },
        )
        .toList();
    await p.setString(_moviesCacheKey, jsonEncode(slim));
  }
}
