import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_shell.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/workspace/workspace_tab.dart';
import 'package:oep_studio/workspace/workspace_tabs_controller.dart';

import '../support/isolated_settings_storage.dart';

/// AP-OEP-WORKSPACE-UX-001 — the real, end-to-end property this package
/// exists to prove: a sidebar click, while the Engineering Workspace is
/// the active destination, mutates the *same* shared
/// `workspaceTabsControllerProvider` instance `EngineeringWorkspacePage`
/// itself renders from — not a second, page-local controller.
///
/// Uses `StudioShell` directly with a plain `child` (the same pattern
/// `studio_shell_events_test.dart` already established) rather than a
/// real `GoRouter`, since `WorkbenchSidebar`'s `onActivateWorkspaceSurface`
/// path (the one this test exercises) never calls `context.go` at all —
/// no router ancestor is needed to prove it.
void main() {
  /// Same real constraint every other sidebar test in this repo already
  /// works around: the sidebar's nav list is a real, lazily-mounted
  /// `ListView` — a row past the fold isn't in the Element tree until
  /// scrolled into view.
  Finder navScrollable() =>
      find.descendant(of: find.byKey(const ValueKey('workbench-sidebar-nav-list')), matching: find.byType(Scrollable));

  Future<void> tapDestinationRow(WidgetTester tester, StudioDestination destination) async {
    final target = find.byKey(ValueKey('sidebar-dest-${destination.path}'));
    // Scroll back to the top first: a prior tap in the same test may have
    // scrolled down past this row's position (rows are listed in a fixed
    // order, not necessarily below wherever the list last stopped).
    await tester.drag(navScrollable(), const Offset(0, 10000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 100, scrollable: navScrollable());
    await tester.pumpAndSettle();
    await tester.tap(target);
    // AP-OEP-WORKSPACE-ROUTING-001 — deliberately `pump()`, not
    // `pumpAndSettle()`: `StudioShell` now keeps a real, persistent
    // `EngineeringWorkspacePage` mounted whenever `selected` is the
    // Workspace (this package's own fix), so tapping the Diagram row
    // here opens a real Diagram tab containing a real
    // `LegacyV2WebViewPage` — its WebView2 initialization never
    // resolves under `flutter test`'s headless binding (the same
    // constraint `_isUnderTest` already documents in `studio_shell.dart`
    // for the separate preloaded Diagram host), which made
    // `pumpAndSettle()` here hang. Every assertion in this file reads
    // `WorkspaceTabsController` state directly, not rendered widgets, so
    // one settled frame is already enough — this doesn't weaken what's
    // actually being tested.
    await tester.pump();
  }

  Widget harness() => MaterialApp(
        home: StudioShell(
          selected: StudioDestination.workspace,
          onSelect: (_) {},
          child: const SizedBox.shrink(),
        ),
      );

  /// AP-OEP-WORKSPACE-ROUTING-001 — `StudioShell` now keeps a real
  /// `EngineeringWorkspacePage` mounted for the Workspace destination
  /// (this package's own fix), so opening a Surface here renders that
  /// Surface's real content for the first time in this file (previously
  /// masked entirely by the harness's own throwaway `SizedBox.shrink()`
  /// `child`). A realistic viewport avoids the same small-viewport
  /// overflow every other full-shell test in this repo already sizes
  /// around (see `diagram_studio_controller_test.dart` for the same
  /// pattern) — this file's own assertions were never about layout, so
  /// this is purely about letting Knowledge/Repository render without
  /// spurious `RenderFlex overflow` noise.
  void useRealisticViewport(WidgetTester tester) {
    useIsolatedSettingsStorage();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('a sidebar click while the workspace is active opens a real workspace tab', (tester) async {
    useRealisticViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: harness()));
    await tester.pumpAndSettle();

    expect(container.read(workspaceTabsControllerProvider).tabs, isEmpty);

    await tapDestinationRow(tester, StudioDestination.knowledge);

    final controller = container.read(workspaceTabsControllerProvider);
    expect(controller.tabs, hasLength(1));
    expect(controller.active!.surfaceId, StudioDestination.knowledge.name);
  });

  testWidgets('clicking the same sidebar Surface twice activates one tab, not two', (tester) async {
    useRealisticViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: harness()));
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.knowledge);
    await tapDestinationRow(tester, StudioDestination.knowledge);

    expect(container.read(workspaceTabsControllerProvider).tabs, hasLength(1));
  });

  testWidgets('the Diagram Studio sidebar row maps to the reserved diagram surfaceId, not a SurfaceRegistry entry', (tester) async {
    useRealisticViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: harness()));
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.diagram);

    final controller = container.read(workspaceTabsControllerProvider);
    expect(controller.tabs, hasLength(1));
    expect(controller.active!.isDiagram, isTrue);
    expect(controller.active!.surfaceId, WorkspaceTab.diagramSurfaceId);
  });

  testWidgets('opening two different Surfaces from the sidebar creates two independent tabs', (tester) async {
    useRealisticViewport(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: harness()));
    await tester.pumpAndSettle();

    await tapDestinationRow(tester, StudioDestination.knowledge);
    await tapDestinationRow(tester, StudioDestination.repository);

    final controller = container.read(workspaceTabsControllerProvider);
    expect(controller.tabs, hasLength(2));
    expect(controller.active!.surfaceId, StudioDestination.repository.name);
  });
}
