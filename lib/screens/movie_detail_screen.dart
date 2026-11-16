import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import 'manual_search_screen.dart';

/// Movie screen with three tabs: Details, History and Manual search.
class MovieDetailScreen extends StatefulWidget {
  final Json movie;
  final int initialTab;
  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.initialTab = 0,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Json _movie = widget.movie;
  final _detailsKey = GlobalKey<AsyncBodyState<Json>>();

  int get _id => _movie['id'] as int;
  String get _label =>
      '${_movie['title']}${movieYear(_movie).isEmpty ? '' : ' (${movieYear(_movie)})'}';
  RadarrApi get _api => context.read<AppState>().api!;

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _toggleMonitor(Json current) async {
    try {
      final r = await _api.updateMovie({
        ...current,
        'monitored': !(current['monitored'] == true),
      });
      setState(() => _movie = {..._movie, 'monitored': r['monitored']});
      _detailsKey.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _deleteFile(int fileId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete movie file?'),
        content: const Text('The file will be removed from disk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _api.deleteMovieFile(fileId);
      _detailsKey.currentState?.reload();
    }, 'File deleted');
  }

  Future<void> _deleteMovie() async {
    var deleteFiles = false;
    var exclusion = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Delete ${_movie['title']}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: deleteFiles,
                onChanged: (v) => setD(() => deleteFiles = v ?? false),
                title: const Text('Also delete files'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: exclusion,
                onChanged: (v) => setD(() => exclusion = v ?? false),
                title: const Text('Add import exclusion'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteMovie(
        _id,
        deleteFiles: deleteFiles,
        addImportExclusion: exclusion,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_label, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'refresh') {
                _run(() => _api.refreshMovie(_id), 'Refresh started');
              } else if (v == 'delete') {
                _deleteMovie();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh & scan')),
              PopupMenuItem(value: 'delete', child: Text('Delete movie')),
            ],
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Details'),
            Tab(text: 'History'),
            Tab(text: 'Search'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          AsyncBody<Json>(
            key: _detailsKey,
            load: (api) => api.movieById(_id),
            builder: (context, m) => _details(m),
          ),
          AsyncBody<List<Json>>(
            load: (api) => api.movieHistory(_id),
            builder: (context, list) => _history(list),
          ),
          ManualSearchView(movieId: _id, label: _label),
        ],
      ),
    ),
  );

  String? _date(Object? v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    return d == null ? null : DateFormat.yMMMd().format(d);
  }

  Widget _details(Json m) {
    final cs = Theme.of(context).colorScheme;
    final file = m['movieFile'] is Map
        ? Json.from(m['movieFile'] as Map)
        : null;
    final monitored = m['monitored'] == true;
    final runtime = m['runtime'];
    final rating =
        ((m['ratings'] as Map?)?['tmdb'] as Map?)?['value'] ??
        ((m['ratings'] as Map?)?['imdb'] as Map?)?['value'];
    final genres = (m['genres'] as List? ?? const []).join(', ');
    final dates = <(String, String)>[
      if (_date(m['inCinemas']) != null) ('In cinemas', _date(m['inCinemas'])!),
      if (_date(m['digitalRelease']) != null)
        ('Digital', _date(m['digitalRelease'])!),
      if (_date(m['physicalRelease']) != null)
        ('Physical', _date(m['physicalRelease'])!),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 110, height: 165, child: Poster(m)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m['title']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (movieYear(m).isNotEmpty)
                        Chip(label: Text(movieYear(m))),
                      if (runtime is num && runtime > 0)
                        Chip(label: Text('$runtime min')),
                      if ('${m['certification'] ?? ''}'.isNotEmpty)
                        Chip(label: Text('${m['certification']}')),
                      if (movieStatusLabel(m) != null)
                        Chip(label: Text(movieStatusLabel(m)!)),
                      if (rating is num && rating > 0)
                        Chip(
                          avatar: const Icon(Icons.star, size: 16),
                          label: Text(rating.toStringAsFixed(1)),
                        ),
                    ],
                  ),
                  if (genres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        genres,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if ('${m['studio'] ?? ''}'.isNotEmpty)
                    Text(
                      '${m['studio']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        if ('${m['overview'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${m['overview']}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
        if (dates.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final d in dates)
            Text(
              '${d.$1}: ${d.$2}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toggleMonitor(m),
                icon: Icon(monitored ? Icons.bookmark : Icons.bookmark_border),
                label: Text(monitored ? 'Monitored' : 'Unmonitored'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    _run(() => _api.searchMovies([_id]), 'Search started'),
                icon: const Icon(Icons.search),
                label: const Text('Auto search'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'File',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: cs.primary),
        ),
        const SizedBox(height: 8),
        if (file == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.insert_drive_file_outlined),
              title: Text('No file'),
              subtitle: Text(
                'Use Auto search or the Search tab to find a release.',
              ),
            ),
          )
        else
          _fileCard(file),
        if ('${m['path'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Path', style: Theme.of(context).textTheme.labelMedium),
          SelectableText('${m['path']}'),
        ],
      ],
    );
  }

