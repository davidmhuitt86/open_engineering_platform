import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/derived_artifact.dart';
import 'package:oep_studio/ingestion/models/ingestion_provenance.dart';
import 'package:oep_studio/ingestion/models/ingestion_run.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/ingestion/models/ingestion_stage.dart';
import 'package:oep_studio/ingestion/models/normalized_document.dart';
import 'package:oep_studio/ingestion/models/normalized_ingestion_product.dart';
import 'package:oep_studio/ingestion/models/normalized_metadata.dart';
import 'package:oep_studio/ingestion/models/normalized_page.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/ingestion/services/knowledge_session_bridge.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_processing_exception.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-008 § 19 acceptance tests (TEST-008-001 through TEST-008-022)
/// for durably persisting UIF's actual `NormalizedDocument` — never before
/// persisted, only its `DerivedArtifact` provenance was — within the
/// existing Knowledge Session persistence domain, as a
/// `NormalizedIngestionProduct`.
///
/// A new, separate file from `derived_artifact_test.dart` (WP-INGEST-002)
/// / `ingestion_run_provenance_persistence_test.dart` (WP-INGEST-006),
/// following the same established conventions: focused new tests rather
/// than reopening a prior work package's frozen file, run against the
/// real TRX300 reference dataset (`reference/ingestion/trx300/source/`)
/// where a real pipeline run is required, plain in-memory model
/// construction where it is not — never modified by any test here.
///
/// **OCR test environment note** (matching every prior ingestion WP's own
/// documented reasoning): this build/test machine has no `tesseract`
/// executable on PATH, so every real-pipeline test below uses
/// `IngestionOrchestrator.run`'s injected `ocrRunner` seam.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  Future<VaultObjectInput> trx300Input({String vaultObjectId = 'trx300-factory-wiring-diagram'}) =>
      VaultObjectInput.fromFile(
        vaultObjectId: vaultObjectId,
        acquisitionRecordIds: const [],
        artifactType: ArtifactType.pdf,
        mimeType: 'application/pdf',
        filePath: trx300Path,
        immutableMetadataSnapshot: const {
          'sourceDocumentIdentity': '1988 Honda TRX300 FourTrax Factory Service Manual, Section 21',
        },
      );

  Future<List<OcrPageResult>> fakeOcrSuccess({
    required SourceMaterial source,
    required List<OcrPageResult> existingResults,
  }) async {
    return [
      OcrPageResult(
        sourceId: source.id,
        page: 1,
        words: [
          OcrWord(
            text: 'Torque',
            confidence: 0.9,
            boundingBox: const OcrBoundingBox(x: 0, y: 0, width: 0.05, height: 0.03),
            readingOrder: 0,
            lineIndex: 0,
          ),
        ],
        imageWidth: 2000,
        imageHeight: 1500,
        sourceFingerprint: 'fake-fingerprint',
        engineVersion: 'fake-ocr-1.0.0',
        processedTime: DateTime(2026, 1, 1),
        success: true,
      ),
    ];
  }

  Future<List<OcrPageResult>> fakeOcrFailure({
    required SourceMaterial source,
    required List<OcrPageResult> existingResults,
  }) async {
    throw const OcrProcessingException('simulated OCR engine unavailable');
  }

  final createdSessionIds = <String>[];
  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  // -- Fixture builders for plain in-memory model tests --------------------

  NormalizedMetadata buildMetadata({bool withOptionalFields = true}) => NormalizedMetadata(
    title: withOptionalFields ? 'TRX300 Factory Service Manual' : null,
    author: withOptionalFields ? 'Honda Motor Co.' : null,
    organization: withOptionalFields ? 'Honda' : null,
    publicationDate: withOptionalFields ? '1988' : null,
    revision: withOptionalFields ? 'Rev A' : null,
    keywords: withOptionalFields ? const ['wiring', 'electrical'] : const [],
    productFamily: withOptionalFields ? 'TRX300' : null,
    manufacturer: withOptionalFields ? 'Honda' : null,
    documentIdentifiers: withOptionalFields ? const ['SEC-21'] : const [],
    language: withOptionalFields ? 'en' : null,
    documentType: withOptionalFields ? 'service_manual' : null,
    pageCount: 1,
    sourceFileName: 'trx300_factory_wiring_diagram.pdf',
    sizeBytes: 12345,
    mimeType: 'application/pdf',
    contentHash: 'a' * 64,
  );

  NormalizedPage buildPage({int pageNumber = 1, String embeddedText = ''}) => NormalizedPage(
    pageNumber: pageNumber,
    widthPt: 612.0,
    heightPt: 792.0,
    rotationDegrees: 0,
    embeddedText: embeddedText,
  );

  NormalizedDocument buildDocument({bool withOptionalFields = true, List<NormalizedPage>? pages}) =>
      NormalizedDocument(
        vaultObjectId: 'trx300-factory-wiring-diagram',
        metadata: buildMetadata(withOptionalFields: withOptionalFields),
        pages: pages ?? [buildPage()],
      );

  group('TEST-008-001 NormalizedMetadata JSON round-trip', () {
    test('every field survives toJson -> fromJson', () {
      final metadata = buildMetadata();
      final roundTripped = NormalizedMetadata.fromJson(metadata.toJson());

      expect(roundTripped.title, metadata.title);
      expect(roundTripped.author, metadata.author);
      expect(roundTripped.organization, metadata.organization);
      expect(roundTripped.publicationDate, metadata.publicationDate);
      expect(roundTripped.revision, metadata.revision);
      expect(roundTripped.keywords, equals(metadata.keywords));
      expect(roundTripped.productFamily, metadata.productFamily);
      expect(roundTripped.manufacturer, metadata.manufacturer);
      expect(roundTripped.documentIdentifiers, equals(metadata.documentIdentifiers));
      expect(roundTripped.language, metadata.language);
      expect(roundTripped.documentType, metadata.documentType);
      expect(roundTripped.pageCount, metadata.pageCount);
      expect(roundTripped.sourceFileName, metadata.sourceFileName);
      expect(roundTripped.sizeBytes, metadata.sizeBytes);
      expect(roundTripped.mimeType, metadata.mimeType);
      expect(roundTripped.contentHash, metadata.contentHash);
    });
  });

  group('TEST-008-002 NormalizedPage JSON round-trip', () {
    test('every field survives toJson -> fromJson', () {
      final page = buildPage(embeddedText: 'Torque 24 Nm');
      final roundTripped = NormalizedPage.fromJson(page.toJson());

      expect(roundTripped.pageNumber, page.pageNumber);
      expect(roundTripped.widthPt, page.widthPt);
      expect(roundTripped.heightPt, page.heightPt);
      expect(roundTripped.rotationDegrees, page.rotationDegrees);
      expect(roundTripped.embeddedText, page.embeddedText);
    });
  });

  group('TEST-008-003 NormalizedDocument JSON round-trip', () {
    test('every field, nested, survives toJson -> fromJson', () {
      final document = buildDocument();
      final roundTripped = NormalizedDocument.fromJson(document.toJson());

      expect(roundTripped.vaultObjectId, document.vaultObjectId);
      expect(roundTripped.metadata.contentHash, document.metadata.contentHash);
      expect(roundTripped.pages, hasLength(document.pages.length));
      expect(roundTripped.pages.single.pageNumber, document.pages.single.pageNumber);
    });
  });

  group('TEST-008-004 nullable NormalizedMetadata fields survive round-trip', () {
    test('every nullable field stays null, not fabricated', () {
      final metadata = buildMetadata(withOptionalFields: false);
      final roundTripped = NormalizedMetadata.fromJson(metadata.toJson());

      expect(roundTripped.title, isNull);
      expect(roundTripped.author, isNull);
      expect(roundTripped.organization, isNull);
      expect(roundTripped.publicationDate, isNull);
      expect(roundTripped.revision, isNull);
      expect(roundTripped.productFamily, isNull);
      expect(roundTripped.manufacturer, isNull);
      expect(roundTripped.language, isNull);
      expect(roundTripped.documentType, isNull);
      expect(roundTripped.keywords, isEmpty);
      expect(roundTripped.documentIdentifiers, isEmpty);
    });
  });

  group('TEST-008-005 multiple pages preserve exact ordering', () {
    test('page order survives round-trip', () {
      final pages = [
        buildPage(pageNumber: 3, embeddedText: 'third'),
        buildPage(pageNumber: 1, embeddedText: 'first'),
        buildPage(pageNumber: 2, embeddedText: 'second'),
      ];
      final document = buildDocument(pages: pages);
      final roundTripped = NormalizedDocument.fromJson(document.toJson());

      expect(
        roundTripped.pages.map((page) => page.pageNumber).toList(),
        equals([3, 1, 2]),
      );
      expect(
        roundTripped.pages.map((page) => page.embeddedText).toList(),
        equals(['third', 'first', 'second']),
      );
    });
  });

  group('TEST-008-006 embeddedText survives exactly', () {
    test('multi-line/special-character embeddedText is preserved byte-for-byte', () {
      const text = 'Line one\nLine "two" with quotes\tand a tab\nUnicode: café — dash';
      final page = buildPage(embeddedText: text);
      final roundTripped = NormalizedPage.fromJson(page.toJson());

      expect(roundTripped.embeddedText, text);
    });
  });

  group('TEST-008-007 NormalizedIngestionProduct JSON round-trip', () {
    test('runId, derivedArtifactId, and the full document survive', () {
      final product = NormalizedIngestionProduct(
        runId: 'run-008-001',
        derivedArtifactId: 'da-structuralAnalysis-deadbeef',
        document: buildDocument(),
      );
      final roundTripped = NormalizedIngestionProduct.fromJson(product.toJson());

      expect(roundTripped.runId, product.runId);
      expect(roundTripped.derivedArtifactId, product.derivedArtifactId);
      expect(roundTripped.document.vaultObjectId, product.document.vaultObjectId);
      expect(roundTripped.document.metadata.contentHash, product.document.metadata.contentHash);
      expect(roundTripped.document.pages, hasLength(product.document.pages.length));
    });
  });

  group('TEST-008-008 runId survives persistence', () {
    test('runId round-trips through toJson/fromJson exactly', () {
      final product = NormalizedIngestionProduct(
        runId: 'exact-run-id-008-008',
        derivedArtifactId: 'da-id',
        document: buildDocument(),
      );
      expect(NormalizedIngestionProduct.fromJson(product.toJson()).runId, 'exact-run-id-008-008');
    });
  });

  group('TEST-008-009 derivedArtifactId survives persistence', () {
    test('derivedArtifactId round-trips through toJson/fromJson exactly', () {
      final product = NormalizedIngestionProduct(
        runId: 'run-id',
        derivedArtifactId: 'exact-derived-artifact-id-008-009',
        document: buildDocument(),
      );
      expect(
        NormalizedIngestionProduct.fromJson(product.toJson()).derivedArtifactId,
        'exact-derived-artifact-id-008-009',
      );
    });
  });

  group('TEST-008-010 KnowledgeSessionRecord round-trip preserves normalized products', () {
    test('normalizedProducts survives an in-memory toJson -> fromJson round-trip', () {
      final record = IngestionKnowledgeSessionBridge.createQueuedSessionRecord(
        sessionId: 'session-008-010',
        sessionName: 'session-008-010',
        repositoryName: 'repo',
        author: 'author',
        queuedRun: IngestionRun(
          runId: 'run-008-010',
          vaultObjectId: 'vault-008-010',
          contentHash: 'hash',
          startedAt: DateTime(2026, 1, 1),
          status: IngestionRunStatus.completed,
          pipelineVersion: 'uif-pipeline-1.0.0',
          parserId: 'pdf',
          parserVersion: '1.0.0',
          processorVersions: const {},
          processingConfiguration: const {},
          stageResults: const [],
        ),
      );
      final withProduct = KnowledgeSessionRecord(
        session: record.session,
        ingestionRuns: record.ingestionRuns,
        normalizedProducts: [
          NormalizedIngestionProduct(runId: 'run-008-010', derivedArtifactId: 'da-008-010', document: buildDocument()),
        ],
      );

      final roundTripped = KnowledgeSessionRecord.fromJson(withProduct.toJson());

      expect(roundTripped.normalizedProducts, hasLength(1));
      expect(roundTripped.normalizedProducts.single.runId, 'run-008-010');
      expect(roundTripped.normalizedProducts.single.derivedArtifactId, 'da-008-010');
      expect(roundTripped.normalizedProducts.single.document.vaultObjectId, 'trx300-factory-wiring-diagram');
    });
  });

  group('TEST-008-011 existing session JSON without normalized products loads successfully', () {
    test('a JSON map with no normalizedProducts key parses to an empty list', () {
      final record = IngestionKnowledgeSessionBridge.createQueuedSessionRecord(
        sessionId: 'session-008-011',
        sessionName: 'session-008-011',
        repositoryName: 'repo',
        author: 'author',
        queuedRun: IngestionRun(
          runId: 'run-008-011',
          vaultObjectId: 'vault-008-011',
          contentHash: 'hash',
          startedAt: DateTime(2026, 1, 1),
          status: IngestionRunStatus.completed,
          pipelineVersion: 'uif-pipeline-1.0.0',
          parserId: 'pdf',
          parserVersion: '1.0.0',
          processorVersions: const {},
          processingConfiguration: const {},
          stageResults: const [],
        ),
      );
      final legacyJson = record.toJson()..remove('normalizedProducts');

      final loaded = KnowledgeSessionRecord.fromJson(legacyJson);

      expect(loaded.normalizedProducts, isEmpty);
      // Every other pre-existing field must still load correctly —
      // backward compatibility means the rest of a real, older
      // session.json (from before WP-INGEST-008) is unaffected.
      expect(loaded.ingestionRuns, hasLength(1));
    });
  });

  group('TEST-008-012/013 multiple normalized products from different runs remain distinct', () {
    test(
      'two runs with different runId (TEST-008-012) and the same processingIdentity (TEST-008-013) both persist '
      'separately, never collapsed/overwritten',
      () async {
        final input = await trx300Input(vaultObjectId: 'trx300-008-012');
        final first = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-a-008-012');
        final second = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-b-008-012');

        // Same VaultObjectInput both times -> same processingIdentity
        // inputs, only runId differs (INGEST-FOLLOWUP-003's frozen
        // processingIdentity semantics -- untouched by this work
        // package, see IngestionRun.processingIdentity's own doc
        // comment).
        var record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
          result: first,
          sessionId: 'session-008-012',
          sessionName: 'session-008-012',
          repositoryName: 'repo',
          author: 'author',
        );
        record = IngestionKnowledgeSessionBridge.mergeInto(record, second);

        expect(record.normalizedProducts, hasLength(2));
        final runIds = record.normalizedProducts.map((product) => product.runId).toSet();
        expect(runIds, equals({'run-a-008-012', 'run-b-008-012'}));
        // Neither product silently replaced the other -- both documents
        // are independently present.
        expect(record.normalizedProducts.every((product) => product.document.pages.isNotEmpty), isTrue);
      },
    );
  });

  group('TEST-008-014 bridge transfers structuralData into the persisted normalized product', () {
    test('toNewSessionRecord carries IngestionResult.structuralData through as a NormalizedIngestionProduct', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-014');
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-008-014');

      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: 'session-008-014',
        sessionName: 'session-008-014',
        repositoryName: 'repo',
        author: 'author',
      );

      expect(record.normalizedProducts, hasLength(1));
      final product = record.normalizedProducts.single;
      expect(product.runId, result.run.runId);
      expect(product.document.vaultObjectId, result.structuralData.vaultObjectId);
      expect(product.document.metadata.contentHash, result.structuralData.metadata.contentHash);
      expect(product.document.pages.length, result.structuralData.pages.length);
      // References a real DerivedArtifact this same result produced.
      expect(result.derivedArtifacts.map((a) => a.derivedArtifactId), contains(product.derivedArtifactId));
    });

    test('completeSessionRecord also carries structuralData through', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-014b');
      final queuedRun = IngestionRun(
        runId: 'run-008-014b',
        vaultObjectId: input.vaultObjectId,
        contentHash: input.contentHash,
        startedAt: DateTime.now(),
        status: IngestionRunStatus.queued,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'none',
        parserVersion: 'none',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: const [],
      );
      final queuedRecord = IngestionKnowledgeSessionBridge.createQueuedSessionRecord(
        sessionId: 'session-008-014b',
        sessionName: 'session-008-014b',
        repositoryName: 'repo',
        author: 'author',
        queuedRun: queuedRun,
      );
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-008-014b');

      final completed = IngestionKnowledgeSessionBridge.completeSessionRecord(
        queuedRecord: queuedRecord,
        result: result,
      );

      expect(completed.normalizedProducts, hasLength(1));
      expect(completed.normalizedProducts.single.runId, 'run-008-014b');
      expect(completed.normalizedProducts.single.document.vaultObjectId, result.structuralData.vaultObjectId);
    });
  });

  group('TEST-008-015 mergeInto preserves normalized products from multiple results', () {
    test('merging a second result appends rather than replaces the first result\'s product', () async {
      final firstInput = await trx300Input(vaultObjectId: 'trx300-008-015-a');
      final secondInput = await trx300Input(vaultObjectId: 'trx300-008-015-b');
      final first = await IngestionOrchestrator.run(input: firstInput, ocrRunner: fakeOcrSuccess, runId: 'run-008-015-a');
      final second = await IngestionOrchestrator.run(input: secondInput, ocrRunner: fakeOcrSuccess, runId: 'run-008-015-b');

      var record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: first,
        sessionId: 'session-008-015',
        sessionName: 'session-008-015',
        repositoryName: 'repo',
        author: 'author',
      );
      expect(record.normalizedProducts, hasLength(1));

      record = IngestionKnowledgeSessionBridge.mergeInto(record, second);

      expect(record.normalizedProducts, hasLength(2));
      expect(
        record.normalizedProducts.map((product) => product.runId).toSet(),
        equals({'run-008-015-a', 'run-008-015-b'}),
      );
    });
  });

  group('TEST-008-016 PARTIAL ingestion with normalized data preserves the normalized product', () {
    test('a PARTIAL run (OCR stage fails, earlier stages succeed) still persists its real NormalizedDocument', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-016');
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrFailure, runId: 'run-008-016');

      expect(result.run.status, IngestionRunStatus.partial);
      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: 'session-008-016',
        sessionName: 'session-008-016',
        repositoryName: 'repo',
        author: 'author',
      );

      // Content/structural extraction ran before the OCR stage that
      // failed, so a real NormalizedDocument exists and must be
      // persistable/inspectable (WP-INGEST-008 § 10) despite the overall
      // PARTIAL status.
      expect(record.normalizedProducts, hasLength(1));
      expect(record.normalizedProducts.single.document.pages, isNotEmpty);
      expect(record.normalizedProducts.single.document.metadata.pageCount, greaterThan(0));
    });
  });

  group('TEST-008-017 failed ingestion before parser output does not fabricate a normalized product', () {
    test('no registered parser -> run FAILED before any parser output exists -> no normalized product persisted', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-017');
      // Empty parser list: PARSER_SELECTION fails before METADATA_EXTRACTION/
      // CONTENT_EXTRACTION/STRUCTURAL_ANALYSIS ever run (see
      // IngestionOrchestrator.run's `selectedParser == null` branch).
      final result = await IngestionOrchestrator.run(input: input, parsers: const [], runId: 'run-008-017');

      expect(result.run.status, IngestionRunStatus.failed);
      expect(result.derivedArtifacts, isEmpty);

      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: 'session-008-017',
        sessionName: 'session-008-017',
        repositoryName: 'repo',
        author: 'author',
      );

      // IngestionResult.structuralData is never null (the orchestrator
      // always fills it with a placeholder for a pre-parse failure -- see
      // IngestionOrchestrator._unresolvedDocument), so the assertion that
      // matters is that the bridge does NOT wrap that placeholder into a
      // persisted NormalizedIngestionProduct.
      expect(record.normalizedProducts, isEmpty);
    });
  });

  group('TEST-008-018 real KnowledgeSessionStorage save -> load preserves normalized products', () {
    test('a normalized product survives a real save/load round-trip through disk', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-018');
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-008-018');
      final sessionId = KnowledgeSessionService.generateId('session-008-018');
      createdSessionIds.add(sessionId);

      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: sessionId,
        sessionName: 'session-008-018',
        repositoryName: 'repo',
        author: 'author',
      );
      await KnowledgeSessionStorage.save(record);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.normalizedProducts, hasLength(1));
      expect(loaded.normalizedProducts.single.runId, 'run-008-018');
      expect(loaded.normalizedProducts.single.document.vaultObjectId, result.structuralData.vaultObjectId);
      expect(loaded.normalizedProducts.single.document.pages.length, result.structuralData.pages.length);
      expect(
        loaded.normalizedProducts.single.document.metadata.contentHash,
        result.structuralData.metadata.contentHash,
      );
    });
  });

  group('TEST-008-019 persisted normalized product retains its associated Vault Object ID', () {
    test('vaultObjectId survives a real save/load round-trip', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-019');
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-008-019');
      final sessionId = KnowledgeSessionService.generateId('session-008-019');
      createdSessionIds.add(sessionId);

      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: sessionId,
        sessionName: 'session-008-019',
        repositoryName: 'repo',
        author: 'author',
      );
      await KnowledgeSessionStorage.save(record);
      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.normalizedProducts.single.document.vaultObjectId, 'trx300-008-019');
    });
  });

  group('TEST-008-020 persisted normalized product retains metadata contentHash', () {
    test('metadata.contentHash survives a real save/load round-trip', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-020');
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-008-020');
      final sessionId = KnowledgeSessionService.generateId('session-008-020');
      createdSessionIds.add(sessionId);

      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: sessionId,
        sessionName: 'session-008-020',
        repositoryName: 'repo',
        author: 'author',
      );
      await KnowledgeSessionStorage.save(record);
      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.normalizedProducts.single.document.metadata.contentHash, isNotEmpty);
      expect(
        loaded.normalizedProducts.single.document.metadata.contentHash,
        result.structuralData.metadata.contentHash,
      );
    });
  });

  group('TEST-008-021/022 no regression in DerivedArtifact identity/association', () {
    // TEST-008-021 ("existing ingestion tests remain green") and
    // TEST-008-022 ("existing Knowledge Session persistence tests remain
    // green") are satisfied by running this repository's full existing
    // `test/ingestion/` and `test/knowledge/` suites unmodified alongside
    // this file (see this work package's AAR for the exact command/
    // result) -- there is deliberately no new test duplicating them here.
    // This group instead covers the one remaining boundary condition
    // specific to this work package: that adding `normalizedProducts`
    // does not disturb `derivedArtifacts`' own independent identity.
    test('derivedArtifacts remains untouched by normalizedProducts on the same record', () async {
      final input = await trx300Input(vaultObjectId: 'trx300-008-021');
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess, runId: 'run-008-021');
      final record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: 'session-008-021',
        sessionName: 'session-008-021',
        repositoryName: 'repo',
        author: 'author',
      );

      expect(record.derivedArtifacts, equals(result.derivedArtifacts));
      expect(record.derivedArtifacts, isNot(isEmpty));
      // Every DerivedArtifact field/shape is exactly what WP-INGEST-002
      // already established -- still provenance/identity metadata only,
      // never a document/content container.
      for (final artifact in record.derivedArtifacts) {
        expect(artifact.contentHash, isNotEmpty);
      }
    });
  });

  // A small standalone unit-level check that DerivedArtifact/IngestionProvenance
  // (unmodified by this WP) still construct and serialize normally when
  // built manually alongside a NormalizedIngestionProduct referencing them
  // -- guards against an accidental import cycle/signature change between
  // the two models this WP explicitly keeps separate (WP-INGEST-008 § 3).
  test('a manually-associated DerivedArtifact + NormalizedIngestionProduct pair round-trips independently', () {
    final artifact = DerivedArtifact(
      derivedArtifactId: 'da-manual-008',
      runId: 'run-manual-008',
      vaultObjectId: 'vault-manual-008',
      stage: IngestionStage.structuralAnalysis,
      artifactType: 'normalized_structural_result',
      contentHash: 'b' * 64,
      createdAt: DateTime(2026, 1, 1),
      processorId: 'pdf',
      processorVersion: '1.0.0',
      provenance: IngestionProvenance(
        vaultObjectId: 'vault-manual-008',
        acquisitionRecordIds: const [],
        runId: 'run-manual-008',
        stage: IngestionStage.structuralAnalysis,
        processorId: 'pdf',
        processorVersion: '1.0.0',
        pipelineVersion: 'uif-pipeline-1.0.0',
      ),
    );
    final product = NormalizedIngestionProduct(
      runId: artifact.runId,
      derivedArtifactId: artifact.derivedArtifactId,
      document: buildDocument(),
    );

    final artifactRoundTripped = DerivedArtifact.fromJson(artifact.toJson());
    final productRoundTripped = NormalizedIngestionProduct.fromJson(product.toJson());

    expect(productRoundTripped.derivedArtifactId, artifactRoundTripped.derivedArtifactId);
    expect(productRoundTripped.runId, artifactRoundTripped.runId);
  });
}
