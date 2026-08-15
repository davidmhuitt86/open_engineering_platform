import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/models/recent_history_entry.dart';
import '../../core/models/search_scope.dart';
import '../../core/models/unified_search_result.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import '../../shared/navigation/unified_navigation.dart';
import '../dashboard/dashboard_page.dart' show showFoundationErrorDialog;
import 'unified_search_service.dart';

/// The Search Workspace (STUDIO-TASK-000010/000012; unified in
/// WORK_PACKAGE_025 ENGINE-TASK-000121). Merges Foundation's live
/// repository search with the Engineering Engine's own Graph/Layout
/// search (`UnifiedSearchService`) into one result list, so a single
/// query finds Knowledge Objects, Relationships, and — when a diagram
/// is open — diagram nodes, relationships, symbols, annotations, and
/// layers, each result tagged with Object Type/Owning Workspace/
/// Repository Location. Neither underlying search is reimplemented —
/// see `docs/UNIFIED_SEARCH.md`. Recent-search history is now the
/// shared, cross-workspace `EngineeringProjectState.recentHistory`
/// (ENGINE-TASK-000119) rather than this page's own local, ephemeral
/// list.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  SearchScope _scope = SearchScope.repository;
  List<UnifiedSearchResult>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    List<UnifiedSearchResult> results;
    try {
      results = UnifiedSearchService.search(ref, query: trimmed, scope: _scope);
    } on FoundationBridgeException catch (error) {
      if (!mounted) return;
      await showFoundationErrorDialog(context, title: 'Couldn\'t Search', error: error);
      return;
    }
    setState(() => _results = results);
    ref.read(engineeringProjectServiceProvider.notifier).recordHistory(RecentHistoryEntry(
          id: trimmed,
          label: trimmed,
          workspaceLabel: StudioDestination.search.label,
          route: StudioDestination.search.path,
          timestamp: DateTime.now(),
        ));
  }

  void _clear() {
    _controller.clear();
    ref.read(foundationRuntimeServiceProvider.notifier).clearSearch();
    setState(() => _results = null);
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final projectState = ref.watch(engineeringProjectServiceProvider);
    final searchHistory = projectState.recentHistory
        .where((entry) => entry.workspaceLabel == 'Search')
        .map((entry) => entry.label)
        .toSet()
        .toList();

    final hasSearched = _results != null;
    final results = _results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Icon(Icons.search_outlined, size: 18, color: StudioColors.selection),
              SizedBox(width: 10),
              Text(
                'Search',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _runSearch,
                    style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 16),
                      hintText: 'Search Knowledge, Diagrams, Evidence, Symbols, Annotations, Layers…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
              // 11px, not 12 -- now that `WorkbenchSidebar` (StudioShell's
              // single left nav, replacing the classic `StudioNavRail`) is
              // wider than the rail it replaced, this Row's available
              // width shrank by a hair, and `DropdownButton` (below)
              // can't itself shrink without overflowing internally.
              // Shaving 1px off two imperceptible gaps recovers the
              // needed space without touching the dropdown itself.
              const SizedBox(width: 11),
              SizedBox(
                height: 36,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SearchScope>(
                    value: _scope,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    items: [
                      for (final scope in SearchScope.values)
                        DropdownMenuItem(value: scope, child: Text(scope.label)),
                    ],
                    onChanged: (scope) {
                      if (scope != null) setState(() => _scope = scope);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 11),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () => _runSearch(_controller.text),
                  child: const Text('Search'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: hasSearched || _controller.text.isNotEmpty ? _clear : null,
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
        if (!foundation.isRepositoryOpen && projectState.engine == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'No repository open and no diagram loaded yet — search will still work once either is available.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: !hasSearched
                    ? const _SearchIdle()
                    : switch (results) {
                        null || [] => const _SearchNoResults(),
                        final results => _SearchResultsList(results: results, ref: ref),
                      },
              ),
              _SearchHistoryPanel(
                history: searchHistory,
                onSelect: (query) {
                  _controller.text = query;
                  _runSearch(query);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchIdle extends StatelessWidget {
  const _SearchIdle();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 40, color: StudioColors.textDisabled),
          SizedBox(height: 16),
          Text(
            'Search across the whole platform',
            style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Enter a search term to find Knowledge Objects, Relationships,\ndiagram elements, symbols, annotations, and layers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SearchNoResults extends StatelessWidget {
  const _SearchNoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 40, color: StudioColors.textDisabled),
            SizedBox(height: 16),
            Text(
              'No results',
              textAlign: TextAlign.center,
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term or search scope.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.ref});

  final List<UnifiedSearchResult> results;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchResultsHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _SearchResultRow(result: result, onTap: () => goToSearchResult(context, ref, result));
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultsHeader extends StatelessWidget {
  const _SearchResultsHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24),
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(flex: 2, child: Text('Object Type', style: style)),
          Expanded(flex: 2, child: Text('Owning Workspace', style: style)),
          Expanded(flex: 2, child: Text('Repository Location', style: style)),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final UnifiedSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Icon(result.icon, size: 15, color: StudioColors.textSecondary)),
              Expanded(
                flex: 3,
                child: Text(
                  result.label,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(result.objectTypeLabel, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  result.owningWorkspaceLabel,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  result.repositoryLocation,
                  overflow: TextOverflow.ellipsis,
                  style: StudioTheme.monoTextStyle.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHistoryPanel extends StatelessWidget {
  const _SearchHistoryPanel({required this.history, required this.onSelect});

  final List<String> history;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StudioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Text(
              'Recent Searches',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No searches yet this session.',
                      style: TextStyle(color: StudioColors.textDisabled, fontSize: 11.5),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final query = history[index];
                      return InkWell(
                        onTap: () => onSelect(query),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 14, color: StudioColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  query,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
