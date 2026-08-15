import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/engineering_context.dart';
import '../models/engineering_context_type.dart';
import '../models/engineering_entity.dart';
import '../models/ocr_bounding_box.dart';
import '../models/ocr_page_result.dart';
import '../models/ocr_word.dart';
import '../models/source_material.dart';
import 'knowledge_session_service.dart';

/// One OCR line, reconstructed exactly the way
/// `EngineeringEntityExtractionService`/`OcrSearchService` already do
/// (words sharing an `OcrWord.lineIndex`, in encounter order) — kept
/// here rather than shared, since this work package reads slightly
/// different fields (word count, line height) than either of those.
class _Line {
  _Line({required this.page, required this.lineIndex, required this.words})
    : text = words.map((w) => w.text).join(' '),
      boundingBox = ContextDetectionService._unionBoundingBox(words.map((w) => w.boundingBox).toList()),
      averageConfidence = words.map((w) => w.confidence).reduce((a, b) => a + b) / words.length;

  final int page;
  final int lineIndex;
  final List<OcrWord> words;
  final String text;
  final OcrBoundingBox boundingBox;
  final double averageConfidence;

  /// Whether this line's position is at or after [other]'s.
  bool isAtOrAfter(_Line other) {
    if (page != other.page) return page > other.page;
    return lineIndex >= other.lineIndex;
  }

  /// Whether this line's position is strictly before [other]'s.
  bool isBefore(_Line other) {
    if (page != other.page) return page < other.page;
    return lineIndex < other.lineIndex;
  }
}

enum _Tier { major, minor }

class _Heading {
  _Heading({required this.line, required this.type, required this.tier, required this.matchStrength});

  final _Line line;
  final EngineeringContextType type;
  final _Tier tier;

  /// How confidently this line was recognized as a heading — folded
  /// into the resulting Context's own `confidence` alongside the
  /// line's real OCR word confidence (see `_buildContext`).
  final double matchStrength;
}

/// The Engineering Context Detection Engine (Work Package 015
/// STUDIO-TASK-000042): "Identify logical engineering contexts using
/// deterministic document structure... Contexts are derived from: OCR
/// layout, Heading hierarchy, Page structure, Tables, Entity
/// proximity. No AI." Pure — no I/O, no randomness; the same OCR and
/// entity input always produces the same contexts.
///
/// See `docs/ENGINEERING_CONTEXT.md` § Detection Rules for the full
/// heuristic account (heading/callout keyword matching, the
/// major/minor tiering that produces parent/child nesting, and the
/// whole-source cache-reuse contract).
abstract final class ContextDetectionService {
  /// Detects (or reuses already-detected) contexts for every page of
  /// [source]'s [ocrResults], using [entities] for the "entity
  /// proximity" signal. [existingContexts] may contain other sources'
  /// contexts too; only [source]'s own are read or returned. Unlike
  /// `EngineeringEntityExtractionService`'s per-page cache reuse,
  /// contexts are re-derived as a **whole document** together (a
  /// context can span multiple pages) — if [source]'s combined OCR
  /// fingerprint is unchanged, every existing context for this source
  /// is returned completely unchanged, preserving any
  /// `EngineeringContextStatus` the engineer already assigned;
  /// otherwise the entire source is freshly re-detected.
  static List<EngineeringContext> detectForSource({
    required SourceMaterial source,
    required List<OcrPageResult> ocrResults,
    required List<EngineeringEntity> entities,
    required List<EngineeringContext> existingContexts,
  }) {
    final pages = ocrResults.where((r) => r.sourceId == source.id && r.success).toList()
      ..sort((a, b) => a.page.compareTo(b.page));
    final existingForSource = existingContexts.where((c) => c.sourceId == source.id).toList();
    if (pages.isEmpty) return const [];

    final combinedFingerprint = computeCombinedFingerprint(pages);
    if (existingForSource.isNotEmpty && existingForSource.every((c) => c.sourceFingerprint == combinedFingerprint)) {
      return existingForSource;
    }

    final lines = _buildLines(pages);
    if (lines.isEmpty) return const [];

    final entitiesForSource = entities.where((e) => e.sourceId == source.id).toList();
    final entityLines = _resolveEntityLines(entitiesForSource, lines);

    final medianHeight = _medianHeight(lines);
    final headings = _detectHeadings(lines, medianHeight);
    if (headings.isEmpty) return const [];

    final now = DateTime.now();
    final majorHeadings = headings.where((h) => h.tier == _Tier.major).toList();
    final majors = <EngineeringContext>[
      for (var i = 0; i < majorHeadings.length; i++)
        _buildContext(
          source: source,
          heading: majorHeadings[i],
          endExclusive: i + 1 < majorHeadings.length ? majorHeadings[i + 1].line : null,
          lines: lines,
          entities: entitiesForSource,
          entityLines: entityLines,
          combinedFingerprint: combinedFingerprint,
          now: now,
          parentContextId: null,
        ),
    ];

    final result = <EngineeringContext>[...majors];
    for (var i = 0; i < headings.length; i++) {
      final heading = headings[i];
      if (heading.tier != _Tier.minor) continue;
      final endExclusive = i + 1 < headings.length ? headings[i + 1].line : null;
      // The enclosing major is the *last* major heading positioned
      // before this minor one — not "any major whose page range
      // happens to include this page number," which incorrectly
      // treats a callout preceding a heading on the very same page as
      // already inside that heading's section. Position (page, line),
      // not page alone, is what actually determines containment.
      EngineeringContext? parent;
      for (var m = 0; m < majorHeadings.length; m++) {
        if (majorHeadings[m].line.isBefore(heading.line)) {
          parent = majors[m];
        }
      }
      result.add(
        _buildContext(
          source: source,
          heading: heading,
          endExclusive: endExclusive,
          lines: lines,
          entities: entitiesForSource,
          entityLines: entityLines,
          combinedFingerprint: combinedFingerprint,
          now: now,
          parentContextId: parent?.id,
        ),
      );
    }

    result.sort((a, b) {
      final pageCompare = a.pageStart.compareTo(b.pageStart);
      return pageCompare != 0 ? pageCompare : a.title.compareTo(b.title);
    });
    return result;
  }

