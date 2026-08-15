import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/auth/auth_result.dart';
import 'package:oep_studio/core/auth/authentication_provider.dart';
import 'package:oep_studio/core/auth/authentication_service.dart';
import 'package:oep_studio/core/routing/studio_destination.dart';
import 'package:oep_studio/features/onboarding/onboarding_flow.dart';
import 'package:oep_studio/features/onboarding/workspace_selection_screen.dart';

/// A deterministic in-memory `AuthenticationService`, so these widget
/// tests never touch the real Windows Credential Manager or
/// `%APPDATA%/oep_studio/auth_session.json`.
class _FakeAuthenticationService implements AuthenticationService {
  final Map<String, String> _accounts = {};
  String? _remembered;

  @override
  Future<bool> hasAnyAccount() async => _accounts.isNotEmpty;

  @override
  Future<String?> rememberedUsername() async => _remembered;

  @override
  Future<AuthResult> signIn({required String usernameOrEmail, required String password, bool rememberMe = false}) async {
    final stored = _accounts[usernameOrEmail.trim()];
    if (stored == null) return AuthResult.failure('No account found for "$usernameOrEmail" on this machine.');
    if (stored != password) return AuthResult.failure('Incorrect password.');
    _remembered = rememberMe ? usernameOrEmail.trim() : null;
    return AuthResult.success(usernameOrEmail.trim());
  }

  @override
  Future<AuthResult> createAccount({required String username, required String password}) async {
    if (password.length < 8) return AuthResult.failure('Password must be at least 8 characters.');
    if (_accounts.containsKey(username.trim())) return AuthResult.failure('An account named "$username" already exists.');
    _accounts[username.trim()] = password;
    return AuthResult.success(username.trim());
  }

  @override
  Future<void> signOut() async => _remembered = null;

  @override
  Future<AuthResult> requestPasswordReset(String usernameOrEmail) async =>
      AuthResult.failure('Password recovery is not available until OEP account services are connected.');
}

/// `SplashScreen._initialize` awaits `SettingsService.load()` -- a real
/// `dart:io` file read -- and a real `Future.delayed`. Neither is
/// fake-clock-controlled, so a plain `tester.pump()` loop doesn't
/// reliably drive them forward (the same category of gap
/// `settleDiagramStudioBootstrap` bridges elsewhere in this suite for
/// `EngineHost.create()`'s asset loads). `tester.runAsync` bridges into
/// the real event loop for the duration of this call.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // A duration argument (not a bare `tester.pump()`) so the fake
      // clock advances too -- `SplashScreen`'s own `Future.delayed` was
      // scheduled under the normal fake-timer test binding, not inside
      // this `runAsync` block, so only advancing the fake clock lets it
      // actually fire.
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}

Future<_FakeAuthenticationService> _pumpOnboarding(WidgetTester tester, {bool hasAccount = false}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final auth = _FakeAuthenticationService();
  if (hasAccount) await auth.createAccount(username: 'jsmith', password: 'correct-horse');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authenticationServiceProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: OnboardingFlow()),
    ),
  );
  return auth;
}

void main() {
  group('Splash', () {
    testWidgets('shows the OEP splash then transitions to Create Account when no account exists', (tester) async {
      await _pumpOnboarding(tester);
      expect(find.text('OEP'), findsOneWidget);
      expect(find.text('Initializing Engine…'), findsOneWidget);

      await _settle(tester);

      expect(find.text('Create Local Account'), findsOneWidget);
    });

    testWidgets('transitions to Login when an account already exists', (tester) async {
      await _pumpOnboarding(tester, hasAccount: true);
      await _settle(tester);

      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });

  group('Login', () {
    testWidgets('a wrong password shows an error and does not proceed', (tester) async {
      await _pumpOnboarding(tester, hasAccount: true);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('login-username-field')), 'jsmith');
      await tester.enterText(find.byKey(const Key('login-password-field')), 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await _settle(tester);

      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.text('Welcome to OEP!'), findsNothing);
    });

    testWidgets('the correct password signs in and reaches Welcome', (tester) async {
      await _pumpOnboarding(tester, hasAccount: true);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('login-username-field')), 'jsmith');
      await tester.enterText(find.byKey(const Key('login-password-field')), 'correct-horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await _settle(tester);

      expect(find.text('Welcome to OEP!'), findsOneWidget);
    });

    testWidgets('signing in with Remember Me is reflected by the auth service', (tester) async {
      final auth = await _pumpOnboarding(tester, hasAccount: true);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('login-username-field')), 'jsmith');
      await tester.enterText(find.byKey(const Key('login-password-field')), 'correct-horse');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await _settle(tester);

      expect(await auth.rememberedUsername(), 'jsmith');
    });

    testWidgets('Create Account link switches to the Create Account screen', (tester) async {
      await _pumpOnboarding(tester, hasAccount: true);
      await _settle(tester);

      await tester.tap(find.text('Create Account'));
      await _settle(tester);

      expect(find.text('Create Local Account'), findsOneWidget);
    });
  });

  group('Create Account', () {
    testWidgets('mismatched password confirmation is rejected', (tester) async {
      await _pumpOnboarding(tester);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('create-username-field')), 'newuser');
      await tester.enterText(find.byKey(const Key('create-password-field')), 'correct-horse');
      await tester.enterText(find.byKey(const Key('create-confirm-password-field')), 'different-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await _settle(tester);

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(find.text('Welcome to OEP!'), findsNothing);
    });

    testWidgets('a valid new account is created and reaches Welcome', (tester) async {
      final auth = await _pumpOnboarding(tester);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('create-username-field')), 'newuser');
      await tester.enterText(find.byKey(const Key('create-password-field')), 'correct-horse');
      await tester.enterText(find.byKey(const Key('create-confirm-password-field')), 'correct-horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await _settle(tester);

      expect(find.text('Welcome to OEP!'), findsOneWidget);
      expect(await auth.hasAnyAccount(), isTrue);
    });
  });

  group('Welcome', () {
    testWidgets('Get Started proceeds to Studio/Workspace Selection', (tester) async {
      await _pumpOnboarding(tester, hasAccount: true);
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('login-username-field')), 'jsmith');
      await tester.enterText(find.byKey(const Key('login-password-field')), 'correct-horse');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await _settle(tester);

      expect(find.byKey(const Key('welcome-get-started-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('welcome-get-started-button')));
      await _settle(tester);

      expect(find.text('Choose Your Workspace'), findsOneWidget);
    });
  });

  group('Studio/Workspace Selection', () {
    testWidgets('only real Studios appear, and selecting one highlights it', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WorkspaceSelectionScreen())),
      );
      await _settle(tester);

      expect(find.text(StudioDestination.diagram.label), findsOneWidget);
      expect(find.text(StudioDestination.knowledge.label), findsOneWidget);
      expect(find.text('Automotive Installer'), findsNothing, reason: 'no such Studio exists in this codebase');

      final continueButton = find.byKey(const Key('workspace-continue-button'));
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull, reason: 'nothing selected yet');

      await tester.tap(find.byKey(Key('workspace-tile-${StudioDestination.diagram.path}')));
      await _settle(tester);

      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.tap(continueButton);
      await _settle(tester);

      expect(find.text('Studio launch will be implemented in the next phase.'), findsOneWidget);
    });
  });
}
