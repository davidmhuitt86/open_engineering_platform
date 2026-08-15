import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import '../models/ocr_page_result.dart';
import '../models/ocr_processing_exception.dart';
import '../models/source_material.dart';
import '../models/source_material_type.dart';
import 'ocr_cache_service.dart';
import 'tesseract_ocr_engine.dart';

/// OCR processing orchestration (Work Package 013 STUDIO-TASK-000034/
/// 000037) — the only service that both renders pages *and* calls
/// [TesseractOcrEngine]. Holds no state of its own; the Connection
/// Manager stores whatever this returns.
///
/// "OCR shall operate per page" for every supported type uniformly —
/// a PDF page is rendered to an image first (the *same* per-page-image
/// input every other supported type already is), rather than using
/// `pdfrx`'s own embedded-text extraction
/// (`PdfPage.loadText`/`loadStructuredText`) for born-digital PDFs.
/// That capability reads a PDF's *embedded* text objects — a different
/// thing from OCR, with no confidence score and no involvement of the
/// chosen OCR engine at all — and using it selectively would mean two
/// different data paths (embedded-text vs. true OCR) with different
/// confidence semantics for what this work package treats as one
/// pipeline. See `docs/OCR_PIPELINE.md` § Architectural Observations.
abstract final class OcrPipelineService {
  /// Pages are rendered at this DPI before OCR — high enough for
  /// reliable text recognition on typical scanned engineering documents
  /// (300 DPI is the standard baseline most OCR guidance recommends;
  /// higher costs more time/memory for diminishing accuracy gains on
  /// already-clean source scans, lower measurably hurts recognition of
  /// small print such as torque callouts or part-number tables).
  static const _renderDpi = 300.0;

  /// Runs OCR for every page of [source] that needs it — new pages, or
  /// pages whose cached result is stale (`OcrCacheService`) — and
  /// returns this source's **complete** updated result list (already-
  /// valid cached pages merged with freshly (re)computed ones, sorted
  /// by page). [existingResults] may contain other sources' results
  /// too; only [source]'s own are read or returned. Throws
  /// [OcrProcessingException] if the OCR engine itself is unavailable
  /// (checked once, before any page work) — a missing engine is a
  /// pipeline-wide failure, not a per-page one. Per-page rendering/
  /// recognition failures do not abort the rest of the document; they
  /// produce a failed [OcrPageResult] for that page only.
  static Future<List<OcrPageResult>> processSource({
    required SourceMaterial source,
    required List<OcrPageResult> existingResults,
  }) async {
    if (!await TesseractOcrEngine.isAvailable()) {
      throw const OcrProcessingException(
        'Tesseract OCR is not installed. Install it and ensure "tesseract" is on PATH before running OCR.',
      );
    }
    final fingerprint = await OcrCacheService.computeFingerprint(File(source.localPath));
    final existingForSource = existingResults.where((result) => result.sourceId == source.id).toList();
    final pageCount = await _pageCountFor(source);
    final pagesToProcess = OcrCacheService.pagesNeedingProcessing(
      existingResults: existingForSource,
      pageCount: pageCount,
      currentFingerprint: fingerprint,
    );

    if (pagesToProcess.isEmpty) {
      return existingForSource..sort((a, b) => a.page.compareTo(b.page));
    }

    final engineVersion = await TesseractOcrEngine.engineVersion();
    final freshResults = <int, OcrPageResult>{};

    if (source.type == SourceMaterialType.pdf) {
      final document = await PdfDocument.openFile(source.localPath);
      try {
        for (final page in pagesToProcess) {
          freshResults[page] = await _processPdfPage(
            document: document,
            page: page,
            source: source,
            fingerprint: fingerprint,
            engineVersion: engineVersion,
          );
        }
      } finally {
        await document.dispose();
      }
    } else {
      // A single-page image source (PNG/JPG/TIFF) — Tesseract reads the
      // Source Material file directly; no rendering step is needed.
      freshResults[1] = await _processImagePage(
        source: source,
        fingerprint: fingerprint,
        engineVersion: engineVersion,
      );
    }

    final stillValidPageNumbers = existingForSource.map((result) => result.page).toSet()
      ..removeAll(pagesToProcess);
    final merged = [
      for (final result in existingForSource)
        if (stillValidPageNumbers.contains(result.page)) result,
      ...freshResults.values,
    ]..sort((a, b) => a.page.compareTo(b.page));
    return merged;
  }

