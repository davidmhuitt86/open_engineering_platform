import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// Search panel — queries the Engine's `SearchService` against both the
/// Engineering Graph and Diagram Layout (WORK_PACKAGE_024,
/// ENGINE-TASK-000114; `oep_engine/docs/SEARCH_AND_NAVIGATION.md`). A
/// Studio-styled port of the Demonstration Host's Search Panel dialog.
class DiagramSearchPanel extends StatefulWidget {
  const DiagramSearchPanel({
    required this.search,
    required this.onGoToResult,
    super.key,
  });

  /// Runs a query against the current graph/layout and returns matches.
  final List<SearchResult> Function(String query) search;
  final void Function(SearchResult result) onGoToResult;

  @override
  State<DiagramSearchPanel> createState() => _DiagramSearchPanelState();
}

class _DiagramSearchPanelState extends State<DiagramSearchPanel> {
  final _controller = TextEditingController();
  List<SearchResult> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    setState(() => _results = query.trim().isEmpty ? const [] : widget.search(query.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: TextField(
            controller: _controller,
            onChanged: _runSearch,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              prefixIcon: Icon(Icons.search, size: 16),
              hintText: 'Search nodes, relationships, annotations, layers…',
            ),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    _controller.text.isEmpty ? 'Type to search.' : 'No matches.',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        result.label,
                        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                      ),
                      subtitle: Text(
                        '${result.kind.name} · matched ${result.matchedField}',
                        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                      ),
                      onTap: () => widget.onGoToResult(result),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
