import 'package:flutter/material.dart';

/// The kinds of Source Material Work Package 008 STUDIO-TASK-000016
/// supports attaching: "Supported initially: PDF, Images, Markdown,
/// Text." No OCR, no parsing — Studio only manages the evidence file
/// itself.
enum SourceMaterialType {
  pdf('PDF', Icons.picture_as_pdf_outlined),
  image('Image', Icons.image_outlined),
  markdown('Markdown', Icons.article_outlined),
  text('Text', Icons.description_outlined),
  other('Other', Icons.insert_drive_file_outlined);

  const SourceMaterialType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Classifies a file by its extension — the only signal available
  /// without parsing the file's contents (explicitly out of scope:
  /// "No OCR. No parsing." — still true for classification itself; Work
  /// Package 013 adds an entirely separate OCR pipeline that augments
  /// Source Material rather than changing how it is classified).
  ///
  /// `tif`/`tiff` were added in Work Package 013 (OCR's own "Supported:
  /// PDF, PNG, JPG, TIFF" list) — grouped under [SourceMaterialType.image]
  /// like every other raster format already here. Flutter's built-in
  /// `Image.file` cannot decode TIFF (unlike PNG/JPG/GIF/BMP/WEBP), so a
  /// TIFF source's on-screen *preview* in `SourceViewerPanel` degrades to
  /// the existing "This image could not be displayed" error state — see
  /// `docs/OCR_PIPELINE.md` § Architectural Observations. This does not
  /// affect OCR itself: Tesseract (via `libtiff`) reads TIFF files
  /// directly from disk, independent of Studio's own preview rendering.
  static SourceMaterialType fromExtension(String fileName) {
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (extension) {
      'pdf' => SourceMaterialType.pdf,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'bmp' || 'webp' || 'tif' || 'tiff' => SourceMaterialType.image,
      'md' || 'markdown' => SourceMaterialType.markdown,
      'txt' => SourceMaterialType.text,
      _ => SourceMaterialType.other,
    };
  }
}
