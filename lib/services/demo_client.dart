import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory fake Radarr server used by demo mode. It answers the same
/// endpoints as the real API, so every screen works without a server.
class DemoServer {
  static const url = 'http://demo.radarr.local';

  final DateTime _now = DateTime.now();
  final List<Map<String, dynamic>> _movies = [];
  final List<Map<String, dynamic>> _queue = [];
  final List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _manualFiles = [];
  var _nextId = 100;

  DemoServer() {
    _seed();
  }

  http.Client client() => MockClient(_handle);

  // title, year, studio, genre, runtime, days since digital release
  // (negative = upcoming), has file, overview
  static const _specs = [
    (
      'Starfall Station',
      2021,
      'Orbit Pictures',
      'Sci-Fi',
      128,
      900,
      true,
      'A crew of engineers keeps a failing deep-space station alive while '
          'uncovering why its original builders vanished.',
    ),
    (
      'The Lighthouse Files',
      2018,
      'Coastline Films',
      'Mystery',
      112,
      2000,
      true,
      'A retired detective reopens cold cases from a remote island '
          'lighthouse, one tape recording at a time.',
    ),
    (
      'Midnight Kitchen',
      2022,
      'Foodies Studio',
      'Comedy',
      98,
      500,
      true,
      'Chefs compete after dark in a hidden kitchen where the only rule is '
          'that every dish must tell a story.',
    ),
    (
      'Northern Lines',
      2019,
      'Rail One',
      'Drama',
      141,
      1700,
      true,
      'Rival railway families fight to connect a frozen frontier at the '
          'dawn of the steam age.',
    ),
    (
      'Paper Tigers',
      2016,
      'Studio 9',
      'Comedy',
      104,
      3000,
      true,
      'Two struggling comic artists turn a basement hobby into a '
          'publishing empire.',
    ),
    (
      'Echo Valley',
      2023,
      'Orbit Pictures',
      'Thriller',
      117,
      120,
      false,
      'Strange sounds echo through a mountain town, and only the new '
          'sheriff seems to hear them.',
    ),
    (
      'Neon Harvest',
      2024,
      'Voltage',
      'Action',
      132,
      30,
      false,
      'A courier crosses a flooded megacity with a package everyone '
          'wants.',
    ),
    (
      'Glass Orchard',
      2025,
      'Quiet Giant',
      'Drama',
      109,
      -20,
      false,
      'A family inherits an orchard with a secret older than the town.',
    ),
    (
      'Signal Fire',
      2025,
      'Voltage',
      'Adventure',
      125,
      -75,
      false,
      'Volunteer firefighters battle more than flames.',
    ),
  ];

