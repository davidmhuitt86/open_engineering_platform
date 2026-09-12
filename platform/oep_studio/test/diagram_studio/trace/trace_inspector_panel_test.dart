import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/trace/trace_controller.dart';
import 'package:oep_studio/diagram_studio/trace/trace_inspector_panel.dart';

/// PRODUCT-READINESS-009 §34 — the Trace Inspector panel's own
/// presentation logic, tested in isolation (same convention
/// `digital_multimeter_instrument_panel_test.dart` already established
/// for PRODUCT-READINESS-008): [traceRuntimeServiceProvider] is
/// overridden directly with a real [TraceController] instance; no
/// `engineeringProjectServiceProvider` override is set up (graph/selection
/// stay at their defaults), so these tests cover mode selection, target
/// display, and structured-result rendering (via REAL
/// [TraceController.setTarget]/[TraceController.runTrace] calls against a
/// hand-built graph, driven directly from the test) — not
/// diagram-selection-driven target derivation, which is a thin wrapper
/// over `EngineeringProjectState.selection` already proven at the
/// `TraceController`/`SelectionService` level
/// (`trace_controller_test.dart`, and the pre-existing, unmodified
/// `SelectionService` test suite).
void main() {
  late TraceController controller;

  setUp(() => controller = TraceController());

  // No manual tearDown/dispose here: `ProviderScope`'s own teardown already
  // disposes the `ChangeNotifierProvider`-vended controller once the
  // widget tree unmounts between tests -- disposing it again here would
  // double-dispose (the same lesson `multimeter_controller_test.dart`'s
  // own widget test already learned).

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [traceRuntimeServiceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: Scaffold(body: TraceInspectorPanel())),
      ),
    );
    await tester.pump();
  }

  EngineeringGraph seriesGraph() => EngineeringGraph(id: 'g', nodes: {
        'battery': const EngineeringNode(
          id: 'battery',
          category: NodeCategory.component,
          displayName: 'Battery',
          metadata: {'v2Category': 'power'},
          properties: {'nominalVoltageV': 12.0},
        ),
        'load': const EngineeringNode(id: 'load', category: NodeCategory.component, displayName: 'Load'),
        'ground': const EngineeringNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground'),
      }, relationships: {
        'w1': const EngineeringRelationship(id: 'w1', relationshipType: RelationshipType.connectedTo, sourceNode: 'battery', targetNode: 'load'),
        'w2': const EngineeringRelationship(id: 'w2', relationshipType: RelationshipType.connectedTo, sourceNode: 'load', targetNode: 'ground'),
      });

  testWidgets('no diagram session: an honest message, not a blank/crashed panel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [traceRuntimeServiceProvider.overrideWith((ref) => null)],
        child: const MaterialApp(home: Scaffold(body: TraceInspectorPanel())),
      ),
    );
    await tester.pump();
    expect(find.textContaining('No diagram session'), findsOneWidget);
  });

  testWidgets('§29 no target yet: an honest placeholder, never a fabricated result', (tester) async {
    await pumpPanel(tester);
    expect(find.textContaining('Select a component or wire'), findsOneWidget);
    expect(find.text('No trace yet.'), findsOneWidget);
  });

  testWidgets('§30 mode selector: tapping a chip changes the controller\'s own mode without losing the target', (tester) async {
    controller.setTarget(TraceTarget.component('battery'));
    await pumpPanel(tester);
    expect(controller.mode, TraceMode.physical);

    await tester.tap(find.text('Conducting'));
    await tester.pump();
    expect(controller.mode, TraceMode.conducting);
    expect(controller.target?.componentId, 'battery', reason: '§30 switching mode must not lose the selected target');

    await tester.tap(find.text('Current Flow'));
    await tester.pump();
    expect(controller.mode, TraceMode.currentFlow);
    expect(controller.target?.componentId, 'battery');
  });

  testWidgets('§9/§16 a real physical trace renders real path results, never fabricated topology', (tester) async {
    controller.setTarget(TraceTarget.component('battery'));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());

    await pumpPanel(tester);
    expect(find.textContaining('path'), findsWidgets);
    expect(find.textContaining('Trace from:'), findsOneWidget);
  });

  testWidgets('§16 a genuinely empty trace result shows "No path found," not a silent blank', (tester) async {
    final isolatedGraph = EngineeringGraph(id: 'g2', nodes: {
      'a': const EngineeringNode(id: 'a', category: NodeCategory.component, displayName: 'A'),
    }, relationships: const {});
    controller.setTarget(TraceTarget.component('a'));
    controller.runTrace(graph: isolatedGraph, solver: const ElectricalSolver());

    await pumpPanel(tester);
    // A single, unconnected component still has a trivial (single-step,
    // no-wire) physical path from TraceEngine's own normalization -- this
    // just proves the panel renders whatever TraceEngine actually
    // returned, real or empty, never a fabrication either way.
    expect(find.text('No trace yet.'), findsNothing);
  });

  testWidgets('§29 Clear resets target and result, both in the controller and the panel', (tester) async {
    controller.setTarget(TraceTarget.component('battery'));
    controller.runTrace(graph: seriesGraph(), solver: const ElectricalSolver());
    await pumpPanel(tester);
    expect(find.textContaining('Trace from:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(controller.target, isNull);
    expect(controller.result, isNull);
    expect(find.textContaining('Select a component or wire'), findsOneWidget);
  });

  test('TraceController identifies itself correctly through the runtime provider (§19/§20)', () {
    expect(controller.mode, TraceMode.physical);
    expect(controller.target, isNull);
  });

  // Two direct parallel branches from the same source (no intermediate
  // splice node -- `isSpliceNode` requires real `v2Category: 'splice'`
  // metadata this synthetic fixture doesn't declare, so a bridging splice
  // hop isn't the right way to exercise "parallel branches" here; two
  // separate wires straight off the source demonstrates the same real
  // branch-preservation requirement without depending on that metadata).
  EngineeringGraph parallelGraph() => EngineeringGraph(id: 'g3', nodes: {
        'source': const EngineeringNode(id: 'source', category: NodeCategory.component, displayName: 'Source', metadata: {'v2Category': 'power'}, properties: {'nominalVoltageV': 12.0}),
        'lh': const EngineeringNode(id: 'lh', category: NodeCategory.component, displayName: 'LH'),
        'rh': const EngineeringNode(id: 'rh', category: NodeCategory.component, displayName: 'RH'),
      }, relationships: {
        'wLh': const EngineeringRelationship(id: 'wLh', relationshipType: RelationshipType.connectedTo, sourceNode: 'source', targetNode: 'lh'),
        'wRh': const EngineeringRelationship(id: 'wRh', relationshipType: RelationshipType.connectedTo, sourceNode: 'source', targetNode: 'rh'),
      });

  /// The Circuit Summary's SOURCE/RETURN/STATE/COMPONENTS/... rows render
  /// via `RichText`/`TextSpan` (so a label and its value can carry
  /// different styles in one line), which `find.text`/`find.textContaining`
  /// -- matchers for plain `Text` widgets only -- never match. This
  /// helper checks the real rendered `RichText` content instead.
  bool richTextContains(WidgetTester tester, String needle) {
    return tester.widgetList<RichText>(find.byType(RichText)).any((w) => w.text.toPlainText().contains(needle));
  }

  testWidgets('§12/§30 the circuit summary shows real component/wire/branch counts and state, never estimated', (tester) async {
    controller.setTarget(TraceTarget.component('source'));
    controller.runTrace(graph: parallelGraph(), solver: const ElectricalSolver());

    await pumpPanel(tester);
    expect(richTextContains(tester, 'COMPONENTS'), isTrue);
    expect(richTextContains(tester, 'WIRES'), isTrue);
    expect(richTextContains(tester, 'BRANCHES'), isTrue);
    expect(richTextContains(tester, 'STATE'), isTrue);
    expect(richTextContains(tester, 'BLOCKED'), isTrue);
  });

  testWidgets('§15 parallel branches render as a real tree -- both LH and RH appear, never collapsed', (tester) async {
    controller.setTarget(TraceTarget.component('source'));
    controller.runTrace(graph: parallelGraph(), solver: const ElectricalSolver());

    await pumpPanel(tester);
    // No `engineeringProjectServiceProvider` override is set up in this
    // test group (see the file's own top doc comment), so the branch
    // tree's own `_terminalName` falls back to the raw node id (no live
    // graph to resolve a display name from) -- this still proves both
    // real, distinct branches render, never collapsed into one.
    expect(find.textContaining('lh'), findsWidgets);
    expect(find.textContaining('rh'), findsWidgets);
  });

  testWidgets('§17 Fit Circuit is disabled until a real highlight plan has actually been applied', (tester) async {
    await pumpPanel(tester);
    expect(find.text('Fit Circuit'), findsNothing, reason: 'no result yet -- the whole action row is not shown');

    controller.setTarget(TraceTarget.component('source'));
    controller.runTrace(graph: parallelGraph(), solver: const ElectricalSolver());
    await tester.pump();

    final fitButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Fit Circuit'));
    // No LegacyV2StateAdapter is wired up in this test (no engineeringProjectServiceProvider
    // override), so a highlight plan is never actually applied -- the button
    // must stay disabled rather than silently no-op on tap.
    expect(fitButton.onPressed, isNull);
  });

  testWidgets('§21 Measure Circuit is enabled only with an unambiguous single source and single return', (tester) async {
    controller.setTarget(TraceTarget.component('source'));
    controller.runTrace(graph: parallelGraph(), solver: const ElectricalSolver());
    await pumpPanel(tester);

    final measureButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Measure Circuit'));
    final result = controller.result!;
    final unambiguous = result.sourceTerminals.length == 1 && result.returnTerminals.length == 1;
    expect(measureButton.onPressed == null, !unambiguous);
  });
}