  static Future<int> _pageCountFor(SourceMaterial source) async {
    if (source.type != SourceMaterialType.pdf) return 1;
    final document = await PdfDocument.openFile(source.localPath);
    try {
      return document.pages.length;
    } finally {
      await document.dispose();
    }
  }

  static Future<OcrPageResult> _processPdfPage({
    required PdfDocument document,
    required int page,
    required SourceMaterial source,
    required String fingerprint,
    required String engineVersion,
  }) async {
    final now = DateTime.now();
    try {
      final pdfPage = document.pages[page - 1];
      final scale = _renderDpi / 72.0;
      final image = await pdfPage.render(fullWidth: pdfPage.width * scale, fullHeight: pdfPage.height * scale);
      if (image == null) {
        return OcrPageResult(
          sourceId: source.id,
          page: page,
          words: const [],
          imageWidth: 0,
          imageHeight: 0,
          sourceFingerprint: fingerprint,
          engineVersion: engineVersion,
          processedTime: now,
          success: false,
          errorMessage: 'This page could not be rendered.',
        );
      }
      final tempFile = await _writeTempPng(image);
      try {
        final output = await TesseractOcrEngine.recognizePage(tempFile.path);
        return OcrPageResult(
          sourceId: source.id,
          page: page,
          words: output.words,
          imageWidth: output.imageWidth,
          imageHeight: output.imageHeight,
          sourceFingerprint: fingerprint,
          engineVersion: engineVersion,
          processedTime: now,
          success: true,
        );
      } finally {
        image.dispose();
        if (await tempFile.exists()) await tempFile.delete();
      }
    } on OcrProcessingException catch (error) {
      return OcrPageResult(
        sourceId: source.id,
        page: page,
        words: const [],
        imageWidth: 0,
        imageHeight: 0,
        sourceFingerprint: fingerprint,
        engineVersion: engineVersion,
        processedTime: now,
        success: false,
        errorMessage: error.message,
      );
    }
  }

  static Future<OcrPageResult> _processImagePage({
    required SourceMaterial source,
    required String fingerprint,
    required String engineVersion,
  }) async {
    final now = DateTime.now();
    try {
      final output = await TesseractOcrEngine.recognizePage(source.localPath);
      return OcrPageResult(
        sourceId: source.id,
        page: 1,
        words: output.words,
        imageWidth: output.imageWidth,
        imageHeight: output.imageHeight,
        sourceFingerprint: fingerprint,
        engineVersion: engineVersion,
        processedTime: now,
        success: true,
      );
    } on OcrProcessingException catch (error) {
      return OcrPageResult(
        sourceId: source.id,
        page: 1,
        words: const [],
        imageWidth: 0,
        imageHeight: 0,
        sourceFingerprint: fingerprint,
        engineVersion: engineVersion,
        processedTime: now,
        success: false,
        errorMessage: error.message,
      );
    }
  }

  /// Converts a rendered [PdfImage]'s raw BGRA8888 pixels into a
  /// temporary PNG file Tesseract's CLI can read by path — `dart:ui`'s
  /// own pixel-to-image decode/encode (`decodeImageFromPixels` +
  /// `Image.toByteData(format: ui.ImageByteFormat.png)`), a Flutter
  /// framework capability, not a new package.
  static Future<File> _writeTempPng(PdfImage image) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      image.pixels,
      image.width,
      image.height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    final uiImage = await completer.future;
    try {
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final tempFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}oep_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(pngBytes);
      return tempFile;
    } finally {
      uiImage.dispose();
    }
  }
}