  Widget _fileCard(Json f) {
    final media = f['mediaInfo'] is Map
        ? Json.from(f['mediaInfo'] as Map)
        : <String, dynamic>{};
    final quality = (f['quality'] as Map?)?['quality']?['name'];
    final languages = (f['languages'] as List? ?? [])
        .map((l) => (l as Map)['name'])
        .join(', ');
    final added = DateTime.tryParse('${f['dateAdded']}')?.toLocal();
    final rows = <(String, String)>[
      ('File', '${f['relativePath'] ?? f['path'] ?? ''}'),
      if (quality != null) ('Quality', '$quality'),
      ('Size', formatBytes((f['size'] as num?) ?? 0)),
      if ('${f['releaseGroup'] ?? ''}'.isNotEmpty)
        ('Release group', '${f['releaseGroup']}'),
      if (languages.isNotEmpty) ('Languages', languages),
      if (media['resolution'] != null) ('Resolution', '${media['resolution']}'),
      if (media['videoCodec'] != null)
        (
          'Video',
          '${media['videoCodec']}'
              '${'${media['videoDynamicRangeType'] ?? ''}'.isNotEmpty ? ' · ${media['videoDynamicRangeType']}' : ''}',
        ),
      if (media['audioCodec'] != null)
        (
          'Audio',
          '${media['audioCodec']}'
              '${media['audioChannels'] != null ? ' ${media['audioChannels']}ch' : ''}',
        ),
      if ('${media['subtitles'] ?? ''}'.isNotEmpty)
        ('Subtitles', '${media['subtitles']}'),
      if (added != null) ('Added', DateFormat.yMMMd().add_jm().format(added)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        r.$1,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Expanded(child: SelectableText(r.$2)),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteFile(f['id'] as int),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete file'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _events = {
    'grabbed': ('Grabbed', Icons.cloud_download),
    'downloadFolderImported': ('Imported', Icons.download_done),
    'movieFolderImported': ('Imported', Icons.download_done),
    'downloadFailed': ('Download failed', Icons.error_outline),
    'movieFileDeleted': ('File deleted', Icons.delete_outline),
    'movieFileRenamed': ('Renamed', Icons.drive_file_rename_outline),
    'downloadIgnored': ('Ignored', Icons.block),
  };

  Widget _history(List<Json> list) {
    if (list.isEmpty) {
      return const EmptyView(Icons.history, 'No history for this movie');
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final h = list[i];
        final ev =
            _events['${h['eventType']}'] ??
            ('${h['eventType']}', Icons.history);
        final date = DateTime.tryParse('${h['date']}')?.toLocal();
        final quality = (h['quality'] as Map?)?['quality']?['name'];
        final data = h['data'] is Map ? h['data'] as Map : const {};
        return ListTile(
          leading: Icon(ev.$2),
          title: Text(ev.$1),
          subtitle: Text(
            [
              '${h['sourceTitle'] ?? ''}',
              if (quality != null) '$quality',
              if (data['indexer'] != null) '${data['indexer']}',
              if (data['downloadClientName'] != null)
                '${data['downloadClientName']}',
            ].join('\n'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          trailing: date == null
              ? null
              : Text(
                  DateFormat('MMM d, y\nHH:mm').format(date),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
        );
      },
    );
  }
}
