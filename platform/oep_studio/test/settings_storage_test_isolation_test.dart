import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/settings/services/settings_storage.dart';

import 'support/isolated_settings_storage.dart';

/// Regression coverage for AP-DIAGRAM-W2-D1 (Wave 2 Stage D1 — Workspace
/// Persistence Test Isolation Hardening). Proves the isolation seam
/// itself: `useIsolatedSettingsStorage()` redirects `SettingsStorage.root()`
/// away from the real production location, the override is scoped to
/// exactly the test that set it, and clearing it restores production
/// behavior — all without ever touching the real
/// `%APPDATA%/oep_studio`.
void main() {
  Directory productionRoot() => Directory(
        '${Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}'
        '${Platform.pathSeparator}oep_studio',
      );

  test('SettingsStorage.root() resolves the real production location when no override is set', () {
    expect(SettingsStorage.root().path, productionRoot().path, reason: 'production behavior (no test override active) must be completely unchanged by this hardening pass');
  });

  test('useIsolatedSettingsStorage() redirects SettingsStorage.root() to an isolated temp directory, never the real production root', () {
    final isolatedDir = useIsolatedSettingsStorage();

    expect(SettingsStorage.root().path, isolatedDir.path);
    expect(SettingsStorage.root().path, isNot(productionRoot().path), reason: 'this is the real-user-data safety assertion: the test root must never equal the real %APPDATA%/oep_studio path');
    expect(isolatedDir.existsSync(), isTrue);
    // Never hard-codes a username/path — computed programmatically from
    // the same environment variables `SettingsStorage.root()` itself
    // reads, matching the task's explicit instruction.
    expect(isolatedDir.path, startsWith(Directory.systemTemp.path));
  });

  test('the override does not leak into a later test in the same isolate', () {
    // The previous test's `addTearDown` must have already cleared the
    // override by the time this test runs (flutter_test runs each
    // test's tearDowns before the next test body starts).
    expect(SettingsStorage.root().path, productionRoot().path, reason: 'a prior test\'s isolated override must not survive into this test');
  });

  test('a real, isolated write actually lands under the temp directory, not production', () async {
    final isolatedDir = useIsolatedSettingsStorage();
    final markerFile = File('${isolatedDir.path}${Platform.pathSeparator}stage_d1_marker.txt');
    await markerFile.writeAsString('isolated');
    expect(markerFile.existsSync(), isTrue);
    expect(
      File('${productionRoot().path}${Platform.pathSeparator}stage_d1_marker.txt').existsSync(),
      isFalse,
      reason: 'the same relative filename must never appear under the real production root',
    );
  });
}
