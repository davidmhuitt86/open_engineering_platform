import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/routing/app_router.dart';
import '../core/theme/studio_theme.dart';

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TEMPORARY DEV-ONLY hot-reload proof marker -- REVERT after testing.
    debugPrint('HOT_RELOAD_PROOF_MARKER_V1');
    return MaterialApp.router(
      title: 'OEP Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.dark,
      darkTheme: StudioTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
