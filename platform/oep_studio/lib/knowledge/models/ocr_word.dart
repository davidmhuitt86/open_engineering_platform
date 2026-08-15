import 'ocr_bounding_box.dart';

/// One recognized word (Work Package 013 STUDIO-TASK-000034: "Each page
/// produces: Text, Confidence, Bounding Boxes, Reading Order"). The
/// atomic unit of OCR output — [OcrPageResult.plainText] joins these in
/// [readingOrder], and the OCR Layer Viewer's overlay/confidence heat
/// map/search all operate on this list directly rather than on a
/// separately-derived text string, so a search match or a heat-map cell
/// always corresponds to exactly one on-page rectangle.
class OcrWord {
  const OcrWord({
    required this.text,
    required this.confidence,
    required this.boundingBox,
    required this.readingOrder,
    required this.lineIndex,
  });

  final String text;

  /// `0.0`–`1.0`, normalized from Tesseract's own `0`–`100` scale (see
  /// `docs/OCR_PIPELINE.md` § Confidence Model).
  final double confidence;

  final OcrBoundingBox boundingBox;

  /// 0-based position within [OcrPageResult.words]' reading order —
  /// Tesseract's own block/paragraph/line/word hierarchy, top-to-bottom
  /// then left-to-right, not re-sorted by Studio. Redundant with the
  /// word's index in the list (words are always stored already in this
  /// order) but kept as an explicit field so a UI or test referencing
  /// one word doesn't need to also carry "and it was list index N" —
  /// the word is self-describing.
  final int readingOrder;

  /// Which line (Tesseract's own line grouping, 0-based, unique only
  /// within one page) this word belongs to — lets
  /// [OcrPageResult.plainText] insert a line break between words on
  /// different lines rather than joining every word on a page with a
  /// single space.
  final int lineIndex;

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'boundingBox': boundingBox.toJson(),
    'readingOrder': readingOrder,
    'lineIndex': lineIndex,
  };

  factory OcrWord.fromJson(Map<String, dynamic> json) {
    return OcrWord(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: OcrBoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>),
      readingOrder: json['readingOrder'] as int,
      lineIndex: json['lineIndex'] as int,
    );
  }
}
