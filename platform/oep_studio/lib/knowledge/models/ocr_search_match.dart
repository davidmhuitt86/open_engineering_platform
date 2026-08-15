/// One Find match (Work Package 013 STUDIO-TASK-000036) — the OCR
/// words on [page] that together contain the matched text, so the OCR
/// Layer Viewer can highlight every overlapping bounding box for one
/// match rather than only a single word (a multi-word query spans more
/// than one [OcrWord]).
class OcrSearchMatch {
  const OcrSearchMatch({required this.page, required this.wordIndices});

  /// 1-based page number, matching [OcrPageResult.page].
  final int page;

  /// Indices into that page's [OcrPageResult.words] — the words this
  /// match's text overlaps, in reading order.
  final List<int> wordIndices;
}
