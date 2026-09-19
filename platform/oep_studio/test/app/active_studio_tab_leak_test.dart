import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/app/active_studio.dart';
import 'package:oep_studio/core/surfaces/surface_registry.dart';
import 'package:oep_studio/workspace/workspace_tab.dart';

/// Direct product-feedback fix: an unscoped Surface tab (one
/// `activeStudioForSurfaceId` maps to `null` -- has no Studio Bar button
/// of its own yet) is deliberately visible under every Studio
/// (`tabsForStudio`'s own doc comment) so it is never lost, but must not
/// silently become the *resolved active* content of an unrelated Studio
/// merely because it happens to be the app-wide `activeId`/`secondTabId`
/// from having been viewed elsewhere. That leak is exactly what produced
/// "a random tab (and its split partner) shows up when I open a
/// different Studio."
void main() {
  Future<WorkspaceTab?> resolvedTab(
    WidgetTester tester, {
    required List<WorkspaceTab> allTabs,
    required ActiveStudio studio,
    required String? globalActiveId,
    Map<ActiveStudio, String> remembered = const {},
  }) async {
    WorkspaceTab? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lastActiveTabPerStudioProvider.overrideWith((ref) => remembered)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              result = resolveActiveTabForStudio(ref, allTabs, studio, globalActiveId);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('an unscoped tab that is the global activeId does NOT leak into an unrelated Studio\'s '
      'resolved tab', (tester) async {
    // "Search" is one of the surfaces `activeStudioForSurfaceId` does not
    // yet map to any of the seven Studios (confirmed: only
    // home/diagram/eam/knowledge/exchange/instruments/settings resolve).
    final unscopedTab = WorkspaceTab(
      id: 'workspace-tab-search',
      surfaceId: SurfaceRegistry.all.firstWhere((s) => s.title == 'Search').id,
    );
    expect(activeStudioForSurfaceId(unscopedTab.surfaceId), isNull,
        reason: 'must genuinely be unscoped for this test to be meaningful');

    final resolved = await resolvedTab(
      tester,
      allTabs: [unscopedTab],
      studio: ActiveStudio.eam,
      globalActiveId: unscopedTab.id, // active elsewhere, e.g. Home/Knowledge
    );

    expect(resolved, isNull, reason: 'EAM owns nothing here; the unscoped tab must not be borrowed as EAM\'s own content');
  });

  testWidgets('a Studio-owned tab is still correctly resolved as active for its own Studio', (tester) async {
    final eamTab = WorkspaceTab(id: 'workspace-tab-eam', surfaceId: ActiveStudio.eam.surfaceId);
    final resolved = await resolvedTab(tester, allTabs: [eamTab], studio: ActiveStudio.eam, globalActiveId: eamTab.id);
    expect(resolved?.id, eamTab.id);
  });

  testWidgets('a remembered (explicitly-visited) unscoped tab is still honored for the Studio that '
      'remembered it', (tester) async {
    final unscopedTab = WorkspaceTab(
      id: 'workspace-tab-search',
      surfaceId: SurfaceRegistry.all.firstWhere((s) => s.title == 'Search').id,
    );
    final resolved = await resolvedTab(
      tester,
      allTabs: [unscopedTab],
      studio: ActiveStudio.eam,
      globalActiveId: null,
      remembered: {ActiveStudio.eam: unscopedTab.id},
    );
    expect(resolved?.id, unscopedTab.id, reason: 'an explicit prior visit while in EAM is a real choice, not a leak');
  });

  testWidgets('clicking an unscoped tab (e.g. Repository) while in a Studio makes it that Studio\'s '
      'resolved active tab, via rememberActiveTabForItsStudio -- the exact "the tab won\'t let me click '
      'on it" regression', (tester) async {
    final repositoryTab = WorkspaceTab(
      id: 'workspace-tab-repository',
      surfaceId: SurfaceRegistry.all.firstWhere((s) => s.title == 'Repository').id,
    );
    expect(activeStudioForSurfaceId(repositoryTab.surfaceId), isNull, reason: 'Repository is genuinely unscoped');

    Map<ActiveStudio, String> remembered = {};
    WorkspaceTab? resolved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lastActiveTabPerStudioProvider.overrideWith((ref) => remembered)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              // Simulates the exact click handler
              // `EngineeringWorkspacePage.build()`'s `activate()` runs.
              return ElevatedButton(
                onPressed: () {
                  rememberActiveTabForItsStudio(ref, ActiveStudio.eam, repositoryTab.id);
                  resolved = resolveActiveTabForStudio(ref, [repositoryTab], ActiveStudio.eam, repositoryTab.id);
                },
                child: const Text('activate'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(resolved?.id, repositoryTab.id,
        reason: 'clicking Repository while in EAM must make it EAM\'s resolved active tab');
  });
}
