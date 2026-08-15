import '../models/ocr_page_result.dart';
import '../models/ocr_search_match.dart';

/// "Searchable Documents" (Work Package 013 STUDIO-TASK-000036): "OCR
/// text becomes searchable. Support: Find, Find Next, Highlight. Search
/// remains local to Source Material." Pure — takes one source's already
/// -cached [OcrPageResult]s and a query, returns ordered matches; holds
/// no state itself (the OCR Layer Viewer dialog owns "which match is
/// current" as its own local, ephemeral widget state, the same way
/// `PdfSourceViewer` owns its drag-gesture state — see
/// `docs/OCR_PIPELINE.md` § Search Model for why this is local widget
/// state rather than Connection Manager state).
///
/// Matching is case-insensitive substring search over each **line's**
/// reconstructed text (words on the same [OcrWord.lineIndex], joined by
/// a single space) — not per-word-only — so a multi-word query like
/// "torque spec" matches even though "Torque" and "Spec" are two
/// separate [OcrWord]s. Deliberately does not search across a line
/// break: "OCR is deterministic" reads most naturally as "match what a
/// human reading the page would visually recognize as one phrase,"
/// which a line boundary already delimits for printed engineering text
/// (a torque callout table row, a parts-list line) far more often than
/// it splits one.
abstract final class OcrSearchService {
  /// Every occurrence of [query] (trimmed, case-insensitive) across
  /// [pageResults] — already filtered to one source and sorted by page
  /// by the caller — in page then reading order. Returns `[]` for a
  /// blank query.
  static List<OcrSearchMatch> find({required List<OcrPageResult> pageResults, required String query}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final lowerQuery = trimmed.toLowerCase();
    final matches = <OcrSearchMatch>[];

    for (final pageResult in pageResults) {
      final lineWordIndices = <int, List<int>>{};
      for (var i = 0; i < pageResult.words.length; i++) {
        lineWordIndices.putIfAbsent(pageResult.words[i].lineIndex, () => []).add(i);
      }
      // Iterate lines in first-word-encountered order, matching the
      // page's overall reading order (words are always stored already
      // in reading order, so each line's word-index list is too).
      final orderedLines = lineWordIndices.values.toList()..sort((a, b) => a.first.compareTo(b.first));

      for (final wordIndices in orderedLines) {
        final starts = <int>[];
        final buffer = StringBuffer();
        for (final index in wordIndices) {
          starts.add(buffer.length);
          buffer.write(pageResult.words[index].text);
          buffer.write(' ');
        }
        final lineText = buffer.toString().toLowerCase();

        var searchFrom = 0;
        while (true) {
          final foundAt = lineText.indexOf(lowerQuery, searchFrom);
          if (foundAt == -1) break;
          final matchEnd = foundAt + lowerQuery.length;
          final overlapping = <int>[
            for (var k = 0; k < wordIndices.length; k++)
              if (starts[k] < matchEnd && starts[k] + pageResult.words[wordIndices[k]].text.length > foundAt)
                wordIndices[k],
          ];
          if (overlapping.isNotEmpty) {
            matches.add(OcrSearchMatch(page: pageResult.page, wordIndices: overlapping));
          }
          searchFrom = foundAt + 1;
        }
      }
    }
    return matches;
  }
}
