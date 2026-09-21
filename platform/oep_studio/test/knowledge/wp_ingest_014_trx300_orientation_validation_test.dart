// ignore_for_file: avoid_print
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/ingestion/services/knowledge_session_bridge.dart';
import 'package:oep_studio/knowledge/models/document_orientation.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/ocr_pipeline_service.dart';
import 'package:oep_studio/knowledge/services/tesseract_ocr_engine.dart';
import 'package:pdfrx/pdfrx.dart';

/// WP-INGEST-014 real-artifact validation: runs the REAL pdfrx render +
/// Tesseract OCR against the TRX300 PDF at 0 and 180 degrees. Skipped when
/// Tesseract is not installed.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  SourceMaterial source(DocumentOrientation o) => SourceMaterial(
    id: 'trx300-orientation',
    originalFileName: 'trx300_factory_wiring_diagram.pdf',
    localPath: trx300Path,
    type: SourceMaterialType.pdf,
    sizeBytes: File(trx300Path).lengthSync(),
    importDate: DateTime(2026),
    addedBy: 'test',
  ).withExtractionOrientation(o);

  test('rotated pdfrx page swaps dimensions for 90/270 and keeps them for 180', () async {
    final document = await PdfDocument.openFile(trx300Path);
    try {
      final page = document.pages.first;
      final r90 = page.rotatedBy(PdfPageRotation.clockwise90);
      final r180 = page.rotatedBy(PdfPageRotation.clockwise180);
      expect(r90.width, page.height);
      expect(r90.height, page.width);
      expect(r180.width, page.width);
      expect(r180.height, page.height);
      // Rendering through the rotated page produces an image in oriented dimensions.
      final image = await r90.render(fullWidth: r90.width, fullHeight: r90.height);
      expect(image!.width, r90.width.round());
      expect(image.height, r90.height.round());
      image.dispose();
    } finally {
      await document.dispose();
    }
  });

  test('real OCR per orientation: orientation recorded, boxes in oriented space, Vault file untouched', () async {
    if (!await TesseractOcrEngine.isAvailable()) {
      markTestSkipped('Tesseract not installed');
      return;
    }
    final before = sha256.convert(File(trx300Path).readAsBytesSync()).toString();
    final results = <int, List<OcrPageResult>>{};
    for (final o in DocumentOrientation.values) {
      results[o.degrees] = await OcrPipelineService.processSource(source: source(o), existingResults: const []);
      final page = results[o.degrees]!.first;
      print('VALIDATION orientation=${o.degrees} words=${page.words.length} '
          'dims=${page.imageWidth}x${page.imageHeight} recorded=${page.orientationDegrees} '
          'text="${page.words.take(6).map((w) => w.text).join(' ')}"');
      expect(page.orientationDegrees, o.degrees);
      expect(page.success, isTrue);
    }
    // TRX300's page is stored sideways: 90 degrees clockwise makes it upright
    // portrait (792x612 pt landscape -> 612x792 portrait).
    expect(results[90]!.first.imageHeight, greaterThan(results[90]!.first.imageWidth));
    expect(results[0]!.first.imageWidth, greaterThan(results[0]!.first.imageHeight));
    final headline = results[90]!.first.words.where((w) => w.text.toUpperCase().contains('WIRING')).toList();
    print('VALIDATION 90deg WIRING boxes: ${headline.map((w) => w.boundingBox.toJson()).toList()}');
    if (headline.isNotEmpty) {
      expect(headline.first.boundingBox.y, lessThan(0.15), reason: 'the title sits at the top of the upright page');
    }
    expect(sha256.convert(File(trx300Path).readAsBytesSync()).toString(), before);
    // A cached 0-degree result is stale for a 180-degree run.
    final reuse = await OcrPipelineService.processSource(
        source: source(DocumentOrientation.deg180), existingResults: results[0]!);
    expect(reuse.first.orientationDegrees, 180);
  }, timeout: const Timeout(Duration(minutes: 8)));

  test('real pipeline end to end: orientation persisted in run + source, identity differs, reload preserves it', () async {
    if (!await TesseractOcrEngine.isAvailable()) {
      markTestSkipped('Tesseract not installed');
      return;
    }
    final before = sha256.convert(File(trx300Path).readAsBytesSync()).toString();
    final identities = <int, String>{};
    final createdSessions = <String>[];
    try {
      for (final o in [DocumentOrientation.deg0, DocumentOrientation.deg90, DocumentOrientation.deg180]) {
        final input = await VaultObjectInput.fromFile(
          vaultObjectId: 'trx300-orientation-e2e',
          acquisitionRecordIds: const [],
          artifactType: ArtifactType.pdf,
          mimeType: 'application/pdf',
          filePath: trx300Path,
          immutableMetadataSnapshot: const {},
        );
        final result = await IngestionOrchestrator.run(input: input, orientation: o);
        identities[o.degrees] = result.run.processingIdentity;
        final sessionId = KnowledgeSessionService.generateId('session');
        createdSessions.add(sessionId);
        await KnowledgeSessionStorage.save(IngestionKnowledgeSessionBridge.toNewSessionRecord(
          result: result,
          sessionId: sessionId,
          sessionName: 'orientation e2e',
          repositoryName: 'repo',
          author: 'test',
        ));
        final reloaded = await KnowledgeSessionStorage.load(sessionId);
        print('E2E orientation=${o.degrees} status=${result.run.status.name} identity=${result.run.processingIdentity} '
            'ocrPages=${result.ocrPageResults.length} ocrWords=${result.ocrPageResults.fold<int>(0, (n, r) => n + r.words.length)} '
            'entities=${result.engineeringEntities.length} candidates=${result.knowledgeCandidates.length} '
            'reloadedSourceOrientation=${reloaded.sources.single.extractionOrientation.degrees} '
            'reloadedRunOrientation=${reloaded.ingestionRuns.single.processingConfiguration['extractionOrientationDegrees']} '
            'reloadedOcrOrientation=${reloaded.ocrPageResults.first.orientationDegrees}');
        expect(reloaded.sources.single.extractionOrientation, o);
        expect(reloaded.ingestionRuns.single.processingConfiguration['extractionOrientationDegrees'], o.degrees);
        expect(reloaded.ocrPageResults.first.orientationDegrees, o.degrees);
        expect(reloaded.ingestionRuns.single.processingIdentity, result.run.processingIdentity);
      }
      expect(identities.values.toSet(), hasLength(3), reason: 'each orientation is a distinct processing identity');
      expect(sha256.convert(File(trx300Path).readAsBytesSync()).toString(), before);
    } finally {
      for (final id in createdSessions) {
        final dir = KnowledgeSessionStorage.sessionDirectory(id);
        if (dir.existsSync()) await dir.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