  void _seed() {
    var id = 1;
    for (final (title, year, studio, genre, runtime, daysAgo, hasFile, overview)
        in _specs) {
      final mid = id++;
      final digital = _now.subtract(Duration(days: daysAgo));
      final released = daysAgo > 0;
      final file = hasFile
          ? {
              'id': _nextId++,
              'movieId': mid,
              'relativePath': '$title ($year)/$title ($year) WEBDL-1080p.mkv',
              'path':
                  '/media/movies/$title ($year)/$title ($year) WEBDL-1080p.mkv',
              'size': 4200000000 + mid * 310000000,
              'dateAdded': digital
                  .add(const Duration(days: 1))
                  .toUtc()
                  .toIso8601String(),
              'releaseGroup': 'DEMO',
              'quality': {
                'quality': {'id': 3, 'name': 'WEBDL-1080p'},
              },
              'languages': [
                {'id': 1, 'name': 'English'},
              ],
              'mediaInfo': {
                'videoCodec': 'x265',
                'audioCodec': 'EAC3',
                'audioChannels': 5.1,
                'resolution': '1920x1080',
                'subtitles': 'English / Spanish',
              },
            }
          : null;
      _movies.add({
        'id': mid,
        'title': title,
        'sortTitle': title.toLowerCase(),
        'year': year,
        'status': released ? 'released' : 'announced',
        'studio': studio,
        'overview': overview,
        'runtime': runtime,
        'certification': 'PG-13',
        'genres': [genre],
        'ratings': {
          'tmdb': {'value': 6.5 + (mid % 5) * 0.4},
        },
        'monitored': true,
        'minimumAvailability': 'announced',
        'isAvailable': released,
        'qualityProfileId': 1,
        'path': '/media/movies/$title ($year)',
        'added': _now
            .subtract(Duration(days: 300 - mid * 11))
            .toIso8601String(),
        'inCinemas': digital
            .subtract(const Duration(days: 90))
            .toUtc()
            .toIso8601String(),
        'digitalRelease': digital.toUtc().toIso8601String(),
        'physicalRelease': digital
            .add(const Duration(days: 30))
            .toUtc()
            .toIso8601String(),
        'images': const [],
        'hasFile': hasFile,
        'sizeOnDisk': file?['size'] ?? 0,
        'movieFile': ?file,
      });
    }

    for (var i = 0; i < 2; i++) {
      final m = _movies[5 + i];
      final size = 4800000000 + i * 600000000;
      _queue.add({
        'id': 500 + i,
        'movieId': m['id'],
        'title':
            '${(m['title'] as String).replaceAll(' ', '.')}.'
            '${m['year']}.1080p.WEB-DL',
        'status': 'downloading',
        'size': size,
        'sizeleft': (size * (0.65 - i * 0.4)).round(),
        'timeleft': i == 0 ? '00:12:40' : '00:41:05',
        'downloadClient': 'qBittorrent',
        'movie': m,
      });
    }

    final stuck = _movies[7];
    final name =
        '${(stuck['title'] as String).replaceAll(' ', '.')}.'
        '${stuck['year']}.1080p.WEB-DL';
    _queue.add({
      'id': 502,
      'movieId': null,
      'title': name,
      'status': 'completed',
      'trackedDownloadStatus': 'warning',
      'trackedDownloadState': 'importBlocked',
      'statusMessages': [
        {
          'title': name,
          'messages': ['Unable to parse file, movie could not be identified'],
        },
      ],
      'downloadId': 'DEMO502',
      'size': 5000000000,
      'sizeleft': 0,
      'downloadClient': 'qBittorrent',
    });
    _manualFiles = [
      {
        'id': 1,
        'path': '/downloads/$name/$name.mkv',
        'relativePath': '$name.mkv',
        'name': name,
        'size': 5000000000,
        'movie': null,
        'quality': {
          'quality': {'id': 3, 'name': 'WEBDL-1080p'},
          'revision': {'version': 1, 'real': 0, 'isRepack': false},
        },
        'languages': [
          {'id': 1, 'name': 'English'},
        ],
        'releaseGroup': 'DEMO',
        'downloadId': 'DEMO502',
        'rejections': [
          {'reason': 'Unknown Movie', 'type': 'permanent'},
        ],
      },
    ];

    for (final m in _movies.where((m) => m['hasFile'] == true).take(6)) {
      _history.add({
        'id': _nextId++,
        'eventType': 'downloadFolderImported',
        'sourceTitle':
            '${(m['title'] as String).replaceAll(' ', '.')}.${m['year']}.1080p.WEB-DL',
        'date': (m['movieFile'] as Map)['dateAdded'],
        'movieId': m['id'],
        'quality': {
          'quality': {'id': 3, 'name': 'WEBDL-1080p'},
        },
        'data': {
          'indexer': 'Demo Indexer',
          'downloadClientName': 'qBittorrent',
        },
        'movie': m,
      });
    }
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> _handle(http.Request req) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final path = req.url.path;
    final q = req.url.queryParameters;
    final m = req.method;
    final body = req.body.isEmpty ? null : jsonDecode(req.body);

    if (path == '/api') return _json({'current': 'v3'});
    final p = path.replaceFirst('/api/v3', '');

    switch (p) {
      case '/system/status':
        return _json({'appName': 'Radarr', 'version': '5.0.0.0 (demo)'});
      case '/health':
        return _json([
          {
            'type': 'warning',
            'source': 'IndexerStatusCheck',
            'message': 'Demo Indexer unavailable due to failures (sample)',
          },
        ]);
      case '/diskspace':
        return _json([
          {
            'path': '/media/movies',
            'label': 'Media',
            'freeSpace': 1200000000000,
            'totalSpace': 4000000000000,
          },
        ]);
      case '/rootfolder':
        return _json([
          {'id': 1, 'path': '/media/movies', 'freeSpace': 1200000000000},
        ]);
      case '/qualityprofile':
        return _json([
          {'id': 1, 'name': 'HD - 1080p'},
          {'id': 2, 'name': 'Ultra-HD'},
          {'id': 3, 'name': 'Any'},
        ]);
      case '/movie':
        if (m == 'POST') {
          final movie = {
            ...Map<String, dynamic>.from(body as Map),
            'id': _nextId++,
            'added': _now.toIso8601String(),
            'images': const [],
            'hasFile': false,
            'sizeOnDisk': 0,
          };
          _movies.add(movie);
          return _json(movie, 201);
        }
        return _json(_movies);
      case '/movie/lookup':
        final term = (q['term'] ?? '').toLowerCase();
        return _json([
          for (final t in _lookupCatalog)
            if (term.isEmpty || '${t['title']}'.toLowerCase().contains(term)) t,
        ]);
      case '/calendar':
        final start = DateTime.parse(q['start']!);
        final end = DateTime.parse(q['end']!);
        bool inRange(Object? v) {
          final d = DateTime.tryParse('$v');
          return d != null && !d.isBefore(start) && d.isBefore(end);
        }

        return _json([
          for (final mv in _movies)
            if (inRange(mv['inCinemas']) ||
                inRange(mv['digitalRelease']) ||
                inRange(mv['physicalRelease']))
              mv,
        ]);
      case '/history':
        return _json({
          'page': 1,
          'totalRecords': _history.length,
          'records': _history,
        });
      case '/history/movie':
        return _json([
          for (final h in _history)
            if ('${h['movieId']}' == q['movieId']) h,
        ]);
      case '/queue/status':
        return _json({'totalCount': _queue.length});
      case '/queue':
        return _json({
          'page': 1,
          'totalRecords': _queue.length,
          'records': _queue,
        });
      case '/wanted/missing':
        final recs = [
          for (final mv in _movies)
            if (mv['hasFile'] != true &&
                mv['monitored'] == true &&
                mv['isAvailable'] == true)
              mv,
        ];
        return _json({'page': 1, 'totalRecords': recs.length, 'records': recs});
      case '/wanted/cutoff':
        final recs = [
          for (final mv in _movies)
            if (mv['hasFile'] == true && mv['monitored'] == true) mv,
        ].take(3).toList();
        return _json({'page': 1, 'totalRecords': recs.length, 'records': recs});
      case '/release':
        if (m == 'POST') return _json({});
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return _json(_releases(int.tryParse(q['movieId'] ?? '') ?? 0));
      case '/manualimport':
        return _json(_manualFiles);
      case '/qualitydefinition':
        return _json([
          for (final (id, n) in const [
            (4, 'HDTV-720p'),
            (5, 'WEBDL-720p'),
            (3, 'WEBDL-1080p'),
            (19, 'WEBDL-2160p'),
          ])
            {
              'id': id,
              'title': n,
              'quality': {'id': id, 'name': n},
            },
        ]);
      case '/language':
        return _json([
          {'id': -1, 'name': 'Any'},
          {'id': 1, 'name': 'English'},
          {'id': 2, 'name': 'French'},
          {'id': 3, 'name': 'Spanish'},
        ]);
      case '/command':
        if (body is Map && body['name'] == 'ManualImport') {
          final ids = {
            for (final f in body['files'] as List) (f as Map)['downloadId'],
          };
          _queue.removeWhere((e) => ids.contains(e['downloadId']));
          _manualFiles = [];
        }
        return _json({'id': _nextId++, 'status': 'queued'}, 201);
    }

    final movieMatch = RegExp(r'^/movie/(\d+)$').firstMatch(p);
    if (movieMatch != null) {
      final id = int.parse(movieMatch.group(1)!);
      final idx = _movies.indexWhere((e) => e['id'] == id);
      if (idx < 0) return _json({'message': 'Not found'}, 404);
      if (m == 'DELETE') {
        _movies.removeAt(idx);
        return _json({});
      }
      if (m == 'PUT') {
        _movies[idx] = {
          ..._movies[idx],
          'monitored': (body as Map)['monitored'],
        };
      }
      return _json(_movies[idx]);
    }

    final fileMatch = RegExp(r'^/moviefile/(\d+)$').firstMatch(p);
    if (fileMatch != null && m == 'DELETE') {
      final id = int.parse(fileMatch.group(1)!);
      for (var i = 0; i < _movies.length; i++) {
        if ((_movies[i]['movieFile'] as Map?)?['id'] == id) {
          _movies[i] = {..._movies[i], 'hasFile': false, 'sizeOnDisk': 0}
            ..remove('movieFile');
        }
      }
      return _json({});
    }

    final queueMatch = RegExp(r'^/queue/(\d+)$').firstMatch(p);
    if (queueMatch != null && m == 'DELETE') {
      final id = int.parse(queueMatch.group(1)!);
      _queue.removeWhere((e) => e['id'] == id);
      return _json({});
    }

    return _json({'message': 'Not found'}, 404);
  }

