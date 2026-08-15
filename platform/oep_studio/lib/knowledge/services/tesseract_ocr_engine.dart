import 'dart:convert';
import 'dart:io';

import '../models/ocr_processing_exception.dart';
import 'tesseract_tsv_parser.dart';

/// The only place in Studio that invokes an external OCR process (Work
/// Package 013's "Keep OCR processing ... inside services" — this
/// class is the service). `OcrPipelineService` is the only caller.
///
/// Wraps a system-installed Tesseract OCR (`docs/OCR_PIPELINE.md` §
/// Package Selection Rationale for why Tesseract, invoked as an
/// external process via its `tsv` output format, was chosen over every
/// Flutter-plugin alternative found). Tesseract is **not bundled** with
/// `oep_studio.exe` the way `pdfium.dll`/`oep_foundation_bridge.dll`
/// are — no suitable Dart package exists to bundle it automatically,
/// the same way none existed to wrap it either. Studio depends on a
/// system-installed `tesseract` the same way its own build toolchain
/// depends on a system-installed `flutter`/`cmake`, and fails clearly
/// (never silently) when it's absent — see [isAvailable].
abstract final class TesseractOcrEngine {
  static const _windowsInstallPaths = [
    r'C:\Program Files\Tesseract-OCR\tesseract.exe',
    r'C:\Program Files (x86)\Tesseract-OCR\tesseract.exe',
  ];

  static String? _resolvedExecutablePath;
  static String? _resolvedVersion;

  /// Locates the `tesseract` executable — a known Windows install path
  /// first, then falls back to whatever `tesseract` resolves to on
  /// `PATH` (covers non-default install locations and other
  /// platforms). Result is cached for the lifetime of the process; a
  /// system-installed engine does not appear or disappear mid-session
  /// in practice, and re-probing before every page would add latency
  /// for no benefit.
  static Future<String?> _resolveExecutablePath() async {
    final cached = _resolvedExecutablePath;
    if (cached != null) return cached;
    for (final path in _windowsInstallPaths) {
      if (await File(path).exists()) {
        _resolvedExecutablePath = path;
        return path;
      }
    }
    try {
      final result = await Process.run('tesseract', const ['--version']);
      if (result.exitCode == 0) {
        _resolvedExecutablePath = 'tesseract';
        return 'tesseract';
      }
    } catch (_) {
      // Not found on PATH — fall through to null.
    }
    return null;
  }

  /// Whether a usable Tesseract installation was found — the OCR Layer
  /// Viewer checks this before offering to run OCR, so a missing engine
  /// shows a clear, professional message rather than a raw process
  /// failure the first time an engineer opens it.
  static Future<bool> isAvailable() async => await _resolveExecutablePath() != null;

  /// `"Tesseract 5.4.0.20240606"` — parsed from `tesseract --version`'s
  /// first line, cached the same way [_resolveExecutablePath] is.
  /// Throws [OcrProcessingException] if the engine isn't available.
  static Future<String> engineVersion() async {
    final cachedVersion = _resolvedVersion;
    if (cachedVersion != null) return cachedVersion;
    final path = await _resolveExecutablePath();
    if (path == null) {
      throw const OcrProcessingException(
        'Tesseract OCR is not installed. Install it and ensure "tesseract" is on PATH before running OCR.',
      );
    }
    final result = await Process.run(path, const ['--version']);
    final firstLine = (result.stdout as String).split('\n').first.trim();
    // Tesseract prints e.g. "tesseract 5.4.0.20240606" on the first line.
    final version = firstLine.startsWith('tesseract ')
        ? 'Tesseract ${firstLine.substring('tesseract '.length)}'
        : firstLine;
    _resolvedVersion = version;
    return version;
  }

  /// Runs OCR on the image at [imagePath] (already-rendered page image
  /// for a PDF; the Source Material file directly for PNG/JPG/TIFF) and
  /// returns its structured result. Throws [OcrProcessingException] if
  /// the engine is unavailable or the process fails.
  static Future<TesseractPageOutput> recognizePage(String imagePath) async {
    final path = await _resolveExecutablePath();
    if (path == null) {
      throw const OcrProcessingException(
        'Tesseract OCR is not installed. Install it and ensure "tesseract" is on PATH before running OCR.',
      );
    }
    final ProcessResult result;
    try {
      result = await Process.run(
        path,
        [imagePath, 'stdout', 'tsv'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (error) {
      throw OcrProcessingException('OCR could not be run: ${error.message}');
    }
    if (result.exitCode != 0) {
      throw OcrProcessingException(
        'OCR failed for this page (exit code ${result.exitCode}). ${(result.stderr as String).trim()}'.trim(),
      );
    }
    try {
      return TesseractTsvParser.parse(result.stdout as String);
    } on FormatException catch (error) {
      throw OcrProcessingException('OCR produced an unreadable result: ${error.message}');
    }
  }
}
