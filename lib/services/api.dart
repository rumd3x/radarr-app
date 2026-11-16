import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'demo_client.dart';
import 'settings.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

/// Radarr API client. Tries the primary URL first and falls back to the
/// secondary URL when the primary is unreachable.
class RadarrApi {
  final ServerConfig config;
  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  String? _activeBase;
  final Map<String, String> _versionByBase = {};

  RadarrApi(this.config, {http.Client? client})
    : _client =
          client ?? (config.isDemo ? DemoServer().client() : http.Client());

  bool get isDemo => config.isDemo;

  List<String> get _bases => [
    ?_activeBase,
    for (final u in [config.primaryUrl, config.secondaryUrl])
      if (u.isNotEmpty && u != _activeBase) u,
  ];

  String? get activeBase => _activeBase;

  Map<String, String> get headers => {
    'X-Api-Key': config.apiKey,
    'Accept': 'application/json',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
    'Content-Type': 'application/json',
  };

  /// Absolute URL for a relative asset path (e.g. movie images).
  String assetUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = _activeBase ?? config.primaryUrl;
    final sep = path.contains('?') ? '&' : '?';
    return '$base$path${sep}apikey=${config.apiKey}';
  }

  Future<String> _version(String base) async {
    final cached = _versionByBase[base];
    if (cached != null) return cached;
    var v = 'v3';
    try {
      final r = await _client
          .get(Uri.parse('$base/api'), headers: headers)
          .timeout(_timeout);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map && j['current'] is String) v = j['current'] as String;
      }
    } catch (_) {}
    return _versionByBase[base] = v;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Duration timeout = _timeout,
  }) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final v = await _version(base);
        final uri = Uri.parse('$base/api/$v$path').replace(
          queryParameters: query?.map(
            (k, val) =>
                MapEntry(k, val is List ? [for (final e in val) '$e'] : '$val'),
          ),
        );
        final req = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) req.body = jsonEncode(body);
        final res = await http.Response.fromStream(
          await _client.send(req).timeout(timeout),
        );
        _activeBase = base;
        if (res.statusCode == 401) {
          throw ApiException('Invalid API key', 401);
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw ApiException(_errorMessage(res), res.statusCode);
        }
        if (res.body.isEmpty) return null;
        return jsonDecode(utf8.decode(res.bodyBytes));
      } on ApiException {
        rethrow;
      } on Exception catch (e) {
        lastError = e;
      }
    }
    throw ApiException('Could not reach Radarr (${lastError ?? 'no URL'})');
  }

  String _errorMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is List && j.isNotEmpty && j.first is Map) {
        return (j.first['errorMessage'] ?? 'Error ${res.statusCode}')
            .toString();
      }
      if (j is Map && j['message'] != null) return j['message'].toString();
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  // ---- System ----
  Future<Json> systemStatus() async =>
      Json.from(await _send('GET', '/system/status'));
  Future<List<Json>> health() async => _list(await _send('GET', '/health'));
  Future<List<Json>> diskSpace() async =>
      _list(await _send('GET', '/diskspace'));

  // ---- Movies ----
  Future<List<Json>> movies() async => _list(await _send('GET', '/movie'));

  Future<Json> movieById(int id) async =>
      Json.from(await _send('GET', '/movie/$id'));

  /// [term] may be a title, `tmdb:603` or `imdb:tt0133093`.
  Future<List<Json>> lookup(String term) async =>
      _list(await _send('GET', '/movie/lookup', query: {'term': term}));

  Future<Json> addMovie(Json body) async =>
      Json.from(await _send('POST', '/movie', body: body));

  Future<Json> updateMovie(Json body) async =>
      Json.from(await _send('PUT', '/movie/${body['id']}', body: body));

  Future<void> deleteMovie(
    int id, {
    bool deleteFiles = false,
    bool addImportExclusion = false,
  }) async {
    await _send(
      'DELETE',
      '/movie/$id',
      query: {
        'deleteFiles': deleteFiles,
        'addImportExclusion': addImportExclusion,
      },
    );
  }

  Future<List<Json>> rootFolders() async =>
      _list(await _send('GET', '/rootfolder'));

  Future<List<Json>> qualityProfiles() async =>
      _list(await _send('GET', '/qualityprofile'));

  Future<List<Json>> calendar(DateTime start, DateTime end) async => _list(
    await _send(
      'GET',
      '/calendar',
      query: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'unmonitored': false,
      },
    ),
  );

  // ---- Movie files / history ----
  Future<void> deleteMovieFile(int id) async {
    await _send('DELETE', '/moviefile/$id');
  }

  Future<List<Json>> movieHistory(int movieId) async =>
      _list(await _send('GET', '/history/movie', query: {'movieId': movieId}));

  // ---- Manual search ----
  // Indexer queries can take minutes, so use a generous timeout.
  static const releaseTimeout = Duration(minutes: 5);

  Future<List<Json>> releases(int movieId) async => _list(
    await _send(
      'GET',
      '/release',
      query: {'movieId': movieId},
      timeout: releaseTimeout,
    ),
  );

  Future<void> grabRelease(String guid, int indexerId) async {
    await _send(
      'POST',
      '/release',
      body: {'guid': guid, 'indexerId': indexerId},
      timeout: releaseTimeout,
    );
  }

  // ---- Activity ----
  Future<List<Json>> queue() async {
    final r = await _send(
      'GET',
      '/queue',
      query: {
        'page': 1,
        'pageSize': 100,
        'includeMovie': true,
        'includeUnknownMovieItems': true,
      },
    );
    return _list(r is Map ? r['records'] : r);
  }

  Future<int> queueCount() async {
    final r = await _send('GET', '/queue/status');
    return (r is Map ? r['totalCount'] as num? : null)?.toInt() ?? 0;
  }

  Future<void> removeQueueItem(int id, {bool blocklist = false}) async {
    await _send(
      'DELETE',
      '/queue/$id',
      query: {'removeFromClient': true, 'blocklist': blocklist},
    );
  }

  /// Files Radarr found for a download that needs manual import
  /// (the web UI's "Interactive Import").
  /// Resolving by [downloadId] lets Radarr match the movie like the web UI
  /// does, but it fails when the client reports no output path; in that case
  /// (or when it finds nothing) the download's [folder] is used instead.
  Future<List<Json>> manualImportCandidates({
    String? folder,
    String? downloadId,
  }) async {
    Future<List<Json>> fetch(Map<String, dynamic> q) async => _list(
      await _send(
        'GET',
        '/manualimport',
        query: {...q, 'filterExistingFiles': false},
      ),
    );

    final hasFolder = folder != null && folder.trim().isNotEmpty;
    if (downloadId != null && downloadId.isNotEmpty) {
      try {
        final r = await fetch({'downloadId': downloadId});
        if (r.isNotEmpty || !hasFolder) return r;
      } on ApiException {
        if (!hasFolder) rethrow;
      }
    }
    return fetch({'folder': folder});
  }

  /// Movie Radarr infers from a release title.
  Future<Json> parse(String title) async =>
      Json.from(await _send('GET', '/parse', query: {'title': title}));

  Future<void> manualImport(List<Json> files, {String mode = 'auto'}) =>
      command('ManualImport', {'files': files, 'importMode': mode});

  Future<List<Json>> qualityDefinitions() async =>
      _list(await _send('GET', '/qualitydefinition'));

  Future<List<Json>> languages() async =>
      _list(await _send('GET', '/language'));

  Future<List<Json>> history({int pageSize = 50}) async {
    final r = await _send(
      'GET',
      '/history',
      query: {
        'page': 1,
        'pageSize': pageSize,
        'sortKey': 'date',
        'sortDirection': 'descending',
        'includeMovie': true,
      },
    );
    return _list(r is Map ? r['records'] : r);
  }

  /// Monitored movies without a file.
  Future<List<Json>> missing({int page = 1, int pageSize = 50}) =>
      _wanted('missing', page, pageSize);

  /// Movies whose file quality is below the profile's cutoff.
  Future<List<Json>> cutoffUnmet({int page = 1, int pageSize = 50}) =>
      _wanted('cutoff', page, pageSize);

  Future<List<Json>> _wanted(String kind, int page, int pageSize) async {
    final r = await _send(
      'GET',
      '/wanted/$kind',
      query: {'page': page, 'pageSize': pageSize, 'monitored': true},
    );
    return _list(r is Map ? r['records'] : r)..sort(
      (a, b) => '${a['sortTitle'] ?? a['title']}'.compareTo(
        '${b['sortTitle'] ?? b['title']}',
      ),
    );
  }

  // ---- Commands ----
  Future<void> command(String name, [Json extra = const {}]) async {
    await _send('POST', '/command', body: {'name': name, ...extra});
  }

  Future<void> searchMovies(List<int> ids) =>
      command('MoviesSearch', {'movieIds': ids});
  Future<void> refreshMovie(int movieId) => command('RefreshMovie', {
    'movieIds': [movieId],
  });
  Future<void> searchMissing() =>
      command('MissingMoviesSearch', {'monitored': true});
  Future<void> searchCutoffUnmet() =>
      command('CutoffUnmetMoviesSearch', {'monitored': true});

  List<Json> _list(dynamic v) =>
      (v as List? ?? const []).map((e) => Json.from(e as Map)).toList();

  void dispose() => _client.close();
}
