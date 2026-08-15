import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/knowledge_validation_exception.dart';
import 'package:oep_studio/knowledge/models/page_selection.dart';
import 'package:oep_studio/knowledge/models/procedure_step.dart';
import 'package:oep_studio/knowledge/models/review_decision.dart';
import 'package:oep_studio/knowledge/models/specification_details.dart';
import 'package:oep_studio/knowledge/models/specification_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/services/source_material_service.dart';

/// Exercises real `dart:io` file access against
/// `KnowledgeSessionStorage.root()` (`%APPDATA%/oep_studio/knowledge_sessions`)
/// rather than an injected temp directory — the storage service has no
/// directory-override parameter, and adding one purely for testability
/// would be exactly the kind of unrequested abstraction this project
/// avoids. Every session created here uses a `storage-test-` prefixed
/// ID and is deleted in `tearDown`, so this never leaves files behind
/// on the machine running the suite, whether a test passes or fails.
void main() {
  final createdSessionIds = <String>[];

  KnowledgeSessionRecord makeRecord({List<KnowledgeCandidate> candidates = const []}) {
    final id = 'storage-test-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(id);
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: id,
        name: 'Storage Test Session',
        repositoryName: 'demo-repo',
        author: 'test-author',
        createdTime: DateTime(2026, 1, 1),
        lastModified: DateTime(2026, 1, 1),
      ),
      candidates: candidates,
      reviewDecisions: [
        ReviewDecision(
          candidateId: 'c1',
          candidateName: 'Timing Cover',
          kind: ReviewDecisionKind.created,
          timestamp: DateTime(2026, 1, 1),
          reviewer: 'test-author',
        ),
      ],
    );
  }

  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  group('save/load round trip', () {
    test('loads back exactly what was saved', () async {
      final record = makeRecord(
        candidates: [
          KnowledgeCandidate(
            id: 'c1',
            type: KnowledgeCandidateType.component,
            name: 'Timing Cover',
            status: KnowledgeCandidateStatus.accepted,
            createdTime: DateTime(2026, 1, 1),
          ),
        ],
      );

      await KnowledgeSessionStorage.save(record);
      final loaded = await KnowledgeSessionStorage.load(record.session.id);

      expect(loaded.session.id, record.session.id);
      expect(loaded.session.name, record.session.name);
      expect(loaded.candidates, hasLength(1));
      expect(loaded.candidates.single.name, 'Timing Cover');
      expect(loaded.candidates.single.status, KnowledgeCandidateStatus.accepted);
      expect(loaded.reviewDecisions, hasLength(1));
      expect(loaded.reviewDecisions.single.kind, ReviewDecisionKind.created);
    });

    test('throws KnowledgeValidationException for a session that does not exist', () async {
      await expectLater(
        KnowledgeSessionStorage.load('storage-test-does-not-exist'),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });

    test('throws KnowledgeValidationException for a corrupted session file', () async {
      final record = makeRecord();
      final directory = KnowledgeSessionStorage.sessionDirectory(record.session.id);
      await directory.create(recursive: true);
      await File(
        '${directory.path}${Platform.pathSeparator}session.json',
      ).writeAsString('{ not valid json');

      await expectLater(
        KnowledgeSessionStorage.load(record.session.id),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });
  });

  group('listAll', () {
    test('includes saved sessions, sorted by lastModified descending', () async {
      final older = makeRecord();
      await KnowledgeSessionStorage.save(older);
      final newer = makeRecord();
      await KnowledgeSessionStorage.save(
        KnowledgeSessionRecord(session: newer.session.copyWith(lastModified: DateTime(2027, 1, 1))),
      );

      final listing = await KnowledgeSessionStorage.listAll();
      final ids = listing.sessions.map((record) => record.session.id).toList();
      expect(ids, containsAll([older.session.id, newer.session.id]));
      expect(ids.indexOf(newer.session.id), lessThan(ids.indexOf(older.session.id)));
    });
  });

  group('delete', () {
    test('removes a session so it no longer loads', () async {
      final record = makeRecord();
      await KnowledgeSessionStorage.save(record);
      await KnowledgeSessionStorage.delete(record.session.id);

      await expectLater(
        KnowledgeSessionStorage.load(record.session.id),
        throwsA(isA<KnowledgeValidationException>()),
      );
    });
  });

  group('evidence round trip', () {
    test('Evidence Regions, Evidence Links, and Page Selections survive save/load', () async {
      final record = makeRecord(
        candidates: [
          KnowledgeCandidate(
            id: 'c1',
            type: KnowledgeCandidateType.component,
            name: 'Timing Cover',
            createdTime: DateTime(2026, 1, 1),
          ),
        ],
      );
      final withEvidence = KnowledgeSessionRecord(
        session: record.session,
        candidates: record.candidates,
        evidenceRegions: [
          EvidenceRegion(
            id: 'region1',
            sourceId: 'source1',
            page: 2,
            x: 0.1,
            y: 0.2,
            width: 0.3,
            height: 0.4,
            label: 'Torque Spec',
            notes: 'See callout',
            createdTime: DateTime(2026, 1, 1),
          ),
        ],
        evidenceLinks: [
          EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'region1', createdTime: DateTime(2026, 1, 1)),
        ],
        pageSelections: [
          PageSelection(id: 'page1', sourceId: 'source1', page: 5, createdTime: DateTime(2026, 1, 1)),
        ],
      );

      await KnowledgeSessionStorage.save(withEvidence);
      final loaded = await KnowledgeSessionStorage.load(record.session.id);

      expect(loaded.evidenceRegions, hasLength(1));
      expect(loaded.evidenceRegions.single.label, 'Torque Spec');
      expect(loaded.evidenceRegions.single.page, 2);
      expect(loaded.evidenceRegions.single.width, 0.3);
      expect(loaded.evidenceLinks, hasLength(1));
      expect(loaded.evidenceLinks.single.candidateId, 'c1');
      expect(loaded.evidenceLinks.single.regionId, 'region1');
      expect(loaded.pageSelections, hasLength(1));
      expect(loaded.pageSelections.single.page, 5);
    });

    test('a session saved before Work Package 009 (no evidence fields) still loads', () async {
      final record = makeRecord();
      final directory = KnowledgeSessionStorage.sessionDirectory(record.session.id);
      await directory.create(recursive: true);
      // Simulates a pre-WP009 session.json with no evidenceRegions/
      // evidenceLinks/pageSelections keys at all.
      await File('${directory.path}${Platform.pathSeparator}session.json').writeAsString(
        '{"formatVersion":1,"session":${jsonEncode(record.session.toJson())},'
        '"candidates":[],"relationshipCandidates":[],"sources":[],"reviewDecisions":[]}',
      );

      final loaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(loaded.evidenceRegions, isEmpty);
      expect(loaded.evidenceLinks, isEmpty);
      expect(loaded.pageSelections, isEmpty);
    });
  });

  group('procedure/specification round trip', () {
    test('Procedure Steps and Specification Details survive save/load', () async {
      final record = makeRecord(
        candidates: [
          KnowledgeCandidate(
            id: 'c1',
            type: KnowledgeCandidateType.procedure,
            name: 'Install Cover',
            createdTime: DateTime(2026, 1, 1),
          ),
          KnowledgeCandidate(
            id: 'c2',
            type: KnowledgeCandidateType.specification,
            name: 'Cover Bolt Torque',
            createdTime: DateTime(2026, 1, 1),
          ),
        ],
      );
      final withProcedureAndSpec = KnowledgeSessionRecord(
        session: record.session,
        candidates: record.candidates,
        procedureSteps: [
          ProcedureStep(
            id: 'step1',
            candidateId: 'c1',
            title: 'Remove old gasket',
            description: 'Scrape residue from mating surface.',
            referencedCandidateIds: const ['c2'],
            createdTime: DateTime(2026, 1, 1),
          ),
        ],
        specificationDetails: [
          SpecificationDetails(
            candidateId: 'c2',
            specType: SpecificationType.torque,
            value: '25',
            unit: 'Nm',
            createdTime: DateTime(2026, 1, 1),
          ),
        ],
      );

      await KnowledgeSessionStorage.save(withProcedureAndSpec);
      final loaded = await KnowledgeSessionStorage.load(record.session.id);

      expect(loaded.procedureSteps, hasLength(1));
      expect(loaded.procedureSteps.single.title, 'Remove old gasket');
      expect(loaded.procedureSteps.single.referencedCandidateIds, ['c2']);
      expect(loaded.specificationDetails, hasLength(1));
      expect(loaded.specificationDetails.single.specType, SpecificationType.torque);
      expect(loaded.specificationDetails.single.value, '25');
      expect(loaded.specificationDetails.single.unit, 'Nm');
    });

    test('a session saved before Work Package 010 (no procedure/specification fields) still loads', () async {
      final record = makeRecord();
      final directory = KnowledgeSessionStorage.sessionDirectory(record.session.id);
      await directory.create(recursive: true);
      // Simulates a pre-WP010 session.json with no procedureSteps/
      // specificationDetails keys at all.
      await File('${directory.path}${Platform.pathSeparator}session.json').writeAsString(
        '{"formatVersion":1,"session":${jsonEncode(record.session.toJson())},'
        '"candidates":[{"id":"c1","type":"component","name":"Timing Cover","description":"",'
        '"status":"pending","createdTime":"2026-01-01T00:00:00.000"}],'
        '"relationshipCandidates":[],"sources":[],"reviewDecisions":[],'
        '"evidenceRegions":[],"evidenceLinks":[],"pageSelections":[]}',
      );

      final loaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(loaded.procedureSteps, isEmpty);
      expect(loaded.specificationDetails, isEmpty);
      // The pre-WP010 candidate (no notes/author/tags keys) must still
      // load, defaulting those fields rather than throwing.
      expect(loaded.candidates.single.notes, isEmpty);
      expect(loaded.candidates.single.author, isEmpty);
      expect(loaded.candidates.single.tags, isEmpty);
    });
  });

  group('duplicate + source material', () {
    test('duplicating a session copies its attached source files independently', () async {
      final original = makeRecord();
      await KnowledgeSessionStorage.save(original);

      final sourceFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}storage_test_source.txt',
      );
      await sourceFile.writeAsString('evidence');
      addTearDown(() => sourceFile.deleteSync());

      final attached = await SourceMaterialService.attach(
        sessionId: original.session.id,
        pickedFilePath: sourceFile.path,
        addedBy: 'test-author',
      );
      await KnowledgeSessionStorage.save(
        KnowledgeSessionRecord(session: original.session, sources: [attached]),
      );

      final reloaded = await KnowledgeSessionStorage.load(original.session.id);
      final duplicate = KnowledgeSessionService.buildDuplicate(reloaded, author: 'test-author');
      createdSessionIds.add(duplicate.session.id);
      await KnowledgeSessionStorage.duplicateSourceFiles(original.session.id, duplicate);
      await KnowledgeSessionStorage.save(duplicate);

      final duplicateLoaded = await KnowledgeSessionStorage.load(duplicate.session.id);
      expect(duplicateLoaded.session.id, isNot(original.session.id));
      expect(duplicateLoaded.sources, hasLength(1));
      expect(File(duplicateLoaded.sources.single.localPath).existsSync(), isTrue);

      // Deleting the original must not affect the duplicate's own copy.
      await KnowledgeSessionStorage.delete(original.session.id);
      expect(File(duplicateLoaded.sources.single.localPath).existsSync(), isTrue);
    });
  });
}
