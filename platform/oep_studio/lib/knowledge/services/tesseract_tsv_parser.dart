import '../models/ocr_bounding_box.dart';
import '../models/ocr_word.dart';

/// One page's worth of parsed Tesseract TSV output — everything
/// [OcrPipelineService] needs to build an [OcrPageResult], before the
/// source fingerprint/engine version (which the caller supplies) are
/// attached.
class TesseractPageOutput {
  const TesseractPageOutput({required this.words, required this.imageWidth, required this.imageHeight});

  final List<OcrWord> words;
  final int imageWidth;
  final int imageHeight;
}

/// Pure parsing of Tesseract's `tsv` output format (`tesseract <input>
/// stdout tsv`) — no process invocation, no file I/O, so this can be
/// unit-tested against a captured string. `TesseractOcrEngine` is the
/// only caller, and the only place that actually runs the `tesseract`
/// process.
///
/// TSV columns (confirmed against a real `tesseract 5.4.0` install,
/// `docs/OCR_PIPELINE.md` § OCR Architecture): `level page_num
/// block_num par_num line_num word_num left top width height conf
/// text`. `level` `1` is the whole page (gives the image's pixel
/// width/height at `left=0, top=0`); `level` `5` is a word. Levels `2`
/// (block), `3` (paragraph), and `4` (line) are structural rows with no
/// text of their own and are skipped — Studio derives line grouping
/// from the `(block_num, par_num, line_num)` tuple on each *word* row
/// instead of reading it back off the level-4 rows, so a malformed or
/// missing level-4 row can never desynchronize word-to-line assignment.
abstract final class TesseractTsvParser {
  static const _pageLevel = 1;
  static const _wordLevel = 5;

  /// Throws [FormatException] if no level-1 (page) row is found — every
  /// well-formed `tesseract ... tsv` invocation emits exactly one,
  /// even for a blank page, so its absence means the output isn't TSV
  /// from this command at all (e.g. stderr text was captured instead).
  static TesseractPageOutput parse(String tsv) {
    // Tesseract emits CRLF line endings on Windows — splitting on '\n'
    // alone leaves a trailing '\r' attached to the text column (the
    // last column on each row), silently corrupting every recognized
    // word. Splitting on any of CRLF/CR/LF normalizes both platforms'
    // output identically.
    final lines = tsv.split(RegExp(r'\r\n|\r|\n'));
    int? imageWidth;
    int? imageHeight;
    final words = <OcrWord>[];

    // 0-based index assigned the first time a given (block, par, line)
    // triple is seen, in encounter order — matches Tesseract's own
    // reading-order traversal without depending on the level-4 rows.
    final lineIndexByKey = <String, int>{};

    for (final line in lines.skip(1)) {
      // Skip the header row.
      if (line.trim().isEmpty) continue;
      final columns = line.split('\t');
      if (columns.length < 12) continue; // Defensive: malformed row.
      final level = int.tryParse(columns[0]);
      if (level == null) continue;

      if (level == _pageLevel) {
        // Page row: ... left(6)=0 top(7)=0 width(8) height(9) ... — the
        // page's own pixel dimensions are columns 8/9, not 6/7 (which
        // are always 0 for the page-level row itself).
        imageWidth = int.tryParse(columns[8]);
        imageHeight = int.tryParse(columns[9]);
        continue;
      }
      if (level != _wordLevel) continue;

      final blockNum = columns[2];
      final parNum = columns[3];
      final lineNum = columns[4];
      final left = int.tryParse(columns[6]);
      final top = int.tryParse(columns[7]);
      final width = int.tryParse(columns[8]);
      final height = int.tryParse(columns[9]);
      final conf = double.tryParse(columns[10]);
      // The text column is last but may itself have been split further
      // if it happened to contain a literal tab — rejoin defensively.
      final text = columns.sublist(11).join('\t');
      if (left == null || top == null || width == null || height == null || conf == null) continue;
      if (text.isEmpty) continue;

      final lineKey = '$blockNum/$parNum/$lineNum';
      final lineIndex = lineIndexByKey.putIfAbsent(lineKey, () => lineIndexByKey.length);

      final pageWidth = imageWidth ?? 1;
      final pageHeight = imageHeight ?? 1;
      words.add(
        OcrWord(
          text: text,
          confidence: (conf / 100).clamp(0.0, 1.0),
          boundingBox: OcrBoundingBox(
            x: pageWidth == 0 ? 0 : left / pageWidth,
            y: pageHeight == 0 ? 0 : top / pageHeight,
            width: pageWidth == 0 ? 0 : width / pageWidth,
            height: pageHeight == 0 ? 0 : height / pageHeight,
          ),
          readingOrder: words.length,
          lineIndex: lineIndex,
        ),
      );
    }

    if (imageWidth == null || imageHeight == null) {
      throw const FormatException('No page-level row found in Tesseract TSV output.');
    }
    return TesseractPageOutput(words: words, imageWidth: imageWidth, imageHeight: imageHeight);
  }
}
