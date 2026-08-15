import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/ocr_page_result.dart';

/// OCR Session Cache logic (Work Package 013 STUDIO-TASK-000037): "OCR
/// results shall persist. Reopening a session shall not rerun OCR.
/// Support cache invalidation when Source Material changes."
///
/// [computeFingerprint] does real file I/O (reading the whole file to
/// hash it) — everything else here is a pure decision over already-
/// computed fingerprints/already-loaded [OcrPageResult]s, so the
/// invalidation *logic* itself is unit-testable without touching disk.
abstract final class OcrCacheService {
  /// A SHA-256 hex digest of [file]'s current bytes
  /// (`docs/OCR_PIPELINE.md` § OCR Cache: why content-based, not
  /// file-system-metadata-based). Reads the whole file — for a large
  /// multi-hundred-page manual this is a bounded, one-time-per-check
  /// cost, small next to the OCR run it might save.
  static Future<String> computeFingerprint(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Whether [existingResults] (already filtered to one source's
  /// results by the caller) has a valid, reusable entry for [page]
  /// against [currentFingerprint] — `true` only if a *successful*
  /// result exists whose [OcrPageResult.sourceFingerprint] matches
  /// exactly. A previously-*failed* page is always considered stale
  /// (never cached as a permanent failure) so a transient error (e.g.
  /// the engine was briefly unavailable) doesn't permanently block that
  /// page from ever being retried on a later session open.
  static bool isCacheValid({
    required List<OcrPageResult> existingResults,
    required int page,
    required String currentFingerprint,
  }) {
    for (final result in existingResults) {
      if (result.page == page) {
        return result.success && result.sourceFingerprint == currentFingerprint;
      }
    }
    return false;
  }

  /// Every page number in `1..pageCount` that needs (re)processing
  /// against [currentFingerprint] — either because no cached result
  /// exists yet or because the cached one is stale (see
  /// [isCacheValid]).
  static List<int> pagesNeedingProcessing({
    required List<OcrPageResult> existingResults,
    required int pageCount,
    required String currentFingerprint,
  }) {
    return [
      for (var page = 1; page <= pageCount; page++)
        if (!isCacheValid(existingResults: existingResults, page: page, currentFingerprint: currentFingerprint))
          page,
    ];
  }
}
