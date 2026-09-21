import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/document_orientation.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation.dart';
import 'package:oep_studio/knowledge/models/evidence_geometry.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/knowledge_validation_exception.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart' show applyRegionClassification;

/// WP-INGEST-015: polyline (linear) evidence alongside rectangle (area) evidence.
void main() {
  final now = DateTime(2026, 1, 1);
  const source = 'source-1';
  final written = <String, String>{};

  setUp(() {
    written.clear();
    KnowledgeSessionStorage.debugSetWriter((id, json) async => written[id] = json);
  });
  tearDown(() => KnowledgeSessionStorage.debugSetWriter(null));

  const bend = [
    GeometryPoint(0.21, 0.43),
    GeometryPoint(0.28, 0.43),
    GeometryPoint(0.35, 0.46),
    GeometryPoint(0.42, 0.46),
  ];

  ({ProviderContainer container, FoundationRuntimeNotifier notifier, String sessionId}) start() {
    final id = 'wp-ingest-015-${DateTime.now().microsecondsSinceEpoch}';
    final container = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(
        () => _Seeded(KnowledgeSession(
          id: id,
          name: 'geometry',
          repositoryName: 'Repo',
          author: 'jsmith',
          createdTime: now,
          lastModified: now,
        )),
      ),
    ]);
    addTearDown(container.dispose);
    return (container: container, notifier: container.read(foundationRuntimeServiceProvider.notifier), sessionId: id);
  }

  Future<KnowledgeSessionRecord> reload(String sessionId) async {
    await KnowledgeSessionStorage.flushPendingForTest();
    return KnowledgeSessionRecord.fromJson(jsonDecode(written[sessionId]!) as Map<String, dynamic>);
  }

  EvidenceRegion path(FoundationRuntimeNotifier n, {double width = 3.5}) => n.createHumanPathAnnotation(
        sourceId: source,
        page: 1,
        points: bend,
        strokeWidth: width,
        annotatorId: 'jsmith',
      );

  group('model', () {
    test('A: a legacy rectangle record (flat x/y/width/height, no geometry key) loads unchanged', () {
      final json = {
        'id': 'r1',
        'sourceId': source,
        'page': 2,
        'x': 0.1,
        'y': 0.2,
        'width': 0.3,
        'height': 0.4,
        'label': 'Old',
        'notes': '',
        'createdTime': now.toIso8601String(),
      };
      final region = EvidenceRegion.fromJson(json);
      expect(region.geometry, isA<RectangleGeometry>());
      expect((region.x, region.y, region.width, region.height), (0.1, 0.2, 0.3, 0.4));
      // And it re-serializes to the same flat shape: no destructive migration.
      final again = region.toJson();
      expect(again.containsKey('geometry'), isFalse);
      expect((again['x'], again['y'], again['width'], again['height']), (0.1, 0.2, 0.3, 0.4));
    });

    test('B/C/D/E: a polyline serializes, deserializes and round-trips exactly, order preserved', () {
      final region = EvidenceRegion(
        id: 'p1',
        sourceId: source,
        page: 1,
        geometry: PolylineGeometry(bend, strokeWidth: 3.5),
        label: 'Wire',
        createdTime: now,
      );
      final json = jsonDecode(jsonEncode(region.toJson())) as Map<String, dynamic>;
      expect((json['geometry'] as Map)['type'], 'polyline');
      final restored = EvidenceRegion.fromJson(json);
      final geometry = restored.geometry as PolylineGeometry;
      expect(geometry.points, bend, reason: 'point order and values preserved');
      expect(geometry.strokeWidth, 3.5);
      expect(jsonEncode(restored.toJson()), jsonEncode(region.toJson()));
    });

    test('a polyline exposes its bounding box through the same x/y/width/height', () {
      final region = EvidenceRegion(
          id: 'p', sourceId: source, page: 1, geometry: PolylineGeometry(bend), label: 'w', createdTime: now);
      expect(region.x, closeTo(0.21, 1e-12));
      expect(region.y, closeTo(0.43, 1e-12));
      expect(region.width, closeTo(0.21, 1e-12));
      expect(region.height, closeTo(0.03, 1e-12));
    });

    test('F: stroke width persists (document points, not pixels)', () {
      final g = PolylineGeometry(bend, strokeWidth: 7.25);
      expect(PolylineGeometry.defaultStrokeWidth, 2.0);
      expect((EvidenceGeometry.fromJson(g.toJson()) as PolylineGeometry).strokeWidth, 7.25);
    });

    test('G: fewer than two points is rejected, never turned into a rectangle', () {
      expect(() => PolylineGeometry(const []), throwsA(isA<KnowledgeValidationException>()));
      expect(() => PolylineGeometry(const [GeometryPoint(0.1, 0.1)]), throwsA(isA<KnowledgeValidationException>()));
    });

    test('H: NaN, infinite and out-of-page coordinates and bad widths are rejected', () {
      for (final bad in [
        GeometryPoint(double.nan, 0.5),
        GeometryPoint(0.5, double.infinity),
        const GeometryPoint(-0.01, 0.5),
        const GeometryPoint(0.5, 1.01),
      ]) {
        expect(() => PolylineGeometry([const GeometryPoint(0.1, 0.1), bad]), throwsA(isA<KnowledgeValidationException>()),
            reason: '$bad');
      }
      for (final w in [0.0, -1.0, double.nan, double.infinity, 1000.0]) {
        expect(() => PolylineGeometry(bend, strokeWidth: w), throwsA(isA<KnowledgeValidationException>()), reason: '$w');
      }
    });

    test('an unknown geometry type is rejected on load', () {
      expect(() => EvidenceGeometry.fromJson({'type': 'spline'}), throwsA(isA<KnowledgeValidationException>()));
    });

    test('geometry carries no semantic type: classification lives on the annotation', () {
      final json = PolylineGeometry(bend).toJson();
      expect(json.keys.toSet(), {'type', 'points', 'strokeWidth'});
    });

    test('Q: zoom changes only the canvas size; the stored width and points do not change', () {
      final g = PolylineGeometry(bend, strokeWidth: 4);
      final before = jsonEncode(g.toJson());
      final atSmall = strokeWidthToCanvasPx(g.strokeWidth, 600, 792);
      final atLarge = strokeWidthToCanvasPx(g.strokeWidth, 2400, 792);
      expect(atLarge / atSmall, closeTo(4.0, 1e-9), reason: 'same document width at 4x zoom');
      expect(jsonEncode(g.toJson()), before);
    });

    test('R: path points use the same normalized page coordinates and orientation map as rectangles', () {
      // A path along a rectangle's diagonal has that rectangle's bounds.
      final rect = RectangleGeometry(0.1, 0.2, 0.3, 0.1).bounds;
      final diagonal = PolylineGeometry(const [GeometryPoint(0.1, 0.2), GeometryPoint(0.4, 0.3)]).bounds;
      expect((diagonal.x, diagonal.y), (rect.x, rect.y));
      expect(diagonal.width, closeTo(rect.width, 1e-12));
      expect(diagonal.height, closeTo(rect.height, 1e-12));
      // Both go through the one DocumentOrientation mapping.
      final o = DocumentOrientation.deg90;
      final p = o.pageToOriented(0.1, 0.2);
      final r = o.rectPageToOriented(0.1, 0.2, 0.0, 0.0);
      expect((p.x, p.y), (r.x, r.y));
    });
  });

  group('PathDraft (in-progress path)', () {
    test('needs two points; cancel removes the unfinished path', () {
      final draft = PathDraft();
      expect(draft.canFinish, isFalse);
      draft.add(1, const GeometryPoint(0.1, 0.1));
      expect(draft.canFinish, isFalse);
      expect(() => draft.finish(), throwsA(isA<KnowledgeValidationException>()));
      draft.cancel();
      expect(draft.isEmpty, isTrue);
      expect(draft.page, isNull);
    });

    test('undoLast removes only the most recent point and empties the draft cleanly', () {
      final draft = PathDraft();
      expect(draft.undoLast(), isFalse);
      draft.add(1, bend[0]);
      draft.add(1, bend[1]);
      draft.add(1, bend[2]);
      expect(draft.undoLast(), isTrue);
      expect(draft.points, [bend[0], bend[1]]);
      expect(draft.canFinish, isTrue);
      draft.undoLast();
      draft.undoLast();
      expect(draft.isEmpty, isTrue);
      expect(draft.page, isNull, reason: 'a fresh path may start on any page');
      expect(draft.add(2, bend[0]), isTrue);
    });

    test('finishing yields one polyline with the default width and clears the draft; other pages are ignored', () {
      final draft = PathDraft();
      expect(draft.add(1, bend[0]), isTrue);
      expect(draft.add(2, bend[1]), isFalse, reason: 'a path stays on one page');
      draft.add(1, bend[1]);
      final geometry = draft.finish();
      expect(geometry.points, [bend[0], bend[1]]);
      expect(geometry.strokeWidth, PolylineGeometry.defaultStrokeWidth);
      expect(draft.isEmpty, isTrue);
    });
  });

  group('session behaviour', () {
    test('I/J/K/L/M: paths and rectangles coexist and survive autosave and reload with their metadata', () async {
      final t = start();
      final rect = t.notifier.createHumanAnnotation(
          sourceId: source, page: 1, x: 0.1, y: 0.1, width: 0.2, height: 0.1, annotatorId: 'jsmith');
      final wire = path(t.notifier);
      final machine = t.notifier.createEvidenceRegion(
          sourceId: source, page: 1, x: 0.5, y: 0.5, width: 0.1, height: 0.1, origin: EvidenceOrigin.machine);
      t.notifier.setObservationName(wire.id, 'Starter Signal');
      t.notifier.setEvidenceRegionNotes(wire.id, 'red wire, bends at relay');
      t.notifier.setAnnotationProperties(wire.id, [
        const AnnotationProperty(key: 'color', value: 'red'),
        const AnnotationProperty(key: 'gauge', value: '18 AWG'),
      ]);

      final record = await reload(t.sessionId);
      expect(record.evidenceRegions, hasLength(3));
      final loadedWire = record.evidenceRegions.firstWhere((r) => r.id == wire.id);
      expect(loadedWire.geometry, isA<PolylineGeometry>());
      expect((loadedWire.geometry as PolylineGeometry).points, bend);
      expect((loadedWire.geometry as PolylineGeometry).strokeWidth, 3.5);
      expect(loadedWire.annotation?.name, 'Starter Signal');
      expect(loadedWire.notes, 'red wire, bends at relay');
      expect(loadedWire.annotation?.properties.map((p) => '${p.key}=${p.value}'), ['color=red', 'gauge=18 AWG']);
      expect(record.evidenceRegions.firstWhere((r) => r.id == rect.id).geometry, isA<RectangleGeometry>());
      expect(record.evidenceRegions.firstWhere((r) => r.id == machine.id).origin, EvidenceOrigin.machine);
    });

    test('changing the width persists and is validated', () async {
      final t = start();
      final wire = path(t.notifier);
      t.notifier.setEvidenceRegionStrokeWidth(wire.id, 6);
      expect(((await reload(t.sessionId)).evidenceRegions.single.geometry as PolylineGeometry).strokeWidth, 6);
      expect(() => t.notifier.setEvidenceRegionStrokeWidth(wire.id, 0), throwsA(isA<KnowledgeValidationException>()));
      final rect = t.notifier.createHumanAnnotation(
          sourceId: source, page: 1, x: 0.1, y: 0.1, width: 0.1, height: 0.1, annotatorId: 'j');
      expect(() => t.notifier.setEvidenceRegionStrokeWidth(rect.id, 3), throwsA(isA<KnowledgeValidationException>()));
    });

    test('an invalid path is rejected by the notifier and creates nothing', () {
      final t = start();
      expect(
        () => t.notifier.createHumanPathAnnotation(
            sourceId: source, page: 1, points: const [GeometryPoint(0.1, 0.1)], annotatorId: 'j'),
        throwsA(isA<KnowledgeValidationException>()),
      );
      expect(t.container.read(foundationRuntimeServiceProvider).evidenceRegions, isEmpty);
    });

    test('N/O/P: a path classifies as Wire through the existing candidate path, links as evidence, and mutates no Repository', () async {
      final t = start();
      final wire = path(t.notifier);
      applyRegionClassification(
        notifier: t.notifier,
        region: wire,
        linkedCandidateIds: const [],
        type: KnowledgeCandidateType.wire,
        customName: 'Starter Signal',
        annotatorId: 'jsmith',
      );
      final state = t.container.read(foundationRuntimeServiceProvider);
      final candidate = state.candidates.single;
      expect(candidate.type, KnowledgeCandidateType.wire);
      expect(candidate.name, 'Starter Signal');
      expect(state.candidatesLinkedToEvidenceRegion(wire.id).map((c) => c.id), [candidate.id]);
      expect(state.evidenceLinks.single.regionId, wire.id);
      final region = state.evidenceRegions.single;
      expect(region.label, 'Wire: Starter Signal');
      expect(region.annotation?.type, 'wire');
      expect(region.geometry, isA<PolylineGeometry>(), reason: 'classification does not touch geometry');
      // Candidate only: no commit, and Wire has no Foundation object mapping.
      expect(state.commitReports, isEmpty);
      expect(KnowledgeCandidateType.wire.foundationCategory, isNull);
      // Survives reload.
      expect((await reload(t.sessionId)).candidates.single.type, KnowledgeCandidateType.wire);
    });

    test('Wire suggests observed-attribute properties, none of them mandatory or topology', () {
      expect(observationPropertySuggestions['wire'],
          containsAll(['color', 'gauge', 'from', 'to', 'circuit', 'signal', 'function']));
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
