import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart';

/// WP-INGEST-013 tests A-V plus the WP-INGEST-012 regression. The Inspector
/// dialog hosts a real `pdfrx` viewer (never rendered by any test in this
/// codebase), so the property model is tested directly and the editing
/// paths through the real, unmodified `FoundationRuntimeNotifier`.
void main() {
  const source = 'source-1';
  final now = DateTime(2026, 1, 1);
  final createdSessionIds = <String>[];

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      // A still-running fire-and-forget save can briefly hold the file on
      // Windows; retry rather than fail (or leak) over disposable test data.
      for (var attempt = 0; attempt < 10 && directory.existsSync(); attempt++) {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    createdSessionIds.clear();
  });

  ({ProviderContainer container, FoundationRuntimeNotifier notifier, String sessionId}) start() {
    final id = 'wp-ingest-013-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(id);
    final container = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(
        () => _SessionSeededNotifier(KnowledgeSession(
          id: id,
          name: 'WP-INGEST-013 test',
          repositoryName: 'Repo One',
          author: 'jsmith',
          createdTime: now,
          lastModified: now,
        )),
      ),
    ]);
    addTearDown(container.dispose);
    return (container: container, notifier: container.read(foundationRuntimeServiceProvider.notifier), sessionId: id);
  }

  EvidenceRegion draw(FoundationRuntimeNotifier n) => n.createHumanAnnotation(
        sourceId: source,
        page: 1,
        x: 0.1,
        y: 0.1,
        width: 0.2,
        height: 0.1,
        annotatorId: 'jsmith',
      );

  EvidenceRegion current(ProviderContainer c, String regionId) =>
      c.read(foundationRuntimeServiceProvider).evidenceRegions.firstWhere((r) => r.id == regionId);

  List<AnnotationProperty> propsOf(ProviderContainer c, String regionId) =>
      current(c, regionId).annotation?.properties ?? const [];

  group('model / serialization', () {
    test('A: an annotation with no properties round-trips', () {
      const annotation = EvidenceAnnotation(id: 'a1');
      final restored = EvidenceAnnotation.fromJson(annotation.toJson());
      expect(restored.id, 'a1');
      expect(restored.properties, isEmpty);
    });

    test('B: one property survives a round-trip', () {
      const annotation = EvidenceAnnotation(id: 'a1', properties: [AnnotationProperty(key: 'part_number', value: '123-456')]);
      final restored = EvidenceAnnotation.fromJson(annotation.toJson());
      expect(restored.properties, [const AnnotationProperty(key: 'part_number', value: '123-456')]);
    });

    test('C: multiple properties survive a round-trip, in order', () {
      const annotation = EvidenceAnnotation(id: 'a1', properties: [
        AnnotationProperty(key: 'part_number', value: '123-456'),
        AnnotationProperty(key: 'manufacturer', value: 'Acme'),
        AnnotationProperty(key: 'wire_color', value: 'red'),
      ]);
      final restored = EvidenceAnnotation.fromJson(annotation.toJson());
      expect(restored.properties.map((p) => p.key), ['part_number', 'manufacturer', 'wire_color']);
      expect(restored.properties.map((p) => p.value), ['123-456', 'Acme', 'red']);
    });

    test('D: optional valueType and unit survive a round-trip (and absent ones stay absent)', () {
      const annotation = EvidenceAnnotation(id: 'a1', properties: [
        AnnotationProperty(key: 'gauge', value: '18', valueType: AnnotationProperty.valueTypeNumber, unit: 'AWG'),
        AnnotationProperty(key: 'shielded', value: 'true', valueType: AnnotationProperty.valueTypeBoolean),
        AnnotationProperty(key: 'note', value: 'x', valueType: null),
      ]);
      final restored = EvidenceAnnotation.fromJson(annotation.toJson()).properties;
      expect(restored[0].valueType, 'number');
      expect(restored[0].unit, 'AWG');
      expect(restored[1].valueType, 'boolean');
      expect(restored[1].unit, isNull);
      expect(restored[2].valueType, isNull);
    });

    test('E: pre-WP-INGEST-013 regions and sessions (no annotation data) still load, as empty', () {
      final legacy = {
        'id': 'r1',
        'sourceId': source,
        'page': 1,
        'x': 0.1,
        'y': 0.1,
        'width': 0.1,
        'height': 0.1,
        'label': 'Torque Callout',
        'createdTime': '2026-01-01T00:00:00.000',
      };
      final region = EvidenceRegion.fromJson(legacy);
      expect(region.annotation, isNull);
      // An annotation payload written without a properties list is empty, not an error.
      expect(EvidenceAnnotation.fromJson({'id': 'a1'}).properties, isEmpty);
      // Through the real session file too.
      final id = 'wp-ingest-013-legacy-${DateTime.now().microsecondsSinceEpoch}';
      createdSessionIds.add(id);
      final session = KnowledgeSession(
          id: id, name: 's', repositoryName: 'r', author: 'a', createdTime: now, lastModified: now);
      return KnowledgeSessionStorage.save(KnowledgeSessionRecord(session: session, evidenceRegions: [region])).then((_) async {
        final loaded = await KnowledgeSessionStorage.load(id);
        expect(loaded.evidenceRegions.single.annotation, isNull);
        expect(loaded.evidenceRegions.single.label, 'Torque Callout');
      });
    });

    test('property keys are normalized to a stable machine-readable form', () {
      expect(AnnotationProperty.normalizeKey('Part Number'), 'part_number');
      expect(AnnotationProperty.normalizeKey('  Wire-Color!! '), 'wire_color');
      expect(AnnotationProperty.normalizeKey('manufacturer'), 'manufacturer');
      expect(AnnotationProperty.normalizeKey('___'), '');
    });
  });

  group('editing (real FoundationRuntimeNotifier)', () {
    test('F/J: add properties -- several can coexist, and the annotation id is minted once', () {
      final s = start();
      final region = draw(s.notifier);
      expect(region.annotation, isNull, reason: 'no payload until a property exists');

      s.notifier.addAnnotationProperty(region.id);
      final firstAnnotationId = current(s.container, region.id).annotation!.id;
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'manufacturer', value: 'Acme'));
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'part_number', value: '1'));

      expect(propsOf(s.container, region.id), hasLength(3));
      expect(current(s.container, region.id).annotation!.id, firstAnnotationId, reason: 'identity is stable across edits');
      expect(s.container.read(foundationRuntimeServiceProvider).evidenceRegions, hasLength(1),
          reason: 'editing a property never creates another region');
    });

    test('G/H: edit a property key (normalized) and value', () {
      final s = start();
      final region = draw(s.notifier);
      s.notifier.addAnnotationProperty(region.id);

      s.notifier.updateAnnotationProperty(region.id, 0, const AnnotationProperty(key: 'Part Number', value: '123-456'));
      expect(propsOf(s.container, region.id).single, const AnnotationProperty(key: 'part_number', value: '123-456'));

      s.notifier.updateAnnotationProperty(
          region.id, 0, const AnnotationProperty(key: 'part_number', value: '999', valueType: 'number', unit: 'pcs'));
      final edited = propsOf(s.container, region.id).single;
      expect(edited.value, '999');
      expect(edited.valueType, 'number');
      expect(edited.unit, 'pcs');
    });

    test('I: delete a property; an empty list is valid; a bad index is a no-op', () {
      final s = start();
      final region = draw(s.notifier);
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'a', value: '1'));
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'b', value: '2'));

      s.notifier.removeAnnotationProperty(region.id, 0);
      expect(propsOf(s.container, region.id).map((p) => p.key), ['b']);
      s.notifier.removeAnnotationProperty(region.id, 99);
      expect(propsOf(s.container, region.id), hasLength(1));
      s.notifier.removeAnnotationProperty(region.id, 0);
      expect(propsOf(s.container, region.id), isEmpty);
      expect(current(s.container, region.id).annotation, isNotNull, reason: 'the (now empty) annotation is still valid');
    });

    test('deleting the region deletes its annotation data with it', () {
      final s = start();
      final region = draw(s.notifier);
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'a', value: '1'));
      s.notifier.deleteEvidenceRegion(region.id);
      expect(s.container.read(foundationRuntimeServiceProvider).evidenceRegions, isEmpty);
    });
  });

  group('persistence through the Knowledge Session', () {
    test('K/L/M/N: properties created on an annotation are saved and reload unchanged', () async {
      final s = start();
      // Every notifier mutation fire-and-forgets a whole-file session
      // save, and `KnowledgeSessionStorage.save` does not serialize
      // overlapping writes (pre-existing, outside this work package) --
      // so, like a person editing, let each save land before the next
      // edit instead of firing several in one microtask.
      Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

      final region = draw(s.notifier);
      await settle();
      s.notifier.addAnnotationProperty(region.id,
          property: const AnnotationProperty(key: 'gauge', value: '18', valueType: 'number', unit: 'AWG'));
      await settle();
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'manufacturer', value: 'Acme'));
      await settle();
      s.notifier.setEvidenceRegionNotes(region.id, 'seen near the ignition switch');
      await settle();
      final before = current(s.container, region.id);

      final reloaded = await KnowledgeSessionStorage.load(s.sessionId);

      final after = reloaded.evidenceRegions.single;
      expect(after.annotation!.id, before.annotation!.id);
      expect(after.annotation!.properties, before.annotation!.properties);
      expect(after.annotation!.properties, hasLength(2));
      expect(after.notes, 'seen near the ignition switch');
    });
  });

  group('classification / candidate behavior (WP-012 preserved)', () {
    void classify(ProviderContainer c, FoundationRuntimeNotifier n, String regionId, KnowledgeCandidateType t, String name) {
      final st = c.read(foundationRuntimeServiceProvider);
      applyRegionClassification(
        notifier: n,
        region: st.evidenceRegions.firstWhere((r) => r.id == regionId),
        linkedCandidateIds: st.candidatesLinkedToEvidenceRegion(regionId).map((k) => k.id).toList(),
        type: t,
        customName: name,
        annotatorId: 'jsmith',
      );
    }

    test('O/P/R: classify then reclassify -> one linked candidate, updated in place, properties intact', () {
      final s = start();
      final region = draw(s.notifier);
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'part_number', value: '123-456'));
      final annotationId = current(s.container, region.id).annotation!.id;

      classify(s.container, s.notifier, region.id, KnowledgeCandidateType.component, 'R123');
      var st = s.container.read(foundationRuntimeServiceProvider);
      expect(st.candidates, hasLength(1));
      final candidateId = st.candidates.single.id;
      expect(propsOf(s.container, region.id).single.value, '123-456', reason: 'classification leaves properties intact');

      classify(s.container, s.notifier, region.id, KnowledgeCandidateType.text, 'R123 label');
      st = s.container.read(foundationRuntimeServiceProvider);
      expect(st.candidates, hasLength(1));
      expect(st.candidates.single.id, candidateId);
      expect(propsOf(s.container, region.id).single.value, '123-456', reason: 'reclassification leaves properties intact');
      expect(current(s.container, region.id).annotation!.id, annotationId);
    });

    test('Q: editing properties never duplicates (or touches) the candidate', () {
      final s = start();
      final region = draw(s.notifier);
      classify(s.container, s.notifier, region.id, KnowledgeCandidateType.component, 'R123');
      final candidateBefore = s.container.read(foundationRuntimeServiceProvider).candidates.single;

      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'manufacturer', value: 'Acme'));
      s.notifier.updateAnnotationProperty(region.id, 0, const AnnotationProperty(key: 'manufacturer', value: 'Other'));
      s.notifier.removeAnnotationProperty(region.id, 0);

      final st = s.container.read(foundationRuntimeServiceProvider);
      expect(st.candidates, hasLength(1));
      expect(st.evidenceLinks, hasLength(1));
      expect(st.candidates.single.name, candidateBefore.name, reason: 'properties are not copied onto the candidate');
      expect(st.candidates.single.type, candidateBefore.type);
    });
  });

  group('boundary protection', () {
    test('S/T/U: property editing creates no Engineering Object, no Repository object, and no commit', () {
      final s = start();
      final region = draw(s.notifier);
      s.notifier.addAnnotationProperty(region.id, property: const AnnotationProperty(key: 'a', value: '1'));
      s.notifier.updateAnnotationProperty(region.id, 0, const AnnotationProperty(key: 'a', value: '2'));
      s.notifier.removeAnnotationProperty(region.id, 0);

      final st = s.container.read(foundationRuntimeServiceProvider);
      expect(st.candidates, isEmpty, reason: 'no candidate -- let alone an accepted Engineering Object -- is created');
      expect(st.objectList, isNull, reason: 'no Repository objects were listed or created');
      expect(st.commitReports, isEmpty, reason: 'no commit ran');
      expect(st.latestCommitReport, isNull);
    });

    test('V: the model is pure and the Inspector never reaches the Reference Vault / acquisition layer', () {
      final model = File('lib/knowledge/models/evidence_annotation.dart').readAsStringSync();
      // INGEST-012: may depend only on sibling pure model enums.
      final imports = RegExp(r"import '([^']+)'").allMatches(model).map((m) => m.group(1)!);
      expect(imports.every((i) => RegExp(r'^evidence_[a-z_]+\.dart$').hasMatch(i)), isTrue,
          reason: 'the property model depends only on sibling evidence models: $imports');
      final inspector = File('lib/knowledge/workspaces/extraction_inspector_dialog.dart').readAsStringSync();
      for (final forbidden in ['acquisition/', 'ReferenceVault', 'CommitTransactionService', 'CommitPlanService']) {
        expect(inspector, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  test('WP-012 regression: counts and relationship eligibility are unaffected by annotation properties', () {
    final withProps = EvidenceRegion(
      id: 'h1',
      sourceId: source,
      page: 1,
      x: 0,
      y: 0,
      width: 0.1,
      height: 0.1,
      label: 'Component: A',
      createdTime: now,
      origin: EvidenceOrigin.human,
      annotation: const EvidenceAnnotation(id: 'a', properties: [AnnotationProperty(key: 'k', value: 'v')]),
    );
    final other = withProps.copyWith(label: 'Text: B');
    final regions = [
      withProps,
      EvidenceRegion(
        id: 'h2',
        sourceId: source,
        page: 1,
        x: 0,
        y: 0,
        width: 0.1,
        height: 0.1,
        label: other.label,
        createdTime: now,
        origin: EvidenceOrigin.human,
      ),
    ];
    final summary = ExtractionInspectorSummary.from(
      FoundationServiceState(phase: FoundationConnectionPhase.connected, evidenceRegions: regions),
      source,
    );
    expect(summary.evidenceCount, 2);
    expect(summary.candidateCount, 0);
    expect(summary.classifiedHumanAnnotationCount, 2);
    expect(summary.canCreateRelationship, isTrue);
  });
}

class _SessionSeededNotifier extends FoundationRuntimeNotifier {
  _SessionSeededNotifier(this.session);

  final KnowledgeSession session;

  @override
  FoundationServiceState build() =>
      FoundationServiceState(phase: FoundationConnectionPhase.connected, knowledgeSession: session);
}
