// PRODUCT-READINESS-011 — real-diagram pre-seed for the Windows E2E test.
//
// The primary E2E acceptance workflow (§7/§8 of the PRODUCT-READINESS-011
// spec) must load the REAL `samples/diagram7.json` through the actual
// production Diagram Studio path, without the test automating the native
// Windows Open-File common dialog (`IFileOpenDialog`, driven by
// `_OpenButton`/`package:file_selector`) — a genuinely separate, hard-to-
// automate native window that is out of this phase's scope.
//
// Instead, this seeds `DiagramTabsStorage`'s own real, production JSON file
// (`diagram_studio_tabs.json`) with a tab entry pointing at the absolute
// path of `samples/diagram7.json`, using the exact same real API
// (`DiagramTabsStorage.save`) and JSON shape (`DiagramTab.toJson()`) real
// production code uses when a real session closes with a tab open. The
// real, existing `'Load Previous Diagram'` button then loads it through the
// actual production `DiagramTabsStorage.load()` path — no synthetic
// replacement, no bypass.
//
// Writes go to an ISOLATED directory (`SettingsStorage.debugSetTestRootOverride`)
// rather than a real developer's actual `%APPDATA%\oep_studio`, so running
// this E2E test never corrupts/overwrites a real person's own tab list,
// recent files, or settings on the same machine.
import 'dart:io';

import 'package:oep_studio/diagram_studio/tabs/diagram_tab.dart';
import 'package:oep_studio/diagram_studio/tabs/diagram_tabs_storage.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

/// Points `SettingsStorage.root()` (and therefore every persistence class
/// built on it) at a fresh, disposable temp directory for the duration of
/// the E2E test, and writes a single real [DiagramTab] entry whose `path`
/// is the absolute path of `samples/diagram7.json` — resolved from the
/// repository's real sample data, never a synthetic/fabricated fixture.
///
/// Returns the isolated root directory so the caller can delete it during
/// teardown. Throws (does not silently continue) if `samples/diagram7.json`
/// cannot be found — a missing primary acceptance fixture must fail loudly,
/// not fall back to a different diagram.
Future<Directory> seedDiagram7AsPreviousTab() async {
  final diagram7 = _locateDiagram7Sample();
  if (!diagram7.existsSync()) {
    throw StateError(
      'seedDiagram7AsPreviousTab: expected primary E2E fixture at '
      '"${diagram7.path}" but it does not exist. The PRODUCT-READINESS-011 '
      'primary acceptance workflow requires the real samples/diagram7.json '
      '— refusing to substitute a synthetic fixture.',
    );
  }

  final isolatedRoot = Directory.systemTemp.createTempSync('oep_studio_e2e_settings_');
  SettingsStorage.debugSetTestRootOverride(isolatedRoot);

  final tab = DiagramTab(
    id: 'e2e-diagram7',
    path: diagram7.path,
    title: 'diagram7',
  );

  await DiagramTabsStorage.save(
    tabs: [tab],
    activeTabId: tab.id,
    recentlyClosed: const [],
  );

  return isolatedRoot;
}

/// Clears the test-root override (restoring real production behavior for
/// any code that runs after this test in the same process) and deletes the
/// isolated directory this seed created.
void clearDiagram7Seed(Directory isolatedRoot) {
  SettingsStorage.debugSetTestRootOverride(null);
  if (isolatedRoot.existsSync()) {
    isolatedRoot.deleteSync(recursive: true);
  }
}

/// Resolves `samples/diagram7.json` relative to the `oep_studio` package
/// root (`integration_test/` binaries run with their CWD set to the
/// package root by `flutter test`/`flutter drive`, matching every other
/// asset-relative-path convention already used in this repository).
File _locateDiagram7Sample() {
  return File('${Directory.current.path}${Platform.pathSeparator}samples${Platform.pathSeparator}diagram7.json');
}
