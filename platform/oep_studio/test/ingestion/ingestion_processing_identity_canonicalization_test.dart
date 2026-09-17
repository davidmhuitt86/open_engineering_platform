import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/ingestion_run.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';

/// INGEST-FOLLOWUP-003 acceptance tests (TEST-ID-001 through TEST-ID-018)
/// hardening [IngestionRun.processingIdentity] against the structural
/// ambiguity of a `|`-delimited join: a delimiter character occurring
/// inside an identity-tuple input value could previously make two
/// genuinely different tuples hash identically. The fix replaces the
/// delimiter-joined string with a deterministic structured JSON
/// representation before SHA-256 hashing -- this file verifies the
/// semantic inputs/exclusions/hash algorithm are unchanged while the
/// serialization ambiguity is gone.
void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);

  IngestionRun buildRun({
    String runId = 'run-a',
    String vaultObjectId = 'vault-object-1',
    String contentHash = 'content-hash-abc',
    DateTime? startedAt,
    DateTime? completedAt,
    IngestionRunStatus status = IngestionRunStatus.completed,
    String pipelineVersion = 'uif-pipeline-1.0.0',
    String parserId = 'pdf',
    String parserVersion = '1.0.0',
    Map<String, String> processorVersions = const {'ocr': 'Tesseract 5.4.0'},
    Map<String, dynamic> processingConfiguration = const {'ocrDpi': 300},
  }) => IngestionRun(
    runId: runId,
    vaultObjectId: vaultObjectId,
    contentHash: contentHash,
    startedAt: startedAt ?? now,
    completedAt: completedAt ?? now.add(const Duration(seconds: 5)),
    status: status,
    pipelineVersion: pipelineVersion,
    parserId: parserId,
    parserVersion: parserVersion,
    processorVersions: processorVersions,
    processingConfiguration: processingConfiguration,
    stageResults: const [],
  );

  group('TEST-ID-001', () {
    test('identical identity inputs with different runId/timestamps/status => identical identity', () {
      final first = buildRun(
        runId: 'run-a',
        startedAt: now,
        completedAt: now.add(const Duration(seconds: 5)),
        status: IngestionRunStatus.completed,
      );
      final second = buildRun(
        runId: 'run-b',
        startedAt: now.add(const Duration(days: 3)),
        completedAt: now.add(const Duration(days: 3, minutes: 1)),
        status: IngestionRunStatus.partial,
      );
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-002', () {
    test('changing only vaultObjectId changes the identity', () {
      final baseline = buildRun(vaultObjectId: 'vault-object-1');
      final changed = buildRun(vaultObjectId: 'vault-object-2');
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-003', () {
    test('changing only contentHash changes the identity', () {
      final baseline = buildRun(contentHash: 'content-hash-abc');
      final changed = buildRun(contentHash: 'content-hash-xyz');
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-004', () {
    test('changing only pipelineVersion changes the identity', () {
      final baseline = buildRun(pipelineVersion: 'uif-pipeline-1.0.0');
      final changed = buildRun(pipelineVersion: 'uif-pipeline-2.0.0');
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-005', () {
    test('changing only parserId changes the identity', () {
      final baseline = buildRun(parserId: 'pdf');
      final changed = buildRun(parserId: 'docx');
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-006', () {
    test('changing only parserVersion changes the identity', () {
      final baseline = buildRun(parserVersion: '1.0.0');
      final changed = buildRun(parserVersion: '1.1.0');
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-007', () {
    test('changing one processor version changes the identity', () {
      final baseline = buildRun(processorVersions: const {'ocr': 'Tesseract 5.4.0'});
      final changed = buildRun(processorVersions: const {'ocr': 'Tesseract 5.5.0'});
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-008', () {
    test('changing one processing configuration value changes the identity', () {
      final baseline = buildRun(processingConfiguration: const {'ocrDpi': 300});
      final changed = buildRun(processingConfiguration: const {'ocrDpi': 600});
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-ID-009', () {
    test('same processor map with a different Dart insertion order => identical identity', () {
      final first = buildRun(
        processorVersions: const {'ocr': 'Tesseract 5.4.0', 'entityExtraction': 'engineering_pattern_library-1'},
      );
      final second = buildRun(
        processorVersions: const {'entityExtraction': 'engineering_pattern_library-1', 'ocr': 'Tesseract 5.4.0'},
      );
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-010', () {
    test('same processingConfiguration map with a different insertion order => identical identity', () {
      final first = buildRun(processingConfiguration: const {'ocrDpi': 300, 'language': 'eng'});
      final second = buildRun(processingConfiguration: const {'language': 'eng', 'ocrDpi': 300});
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-011', () {
    test('equivalent nested configuration maps in different insertion order => identical identity', () {
      final first = buildRun(
        processingConfiguration: const {
          'dpi': 300,
          'ocr': {'language': 'eng', 'mode': 'accurate'},
        },
      );
      final second = buildRun(
        processingConfiguration: const {
          'ocr': {'mode': 'accurate', 'language': 'eng'},
          'dpi': 300,
        },
      );
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-012', () {
    test('changing list order within a configuration changes the identity (lists are not sorted)', () {
      final first = buildRun(
        processingConfiguration: const {
          'stages': ['a', 'b', 'c'],
        },
      );
      final second = buildRun(
        processingConfiguration: const {
          'stages': ['c', 'b', 'a'],
        },
      );
      expect(first.processingIdentity, isNot(second.processingIdentity));
    });
  });

  group('TEST-ID-013', () {
    test('delimiter-containing values cannot create tuple ambiguity', () {
      // Under the old `|`-join scheme, joining
      // [vaultObjectId, contentHash, ...] with '|' made these two tuples
      // produce the identical joined string "A|B|C|..." -- proving the
      // bug this fix addresses.
      final oldSchemeJoined1 = ['A|B', 'C'].join('|');
      final oldSchemeJoined2 = ['A', 'B|C'].join('|');
      expect(
        oldSchemeJoined1,
        oldSchemeJoined2,
        reason: 'sanity check: the old delimiter-joined scheme really was ambiguous for these inputs',
      );

      final first = buildRun(vaultObjectId: 'A|B', contentHash: 'C');
      final second = buildRun(vaultObjectId: 'A', contentHash: 'B|C');
      expect(
        first.processingIdentity,
        isNot(second.processingIdentity),
        reason: 'the hardened structured-JSON identity must keep these distinct',
      );
    });
  });

  group('TEST-ID-014', () {
    test('int 1 and string "1" in processingConfiguration produce different identities', () {
      final intValue = buildRun(processingConfiguration: const {'threshold': 1});
      final stringValue = buildRun(processingConfiguration: const {'threshold': '1'});
      expect(intValue.processingIdentity, isNot(stringValue.processingIdentity));
    });
  });

  group('TEST-ID-015', () {
    test('changing only startedAt/completedAt leaves the identity unchanged', () {
      final first = buildRun(startedAt: DateTime(2020, 1, 1), completedAt: DateTime(2020, 1, 1, 0, 0, 5));
      final second = buildRun(startedAt: DateTime(2026, 6, 6), completedAt: null);
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-016', () {
    test('changing only runId leaves the identity unchanged', () {
      final first = buildRun(runId: 'run-a');
      final second = buildRun(runId: 'run-b');
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-017', () {
    test('changing only status leaves the identity unchanged', () {
      final first = buildRun(status: IngestionRunStatus.completed);
      final second = buildRun(status: IngestionRunStatus.failed);
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-ID-018', () {
    test('identity survives an IngestionRun JSON round trip', () {
      final original = buildRun(
        processorVersions: const {'ocr': 'Tesseract 5.4.0', 'entityExtraction': 'engineering_pattern_library-1'},
        processingConfiguration: const {
          'ocrDpi': 300,
          'stages': ['a', 'b'],
          'ocr': {'language': 'eng', 'mode': 'accurate'},
        },
      );

      final reconstructed = IngestionRun.fromJson(original.toJson());
      expect(reconstructed.processingIdentity, original.processingIdentity);
    });
  });
}
