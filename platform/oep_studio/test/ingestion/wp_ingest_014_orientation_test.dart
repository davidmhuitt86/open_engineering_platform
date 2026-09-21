import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/knowledge/models/document_orientation.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/ocr_cache_service.dart';

/// WP-INGEST-014: persistent Extraction Orientation.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  Future<VaultObjectInput> input() => VaultObjectInput.fromFile(
    vaultObjectId: 'orientation-vault-entry',
    acquisitionRecordIds: const [],
    artifactType: ArtifactType.pdf,
    mimeType: 'application/pdf',
    filePath: trx300Path,
    immutableMetadataSnapshot: const {},
  );

  String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

  group('DocumentOrientation', () {
    test('accepts exactly 0/90/180/270 and normalizes full turns', () {
      expect([for (final d in [0, 90, 180, 270]) DocumentOrientation.fromDegrees(d).degrees], [0, 90, 180, 270]);
      expect(DocumentOrientation.fromDegrees(360), DocumentOrientation.deg0);
      expect(DocumentOrientation.fromDegrees(-90), DocumentOrientation.deg270);
      expect(() => DocumentOrientation.fromDegrees(45), throwsArgumentError);
      expect(DocumentOrientation.deg270.quarterTurns, 3);
    });

    test('180 degrees maps the page top-left corner to the oriented bottom-right', () {
      final p = DocumentOrientation.deg180.pageToOriented(0.1, 0.2);
      expect(p.x, closeTo(0.9, 1e-9));
      expect(p.y, closeTo(0.8, 1e-9));
      final r = DocumentOrientation.deg180.rectPageToOriented(0.1, 0.2, 0.3, 0.1);
      expect(r.x, closeTo(0.6, 1e-9));
      expect(r.y, closeTo(0.7, 1e-9));
      expect(r.width, closeTo(0.3, 1e-9));
      expect(r.height, closeTo(0.1, 1e-9));
    });

    test('90 degrees clockwise sends the page top-left to the oriented top-right', () {
      final p = DocumentOrientation.deg90.pageToOriented(0, 0);
      expect((p.x, p.y), (1.0, 0.0));
    });

    test('page -> oriented -> page round-trips for every orientation', () {
      for (final o in DocumentOrientation.values) {
        final oriented = o.rectPageToOriented(0.12, 0.34, 0.2, 0.05);
        final back = o.rectOrientedToPage(oriented.x, oriented.y, oriented.width, oriented.height);
        expect(back.x, closeTo(0.12, 1e-9), reason: '$o');
        expect(back.y, closeTo(0.34, 1e-9), reason: '$o');
        expect(back.width, closeTo(0.2, 1e-9), reason: '$o');
        expect(back.height, closeTo(0.05, 1e-9), reason: '$o');
      }
    });

    test('90/270 swap the width and height of a rect', () {
      final r = DocumentOrientation.deg90.rectPageToOriented(0.1, 0.1, 0.4, 0.1);
      expect(r.width, closeTo(0.1, 1e-9));
      expect(r.height, closeTo(0.4, 1e-9));
    });
  });

  group('persisted orientation on models', () {
    test('SourceMaterial persists a non-zero orientation and defaults missing to 0', () {
      final source = SourceMaterial(
        id: 's',
        originalFileName: 'a.pdf',
        localPath: 'a.pdf',
        type: SourceMaterialType.pdf,
        sizeBytes: 1,
        importDate: DateTime(2026),
        addedBy: 'x',
      ).withExtractionOrientation(DocumentOrientation.deg180);
      final json = source.toJson();
      expect(json['extractionOrientation'], 180);
      expect(SourceMaterial.fromJson(json).extractionOrientation, DocumentOrientation.deg180);
      json.remove('extractionOrientation');
      expect(SourceMaterial.fromJson(json).extractionOrientation, DocumentOrientation.deg0);
    });

    test('OCR cache treats a different orientation as stale, the same as valid', () {
      final cached = OcrPageResult(
        sourceId: 's',
        page: 1,
        words: const [],
        imageWidth: 1,
        imageHeight: 1,
        sourceFingerprint: 'fp',
        engineVersion: 'e',
        processedTime: DateTime(2026),
        success: true,
        orientationDegrees: 180,
      );
      expect(OcrPageResult.fromJson(cached.toJson()).orientationDegrees, 180);
      expect(
        OcrCacheService.isCacheValid(existingResults: [cached], page: 1, currentFingerprint: 'fp', orientationDegrees: 180),
        isTrue,
      );
      expect(
        OcrCacheService.isCacheValid(existingResults: [cached], page: 1, currentFingerprint: 'fp', orientationDegrees: 0),
        isFalse,
      );
    });
  });

  group('orchestrator applies and records orientation', () {
    final seenOrientations = <int>[];

    Future<List<OcrPageResult>> fakeOcr({
      required SourceMaterial source,
      required List<OcrPageResult> existingResults,
    }) async {
      seenOrientations.add(source.extractionOrientation.degrees);
      return [
        OcrPageResult(
          sourceId: source.id,
          page: 1,
          words: const [
            OcrWord(
              text: 'Torque',
              confidence: 0.9,
              boundingBox: OcrBoundingBox(x: 0.1, y: 0.1, width: 0.05, height: 0.03),
              readingOrder: 0,
              lineIndex: 0,
            ),
          ],
          imageWidth: 2000,
          imageHeight: 1500,
          sourceFingerprint: 'fp',
          engineVersion: 'fake',
          processedTime: DateTime(2026),
          success: true,
          orientationDegrees: source.extractionOrientation.degrees,
        ),
      ];
    }

    test('orientation reaches the OCR stage, run config, identity and source; Vault artifact is unchanged', () async {
      final before = sha(trx300Path);
      seenOrientations.clear();
      final r180a = await IngestionOrchestrator.run(
        input: await input(),
        ocrRunner: fakeOcr,
        orientation: DocumentOrientation.deg180,
      );
      final r180b = await IngestionOrchestrator.run(
        input: await input(),
        ocrRunner: fakeOcr,
        orientation: DocumentOrientation.deg180,
      );
      final r0 = await IngestionOrchestrator.run(input: await input(), ocrRunner: fakeOcr);

      expect(seenOrientations, [180, 180, 0]);
      expect(r180a.run.processingConfiguration['extractionOrientationDegrees'], 180);
      expect(r0.run.processingConfiguration['extractionOrientationDegrees'], 0);
      expect(r180a.run.processingIdentity, r180b.run.processingIdentity);
      expect(r180a.run.processingIdentity, isNot(r0.run.processingIdentity));
      expect(r180a.source.extractionOrientation, DocumentOrientation.deg180);
      expect(r0.source.extractionOrientation, DocumentOrientation.deg0);
      expect(r180a.ocrPageResults.single.orientationDegrees, 180);
      expect(sha(trx300Path), before, reason: 'the original artifact must never be rewritten');
    });
  });
}
