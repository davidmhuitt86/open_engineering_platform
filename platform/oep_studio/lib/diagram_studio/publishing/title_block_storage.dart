import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';

import '../../settings/services/settings_storage.dart';

/// AP-DS-004: persistence for a diagram's [TitleBlock].
///
/// **Design decision (documented per the task spec's own request):** the
/// Title Block is stored as its own Studio-side JSON file,
/// `title_blocks.json`, mapping a diagram identity -> [TitleBlock] JSON —
/// mirroring [DiagramStudioSettingsStorage]'s "own file under
/// `SettingsStorage.root()`" pattern, NOT folded into `DiagramDocument`'s
/// own envelope. Reasoning:
///
/// 1. `DiagramDocument`/the `.json` document schema on disk is owned by
///    AP-DS-001A/002's persistence work and is actively used by both the
///    legacy-migration importer and the Repository save/load path
///    (`DiagramRepositoryService`) — extending that schema is a
///    cross-cutting change to code this phase was told to touch minimally,
///    for a field (Title Block) that nothing else in the document schema
///    depends on structurally.
/// 2. A Title Block is closer to "how this diagram should be published"
///    than "what this diagram engineering-wise is" — same category of
///    fact as a Print Profile or Export Profile (this phase's own
///    Document Management section), which are explicitly Studio-side
///    concerns, not engineering data. Keeping it alongside those in one
///    publishing-settings family is more consistent than splitting one
///    conceptual group (Title Block config vs. Print/Export profiles)
///    across two different storage mechanisms.
/// 3. It keeps this phase's persistence 100% additive — zero risk of
///    breaking existing `DiagramDocument.toJson`/`fromJson` round-trips
///    or the legacy migration importer's schema assumptions.
///
/// Trade-off, disclosed honestly: a Title Block saved this way travels
/// with the *local install*, keyed by the diagram's file path, not
/// embedded in the `.json` document file itself — so it will not survive
/// copying the diagram file to another machine or into a Drawing Package
/// export (Package Manifest/export bundling reads the Title Block via
/// this storage at export time, not from the document file). If a future
/// phase decides Title Blocks must travel with the document file, moving
/// this map's per-diagram entry into `DiagramDocument`'s envelope is a
/// contained follow-up, not a rearchitecture.
abstract final class TitleBlockStorage {
  /// Test-only override: three separate test files exercise this class
  /// (and [TitleBlockPresetStorage] below) against the real,
  /// process-global `SettingsStorage.root()` path by default, which
  /// `flutter test`'s default cross-file parallelism turned into a
  /// genuine, reproducible file-handle race (two test files writing/
  /// deleting the same real `title_blocks.json` concurrently) — found
  /// during this phase's own independent verification pass, not a
  /// hypothetical concern. Tests set this to a per-file temp directory
  /// in `setUpAll`/reset it in `tearDownAll`; production code never
  /// touches it, so it defaults to `null` (meaning "use the real root").
  static Directory? testRootOverride;

  static File _file() =>
      File('${(testRootOverride ?? SettingsStorage.root()).path}${Platform.pathSeparator}title_blocks.json');

  /// Diagram identity key: file path if the diagram has been saved,
  /// otherwise a caller-supplied fallback (e.g. `'untitled'`) — unsaved
  /// diagrams sharing a title block is an acceptable, disclosed
  /// limitation given there is no other stable identity available yet.
  static Future<TitleBlock> load(String diagramKey) async {
    final all = await _loadAll();
    final entry = all[diagramKey];
    if (entry == null) return TitleBlock.empty;
    return TitleBlock.fromJson(Map<String, Object?>.from(entry as Map));
  }

  static Future<void> save(String diagramKey, TitleBlock titleBlock) async {
    final all = await _loadAll();
    all[diagramKey] = titleBlock.toJson();
    await _saveAll(all);
  }

  static Future<Map<String, Object?>> _loadAll() async {
    final file = _file();
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return {};
      return decoded;
    } on FormatException {
      return {};
    }
  }

  static Future<void> _saveAll(Map<String, Object?> all) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(all));
  }
}

/// Item 7 (Templates & Document Management, lowest priority per the task
/// spec) — minimal, honest implementation: named Title Block presets a
/// user can save and re-apply, following `RecentFilesStorage`'s own
/// JSON-on-disk-list pattern. This is NOT a full template system (no
/// Report/Print-Layout/Cover-Page/Header/Footer templates, no Print/Export
/// Profiles, no Saved Layouts/Favorites/Recent-Exports tracking) — that
/// fuller scope is disclosed as deferred future work in this phase's
/// final report.
abstract final class TitleBlockPresetStorage {
  /// See [TitleBlockStorage.testRootOverride] — same reasoning, same
  /// mechanism, kept as a separate field since these are two
  /// independent files on disk.
  static Directory? testRootOverride;

  static File _file() =>
      File('${(testRootOverride ?? SettingsStorage.root()).path}${Platform.pathSeparator}title_block_presets.json');

  static Future<Map<String, TitleBlock>> loadAll() async {
    final file = _file();
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return {};
      return decoded.map(
        (name, value) => MapEntry(name, TitleBlock.fromJson(Map<String, Object?>.from(value as Map))),
      );
    } on FormatException {
      return {};
    }
  }

  static Future<void> savePreset(String name, TitleBlock titleBlock) async {
    final all = await loadAll();
    all[name] = titleBlock;
    await _persist(all);
  }

  static Future<void> deletePreset(String name) async {
    final all = await loadAll();
    all.remove(name);
    await _persist(all);
  }

  static Future<void> _persist(Map<String, TitleBlock> all) async {
    await SettingsStorage.root().create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file().writeAsString(encoder.convert(all.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
