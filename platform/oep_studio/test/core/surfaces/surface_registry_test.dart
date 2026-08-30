import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/core/routing/studio_registry.dart';
import 'package:oep_studio/core/surfaces/surface_definition.dart';
import 'package:oep_studio/core/surfaces/surface_registry.dart';

/// AP-OEP-SURFACE-ARCHITECTURE-002 — focused tests for the new,
/// additive Surface layer (`docs/OEP_SURFACE_ARCHITECTURE.md` §19
/// Migration Steps 1-2). Does not touch `DiagramTab`,
/// `WebSurfaceTabsController`, or any Diagram/V2 behavior — those are
/// explicitly out of scope for this package (Phase 5 of the task).
void main() {
  group('SurfaceDefinition', () {
    test('constructs with the minimum justified fields', () {
      const surface = SurfaceDefinition(
        id: 'test-surface',
        title: 'Test Surface',
        icon: Icons.abc,
        presentationTechnology: SurfacePresentationTechnology.native,
        build: _dummyBuilder,
      );
      expect(surface.id, 'test-surface');
      expect(surface.title, 'Test Surface');
      expect(surface.icon, Icons.abc);
      expect(surface.presentationTechnology, SurfacePresentationTechnology.native);
      expect(surface.build, _dummyBuilder);
    });
  });

  group('SurfaceRegistry', () {
    test('contains the expected current Studio surfaces, excluding Diagram', () {
      final ids = SurfaceRegistry.all.map((s) => s.id).toSet();

      // Every non-diagram, non-workspace destination that is actually
      // registered in StudioRegistry.defaultRegistry must be present —
      // derived, not hand-duplicated. `workspace`
      // (AP-OEP-WORKSPACE-SHELL-001) is excluded for the same
      // self-referential reason `diagram` is — see `SurfaceRegistry`'s
      // own doc comment. `diagram-classic` (AP-OEP-WORKBENCH-
      // RETIREMENT-001) no longer exists at all.
      for (final descriptor in StudioRegistry.defaultRegistry.descriptors) {
        if (descriptor.destination == StudioDestination.diagram || descriptor.destination == StudioDestination.workspace) {
          continue;
        }
        expect(
          ids.contains(descriptor.destination.name),
          isTrue,
          reason: '${descriptor.destination.name} is registered in StudioRegistry but missing from SurfaceRegistry',
        );
      }
    });

    test('excludes Diagram (§ Phase 5: Diagram Studio has its own dedicated path)', () {
      final ids = SurfaceRegistry.all.map((s) => s.id).toSet();
      expect(ids.contains(StudioDestination.diagram.name), isFalse);
    });

    test('every surface title/icon matches its StudioDestination (single source of truth, no duplication)', () {
      final byId = {for (final descriptor in StudioRegistry.defaultRegistry.descriptors) descriptor.destination.name: descriptor.destination};
      for (final surface in SurfaceRegistry.all) {
        final destination = byId[surface.id];
        expect(destination, isNotNull, reason: 'Surface ${surface.id} has no matching StudioDestination');
        expect(surface.title, destination!.label);
        expect(surface.icon, destination.icon);
      }
    });

    test('forId returns the matching SurfaceDefinition', () {
      final first = SurfaceRegistry.all.first;
      expect(SurfaceRegistry.forId(first.id), same(first));
    });

    test('forId returns null for an unknown id', () {
      expect(SurfaceRegistry.forId('does-not-exist'), isNull);
    });

    test('no duplicate Surface ids', () {
      final ids = SurfaceRegistry.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'SurfaceRegistry.all contains duplicate ids: $ids');
    });

    testWidgets('every surface constructs a real widget instance without a GoRouterState', (tester) async {
      // One throwaway context is enough — every current `build` closure
      // is `(context) => const XPage()`, plain widget *construction*,
      // which never reads `context` or consults a Riverpod provider
      // (that only happens once a widget is actually composed into a
      // tree). This confirms the factory signature works without a
      // `GoRouterState` (§ `SurfaceDefinition`'s own doc comment); it
      // does not attempt to fully render every Studio page, which would
      // need each one's own provider/document setup and is out of this
      // package's scope.
      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox.shrink();
      })));

      for (final surface in SurfaceRegistry.all) {
        final built = surface.build(capturedContext);
        expect(built, isNotNull, reason: '${surface.id} produced a null widget');
      }
    });
  });
}

Widget _dummyBuilder(BuildContext context) => const SizedBox.shrink();
