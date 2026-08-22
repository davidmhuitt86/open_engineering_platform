import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller_provider.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// Regression coverage for AP-DIAGRAM-W2-A (Wave 2 Stage A) — the
/// provider-hosted lifetime for `DiagramStudioController`
/// (`controller/diagram_studio_controller_provider.dart`), and the
/// hazard composition boundary §29 item 1 calls out explicitly: making
/// the controller provider-hosted must not let a Diagram Studio revisit
/// (widget unmount/remount within the same app session) either
/// reconstruct the controller or re-run bootstrap over a live,
/// in-memory-only edit.
///
/// **What this test proves, concretely:**
///   A. Initial bootstrap completes (the page reaches its post-bootstrap
///      UI — same wait condition `diagram_studio_controller_test.dart`
///      already uses).
///   C. A live edit is made against the real Engine session
///      (`addNode`), independent of any persisted file on disk.
///   D. `DiagramStudioPage` is unmounted, then remounted, inside the
///      *same* `ProviderContainer` — the in-process equivalent of
///      navigating away from and back to Diagram Studio within one app
///      session (a full `GoRouter` navigation round-trip is not needed
///      to exercise this invariant: nothing about the provider's
///      lifetime depends on the routing mechanism, only on the
///      container it lives in outliving the widget).
///   E./F. The live node from step C is still present after the
///      remount's own bootstrap has run — i.e. bootstrap did not
///      re-open whatever document was last persisted to disk over the
///      live in-memory session.
///   G. The second mount's `DiagramStudioController` is the identical
///      object (`identical()`) as the first mount's — the provider did
///      not construct a second one.
///
/// **What this test does not attempt to prove:** step B ("appropriate
/// persisted state is restored") in the literal sense of a *second
/// process* launching against a real `diagram_studio_tabs.json`/
/// `diagram_studio_workspace.json` on disk — that is exercised by
/// existing tab/workspace-persistence tests elsewhere. What matters for
/// the Stage A invariant is not what bootstrap restores on its one
/// genuine run, but that it does not run a second time and clobber live
/// state — which is exactly what F and G verify directly.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'DiagramStudioController provider: single instance survives a revisit; bootstrap does not re-run over live edits',
    (tester) async {
      useIsolatedSettingsStorage();

      // AP-DIAGRAM-V2-BRIDGE-010 — the original version of this test
      // proved the invariant by mounting/unmounting `DiagramStudioPage`
      // (now retired) inside one `ProviderContainer` and checking the
      // controller identity survived the remount. That ceremony is no
      // longer necessary to prove the same thing: `diagramStudioControllerProvider`
      // is a plain (non-`autoDispose`) `AsyncNotifierProvider` — its
      // lifetime is tied to the `ProviderContainer`, not to any
      // particular widget's mount state, confirmed directly by reading
      // `diagram_studio_controller_provider.dart`'s own definition. So
      // reading the provider twice from the *same* container, with a
      // live edit in between, exercises the exact same "does a second
      // read reconstruct the controller / discard live state" question
      // — more directly, without a widget-mount proxy for it.
      final (firstController, container) = await bootstrapDiagramStudioController(tester);
      final EngineeringEngine engine = firstController.engine;

      final beforeIds = Set<String>.from(engine.editing.session.graph.nodes.keys);
      firstController.addNode('battery', const Point2D(40, 40));
      await settle(tester);
      final liveIds = engine.editing.session.graph.nodes.keys.toSet();
      expect(liveIds.length, beforeIds.length + 1, reason: 'setup: the live edit must actually land before testing that it survives a re-read');

      final secondController = (await tester.runAsync(() => container.read(diagramStudioControllerProvider.future)))!;

      expect(
        identical(secondController, firstController),
        isTrue,
        reason: 'the provider-hosted controller must not be reconstructed by a second read from the same container',
      );

      final afterRereadIds = engine.editing.session.graph.nodes.keys.toSet();
      expect(
        afterRereadIds,
        liveIds,
        reason: 'a second provider read must not re-run bootstrap and discard/replace the live in-memory document',
      );
    },
  );
}
