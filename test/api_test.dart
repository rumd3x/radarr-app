import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radarr_app/services/api.dart';
import 'package:radarr_app/services/settings.dart';

RadarrApi _api(Future<http.Response> Function(http.Request) handler) =>
    RadarrApi(
      const ServerConfig(primaryUrl: 'http://p', secondaryUrl: '', apiKey: 'k'),
      client: MockClient(
        (r) async => r.url.path == '/api'
            ? http.Response('{"current":"v3"}', 200)
            : handler(r),
      ),
    );

void main() {
  test('normalizeUrl adds scheme and strips trailing slash', () {
    expect(
      ServerConfig.normalizeUrl('192.168.1.2:7878/'),
      'http://192.168.1.2:7878',
    );
    expect(ServerConfig.normalizeUrl(' https://a.b '), 'https://a.b');
    expect(ServerConfig.normalizeUrl(''), '');
  });

  test('falls back to secondary URL and sends API key', () async {
    final seen = <Uri>[];
    String? key;
    final client = MockClient((req) async {
      seen.add(req.url);
      if (req.url.host == 'primary') throw http.ClientException('down');
      key = req.headers['X-Api-Key'];
      if (req.url.path == '/api') return http.Response('{"current":"v3"}', 200);
      return http.Response('{"version":"5.0"}', 200);
    });
    final api = RadarrApi(
      const ServerConfig(
        primaryUrl: 'http://primary',
        secondaryUrl: 'http://secondary',
        apiKey: 'abc',
      ),
      client: client,
    );
    final status = await api.systemStatus();
    expect(status['version'], '5.0');
    expect(key, 'abc');
    expect(api.activeBase, 'http://secondary');
    expect(seen.last.path, '/api/v3/system/status');
  });

  test('manual search lists and grabs releases', () async {
    final calls = <String>[];
    String? grabBody;
    final api = _api((r) async {
      calls.add('${r.method} ${r.url.path}?${r.url.query}');
      if (r.method == 'POST') grabBody = r.body;
      return http.Response(
        r.method == 'GET' ? '[{"guid":"g","indexerId":2}]' : '{}',
        200,
      );
    });
    final list = await api.releases(7);
    await api.grabRelease('g', 2);
    expect(list.single['guid'], 'g');
    expect(calls, ['GET /api/v3/release?movieId=7', 'POST /api/v3/release?']);
    expect(grabBody, '{"guid":"g","indexerId":2}');
  });

  test('movie commands use movieIds', () async {
    final bodies = <Map>[];
    final api = _api((r) async {
      bodies.add(jsonDecode(r.body) as Map);
      return http.Response('{}', 201);
    });
    await api.searchMovies([3, 4]);
    await api.refreshMovie(3);
    await api.searchMissing();
    expect(bodies[0], {
      'name': 'MoviesSearch',
      'movieIds': [3, 4],
    });
    expect(bodies[1], {
      'name': 'RefreshMovie',
      'movieIds': [3],
    });
    expect(bodies[2]['name'], 'MissingMoviesSearch');
  });

  test('wanted lists are unwrapped and sorted by title', () async {
    Uri? uri;
    final api = _api((r) async {
      uri = r.url;
      return http.Response(
        jsonEncode({
          'records': [
            {'id': 2, 'title': 'B'},
            {'id': 1, 'title': 'A'},
          ],
        }),
        200,
      );
    });
    final list = await api.missing();
    expect(uri!.path, '/api/v3/wanted/missing');
    expect(uri!.queryParameters['monitored'], 'true');
    expect(list.map((m) => m['id']), [1, 2]);
  });

  test('removeQueueItem sends blocklist flag', () async {
    Uri? uri;
    final api = _api((r) async {
      uri = r.url;
      return http.Response('{}', 200);
    });
    await api.removeQueueItem(9, blocklist: true);
    expect(uri!.path, '/api/v3/queue/9');
    expect(uri!.queryParameters['blocklist'], 'true');
    expect(uri!.queryParameters['removeFromClient'], 'true');
  });

  test('reports invalid API key on 401', () async {
    final api = RadarrApi(
      const ServerConfig(primaryUrl: 'http://p', secondaryUrl: '', apiKey: 'x'),
      client: MockClient((r) async => http.Response('', 401)),
    );
    expect(api.systemStatus(), throwsA(isA<ApiException>()));
  });

  test('demo mode serves sample data without a server', () async {
    final api = RadarrApi(ServerConfig.demo);
    expect(api.isDemo, isTrue);
    final movies = await api.movies();
    expect(movies, isNotEmpty);
    expect(await api.queue(), isNotEmpty);
    expect(await api.missing(), isNotEmpty);
    expect(await api.releases(1), isNotEmpty);
    expect(await api.movieHistory(1), isNotEmpty);
    expect(await api.lookup('harbor'), isNotEmpty);
    expect(
      await api.calendar(
        DateTime.now().subtract(const Duration(days: 3)),
        DateTime.now().add(const Duration(days: 30)),
      ),
      isNotEmpty,
    );
    final updated = await api.updateMovie({
      ...movies.first,
      'monitored': false,
    });
    expect(updated['monitored'], false);
  });

  test('manualImport posts a ManualImport command', () async {
    Map? body;
    final api = _api((req) async {
      body = req.bodyBytes.isEmpty ? null : jsonDecode(req.body) as Map;
      return http.Response('{}', 201);
    });
    await api.manualImport([
      {'path': '/a.mkv', 'movieId': 1},
    ], mode: 'copy');
    expect(body!['name'], 'ManualImport');
    expect(body!['importMode'], 'copy');
    expect((body!['files'] as List).length, 1);
  });
}
