import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/settings_exception.dart';

/// Local JSON persistence for the User Configuration (Work Package 017
/// STUDIO-TASK-000053; SDD-023 Configuration Storage). One file,
/// `%APPDATA%/oep_studio/settings.json` — unlike Knowledge Sessions
/// (one directory per session), there is exactly one User
/// Configuration per Studio installation. Uses `dart:io`/
/// `Platform.environment` directly, mirroring
/// `KnowledgeSessionStorage`'s own precedent and reasoning (Work
/// Package 008): this is a Windows-only desktop target already, so
/// `path_provider`'s cross-platform channel code would be dead weight.
///
/// All I/O and parse errors are translated to [SettingsException] with
/// a professional message — never a raw `IOException`/`FormatException`
/// reaching the UI (Work Package 017 Error Handling: "Corrupt
/// configuration ... Display professional messages").
abstract final class SettingsStorage {
  /// AP-DIAGRAM-W2-D1 (Wave 2 Stage D1 — Workspace Persistence Test
  /// Isolation Hardening): the sole test seam for isolating persistence
  /// tests from this real machine's actual `%APPDATA%/oep_studio`.
  /// `null` (the only value production code ever sees) means [root]
  /// resolves the real production location exactly as before this
  /// change — production behavior is unaffected. Every Studio
  /// persistence class that ultimately stores under
  /// `SettingsStorage.root()` (`WorkspaceStateStorage`,
  /// `DiagramTabsStorage`, `DiagramDocument`'s autosave directory,
  /// `DiagramStudioSettingsStorage`, `RecentFilesStorage`,
  /// `InstrumentDockStorage`, `SettingsStorage` itself, and every other
  /// caller enumerated in `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md`'s
  /// persistence inventory) resolves through this one method, so
  /// overriding it here isolates all of them at once — no per-class
  /// seam is needed, and none of their own code changes.
  static Directory? _testRootOverride;

  /// Sets (or clears, with `null`) the directory [root] returns instead
  /// of the real production location. Deliberately a plain static
  /// toggle rather than a second persistence abstraction or a Riverpod
  /// provider: `SettingsStorage` and everything built on it is a
  /// static-method utility with no dependency-injection seam anywhere
  /// today, and adding one purely to make this override cleaner would
  /// be a persistence-subsystem redesign this hardening pass is
  /// explicitly not authorized to do.
  ///
  /// Callers (tests) own the override's lifecycle: set it to a real,
  /// disposable temp directory before exercising any persistence code,
  /// and reset it to `null` afterward (an `addTearDown` in the same
  /// test, so a failure doesn't leak the override into a later test in
  /// the same isolate). This method does not manage that lifecycle
  /// itself.
  @visibleForTesting
  static void debugSetTestRootOverride(Directory? directory) {
    _testRootOverride = directory;
  }

  /// AP-OEP-WORKSPACE-PERSISTENCE-001 — lets a test-isolation helper
  /// (`useIsolatedSettingsStorage`) restore whatever override was
  /// already active before it ran, instead of hard-resetting to `null`
  /// (the real production location). Needed once a *global*,
  /// whole-suite override can be active underneath a more specific,
  /// single-test override (see `test/flutter_test_config.dart`) — never
  /// read by production code.
  @visibleForTesting
  static Directory? get debugTestRootOverride => _testRootOverride;

  static Directory root() {
    final override = _testRootOverride;
    if (override != null) return override;
    final base =
        Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}oep_studio');
  }

  static File _file() => File('${root().path}${Platform.pathSeparator}settings.json');

  /// Reads the raw settings JSON, or `null` if no settings file exists
  /// yet (a fresh install — [SettingsService.load] falls back to
  /// [UserConfiguration.defaults] in that case).
  static Future<Map<String, dynamic>?> readRaw() async {
    final file = _file();
    if (!file.existsSync()) return null;
    final String contents;
    try {
      contents = await file.readAsString();
    } on IOException catch (error) {
      throw SettingsException('Couldn\'t read the settings file: ${error.toString()}');
    }
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        throw const SettingsException('The settings file is corrupted and could not be loaded.');
      }
      return decoded;
    } on FormatException catch (error) {
      throw SettingsException('The settings file is corrupted and could not be loaded (${error.message}).');
    } on TypeError {
      throw const SettingsException('The settings file is corrupted and could not be loaded.');
    }
  }

  /// Writes the settings JSON, creating `%APPDATA%/oep_studio/` if
  /// needed. Callers (`SettingsService.save`) must validate first —
  /// this method persists whatever it is given.
  static Future<void> writeRaw(Map<String, dynamic> json) async {
    try {
      await root().create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await _file().writeAsString(encoder.convert(json));
    } on IOException catch (error) {
      throw SettingsException('Couldn\'t save settings: ${error.toString()}');
    }
  }

  /// Removes the settings file entirely, so the next [readRaw] reports
  /// "no settings file yet". Used by tests and by a genuine full reset;
  /// "Reset Defaults" itself just writes [UserConfiguration.defaults]
  /// back through [writeRaw] rather than deleting.
  static Future<void> delete() async {
    final file = _file();
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } on IOException catch (error) {
      throw SettingsException('Couldn\'t delete settings file: ${error.toString()}');
    }
  }
}
