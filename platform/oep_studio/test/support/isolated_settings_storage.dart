import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

/// AP-DIAGRAM-W2-D1 (Wave 2 Stage D1 — Workspace Persistence Test
/// Isolation Hardening). Every Studio persistence class resolves its
/// storage location through `SettingsStorage.root()`
/// (`workspace_state_storage.dart`, `diagram_tabs_storage.dart`,
/// `diagram_document.dart`'s autosave directory, and the rest — see
/// `SettingsStorage.debugSetTestRootOverride`'s own doc comment for the
/// full list). Call this at the top of any `test`/`testWidgets` body
/// that exercises real persistence — it creates a fresh temp directory,
/// points every persistence class at it for the duration of the test,
/// and tears both down afterward via `addTearDown` (works identically in
/// plain `test()` and `testWidgets()` — both expose the same top-level
/// `addTearDown`).
///
/// **What this replaces.** Stage D's own tests captured this real
/// machine's actual `%APPDATA%/oep_studio` content before running and
/// restored it in a `finally` block — a real corruption occurred twice
/// during that stage despite that discipline (documented in the Stage D
/// completion report). This helper removes the hazard at its root:
/// tests using it never touch the real location at all, so there is
/// nothing to back up or restore, and no reason to serialize test
/// execution to avoid two tests racing on the same real file.
///
/// Returns the temp [Directory] in case a test needs to inspect files
/// directly (e.g. to assert a specific JSON file's raw contents).
Directory useIsolatedSettingsStorage() {
  final dir = Directory.systemTemp.createTempSync('oep_studio_settings_test_');

  // Real-user-data safety: fail loudly, before any persistence code
  // runs, if this resolved somewhere that could plausibly be the real
  // production location — computed the same way `SettingsStorage.root()`
  // computes it, never by hard-coding a username or path.
  final wouldBeProductionRoot = Directory(
    '${Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}'
    '${Platform.pathSeparator}oep_studio',
  );
  if (_normalized(dir.path) == _normalized(wouldBeProductionRoot.path)) {
    throw StateError(
      'useIsolatedSettingsStorage() resolved a temp directory identical to the real production SettingsStorage root '
      '($wouldBeProductionRoot) — refusing to proceed, since every test using this helper assumes it is writing '
      'somewhere disposable.',
    );
  }

  SettingsStorage.debugSetTestRootOverride(dir);
  addTearDown(() {
    SettingsStorage.debugSetTestRootOverride(null);
    // Best-effort only: a `persist()`-style call made from a
    // `testWidgets` fake-async zone still schedules a real `dart:io`
    // write (see `diagram_workspace_persistence_provider_test.dart`'s
    // own notes), and on Windows that write can still hold its file
    // handle open for a moment after the test body returns — deleting
    // the directory out from under it throws `PathAccessException`
    // (verified: it does, under default test concurrency). That failed
    // write was always going to a *disposable* temp directory, so a
    // failure to delete it promptly is not a correctness problem, only
    // a tidiness one — the OS reclaims its own temp directory over
    // time regardless. Swallow it rather than fail the test over
    // cleanup of something that was never real user data to begin with.
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Ignored — see comment above.
      }
    }
  });
  return dir;
}

String _normalized(String path) => path.replaceAll('\\', '/').toLowerCase();
