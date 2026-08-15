import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/authentication_provider.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';
import 'workspace_selection_screen.dart';

/// The Splash → Login → First-run Welcome → Studio/Workspace Selection
/// sequence (OEP First Startup UI, Phase 0A).
///
/// Self-contained up through Workspace Selection: no `go_router`
/// involvement, no change to `StudioShell`/`app_router.dart`/any
/// existing Studio. Once the user picks a Studio and presses Continue,
/// [onLaunch] hands control back to the caller (`OepBootApp`), which is
/// the one place that knows how to actually enter the real,
/// `go_router`-based application -- this widget itself still never
/// imports or references `StudioApp`/`appRouter`.
enum OnboardingStage { splash, login, createAccount, welcome, workspaceSelection }

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.onLaunch});

  /// Called with the Studio the user chose to launch. `null` (the
  /// default) preserves the original standalone behavior (the
  /// placeholder "Studio launch will be implemented" dialog).
  final void Function(StudioDestination destination)? onLaunch;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  OnboardingStage _stage = OnboardingStage.splash;

  void _goTo(OnboardingStage stage) => setState(() => _stage = stage);

  Future<void> _handleSplashComplete() async {
    final auth = ref.read(authenticationServiceProvider);
    final hasAccount = await auth.hasAnyAccount();
    if (!mounted) return;
    if (!hasAccount) {
      _goTo(OnboardingStage.createAccount);
      return;
    }
    final remembered = await auth.rememberedUsername();
    if (!mounted) return;
    _goTo(remembered != null ? OnboardingStage.welcome : OnboardingStage.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioColors.background,
      body: switch (_stage) {
        OnboardingStage.splash => SplashScreen(onInitialized: _handleSplashComplete),
        OnboardingStage.login => LoginScreen(
            onSignedIn: (username) => _goTo(OnboardingStage.welcome),
            onCreateAccount: () => _goTo(OnboardingStage.createAccount),
          ),
        OnboardingStage.createAccount => CreateAccountScreen(
            onCreated: (username) => _goTo(OnboardingStage.welcome),
            onCancel: () => _goTo(OnboardingStage.login),
          ),
        OnboardingStage.welcome => WelcomeScreen(onGetStarted: () => _goTo(OnboardingStage.workspaceSelection)),
        OnboardingStage.workspaceSelection => WorkspaceSelectionScreen(onLaunch: widget.onLaunch),
      },
    );
  }
}
