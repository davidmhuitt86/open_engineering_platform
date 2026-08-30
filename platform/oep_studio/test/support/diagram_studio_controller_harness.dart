import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller.dart';
import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller_provider.dart';

/// AP-DIAGRAM-V2-BRIDGE-010 — bootstraps a real, fully-started
/// [DiagramStudioController] for tests, without mounting the (now
/// retired) native `DiagramStudioPage` widget.
///
/// Every bridge/controller/persistence test in this codebase used to
/// pump `DiagramStudioPage` purely to reach `state.controllerForTest`/
/// `state.engine` — a real `DiagramStudioController`/`EngineeringEngine`
/// pair, but obtained only as a side effect of mounting a whole native
/// canvas widget tree neither the bridge nor these tests actually
/// exercise. `diagram_studio_controller_provider.dart`'s own doc comment
/// already establishes that `DiagramStudioController.bootstrap` is the
/// **provider's** responsibility, not the page's ("`DiagramStudioPage`
/// must never call `DiagramStudioController.bootstrap`... it awaits
/// `diagramStudioControllerProvider`") — meaning the exact same real
/// bootstrap sequence (Engine start, tab/document restore) is reachable
/// by simply awaiting the provider directly, with no widget-tree
/// dependency on `DiagramStudioPage` at all. This harness does exactly
/// that.
///
/// A bare `MaterialApp`/`Scaffold` (no diagram content) is still pumped
/// because `tester.pump()`/`tester.runAsync()` need a mounted widget
/// tree to drive frames — it carries no Diagram Studio-specific meaning.
Widget diagramStudioTestHarness() => const ProviderScope(
      child: MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

/// Pumps [diagramStudioTestHarness], awaits the real controller
/// bootstrap, and returns both the controller and the [ProviderContainer]
/// (so callers can also read `engineeringProjectServiceProvider`/
/// `diagramTabsProvider`/etc. directly, exactly as they could reach
/// sibling providers via `ProviderScope.containerOf` before).
Future<(DiagramStudioController, ProviderContainer)> bootstrapDiagramStudioController(WidgetTester tester) async {
  await tester.pumpWidget(diagramStudioTestHarness());
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
    listen: false,
  );
  late DiagramStudioController controller;
  await tester.runAsync(() async {
    controller = await container.read(diagramStudioControllerProvider.future);
  });
  await tester.pumpAndSettle();
  return (controller, container);
}

/// AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — same real
/// bootstrap as [bootstrapDiagramStudioController], but against an
/// explicit, caller-chosen `WorkspaceTab.id` via
/// `diagramStudioControllerFamily(instanceId)` rather than the primary
/// alias — for tests proving two Diagram instances are genuinely
/// independent. Pass the SAME [container] for a second call to prove two
/// instances coexist within one `ProviderContainer` (the real, single
/// app-wide container shape); omit it to get a fresh one.
Future<(DiagramStudioController, ProviderContainer)> bootstrapDiagramStudioControllerInstance(
  WidgetTester tester,
  String instanceId, {
  ProviderContainer? container,
}) async {
  ProviderContainer resolvedContainer;
  if (container != null) {
    resolvedContainer = container;
  } else {
    await tester.pumpWidget(diagramStudioTestHarness());
    resolvedContainer = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
      listen: false,
    );
  }
  late DiagramStudioController controller;
  await tester.runAsync(() async {
    controller = await resolvedContainer.read(diagramStudioControllerFamily(instanceId).future);
  });
  await tester.pumpAndSettle();
  return (controller, resolvedContainer);
}
