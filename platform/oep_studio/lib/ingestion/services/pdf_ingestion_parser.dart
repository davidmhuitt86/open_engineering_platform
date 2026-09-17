import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../../knowledge/models/source_material.dart';
import '../../knowledge/models/source_material_type.dart';
import '../models/artifact_type.dart';
import '../models/normalized_document.dart';
import '../models/normalized_metadata.dart';
import '../models/normalized_page.dart';
import '../models/vault_object_input.dart';
import 'ingestion_parser.dart';

/// The PDF parser (AP-INGEST-001 § 8, WP-INGEST-001 § 6.4/§ 17) — the
/// only parser this first vertical slice implements
/// ("implement only the parser required for the TRX300 PDF. Do not
/// create a large parser catalog."). Written generically against
/// [ArtifactType.pdf] rather than hardcoded to TRX300 specifically, since
/// a parser that only accepted one exact file would not actually satisfy
/// the Parser Contract (AP-INGEST-001 § 8: "supportedArtifactTypes[]",
/// "canParse(input)") — but no other artifact type gets a parser here.
///
/// Uses `pdfrx` (already a dependency, via `OcrPipelineService`) for page
/// geometry and embedded-text extraction — never Tesseract/OCR, which
/// remains a later, separate stage (AP-INGEST-001 § 12 draws this line
/// explicitly).
class PdfIngestionParser implements IngestionParser {
  const PdfIngestionParser();

  @override
  String get parserId => 'uif.pdf_parser';

  @override
  String get version => '1.0.0';

  @override
  List<ArtifactType> get supportedArtifactTypes => const [ArtifactType.pdf];

  @override
  List<String> get supportedMimeTypes => const ['application/pdf'];

  @override
  bool canParse(VaultObjectInput input) =>
      input.artifactType == ArtifactType.pdf || input.mimeType == 'application/pdf';

  @override
  Future<ParserOutput> parse(VaultObjectInput input) async {
    final file = File(input.storageReference);
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : input.storageReference;
    final sizeBytes = await file.length();

    final document = await PdfDocument.openFile(input.storageReference);
    final diagnostics = <String>[];
    List<NormalizedPage> pages;
    try {
      pages = <NormalizedPage>[];
      for (final page in document.pages) {
        var embeddedText = '';
        try {
          final text = await page.loadText();
          embeddedText = text?.fullText ?? '';
        } catch (error) {
          // Some PDFs (purely scanned/rasterized ones, like TRX300's) have
          // no embedded text layer at all, or pdfrx's text extraction can
          // fail outright for them. Content extraction records this as a
          // diagnostic rather than letting it abort the whole parse — "A
          // parser shall not... perform engineering validation as a
          // source of truth", and a missing text layer is a fact about
          // the source, not a parser failure.
          diagnostics.add('Page ${page.pageNumber}: no extractable embedded text layer ($error).');
        }
        if (embeddedText.trim().isEmpty) {
          diagnostics.add(
            'Page ${page.pageNumber}: embedded text layer is empty — content extraction for this page relies on '
            'the downstream OCR stage.',
          );
        }
        pages.add(
          NormalizedPage(
            pageNumber: page.pageNumber,
            widthPt: page.width,
            heightPt: page.height,
            rotationDegrees: _rotationDegrees(page.rotation),
            embeddedText: embeddedText,
          ),
        );
      }
    } finally {
      await document.dispose();
    }

    final metadata = NormalizedMetadata(
      pageCount: pages.length,
      sourceFileName: fileName,
      sizeBytes: sizeBytes,
      mimeType: input.mimeType,
      contentHash: input.contentHash,
      documentIdentifiers: [input.vaultObjectId],
    );

    final source = SourceMaterial(
      id: 'source-${input.contentHash.substring(0, 16)}',
      originalFileName: fileName,
      localPath: input.storageReference,
      type: SourceMaterialType.pdf,
      sizeBytes: sizeBytes,
      importDate: DateTime.fromMillisecondsSinceEpoch(0),
      addedBy: 'uif',
    );

    return ParserOutput(
      document: NormalizedDocument(vaultObjectId: input.vaultObjectId, metadata: metadata, pages: pages),
      source: source,
      diagnostics: diagnostics,
    );
  }

  static int _rotationDegrees(PdfPageRotation rotation) {
    switch (rotation) {
      case PdfPageRotation.none:
        return 0;
      case PdfPageRotation.clockwise90:
        return 90;
      case PdfPageRotation.clockwise180:
        return 180;
      case PdfPageRotation.clockwise270:
        return 270;
    }
  }
}
