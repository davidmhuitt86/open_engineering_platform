import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation_status.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart';

/// INGEST-012 (Observation model) tests. The Observation is the
/// `EvidenceAnnotation` payload carried by an `EvidenceRegion`; the
/// Inspector's private widgets are exercised through the same unmodified
/// notifier methods they call (the hosted pdfrx viewer is never rendered in
/// this codebase's tests).
void main() {
  const source = 'source-1';
  final now = DateTime(2026, 1, 1);
  final createdIds = <String>[];

  tearDown(() async {
    await KnowledgeSessionStorage.flushPendingForTest();
    for (final id in createdIds) {
      final dir = KnowledgeSessionStorage.sessionDirectory(id);
      for (var i = 0; i < 10 && dir.existsSync(); i++) {
        try {
          await dir.delete(recursive: true);
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    createdIds.clear();
  });

  ({ProviderContainer c, FoundationRuntimeNotifier n, String id}) start() {
    final id = 'wp-ingest-012-obs-${DateTime.now().microsecondsSinceEpoch}';
    createdIds.add(id);
    final c = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(() => _Seeded(KnowledgeSession(
          id: id, name: 'obs', repositoryName: 'Repo', author: 'jsmith', createdTime: now, lastModified: now))),
    ]);
    addTearDown(c.dispose);
    return (c: c, n: c.read(foundationRuntimeServiceProvider.notifier), id: id);
  }

  EvidenceRegion draw(FoundationRuntimeNotifier n) => n.createHumanAnnotation(
      sourceId: source, page: 1, x: 0.1, y: 0.1, width: 0.2, height: 0.1, annotatorId: 'jsmith');

  FoundationServiceState st(ProviderContainer c) => c.read(foundationRuntimeServiceProvider);
  EvidenceRegion reg(ProviderContainer c, String id) => st(c).evidenceRegions.firstWhere((r) => r.id == id);

  group('model', () {
    test('A: universal fields only, everything else absent', () {
      const o = Observation(id: 'o1', type: 'component', name: 'Relay', description: 'K1');
      final r = Observation.fromJson(o.toJson());
      expect((r.type, r.name, r.description), ('component', 'Relay', 'K1'));
      expect(r.properties, isEmpty);
      expect(r.origin, isNull);
      expect(r.authorId, isNull);
    });

    test('B-F: arbitrary string, numeric and boolean properties round-trip in order', () {
      const o = Observation(id: 'o1', properties: [
        ObservationProperty(key: 'label', value: 'A1', source: 'human'),
        ObservationProperty(key: 'gauge', value: '18', valueType: 'number', unit: 'AWG'),
        ObservationProperty(key: 'shielded', value: 'true', valueType: 'boolean'),
      ]);
      final r = Observation.fromJson(o.toJson());
      expect(r.properties, o.properties);
      expect(r.properties[0].source, 'human');
      expect(r.properties[1].numericValue, 18);
      expect(r.properties[2].booleanValue, isTrue);
      expect(r.properties[0].numericValue, isNull);
    });

    test('G: empty properties round-trip', () {
      expect(Observation.fromJson(const Observation(id: 'o').toJson()).properties, isEmpty);
    });

    test('origin llm and a model identity are representable without schema change', () {
      const o = Observation(
          id: 'o', origin: EvidenceOrigin.llm, authorId: 'model-x@1', status: EvidenceAnnotationStatus.unverified);
      final r = Observation.fromJson(o.toJson());
      expect(r.origin, EvidenceOrigin.llm);
      expect(r.authorId, 'model-x@1');
      expect(r.status, EvidenceAnnotationStatus.unverified);
    });

    test('S/T: a future-style wire needs no dedicated model, only keys', () {
      const wire = Observation(id: 'w', type: 'wire', name: 'W12', properties: [
        ObservationProperty(key: 'color', value: 'red'),
        ObservationProperty(key: 'gauge', value: '18 AWG'),
        ObservationProperty(key: 'function', value: 'power'),
      ]);
      final r = Observation.fromJson(wire.toJson());
      expect(r.type, 'wire');
      expect({for (final p in r.properties) p.key: p.value}, {'color': 'red', 'gauge': '18 AWG', 'function': 'power'});
    });

    test('I/J: legacy region and WP-013 annotation JSON without observation fields load', () {
      final region = EvidenceRegion.fromJson({
        'id': 'r1',
        'sourceId': source,
        'page': 1,
        'x': 0.1,
        'y': 0.1,
        'width': 0.1,
        'height': 0.1,
        'label': 'Old',
        'createdTime': '2026-01-01T00:00:00.000',
      });
      expect(region.annotation, isNull);
      final wp13 = Observation.fromJson({'id': 'a', 'properties': []});
      expect((wp13.type, wp13.origin, wp13.regionId), (null, null, null));
    });

    test('type suggestions are configuration only', () {
      expect(observationPropertySuggestions['wire'], containsAll(['color', 'gauge']));
    });
  });

  group('notifier / persistence', () {
    test('K/L: human observation is stamped with provenance; machine region stays machine', () {
      final t = start();
      final human = draw(t.n);
      t.n.addAnnotationProperty(human.id, property: const ObservationProperty(key: 'color', value: 'red'));
      final o = reg(t.c, human.id).annotation!;
      expect(o.origin, EvidenceOrigin.human);
      expect(o.authorId, 'jsmith');
      expect(o.regionId, human.id);
      expect(o.status, EvidenceAnnotationStatus.unverified);

      final machine = t.n.createEvidenceRegion(
          sourceId: source, page: 1, x: 0, y: 0, width: 0.1, height: 0.1, origin: EvidenceOrigin.machine);
      expect(reg(t.c, machine.id).origin, EvidenceOrigin.machine);
      expect(reg(t.c, machine.id).annotation, isNull);
    });

    test('M/N/O/Q: classification records the observation, keeps ONE candidate, no engineering object; reclassify preserves observation', () {
      final t = start();
      final region = draw(t.n);
      final entitiesBefore = st(t.c).engineeringEntities.length;
      applyRegionClassification(
          notifier: t.n,
          region: region,
          linkedCandidateIds: const [],
          type: KnowledgeCandidateType.component,
          customName: 'K1',
          annotatorId: 'jsmith');
      final firstId = reg(t.c, region.id).annotation!.id;
      expect(reg(t.c, region.id).annotation!.type, 'component');
      expect(reg(t.c, region.id).annotation!.name, 'K1');
      expect(st(t.c).candidates, hasLength(1));
      expect(st(t.c).evidenceLinks, hasLength(1));

      t.n.addAnnotationProperty(region.id, property: const ObservationProperty(key: 'part_number', value: '9'));
      final linked = st(t.c).candidatesLinkedToEvidenceRegion(region.id).map((c) => c.id).toList();
      applyRegionClassification(
          notifier: t.n,
          region: reg(t.c, region.id),
          linkedCandidateIds: linked,
          type: KnowledgeCandidateType.tool,
          customName: 'Torque Wrench',
          annotatorId: 'jsmith');
      final o = reg(t.c, region.id).annotation!;
      expect(o.id, firstId);
      expect(o.type, 'tool');
      expect(o.properties.single.key, 'part_number');
      expect(st(t.c).candidates, hasLength(1));
      expect(st(t.c).candidates.single.type, KnowledgeCandidateType.tool);
      expect(st(t.c).engineeringEntities.length, entitiesBefore);
      expect(st(t.c).commitReports, isEmpty);
    });

    test('R: add / edit / remove property through the notifier used by the Inspector', () {
      final t = start();
      final r = draw(t.n);
      t.n.addAnnotationProperty(r.id);
      t.n.updateAnnotationProperty(
          r.id, 0, const ObservationProperty(key: 'Pin Count', value: '4', valueType: 'number'));
      expect(reg(t.c, r.id).annotation!.properties.single.key, 'pin_count');
      t.n.removeAnnotationProperty(r.id, 0);
      expect(reg(t.c, r.id).annotation!.properties, isEmpty);
    });

    test('description follows the notes the UI edits once an observation exists', () {
      final t = start();
      final r = draw(t.n);
      t.n.addAnnotationProperty(r.id);
      t.n.setEvidenceRegionNotes(r.id, '  hello ');
      expect(reg(t.c, r.id).annotation!.description, 'hello');
      expect(reg(t.c, r.id).notes, 'hello');
    });

    test('H: observation survives save and reload', () async {
      final t = start();
      final r = draw(t.n);
      applyRegionClassification(
          notifier: t.n,
          region: r,
          linkedCandidateIds: const [],
          type: KnowledgeCandidateType.component,
          customName: 'Conn',
          annotatorId: 'jsmith');
      t.n.addAnnotationProperty(r.id,
          property: const ObservationProperty(key: 'gauge', value: '18', valueType: 'number', unit: 'AWG'));
      await KnowledgeSessionStorage.flushPendingForTest();
      final loaded = await KnowledgeSessionStorage.load(t.id);
      final o = loaded.evidenceRegions.single.annotation!;
      expect((o.type, o.name, o.origin, o.regionId), ('component', 'Conn', EvidenceOrigin.human, r.id));
      expect(o.properties.single,
          const ObservationProperty(key: 'gauge', value: '18', valueType: 'number', unit: 'AWG'));
    });

    test('P: deleting a region removes its observation and links from state and disk', () async {
      final t = start();
      final r = draw(t.n);
      applyRegionClassification(
          notifier: t.n,
          region: r,
          linkedCandidateIds: const [],
          type: KnowledgeCandidateType.text,
          customName: 'x',
          annotatorId: 'jsmith');
      t.n.deleteEvidenceRegion(r.id);
      await KnowledgeSessionStorage.flushPendingForTest();
      final loaded = await KnowledgeSessionStorage.load(t.id);
      expect(loaded.evidenceRegions, isEmpty);
      expect(loaded.evidenceLinks, isEmpty);
    });

    test('WP-012 regression: relationship gating still counts classified human annotations only', () {
      final t = start();
      final a = draw(t.n);
      final b = draw(t.n);
      applyRegionClassification(
          notifier: t.n,
          region: a,
          linkedCandidateIds: const [],
          type: KnowledgeCandidateType.component,
          customName: '',
          annotatorId: 'j');
      expect(ExtractionInspectorSummary.from(st(t.c), source).canCreateRelationship, isFalse);
      applyRegionClassification(
          notifier: t.n,
          region: b,
          linkedCandidateIds: const [],
          type: KnowledgeCandidateType.component,
          customName: '',
          annotatorId: 'j');
      expect(ExtractionInspectorSummary.from(st(t.c), source).canCreateRelationship, isTrue);
    });
  });
}

class _Seeded extends FoundationRuntimeNotifier {
  _Seeded(this.session);
  final KnowledgeSession session;
  @override
  FoundationServiceState build() =>
      FoundationServiceState(phase: FoundationConnectionPhase.connected, knowledgeSession: session);
}