  /// SHA-256 of every page's own `OcrPageResult.sourceFingerprint`,
  /// concatenated in page order — see `detectForSource`'s own doc
  /// comment for why this is whole-source rather than per-page.
  static String computeCombinedFingerprint(List<OcrPageResult> pages) {
    final joined = pages.map((p) => p.sourceFingerprint).join('|');
    return sha256.convert(utf8.encode(joined)).toString();
  }

  /// Public wrapper around the same bounding-box union math this
  /// service uses internally — `FoundationRuntimeNotifier.mergeContexts`
  /// reuses it rather than duplicating the union formula.
  static OcrBoundingBox unionBoundingBoxOf(List<OcrBoundingBox> boxes) => _unionBoundingBox(boxes);

  static List<_Line> _buildLines(List<OcrPageResult> pages) {
    final lines = <_Line>[];
    for (final page in pages) {
      final byLine = <int, List<OcrWord>>{};
      for (final word in page.words) {
        byLine.putIfAbsent(word.lineIndex, () => []).add(word);
      }
      final orderedIndices = byLine.keys.toList()..sort();
      for (final lineIndex in orderedIndices) {
        lines.add(_Line(page: page.page, lineIndex: lineIndex, words: byLine[lineIndex]!));
      }
    }
    return lines;
  }

  /// Locates the exact line each entity was matched from, by
  /// reconstructing the same line text `EngineeringEntityExtractionService`
  /// built and slicing it at the entity's own recorded
  /// `[characterStart, characterEnd)` — a precise cross-check (not just
  /// "this text appears somewhere on this line") since it validates
  /// both the substring content and its exact offset. An entity whose
  /// line cannot be resolved this way (only possible if the OCR
  /// underlying it has since changed) is simply left unmapped — see
  /// `_buildContext`'s fallback below.
  static Map<String, _Line> _resolveEntityLines(List<EngineeringEntity> entities, List<_Line> lines) {
    final byPage = <int, List<_Line>>{};
    for (final line in lines) {
      byPage.putIfAbsent(line.page, () => []).add(line);
    }
    final resolved = <String, _Line>{};
    for (final entity in entities) {
      for (final line in byPage[entity.page] ?? const <_Line>[]) {
        if (entity.characterEnd > line.text.length) continue;
        if (line.text.substring(entity.characterStart, entity.characterEnd) == entity.extractedText) {
          resolved[entity.id] = line;
          break;
        }
      }
    }
    return resolved;
  }

  static double _medianHeight(List<_Line> lines) {
    final heights = lines.map((l) => l.boundingBox.height).toList()..sort();
    if (heights.isEmpty) return 0;
    return heights[heights.length ~/ 2];
  }

  /// Callout keywords (Warning/Note) are recognized regardless of line
  /// height — real service manuals typically print these inline, at
  /// body text size, not as a larger section heading. Every other
  /// context type requires *both* a keyword match *and* a short,
  /// larger-than-median line — the layout signal that distinguishes an
  /// actual section heading from the same word appearing incidentally
  /// inside a body paragraph.
  static List<_Heading> _detectHeadings(List<_Line> lines, double medianHeight) {
    final headings = <_Heading>[];
    for (final line in lines) {
      final calloutType = _matchCallout(line.text);
      if (calloutType != null) {
        headings.add(_Heading(line: line, type: calloutType, tier: _Tier.minor, matchStrength: 0.95));
        continue;
      }
      final wordCount = line.words.length;
      if (wordCount == 0 || wordCount > 8) continue;
      if (line.boundingBox.height <= medianHeight * 1.15) continue;
      final type = _matchSectionKeyword(line.text);
      if (type == null) continue;
      final tier = _majorTypes.contains(type) ? _Tier.major : _Tier.minor;
      headings.add(_Heading(line: line, type: type, tier: tier, matchStrength: 0.85));
    }
    return headings;
  }

