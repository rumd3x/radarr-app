import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

class AddMovieScreen extends StatefulWidget {
  const AddMovieScreen({super.key});

  @override
  State<AddMovieScreen> createState() => _AddMovieScreenState();
}

class _AddMovieScreenState extends State<AddMovieScreen> {
  final _ctrl = TextEditingController();
  List<Json> _results = [];
  bool _loading = false;
  Object? _error;

  RadarrApi get _api => context.read<AppState>().api!;

  Future<void> _search() async {
    final term = _ctrl.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.lookup(term);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(Json s) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddSheet(movie: s, api: _api),
    );
    if (added == true && mounted) {
      toast(context, '${s['title']} added');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: TextField(
        controller: _ctrl,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search new movie (or tmdb:603, imdb:tt…)',
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _search(),
      ),
      actions: [IconButton(icon: const Icon(Icons.search), onPressed: _search)],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? ErrorView(error: _error!, onRetry: _search)
        : _results.isEmpty
        ? const EmptyView(Icons.search, 'Search for a movie to add')
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final s = _results[i];
              final exists = (s['id'] as int? ?? 0) > 0;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: exists ? null : () => _add(s),
                  child: Row(
                    children: [
                      SizedBox(width: 70, height: 100, child: Poster(s)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s['title']}${movieYear(s).isEmpty ? '' : ' (${movieYear(s)})'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s['overview'] ?? ''}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          exists
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: exists ? Colors.green : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class _AddSheet extends StatefulWidget {
  final Json movie;
  final RadarrApi api;
  const _AddSheet({required this.movie, required this.api});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  List<Json> _roots = [];
  List<Json> _profiles = [];
  String? _root;
  int? _profile;
  String _monitor = 'movieOnly';
  String _availability = 'announced';
  bool _searchNow = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _monitorOptions = {
    'movieOnly': 'Movie only',
    'movieAndCollection': 'Movie and collection',
    'none': 'None',
  };

  static const _availabilityOptions = {
    'announced': 'Announced',
    'inCinemas': 'In cinemas',
    'released': 'Released',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        widget.api.rootFolders(),
        widget.api.qualityProfiles(),
      ]);
      if (!mounted) return;
      setState(() {
        _roots = r[0];
        _profiles = r[1];
        _root = _roots.isNotEmpty ? _roots.first['path'] as String : null;
        _profile = _profiles.isNotEmpty ? _profiles.first['id'] as int : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_root == null || _profile == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.addMovie({
        ...widget.movie,
        'rootFolderPath': _root,
        'qualityProfileId': _profile,
        'monitored': _monitor != 'none',
        'minimumAvailability': _availability,
        'addOptions': {'monitor': _monitor, 'searchForMovie': _searchNow},
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: _loading
        ? const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add ${widget.movie['title']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _root,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Root folder'),
                  items: [
                    for (final r in _roots)
                      DropdownMenuItem(
                        value: r['path'] as String,
                        child: Text('${r['path']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _root = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _profile,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Quality profile',
                  ),
                  items: [
                    for (final p in _profiles)
                      DropdownMenuItem(
                        value: p['id'] as int,
                        child: Text('${p['name']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _profile = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _monitor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Monitor'),
                  items: [
                    for (final e in _monitorOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _monitor = v ?? 'movieOnly'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _availability,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Minimum availability',
                  ),
                  items: [
                    for (final e in _availabilityOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) =>
                      setState(() => _availability = v ?? 'announced'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start search for movie'),
                  value: _searchNow,
                  onChanged: (v) => setState(() => _searchNow = v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _saving || _root == null || _profile == null
                      ? null
                      : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add movie'),
                ),
              ],
            ),
          ),
  );
}
