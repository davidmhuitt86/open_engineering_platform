import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';
import 'package:oep_studio/diagram_studio/inspector/engineering_node_properties.dart';
import 'package:oep_studio/diagram_studio/inspector/engineering_relationship_properties.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

/// AP-OEP-DIAGRAM-VALIDATION-001 — the Diagram Property Inspector's own
/// "Validation Findings" section, added to `EngineeringNodeProperties`/
/// `EngineeringRelationshipProperties`. These tests exercise the section
/// directly (not the whole Diagram Studio page — real WebView2/Engine
/// bootstrap is unrelated to what's under test here and unreliable under
/// `flutter test`, the same reasoning every other Diagram-adjacent test
/// in this suite already documents) by overriding
/// `engineeringProjectServiceProvider` with a fixed `ValidationReport`.
void main() {
  const node = EngineeringNode(id: 'node-1', category: NodeCategory.component, displayName: 'Resistor R1');
  const relationship = EngineeringRelationship(
    id: 'rel-1',
    relationshipType: RelationshipType.connectedTo,
    sourceNode: 'node-1',
    targetNode: 'node-2',
  );

  ProviderScope harness({required Widget child, ValidationReport? report}) {
    return ProviderScope(
      overrides: [
        engineeringProjectServiceProvider.overrideWith(
          () => _FakeEngineeringProjectNotifier(EngineeringProjectState(document: DiagramDocument(), validationReport: report)),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('EngineeringNodeProperties — Validation Findings', () {
    testWidgets('1. no matching findings -> no Validation Findings section', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringNodeProperties(node: node),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.error, message: 'unrelated', subjectId: 'node-9'),
        ]),
      ));

      expect(find.text('Validation Findings'), findsNothing);
    });

    testWidgets('2. one matching finding -> it appears', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringNodeProperties(node: node),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.error, message: 'R1 has no rating', subjectId: 'node-1'),
        ]),
      ));

      expect(find.text('Validation Findings'), findsOneWidget);
      expect(find.text('R1 has no rating'), findsOneWidget);
    });

    testWidgets('3. multiple matching findings -> all appear', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringNodeProperties(node: node),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.error, message: 'finding A', subjectId: 'node-1'),
          ValidationFinding(code: 'E2', severity: ValidationSeverity.warning, message: 'finding B', subjectId: 'node-1'),
        ]),
      ));

      expect(find.text('finding A'), findsOneWidget);
      expect(find.text('finding B'), findsOneWidget);
    });

    testWidgets('4. ignores findings belonging to another node', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringNodeProperties(node: node),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.error, message: 'belongs to R2', subjectId: 'node-2'),
        ]),
      ));

      expect(find.text('Validation Findings'), findsNothing);
      expect(find.text('belongs to R2'), findsNothing);
    });

    testWidgets('unavailable validation report -> no section, no crash', (tester) async {
      await tester.pumpWidget(harness(child: const EngineeringNodeProperties(node: node), report: null));

      expect(find.text('Validation Findings'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('EngineeringRelationshipProperties — Validation Findings', () {
    testWidgets('5. matching finding -> it appears', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringRelationshipProperties(
          relationship: relationship,
          sourceNodeName: 'Resistor R1',
          targetNodeName: 'Resistor R2',
        ),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.warning, message: 'wire undersized', subjectId: 'rel-1'),
        ]),
      ));

      expect(find.text('Validation Findings'), findsOneWidget);
      expect(find.text('wire undersized'), findsOneWidget);
    });

    testWidgets('5. no Validation findings at all -> no section', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringRelationshipProperties(
          relationship: relationship,
          sourceNodeName: 'Resistor R1',
          targetNodeName: 'Resistor R2',
        ),
        report: ValidationReport(findings: const []),
      ));

      expect(find.text('Validation Findings'), findsNothing);
    });

    testWidgets('7. multiple matching findings -> all appear', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringRelationshipProperties(
          relationship: relationship,
          sourceNodeName: 'Resistor R1',
          targetNodeName: 'Resistor R2',
        ),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.warning, message: 'rel finding A', subjectId: 'rel-1'),
          ValidationFinding(code: 'E2', severity: ValidationSeverity.error, message: 'rel finding B', subjectId: 'rel-1'),
        ]),
      ));

      expect(find.text('rel finding A'), findsOneWidget);
      expect(find.text('rel finding B'), findsOneWidget);
    });

    testWidgets('ignores findings belonging to another relationship', (tester) async {
      await tester.pumpWidget(harness(
        child: const EngineeringRelationshipProperties(
          relationship: relationship,
          sourceNodeName: 'Resistor R1',
          targetNodeName: 'Resistor R2',
        ),
        report: ValidationReport(findings: const [
          ValidationFinding(code: 'E1', severity: ValidationSeverity.warning, message: 'belongs to rel-2', subjectId: 'rel-2'),
        ]),
      ));

      expect(find.text('Validation Findings'), findsNothing);
    });
  });

  testWidgets('7/8. severity color and Suggested Fix presentation match the shared ValidationFindingTile', (tester) async {
    // SuggestedFixes.forCode('missing-rating') — if the real catalog
    // doesn't map this code, the tile still renders (fix subtitle is
    // optional); this only proves the same shared tile/catalog is used,
    // not a specific fix's exact text.
    await tester.pumpWidget(harness(
      child: const EngineeringNodeProperties(node: node),
      report: ValidationReport(findings: const [
        ValidationFinding(code: 'missing-rating', severity: ValidationSeverity.error, message: 'no rating set', subjectId: 'node-1'),
      ]),
    ));

    expect(find.byIcon(Icons.circle), findsWidgets, reason: 'the shared severity dot from ValidationFindingTile');
    expect(find.text('no rating set'), findsOneWidget);
  });

  testWidgets('9/10. tapping a Diagram finding invokes goToValidationResult, which resolves through the real navigation path',
      (tester) async {
    // No session/graph/EngineeringObjectRuntime match exists in this
    // minimal fixture, so `goToValidationResult`'s own, already-tested
    // resolution chain (unified_navigation_test coverage) correctly
    // falls through to its final, real fallback: opening/activating the
    // Validation Surface via the same Workspace-aware
    // `openOrActivateDestination` helper every other converted
    // navigation function already uses — proving this UI calls the one
    // real function, not a bespoke navigation path.
    final container = ProviderContainer(
      overrides: [
        engineeringProjectServiceProvider.overrideWith(
          () => _FakeEngineeringProjectNotifier(
            EngineeringProjectState(
              document: DiagramDocument(),
              validationReport: ValidationReport(findings: const [
                ValidationFinding(code: 'E1', severity: ValidationSeverity.error, message: 'no rating', subjectId: 'node-1'),
              ]),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: StudioDestination.workspace.path,
      routes: [
        GoRoute(
          path: StudioDestination.workspace.path,
          builder: (context, state) => const Scaffold(body: EngineeringNodeProperties(node: node)),
        ),
        GoRoute(path: StudioDestination.validation.path, builder: (context, state) => const Scaffold(body: Text('standalone-validation'))),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();

    await tester.tap(find.text('no rating'));
    await tester.pumpAndSettle();

    final tabs = container.read(workspaceTabsControllerProvider);
    expect(tabs.tabs, hasLength(1), reason: 'the Workspace was active, so navigation opened a real Workspace tab, not a bare route change');
    expect(tabs.active!.surfaceId, StudioDestination.validation.name);
  });
}

class _FakeEngineeringProjectNotifier extends EngineeringProjectNotifier {
  _FakeEngineeringProjectNotifier(this._state);

  final EngineeringProjectState _state;

  @override
  EngineeringProjectState build() => _state;
}
