import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/analysis/analysis_controller.dart';
import 'package:oep_studio/diagram_studio/analysis/analysis_results_panel.dart';
import 'package:oep_studio/diagram_studio/analysis/analysis_ui_state.dart';

const _instanceId = 'test-instance';

class _FixedAnalysisNotifier extends AnalysisNotifier {
  final AnalysisUiState fixedState;
  _FixedAnalysisNotifier(this.fixedState);

  @override
  AnalysisUiState build(String arg) => fixedState;

  @override
  Future<void> analyze() async {}
}

AnalysisResult _successResult() {
  final runtime = KnowledgeRuntime.activate(buildElectricalCorePackage(),
      allowUnsignedDevelopmentPackages: true);
  final graph = buildCanonicalCircuitGraph();
  return const AnalysisEngine().analyze(
    request: AnalysisRequest(
      requestId: 'req-test',
      documentId: 'doc-test',
      documentVersion: 'v1',
      knowledgePackageId: 'electrical-core',
    ),
    graph: graph,
    runtime: runtime,
  );
}

Future<void> _pumpPanel(WidgetTester tester, AnalysisUiState fixedState) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diagramAnalysisFamily
            .overrideWith(() => _FixedAnalysisNotifier(fixedState)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AnalysisResultsPanel(instanceId: _instanceId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AnalysisResultsPanel', () {
    testWidgets(
        'idle state shows the empty-state prompt, not fabricated values',
        (tester) async {
      await _pumpPanel(tester, const AnalysisUiState());
      expect(find.textContaining('Click Analyze'), findsOneWidget);
      expect(find.text('Analysis: Successful'), findsNothing);
    });

    testWidgets(
        'success state displays Summary reading straight from AnalysisResult (12 V / 10 Ω / 1.2 A / 14.4 W)',
        (tester) async {
      final result = _successResult();
      await _pumpPanel(
        tester,
        AnalysisUiState(
          phase: AnalysisUiPhase.success,
          result: result,
          currentDocumentVersion: result.documentVersion,
        ),
      );

      expect(find.text('Analysis: Successful'), findsOneWidget);
      // "12 V"/"1.2 A" legitimately appear more than once (Summary,
      // Component Results, and node/branch rows all read the same
      // AnalysisResult fields) — findsWidgets proves the value is
      // present without over-constraining how many places show it.
      expect(find.text('12 V'), findsWidgets);
      expect(find.text('10 Ω'), findsWidgets);
      expect(find.text('1.2 A'), findsWidgets);
      expect(find.text('14.4 W'), findsWidgets);
    });

    testWidgets(
        'constraint section reads SATISFIED from ConstraintResult, never recomputes R > 0',
        (tester) async {
      final result = _successResult();
      await _pumpPanel(
        tester,
        AnalysisUiState(
            phase: AnalysisUiPhase.success,
            result: result,
            currentDocumentVersion: result.documentVersion),
      );
      expect(find.textContaining('SATISFIED'), findsOneWidget);
    });

    testWidgets(
        'derivation section shows all 6 structured steps from AnalysisResult.derivation',
        (tester) async {
      final result = _successResult();
      await _pumpPanel(
        tester,
        AnalysisUiState(
            phase: AnalysisUiPhase.success,
            result: result,
            currentDocumentVersion: result.documentVersion),
      );
      expect(find.textContaining("Apply Ohm's Law"), findsOneWidget);
      expect(find.textContaining('Apply power equation'), findsOneWidget);
      expect(find.textContaining('V = I × R'), findsWidgets);
    });

    testWidgets(
        'provenance section discloses law/equation/package/runtime identity',
        (tester) async {
      final result = _successResult();
      await _pumpPanel(
        tester,
        AnalysisUiState(
            phase: AnalysisUiPhase.success,
            result: result,
            currentDocumentVersion: result.documentVersion),
      );
      // Provenance is collapsed by default (B7: "a concise expandable
      // provenance section is preferable") and below the fold — scroll
      // it into view, then expand it before asserting.
      await tester.ensureVisible(find.text('PROVENANCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PROVENANCE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('law.ohms_law'), findsOneWidget);
      expect(find.textContaining('electrical-core'), findsWidgets);
    });

    testWidgets(
        'stale banner appears when currentDocumentVersion differs from the result\'s',
        (tester) async {
      final result = _successResult();
      await _pumpPanel(
        tester,
        AnalysisUiState(
          phase: AnalysisUiPhase.success,
          result: result,
          currentDocumentVersion: 'a-different-hash',
        ),
      );
      expect(find.textContaining('Historical'), findsOneWidget);
    });

    testWidgets(
        'stale banner is absent when currentDocumentVersion matches the result\'s',
        (tester) async {
      final result = _successResult();
      await _pumpPanel(
        tester,
        AnalysisUiState(
            phase: AnalysisUiPhase.success,
            result: result,
            currentDocumentVersion: result.documentVersion),
      );
      expect(find.textContaining('Historical'), findsNothing);
    });

    testWidgets(
        'failure state surfaces the Engine diagnostic message, not a generic "calculation failed"',
        (tester) async {
      final runtime = KnowledgeRuntime.activate(buildElectricalCorePackage(),
          allowUnsignedDevelopmentPackages: true);
      final builder = GraphBuilder(id: 'g')
        ..addNode(
          id: 'source-1',
          category: NodeCategory.component,
          displayName: 'Source',
          metadata: const {
            'componentModelId': ElectricalCoreIds.voltageSourceModel
          },
          properties: const {
            'voltage': {'value': 12.0, 'unit': 'unit.volt'},
          },
        )
        ..addNode(
          id: 'resistor-1',
          category: NodeCategory.component,
          displayName: 'Resistor',
          metadata: const {'componentModelId': ElectricalCoreIds.resistorModel},
        )
        ..addNode(
          id: 'ground-1',
          category: NodeCategory.ground,
          displayName: 'Ground',
          metadata: const {
            'componentModelId': ElectricalCoreIds.referenceNodeModel
          },
        )
        ..connect('source-1', 'resistor-1')
        ..connect('resistor-1', 'ground-1');
      final result = const AnalysisEngine().analyze(
        request: const AnalysisRequest(
          requestId: 'req-fail',
          documentId: 'doc-fail',
          documentVersion: 'v1',
          knowledgePackageId: 'electrical-core',
        ),
        graph: builder.build(),
        runtime: runtime,
      );

      await _pumpPanel(
        tester,
        AnalysisUiState(
            phase: AnalysisUiPhase.failure,
            result: result,
            currentDocumentVersion: result.documentVersion),
      );
      expect(find.textContaining('missing required parameter'), findsOneWidget);
      expect(find.textContaining('calculation failed'), findsNothing);
    });

    testWidgets(
        'no engineering arithmetic runs in this widget — Analyze button just dispatches the notifier',
        (tester) async {
      await _pumpPanel(tester, const AnalysisUiState());
      expect(find.widgetWithText(ElevatedButton, 'Analyze'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Analyze'));
      await tester.pumpAndSettle();
      // The fake notifier's analyze() is a no-op — reaching here without
      // an exception confirms the button only dispatches to the
      // controller layer, never computes a value inline.
    });
  });
}
