import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../../shared/widgets/oep_list_view.dart';
import '../models/search_result_item.dart';
import '../services/exchange_runtime_service.dart';

/// Search (WP-EXC-010 §5) -- mirrors `apps/publisher-portal`'s
/// `SearchResultsPage` params (`?q=&status=&sortBy=&sortDirection=&page=`)
/// against `ExchangeRuntimeNotifier.search`, which wraps the same
/// `GET /search` the web Exchange calls.
class ExchangeSearchPanel extends ConsumerStatefulWidget {
  const ExchangeSearchPanel({super.key});

  @override
  ConsumerState<ExchangeSearchPanel> createState() => _ExchangeSearchPanelState();
}

class _ExchangeSearchPanelState extends ConsumerState<ExchangeSearchPanel> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _runSearch(WidgetRef ref, {int page = 1}) {
    ref.read(exchangeRuntimeServiceProvider.notifier).search(q: _queryController.text.trim(), page: page);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exchangeRuntimeServiceProvider);
    final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);
    final results = state.searchResults;

    return KnowledgePanel(
      title: 'Search Packages',
      icon: Icons.search_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(hintText: 'Search packages…', isDense: true),
                    onSubmitted: (_) => _runSearch(ref),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: () => _runSearch(ref), child: const Text('Search')),
              ],
            ),
          ),
          Expanded(
            child: OEPListView(
              items: results.items,
              emptyMessage: 'No results.',
              itemBuilder: (context, item) => _SearchResultRow(item: item, onTap: () => notifier.selectPackage(item.id)),
            ),
          ),
          if (results.totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Page ${results.currentPage} of ${results.totalPages}',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: results.currentPage > 1 ? () => _runSearch(ref, page: results.currentPage - 1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed:
                        results.currentPage < results.totalPages ? () => _runSearch(ref, page: results.currentPage + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.item, required this.onTap});

  final SearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(item.displayName, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(
        item.publisherName,
        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
      ),
      trailing: Text(item.currentVersion ?? '--', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
    );
  }
}