  static const _majorTypes = {
    EngineeringContextType.procedure,
    EngineeringContextType.component,
    EngineeringContextType.connector,
    EngineeringContextType.circuit,
    EngineeringContextType.wiringSection,
    EngineeringContextType.torqueTable,
    EngineeringContextType.specificationTable,
    EngineeringContextType.partsList,
  };

  static EngineeringContextType? _matchCallout(String text) {
    final trimmed = text.trim();
    if (RegExp(r'^(WARNING|CAUTION|DANGER)\b', caseSensitive: false).hasMatch(trimmed)) {
      return EngineeringContextType.warning;
    }
    if (RegExp(r'^NOTE\b', caseSensitive: false).hasMatch(trimmed)) {
      return EngineeringContextType.note;
    }
    return null;
  }

  /// Checked in this order deliberately: "torque" is checked before
  /// the generic "specification" keyword so a line like "Torque
  /// Specification Table" classifies as a Torque Table, the more
  /// specific of the two named types, not the generic Specification
  /// Table.
  static EngineeringContextType? _matchSectionKeyword(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('torque')) return EngineeringContextType.torqueTable;
    if (lower.contains('parts list') || lower.contains('parts catalog') || lower.contains('bill of materials')) {
      return EngineeringContextType.partsList;
    }
    if (lower.contains('specification')) return EngineeringContextType.specificationTable;
    if (lower.contains('wiring') || lower.contains('harness')) return EngineeringContextType.wiringSection;
    if (lower.contains('circuit')) return EngineeringContextType.circuit;
    if (lower.contains('connector')) return EngineeringContextType.connector;
    if (lower.contains('component')) return EngineeringContextType.component;
    if (lower.contains('procedure')) return EngineeringContextType.procedure;
    if (lower.contains('figure')) return EngineeringContextType.figure;
    if (lower.contains('diagram') || lower.contains('schematic')) return EngineeringContextType.diagram;
    return null;
  }

  static EngineeringContext _buildContext({
    required SourceMaterial source,
    required _Heading heading,
    required _Line? endExclusive,
    required List<_Line> lines,
    required List<EngineeringEntity> entities,
    required Map<String, _Line> entityLines,
    required String combinedFingerprint,
    required DateTime now,
    required String? parentContextId,
  }) {
    final childEntities = entities.where((entity) {
      final line = entityLines[entity.id];
      // Fallback for an entity whose exact line could not be resolved
      // (see `_resolveEntityLines`): fall back to page-only
      // containment, strictly interior pages only, to avoid
      // double-counting an entity across two contexts sharing a
      // boundary page.
      if (line == null) {
        return endExclusive == null
            ? entity.page > heading.line.page
            : entity.page > heading.line.page && entity.page < endExclusive.page;
      }
      final afterStart = line.isAtOrAfter(heading.line);
      final beforeEnd = endExclusive == null || line.isBefore(endExclusive);
      return afterStart && beforeEnd;
    }).toList();

    // Page range reflects the actual document content between this
    // heading and the next one (of the same tier-appropriate scope),
    // not merely "the next heading's own page" — a Procedure section
    // several blank-of-headings pages long should report its true
    // extent, and a heading that itself isn't the first line on its
    // page still claims that page's preceding content.
    final pageStart = heading.line.page;
    final rangeLines = lines.where(
      (line) => line.isAtOrAfter(heading.line) && (endExclusive == null || line.isBefore(endExclusive)),
    );
    final pageEnd = rangeLines.isEmpty ? pageStart : rangeLines.map((l) => l.page).reduce((a, b) => a > b ? a : b);

    final boxes = [heading.line.boundingBox, ...childEntities.map((e) => e.boundingBox)];
    final boundingRegion = _unionBoundingBox(boxes);
    final confidence = (heading.matchStrength * heading.line.averageConfidence).clamp(0.0, 1.0);

    return EngineeringContext(
      id: KnowledgeSessionService.generateId('context'),
      type: heading.type,
      title: heading.line.text.trim(),
      sourceId: source.id,
      pageStart: pageStart,
      pageEnd: pageEnd,
      boundingRegion: boundingRegion,
      childEntityIds: [for (final entity in childEntities) entity.id],
      confidence: confidence,
      sourceFingerprint: combinedFingerprint,
      detectedTime: now,
      parentContextId: parentContextId,
    );
  }

  static OcrBoundingBox _unionBoundingBox(List<OcrBoundingBox> boxes) {
    var minX = boxes.first.x;
    var minY = boxes.first.y;
    var maxX = boxes.first.x + boxes.first.width;
    var maxY = boxes.first.y + boxes.first.height;
    for (final box in boxes.skip(1)) {
      if (box.x < minX) minX = box.x;
      if (box.y < minY) minY = box.y;
      if (box.x + box.width > maxX) maxX = box.x + box.width;
      if (box.y + box.height > maxY) maxY = box.y + box.height;
    }
    return OcrBoundingBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY);
  }
}
