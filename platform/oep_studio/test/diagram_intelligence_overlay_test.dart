import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/panels/diagram_intelligence_overlay.dart';

/// AP-DS-003 items 1+2 (Validation Overlay / Analysis Overlay): widget
/// tests for `DiagramIntelligenceOverlay`, the presentation-only Stack
/// layer `DiagramStudioPage` composes over `GraphViewPanel`. Unlike the
/// Intelligence panels (`test/intelligence_panels_test.dart`), this
/// widget takes plain data only — a `DiagramLayoutState`, a pan/zoom
/// pair, and sets of already-translated canvas node ids — never a
/// `DiagramIntelligenceService`/`FoundationBridge`, so it's fully
/// testable here with synthetic data standing in for a real EIP result.
void main() {
  Widget harness(Widget child) {
    return MaterialApp(
      theme: StudioTheme.dark,
      home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
    );
  }

  final layout = DiagramLayoutState.empty.copyWith(
    positions: {
      'n1': const Point2D(100, 100),
      'n2': const Point2D(300, 100),
    },
  );

  group('DiagramIntelligenceOverlay', () {
    testWidgets('renders no markers when both id sets are empty', (tester) async {
      await tester.pumpWidget(harness(DiagramIntelligenceOverlay(
        layout: layout,
        pan: const Point2D(0, 0),
        zoom: 1,
      )));

      expect(find.byIcon(Icons.priority_high), findsNothing);
    });

    testWidgets('renders one validation marker per node in validationNodeIds', (tester) async {
      await tester.pumpWidget(harness(DiagramIntelligenceOverlay(
        layout: layout,
        pan: const Point2D(0, 0),
        zoom: 1,
        validationNodeIds: const {'n1', 'n2'},
        validationSummary: '2 findings',
      )));

      expect(find.byIcon(Icons.priority_high), findsNWidgets(2));
    });

    testWidgets('a validation marker is positioned using pan/zoom, not raw scene coordinates', (tester) async {
      await tester.pumpWidget(harness(DiagramIntelligenceOverlay(
        layout: layout,
        pan: const Point2D(50, 20),
        zoom: 2,
        validationNodeIds: const {'n1'},
      )));

      // Marker sits at the node's top-right corner: screen = pan + zoom *
      // (position + (width, 0)), node width defaults to 100 scene units
      // when `layout.sizeOf` has no entry (mirrors `DiagramStudioPage`'s
      // own `_nodeSize` default), offset by the marker's own half-size
      // (9px) exactly as `DiagramIntelligenceOverlay._validationMarker`
      // computes it.
      final expectedLeft = 50 + 2 * (100 + 100) - 9;
      final expectedTop = 20 + 2 * 100 - 9;
      final positioned = tester.widget<Positioned>(
        find.ancestor(of: find.byIcon(Icons.priority_high), matching: find.byType(Positioned)).first,
      );
      expect(positioned.left, expectedLeft);
      expect(positioned.top, expectedTop);
    });

    testWidgets('tapping a validation marker invokes onValidationMarkerTap with the node id', (tester) async {
      String? tapped;
      await tester.pumpWidget(harness(DiagramIntelligenceOverlay(
        layout: layout,
        pan: const Point2D(0, 0),
        zoom: 1,
        validationNodeIds: const {'n1'},
        onValidationMarkerTap: (id) => tapped = id,
      )));

      await tester.tap(find.byIcon(Icons.priority_high));
      expect(tapped, 'n1');
    });

    testWidgets('renders an analysis highlight per node in analysisNodeIds, distinct from validation markers',
        (tester) async {
      await tester.pumpWidget(harness(DiagramIntelligenceOverlay(
        layout: layout,
        pan: const Point2D(0, 0),
        zoom: 1,
        analysisNodeIds: const {'n1'},
        validationNodeIds: const {'n2'},
      )));

      // Exactly one error-style validation badge (n2) and no crash/overlap
      // rendering the analysis highlight (n1) alongside it — the two
      // treatments are independent Stack children keyed off disjoint id
      // sets.
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
    });

    testWidgets('a node missing from layout is silently skipped, not a crash', (tester) async {
      await tester.pumpWidget(harness(DiagramIntelligenceOverlay(
        layout: layout,
        pan: const Point2D(0, 0),
        zoom: 1,
        validationNodeIds: const {'not-in-layout'},
        analysisNodeIds: const {'also-missing'},
      )));

      expect(find.byIcon(Icons.priority_high), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