  List<Map<String, dynamic>> _releases(int movieId) => [
    for (final (i, r) in const [
      ('1080p WEB-DL', 'WEBDL-1080p', 4300000000, 128, 4, <String>[]),
      ('2160p WEB-DL HDR', 'WEBDL-2160p', 18200000000, 54, 9, <String>[]),
      ('720p WEB-DL', 'WEBDL-720p', 1900000000, 12, 30, <String>[]),
      (
        '1080p WEB-DL x264',
        'WEBDL-1080p',
        3900000000,
        0,
        2,
        ['Not an upgrade for existing movie file'],
      ),
    ].indexed)
      {
        'guid': 'demo-$movieId-$i',
        'indexerId': 1,
        'indexer': 'Demo Indexer',
        'title': 'Sample.Movie.2024.${r.$1.replaceAll(' ', '.')}-DEMO',
        'size': r.$3,
        'seeders': r.$4,
        'leechers': r.$4 ~/ 4,
        'age': r.$5,
        'ageHours': r.$5 * 24,
        'protocol': 'torrent',
        'quality': {
          'quality': {'id': 3, 'name': r.$2},
        },
        'languages': [
          {'id': 1, 'name': 'English'},
        ],
        'customFormatScore': 0,
        'rejected': r.$6.isNotEmpty,
        'rejections': r.$6,
      },
  ];

  static final List<Map<String, dynamic>> _lookupCatalog = [
    for (final (i, t) in const [
      ('Harbor Lights', 2020, 'A night-shift crew keeps a busy port running.'),
      ('Glass Harvest', 2017, 'A family inherits a farm with a secret.'),
      ('Signal Tower', 2024, 'Volunteer rangers battle more than wildfires.'),
    ].indexed)
      {
        'title': t.$1,
        'sortTitle': t.$1.toLowerCase(),
        'year': t.$2,
        'overview': t.$3,
        'status': 'released',
        'studio': 'Demo Pictures',
        'tmdbId': 900000 + i,
        'titleSlug': '${900000 + i}',
        'images': const [],
      },
  ];
}
