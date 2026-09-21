import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/evidence_geometry.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// WP-INGEST-015 Inspector behaviour. The pdfrx viewer cannot run under the
/// widget tester, so the drawing gesture itself is covered by `PathDraft`
/// tests and the real-TRX300 run; here the annotation panel, mode selector,
/// width, persistence and reopen behaviour are exercised on an image source.
void main() {
  final now = DateTime(2026, 1, 1);
  final written = <String, String>{};

  setUp(() {
    written.clear();
    KnowledgeSessionStorage.debugSetWriter((id, json) async => written[id] = json);
  });
  tearDown(() => KnowledgeSessionStorage.debugSetWriter(null));

  late ProviderContainer container;
  late String sessionId;
  late SourceMaterial source;
  late EvidenceRegion area;
  late EvidenceRegion wire;

  Future<void> openInspector(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);
    sessionId = 'wp-ingest-015-ui-${DateTime.now().microsecondsSinceEpoch}';
    source = SourceMaterial(
      id: 'source-1',
      originalFileName: 'trx300.png',
      localPath: 'unused.png',
      type: SourceMaterialType.image,
      sizeBytes: 1,
      importDate: now,
      addedBy: 'test',
    );
    container = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(
        () => _Seeded(
          KnowledgeSession(
            id: sessionId,
            name: 'path ui',
            repositoryName: 'Repo',
            author: 'jsmith',
            createdTime: now,
            lastModified: now,
          ),
          source,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);
    area = notifier.createHumanAnnotation(
        sourceId: source.id, page: 1, x: 0.1, y: 0.1, width: 0.2, height: 0.1, annotatorId: 'jsmith');
    wire = notifier.createHumanPathAnnotation(
      sourceId: source.id,
      page: 1,
      points: const [GeometryPoint(0.2, 0.5), GeometryPoint(0.3, 0.5), GeometryPoint(0.35, 0.55)],
      annotatorId: 'jsmith',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExtractionInspectorDialog(context, source: source),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<EvidenceRegion> persisted(String id) async {
    await KnowledgeSessionStorage.flushPendingForTest();
    final record = KnowledgeSessionRecord.fromJson(jsonDecode(written[sessionId]!) as Map<String, dynamic>);
    return record.evidenceRegions.firstWhere((r) => r.id == id);
  }

  Finder inCard(EvidenceRegion r, Finder f) =>
      find.descendant(of: find.byKey(ValueKey('annotation-${r.id}')), matching: f);
  Finder hint(EvidenceRegion r, String h) =>
      inCard(r, find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == h));
  final save = find.byKey(const ValueKey('save-annotation-changes'));

  testWidgets('1/2: Area is the default mode and Path can be selected', (tester) async {
    await openInspector(tester);
    SegmentedButton<dynamic> selector() => tester.widget(find.byKey(const ValueKey('annotation-mode-selector')));
    expect(selector().selected.single.toString(), contains('area'));
    // Arm drawing, then choose Path: the Finish/Cancel controls appear, empty.
    await tester.tap(find.byTooltip('Annotate a Region'));
    await tester.pump();
    expect(find.byKey(const ValueKey('finish-path')), findsNothing, reason: 'no path controls in Area mode');
    await tester.tap(find.text('Path'));
    await tester.pump();
    expect(selector().selected.single.toString(), contains('path'));
    // 3/4: nothing drawn yet -> cannot finish or cancel.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('finish-path'))).onPressed, isNull);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('cancel-path'))).onPressed, isNull);
    await tester.tap(find.text('Area'));
    await tester.pump();
    expect(find.byKey(const ValueKey('finish-path')), findsNothing);
  });

  testWidgets('5: a finished path is one EvidenceRegion listed as a path with a width control; areas have none', (tester) async {
    await openInspector(tester);
    final regions = container.read(foundationRuntimeServiceProvider).evidenceRegions;
    expect(regions.where((r) => r.geometry is PolylineGeometry), hasLength(1));
    expect(find.text('Page 1 · Path'), findsOneWidget);
    expect(find.byKey(const ValueKey('path-width-field')), findsOneWidget, reason: 'only the path has a width');
    expect(inCard(area, find.byKey(const ValueKey('path-width-field'))), findsNothing);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('path-width-field')));
    expect(field.controller!.text, '2.0', reason: 'default visual width');
  });

  testWidgets('6/7/8/9/10: width, name, notes and properties save, persist and survive reopen', (tester) async {
    await openInspector(tester);
    await tester.enterText(find.byKey(const ValueKey('path-width-field')), '4.5');
    await tester.enterText(hint(wire, 'Name (optional)'), 'Starter Signal');
    await tester.tap(inCard(wire, find.text('Details')));
    await settle(tester);
    await tester.enterText(
      inCard(wire, find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Description / Notes')),
      'traced over the red wire',
    );
    await tester.ensureVisible(inCard(wire, find.text('Add Property')));
    await tester.pump();
    await tester.tap(inCard(wire, find.text('Add Property')));
    await tester.pump();
    await tester.enterText(hint(wire, 'key'), 'Color');
    await tester.enterText(hint(wire, 'value'), 'red');
    await tester.pump();
    await tester.tap(save);
    await tester.pump();

    final saved = await persisted(wire.id);
    expect((saved.geometry as PolylineGeometry).strokeWidth, 4.5);
    expect((saved.geometry as PolylineGeometry).points, (wire.geometry as PolylineGeometry).points);
    expect(saved.annotation?.name, 'Starter Signal');
    expect(saved.notes, 'traced over the red wire');
    expect(saved.annotation?.properties.single.key, 'color');
    expect(saved.annotation?.properties.single.value, 'red');
    // The rectangle is untouched.
    expect((await persisted(area.id)).geometry, isA<RectangleGeometry>());

    // 11: close and reopen -> the path and its width are still there.
    await settle(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Save changes?'), findsNothing);
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Page 1 · Path'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('path-width-field'))).controller!.text, '4.5');
  });

  testWidgets('an invalid width is reported on Save and nothing about the path changes', (tester) async {
    await openInspector(tester);
    await tester.enterText(find.byKey(const ValueKey('path-width-field')), 'abc');
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(find.textContaining('Not saved:'), findsOneWidget);
    final region = container.read(foundationRuntimeServiceProvider).evidenceRegions.firstWhere((r) => r.id == wire.id);
    expect((region.geometry as PolylineGeometry).strokeWidth, PolylineGeometry.defaultStrokeWidth);
  });

  testWidgets('12: an existing area annotation still saves exactly as before', (tester) async {
    await openInspector(tester);
    await tester.enterText(hint(area, 'Name (optional)'), 'Pump');
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    final saved = await persisted(area.id);
    expect(saved.annotation?.name, 'Pump');
    expect((saved.x, saved.y, saved.width, saved.height), (0.1, 0.1, 0.2, 0.1));
  });

  testWidgets('deleting a path removes it from the session', (tester) async {
    await openInspector(tester);
    await tester.tap(inCard(wire, find.byIcon(Icons.delete_outline)));
    await tester.pump();
    expect(container.read(foundationRuntimeServiceProvider).evidenceRegions.map((r) => r.id), [area.id]);
  });
}

class _Seeded extends FoundationRuntimeNotifier {
  _Seeded(this.session, this.source);

  final KnowledgeSession session;
  final SourceMaterial source;

  @override
  FoundationServiceState build() => FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        knowledgeSession: session,
        sourceMaterials: [source],
      );
}
