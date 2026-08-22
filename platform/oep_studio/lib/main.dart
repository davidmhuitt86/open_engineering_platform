import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TEMPORARY DEV-ONLY BYPASS (hot-reload tooling verification) --
// REVERT BEFORE ANY REAL WORK: boots straight into `StudioApp` instead
// of `OepBootApp` (login/onboarding + Studio chooser), so the running
// app lands directly on a Studio destination for interactive hot-reload
// testing. See `app/oep_boot_app.dart` for the real, unmodified startup
// flow this is standing in for.
import 'app/studio_app.dart';

void main() {
  runApp(const ProviderScope(child: StudioApp()));
}
