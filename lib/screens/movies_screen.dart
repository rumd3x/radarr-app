import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import 'add_movie_screen.dart';
import 'movie_detail_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

enum _Filter { all, monitored, unmonitored, downloaded, missing }

class _MoviesScreenState extends State<MoviesScreen> {
  List<Json> _all = [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  bool _searching = false;
  bool _grid = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    final cached = await state.cachedMovies();
    if (cached != null && mounted) {
      setState(() {
        _all = cached;
        _loading = false;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    try {
      final list = await state.api!.movies();
      state.cacheMovies(list);
      if (!mounted) return;
      setState(() {
        _all = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<Json> get _visible {
    final q = _query.toLowerCase();
    final list = _all.where((m) {
      if (q.isNotEmpty && !('${m['title']}'.toLowerCase().contains(q))) {
        return false;
      }
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.monitored:
          return m['monitored'] == true;
        case _Filter.unmonitored:
          return m['monitored'] != true;
        case _Filter.downloaded:
          return m['hasFile'] == true;
        case _Filter.missing:
          return m['hasFile'] != true && m['monitored'] == true;
      }
    }).toList();
    list.sort(
      (a, b) => '${a['sortTitle'] ?? a['title']}'.compareTo(
        '${b['sortTitle'] ?? b['title']}',
      ),
    );
    return list;
  }

  Future<void> _open(Json m) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: m)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Filter library…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text('Movies (${_all.length})'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          IconButton(
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          PopupMenuButton<_Filter>(
            icon: const Icon(Icons.filter_list),
            initialValue: _filter,
            onSelected: (f) => setState(() => _filter = f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Filter.all, child: Text('All')),
              PopupMenuItem(value: _Filter.monitored, child: Text('Monitored')),
              PopupMenuItem(
                value: _Filter.unmonitored,
                child: Text('Unmonitored'),
              ),
              PopupMenuItem(
                value: _Filter.downloaded,
                child: Text('Downloaded'),
              ),
              PopupMenuItem(value: _Filter.missing, child: Text('Missing')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMovieScreen()),
          );
          _refresh();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _all.isEmpty)
          ? ErrorView(error: _error!, onRetry: _refresh)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: items.isEmpty
                  ? const EmptyView(
                      Icons.video_library_outlined,
                      'No movies found',
                    )
                  : _grid
                  ? _buildGrid(items)
                  : _buildList(items),
            ),
    );
  }

  Widget _buildGrid(List<Json> items) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 160,
      childAspectRatio: 0.62,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final m = items[i];
      return GestureDetector(
        onTap: () => _open(m),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Poster(m),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StatusBar(m, thick: true),
              ),
              if (m['monitored'] != true)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.bookmark_border,
                    size: 20,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildList(List<Json> items) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final m = items[i];
      final size = (m['sizeOnDisk'] as num?) ?? 0;
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(m),
          child: Row(
            children: [
              SizedBox(width: 64, height: 92, child: Poster(m)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          movieYear(m),
                          if ('${m['studio'] ?? ''}'.isNotEmpty)
                            '${m['studio']}',
                          if (size > 0) formatBytes(size),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _StatusBar(m),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Green when downloaded, red when monitored but missing, grey otherwise.
class _StatusBar extends StatelessWidget {
  final Json movie;
  final bool thick;
  const _StatusBar(this.movie, {this.thick = false});

  @override
  Widget build(BuildContext context) {
    final have = movie['hasFile'] == true;
    final color = have
        ? Colors.green
        : (movie['monitored'] == true ? Colors.redAccent : Colors.grey);
    final bar = LinearProgressIndicator(
      value: have ? 1 : 0,
      minHeight: thick ? 5 : 6,
      color: color,
      backgroundColor: color.withValues(alpha: 0.35),
    );
    if (thick) return bar;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(borderRadius: BorderRadius.circular(4), child: bar),
        ),
        const SizedBox(width: 8),
        Text(
          have
              ? 'Downloaded'
              : (movie['monitored'] == true ? 'Missing' : 'Unmonitored'),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
