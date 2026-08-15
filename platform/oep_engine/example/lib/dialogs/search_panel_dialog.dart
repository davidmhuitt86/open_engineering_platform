import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

/// Search Panel (WORK_PACKAGE_023, ENGINE-TASK-000104/000106): a query
/// box over `SearchProvider.search`, a result list, and Next/Previous/
/// Zoom To/Select/Center actions built on `NavigationService`'s
/// search-result index plus the existing `ViewStateService`/
/// `SelectionService` primitives — no duplicate zoom/select/center logic.
Future<void> showSearchPanelDialog(
  BuildContext context, {
  required EngineeringEngine engine,
  required EditingSession Function() session,
  required void Function(SearchResult result) onGoToResult,
}) async {
  final controller = TextEditingController();
  final navigation = engine.registry.navigation as NavigationService;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void runSearch(String query) {
            final results =
                engine.registry.search.search(session().graph, session().layout, query);
            navigation.setSearchResults(results);
            setState(() {});
          }

          final results = navigation.searchResults;
          final current = navigation.currentResult;

          return AlertDialog(
            title: const Text('Search'),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search nodes, relationships, symbols, labels, layers…',
                    ),
                    onChanged: runSearch,
                    onSubmitted: runSearch,
                  ),
                  const SizedBox(height: 8),
                  Text('${results.length} result(s)'),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return ListTile(
                          dense: true,
                          selected: result == current,
                          leading: Icon(_iconFor(result.kind)),
                          title: Text(result.label),
                          subtitle: Text('${result.kind.name} · ${result.matchedField}'),
                          onTap: () {
                            navigation.setSearchResults(results);
                            while (navigation.currentResult != result) {
                              navigation.nextResult();
                            }
                            setState(() {});
                            onGoToResult(result);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Previous result',
                onPressed: results.isEmpty
                    ? null
                    : () {
                        navigation.previousResult();
                        setState(() {});
                        final result = navigation.currentResult;
                        if (result != null) onGoToResult(result);
                      },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'Next result',
                onPressed: results.isEmpty
                    ? null
                    : () {
                        navigation.nextResult();
                        setState(() {});
                        final result = navigation.currentResult;
                        if (result != null) onGoToResult(result);
                      },
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

IconData _iconFor(SearchResultKind kind) {
  switch (kind) {
    case SearchResultKind.node:
      return Icons.category_outlined;
    case SearchResultKind.relationship:
      return Icons.timeline;
    case SearchResultKind.symbol:
      return Icons.widgets_outlined;
    case SearchResultKind.annotation:
      return Icons.sticky_note_2_outlined;
    case SearchResultKind.layer:
      return Icons.layers_outlined;
  }
}
