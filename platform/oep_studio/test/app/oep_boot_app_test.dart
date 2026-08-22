import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/oep_boot_app.dart';
import 'package:oep_studio/core/auth/auth_result.dart';
import 'package:oep_studio/core/auth/authentication_provider.dart';
import 'package:oep_studio/core/auth/authentication_service.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_webview.dart';

/// A deterministic in-memory `AuthenticationService` -- the same
/// pattern `onboarding_flow_test.dart` already established, duplicated
/// (not imported) since that one is file-private.
class _FakeAuthenticationService implements AuthenticationService {
  final Map<String, String> _accounts = {'jsmith': 'correct-horse'};

  @override
  Future<bool> hasAnyAccount() async => _accounts.isNotEmpty;

  @override
  Future<String?> rememberedUsername() async => 'jsmith';

  @override
  Future<AuthResult> signIn({required String usernameOrEmail, required String password, bool rememberMe = false}) async {
    final stored = _accounts[usernameOrEmail.trim()];
    if (stored == null) return AuthResult.failure('No account found.');
    if (stored != password) return AuthResult.failure('Incorrect password.');
    return AuthResult.success(usernameOrEmail.trim());
  }

  @override
  Future<AuthResult> createAccount({required String username, required String password}) async {
    _accounts[username.trim()] = password;
    return AuthResult.success(username.trim());
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> requestPasswordReset(String usernameOrEmail) async => AuthResult.success(usernameOrEmail.trim());
}

/// OEP Diagram Studio -- connects the boot-time Studio/Workspace
/// Selection chooser to the real application: proves that picking
/// Diagram Studio and pressing Continue on `WorkspaceSelectionScreen`
/// actually launches `StudioApp`/`appRouter` and lands on a real,
/// bootstrapped Diagram Studio -- not the old placeholder dialog.
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  }

  testWidgets('selecting Diagram Studio and pressing Continue launches the real, bootstrapped Diagram Studio', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authenticationServiceProvider.overrideWithValue(_FakeAuthenticationService())],
        child: const OepBootApp(),
      ),
    );
    await settle(tester);

    // Remembered account -> Splash goes straight to Welcome.
    expect(find.byKey(const Key('welcome-get-started-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome-get-started-button')));
    await settle(tester);

    expect(find.text('Choose Your Workspace'), findsOneWidget);
    await tester.tap(find.byKey(Key('workspace-tile-${StudioDestination.diagram.path}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('workspace-continue-button')));
    await settle(tester);

    // The old placeholder dialog must be gone -- this is a real launch now.
    expect(find.text('Studio launch will be implemented in the next phase.'), findsNothing);

    // `StudioApp`/`appRouter` is now live and has navigated to Diagram
    // Studio -- proven by its real bootstrap completing. AP-DIAGRAM-V2-
    // BRIDGE-010: the "Add node" tooltip this test used to wait for
    // belonged to the native renderer, retired by that task -- `/diagram`
    // has rendered the Web Surface host (Legacy V2 auto-opened) since
    // AP-DIAGRAM-V2-BRIDGE-002. AP-OEP-DIAGRAM-UX-001 replaced the
    // "Legacy V2 (open)" text button this test used to wait for with an
    // icon-only "+"/globe toolbar and a tab strip whose label now tracks
    // the open document's title rather than a fixed string, so the
    // stable confirmation signal is the actual embedded widget type
    // instead of any particular piece of UI text.
    for (var i = 0; i < 40 && find.byType(LegacyV2WebViewPage).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.byType(LegacyV2WebViewPage), findsOneWidget, reason: 'Diagram Studio must actually be the active route, fully bootstrapped with Legacy V2 auto-opened');
  });
}
