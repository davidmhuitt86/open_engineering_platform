import 'package:flutter/material.dart';

import '../core/routing/app_router.dart';
import '../core/routing/studio_destination.dart';
import '../core/theme/studio_theme.dart';
import '../features/onboarding/onboarding_flow.dart';
import 'studio_app.dart';

/// The real application entry point (OEP First Startup UI, Phase 0A) --
/// deliberately separate from [StudioApp] (the existing `go_router`-
/// based application, in `studio_app.dart`), which stays completely
/// untouched: every existing test instantiates `StudioApp` directly, so
/// changing it would regress the entire existing suite. Only
/// `main.dart` changes, to boot into this widget instead.
///
/// [OnboardingFlow] now actually launches into [StudioApp]/`appRouter`
/// once the user picks a Studio and presses Continue on Workspace
/// Selection -- this is that connection point. `appRouter` itself is
/// the same single, unmodified global `GoRouter` every existing route
/// test already exercises; this widget only ever calls its real,
/// public `go()` API (exactly what `StudioShell.onSelect` already
/// does), never a second router/navigation system.
class OepBootApp extends StatefulWidget {
  const OepBootApp({super.key});

  @override
  State<OepBootApp> createState() => _OepBootAppState();
}

class _OepBootAppState extends State<OepBootApp> {
  bool _launched = false;

  void _launchStudio(StudioDestination destination) {
    setState(() => _launched = true);
    // `appRouter` boots to its own fixed `initialLocation`
    // (`StudioDestination.dashboard.path`) regardless of which Studio
    // the user picked -- one real `go()` call after `StudioApp` mounts
    // takes it the rest of the way, the same navigation the app's own
    // sidebar/shell already performs on every Studio switch.
    WidgetsBinding.instance.addPostFrameCallback((_) => appRouter.go(destination.path));
  }

  @override
  Widget build(BuildContext context) {
    if (_launched) return const StudioApp();
    return MaterialApp(
      title: 'OEP',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.dark,
      darkTheme: StudioTheme.dark,
      themeMode: ThemeMode.dark,
      home: OnboardingFlow(onLaunch: _launchStudio),
    );
  }
}
