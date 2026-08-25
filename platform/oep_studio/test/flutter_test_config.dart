import 'dart:async';
import 'dart:io';

import 'package:oep_studio/settings/services/settings_storage.dart';

/// AP-OEP-WORKSPACE-PERSISTENCE-001 — `StudioShell` now unconditionally
/// builds a persistent `EngineeringWorkspacePage` host the moment it is
/// mounted (`AP-OEP-WORKSPACE-ROUTING-001`), and that host reads
/// `workspaceTabsControllerProvider`, whose creation now performs real
/// (fire-and-forget) file I/O against `SettingsStorage.root()` — for the
/// first time in this codebase, merely *building* the app's normal
/// widget tree touches disk, not only a test that deliberately exercises
/// persistence.
///
/// `StudioShell`/`StudioApp` is mounted by hundreds of pre-existing
/// tests with no relationship to the Workspace at all (`widget_test.dart`,
/// `onboarding_flow_test.dart`, and more) — requiring every one of them
/// (and every future one) to remember `useIsolatedSettingsStorage()`
/// individually would be both impractical and easy to miss. Flutter's
/// own `flutter_test_config.dart` convention — automatically run once
/// per test file, wrapping that file's entire `main()` — is the correct,
/// existing mechanism for a whole-suite default like this, not a new
/// persistence architecture: it only ever sets `SettingsStorage`'s
/// already-existing test seam (`debugSetTestRootOverride`, built for
/// exactly this purpose — see its own doc comment) to a disposable temp
/// directory, for the duration of the test process.
///
/// A single test that needs its own separately-isolated directory (e.g.
/// to assert on that test's own file in isolation from others) still
/// calls `useIsolatedSettingsStorage()` as before — it now composes
/// correctly with this global default by restoring *this* override
/// (rather than hard-resetting to the real production location) once
/// that specific test ends.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final dir = Directory.systemTemp.createTempSync('oep_studio_suite_settings_test_');
  SettingsStorage.debugSetTestRootOverride(dir);
  try {
    await testMain();
  } finally {
    SettingsStorage.debugSetTestRootOverride(null);
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Best-effort only — see `useIsolatedSettingsStorage`'s own
        // identical note on why a failed cleanup of a disposable temp
        // directory is not a correctness problem.
      }
    }
  }
}
