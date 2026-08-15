import 'package:flutter/material.dart';

import '../core/routing/app_router.dart';
import '../core/theme/studio_theme.dart';

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
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
