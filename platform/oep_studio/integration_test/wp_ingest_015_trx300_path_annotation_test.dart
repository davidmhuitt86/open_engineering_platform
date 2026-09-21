// WP-INGEST-015 real-artifact validation: draws a component area, a text area
// and a multi-point wire path on the REAL TRX300 PDF in the real Extraction
// Inspector (real pdfrx viewer, real session storage), then closes/reopens,
// reloads the session from disk and zooms in/out.
//
// Run (from platform/oep_studio):
//   flutter test integration_test/wp_ingest_015_trx300_path_annotation_test.dart -d windows
// Screenshots are written to the directory named by the OEP_SHOT_DIR
// environment variable (default: the system temp directory). The source's
// Extraction Orientation comes from OEP_ORIENT (default 90, which shows the
// sideways TRX300 upright).
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/document_orientation.dart';
import 'package:oep_studio/knowledge/models/evidence_geometry.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart';
import 'package:pdfrx/pdfrx.dart';

final _shotDir = Platform.environment['OEP_SHOT_DIR'] ?? Directory.systemTemp.path;

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(String name) async {
  final view = RendererBinding.instance.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 1.0);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  File('$_shotDir${Platform.pathSeparator}wp015_$name.png').writeAsBytesSync(bytes);
  image.dispose();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TRX300: area + text + wire path annotations, reopen, reload, zoom', (tester) async {
    final pdfPath = '${Directory.current.path}/../../reference/ingestion/trx300/source/trx300_factory_wiring_diagram.pdf';
    final now = DateTime.now();
    final sessionId = 'wp-ingest-015-e2e-${now.microsecondsSinceEpoch}';
    final orientation = DocumentOrientation.fromDegrees(int.parse(Platform.environment['OEP_ORIENT'] ?? '90'));
    final source = SourceMaterial(
      id: 'source-trx300',
      originalFileName: 'trx300_factory_wiring_diagram.pdf',
      localPath: File(pdfPath).absolute.path,
      type: SourceMaterialType.pdf,
      sizeBytes: File(pdfPath).lengthSync(),
      importDate: now,
      addedBy: 'e2e',
    ).withExtractionOrientation(orientation);

    final container = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(
        () => _Seeded(
          KnowledgeSession(
            id: sessionId,
            name: 'WP-INGEST-015 TRX300',
            repositoryName: 'Repo',
            author: 'e2e',
            createdTime: now,
            lastModified: now,
          ),
          source,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
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
    ));
    await tester.tap(find.text('open'));
    await _pumpFor(tester, const Duration(seconds: 4));
    await _shot('01_opened');
    print('E2E viewer rect: ${tester.getRect(find.byType(PdfViewer))} orientation=${orientation.degrees}');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Zoom In'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
    }
    await _pumpFor(tester, const Duration(seconds: 2));
    await _shot('02_zoomed');

    // ---- 1. component AREA and 2. text AREA (default Area mode) ----------
    await tester.tap(find.byTooltip('Annotate a Region'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.timedDragFrom(const Offset(735, 150), const Offset(80, 112), const Duration(milliseconds: 500));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await tester.timedDragFrom(const Offset(836, 292), const Offset(30, 80), const Duration(milliseconds: 500));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    final areaRegions = container.read(foundationRuntimeServiceProvider).evidenceRegions;
    print('E2E areas drawn: ${areaRegions.length}');
    expect(areaRegions, hasLength(2));
    expect(areaRegions.every((r) => r.geometry is RectangleGeometry), isTrue);

    // ---- 3. WIRE PATH across two bends ------------------------------------
    await tester.tap(find.text('Path'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    const taps = [Offset(388, 250), Offset(388, 361), Offset(590, 361), Offset(783, 361), Offset(783, 480)];
    for (final p in taps) {
      await tester.tapAt(p);
      await _pumpFor(tester, const Duration(milliseconds: 250));
    }
    expect(find.text('Finish Path (5 pts)'), findsOneWidget);
    // Magnifier loupe follows the mouse while tracing.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 420));
    await mouse.moveTo(const Offset(783, 480));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('path-magnifier')), findsOneWidget);
    await _shot('03_path_magnifier');
    // Undo Last removes only the most recent vertex.
    await tester.tapAt(const Offset(700, 430));
    await _pumpFor(tester, const Duration(milliseconds: 250));
    expect(find.text('Finish Path (6 pts)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('undo-path-point')));
    await _pumpFor(tester, const Duration(milliseconds: 250));
    expect(find.text('Finish Path (5 pts)'), findsOneWidget);
    await mouse.removePointer();
    await _shot('03_path_in_progress');
    await tester.tap(find.byKey(const ValueKey('finish-path')));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    final regions = container.read(foundationRuntimeServiceProvider).evidenceRegions;
    expect(regions, hasLength(3));
    final wire = regions.firstWhere((r) => r.geometry is PolylineGeometry);
    final wireGeometry = wire.geometry as PolylineGeometry;
    print('E2E wire points: ${wireGeometry.points}');
    expect(wireGeometry.points, hasLength(5));

    List<Offset> overlayVertices() {
      final painters = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PathPainter');
      RenderBox? best;
      List<Offset> bestOffsets = const [];
      for (final e in painters.evaluate()) {
        final box = e.renderObject! as RenderBox;
        final offsets = ((e.widget as CustomPaint).painter! as dynamic).offsets as List<Offset>;
        if (offsets.length != 5) continue;
        if (best == null || box.size.width > best.size.width) {
          best = box;
          bestOffsets = offsets;
        }
      }
      return best == null ? const [] : [for (final o in bestOffsets) best.localToGlobal(o)];
    }

    // Alignment at draw time: each overlay vertex, in global coordinates, is where it was clicked.
    final vertices = overlayVertices();
    expect(vertices, hasLength(5));
    var maxErr = 0.0;
    for (var i = 0; i < 5; i++) {
      final err = (vertices[i] - taps[i]).distance;
      if (err > maxErr) maxErr = err;
    }
    print('E2E draw-time max vertex error (logical px): ${maxErr.toStringAsFixed(2)}');
    expect(maxErr, lessThan(3.0));

    // Width + classification + Save through the panel.
    final widthField = find.byKey(const ValueKey('path-width-field'));
    await tester.ensureVisible(widthField);
    await tester.enterText(widthField, '3.0');
    await tester.pump();
    Future<void> classify(String regionId, String label) async {
      final dropdown = find.descendant(
          of: find.byKey(ValueKey('annotation-$regionId')),
          matching: find.byType(DropdownButton<KnowledgeCandidateType>));
      await tester.ensureVisible(dropdown);
      await _pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(dropdown);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text(label).last);
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }

    final annotationList = find.byType(ListView).last;
    await tester.drag(annotationList, const Offset(0, 2000));
    await _pumpFor(tester, const Duration(milliseconds: 400));
    await classify(areaRegions[0].id, 'Component');
    await classify(areaRegions[1].id, 'Text');
    await tester.drag(annotationList, const Offset(0, -2000));
    await _pumpFor(tester, const Duration(milliseconds: 400));
    await classify(wire.id, 'Wire');
    await tester.tap(find.byKey(const ValueKey('save-annotation-changes')));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Changes saved'), findsOneWidget);
    await _shot('04_saved');

    Future<void> verifyPersisted(String stage) async {
      final record = await KnowledgeSessionStorage.load(sessionId);
      final persisted = record.evidenceRegions;
      final w = persisted.firstWhere((r) => r.geometry is PolylineGeometry);
      final g = w.geometry as PolylineGeometry;
      print('E2E [$stage] regions=${persisted.length} candidates=${record.candidates.length} '
          'wire: pts=${g.points.length} width=${g.strokeWidth}pt label="${w.label}" type=${w.annotation?.type} '
          'sourceOrientation=${record.sources.single.extractionOrientation.degrees}');
      expect(persisted, hasLength(3));
      expect(g.points, wireGeometry.points);
      expect(g.strokeWidth, 3.0);
      expect(w.annotation?.type, 'wire');
      expect(persisted.where((r) => r.geometry is RectangleGeometry), hasLength(2));
      expect(record.candidates.map((c) => c.type.label).toSet(), {'Component', 'Text', 'Wire'});
      expect(record.evidenceLinks, hasLength(3));
    }

    await verifyPersisted('after save');

    // ---- close, reopen ------------------------------------------------------
    await tester.tap(find.byTooltip('Close'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Save changes?'), findsNothing);
    await tester.tap(find.text('open'));
    await _pumpFor(tester, const Duration(seconds: 4));
    await _shot('05_reopened_fit');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('path-width-field'))).controller!.text, '3.0');

    // The overlay vertices are the stored normalized points mapped onto the page.
    void expectOverlayMatchesStored(String stage) {
      // The page overlay is the largest 5-vertex path painter (the annotation
      // thumbnail draws a small one in crop space).
      final painters = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_PathPainter');
      RenderBox? best;
      List<Offset>? bestOffsets;
      for (final e in painters.evaluate()) {
        final box = e.renderObject! as RenderBox;
        final offsets = ((e.widget as CustomPaint).painter! as dynamic).offsets as List<Offset>;
        if (offsets.length != 5) continue;
        if (best == null || box.size.width > best.size.width) {
          best = box;
          bestOffsets = offsets;
        }
      }
      expect(best, isNotNull, reason: '$stage: path overlay present');
      for (var i = 0; i < 5; i++) {
        final page = orientation.orientedToPage(wireGeometry.points[i].x, wireGeometry.points[i].y);
        expect(bestOffsets![i].dx / best!.size.width, closeTo(page.x, 1e-6), reason: '$stage x[$i]');
        expect(bestOffsets[i].dy / best.size.height, closeTo(page.y, 1e-6), reason: '$stage y[$i]');
      }
      print('E2E [$stage] overlay vertices = stored normalized geometry mapped to the page (canvas ${best!.size.width.round()} px wide)');
    }

    expectOverlayMatchesStored('reopened');

    // ---- zoom in a lot, then out a lot -------------------------------------
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Zoom In'));
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }
    await _pumpFor(tester, const Duration(seconds: 1));
    await _shot('06_zoomed_in');
    expectOverlayMatchesStored('zoomed in');
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byTooltip('Zoom Out'));
      await _pumpFor(tester, const Duration(milliseconds: 400));
    }
    await _pumpFor(tester, const Duration(seconds: 1));
    await _shot('07_zoomed_out');
    expectOverlayMatchesStored('zoomed out');

    // ---- reload the session from disk and verify again ---------------------
    await verifyPersisted('after reload');
    await KnowledgeSessionStorage.delete(sessionId);
  }, timeout: const Timeout(Duration(minutes: 10)));
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
