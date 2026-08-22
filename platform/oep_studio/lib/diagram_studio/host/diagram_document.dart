import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:engineering_engine/engineering_engine.dart';

import '../../settings/services/settings_storage.dart';

/// A Diagram Studio document — an Engineering Graph plus its Diagram
/// Layout, persisted together as one file (WORK_PACKAGE_024,
/// ENGINE-TASK-000111: Open/Save/Save As/Close/Dirty State).
///
/// Foundation's actual repository API has no schema for Diagram Layout/
/// ViewState/Annotations/Layers/wire overrides, no "Save"/"Save As", and
/// no dirty-state concept at all — it only knows `EngineeringObject`/
/// `Relationship` plus an append-only audit log (see
/// `docs/REPOSITORY_INTEGRATION.md` for the full account). Building
/// genuine Foundation-backed diagram persistence would require a
/// Foundation-side schema change, which is out of scope — `oep_foundation`
/// may not be modified. A Diagram Studio document therefore uses the
/// Engineering Engine's own existing, already-serializable
/// `EngineeringGraph.toJson()`/`DiagramLayoutState.toJson()` — the same
/// SDD-025-sanctioned path Foundation-less verification already used in
/// WORK_PACKAGE_019–023 ("Engineering Engine shall operate without an
/// open Repository where practical"). This class composes those two
/// already-serializable pieces into one file; it does not reimplement
/// graph or layout serialization itself. The *ambient* Foundation
/// repository (opened separately, via the existing
/// `FoundationRuntimeNotifier`) is tracked for display only — see
/// `DiagramStudioPage`.
///
/// AP-DS-001A adds three purely-local refinements on top of the same
/// schema (still `schemaVersion = 1`, still no Foundation persistence):
/// document metadata (title/created/modified timestamps), a debounced
/// Autosave that writes to a *separate* recovery file (never the user's
/// own save path), and crash Recovery detection via [DiagramDocument.
/// findRecovery].
class DiagramDocument {
  static const int schemaVersion = 1;

  String? path;
  bool isDirty = false;

  /// A stable identifier for this document instance, used only to name
  /// its autosave/recovery file — generated once per in-memory document
  /// (on `open`/first `saveAs`/first `autosave`) and carried in the
  /// envelope so a recovery file can be matched back to it.
  String? _documentId;

  DiagramDocumentMetadata metadata = DiagramDocumentMetadata.newDocument();

  static Directory _autosaveDir() =>
      Directory('${SettingsStorage.root().path}${Platform.pathSeparator}autosave');

  File _autosaveFile(String id) =>
      File('${_autosaveDir().path}${Platform.pathSeparator}$id.autosave.json');

  String _ensureId() => _documentId ??= _generateId();

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 2 — the stable per-in-memory-document
  /// identity this bridge needs, exposed publicly. Already existed as
  /// [_ensureId] (used internally to name the autosave/recovery file) —
  /// this task adds no new identity mechanism, only a public accessor.
  /// Distinguishes two different never-saved documents in the same
  /// session even though `path` is `null` for both, because [close]
  /// resets `_documentId` to `null` (line below) and this getter
  /// regenerates a fresh one lazily on next access — so "new document A"
  /// and "new document B" (created via `newDocument()`, which calls
  /// `close()` first) get different ids despite being the same
  /// `DiagramDocument` Dart object instance (`EngineeringProjectState`
  /// mutates it in place rather than replacing it — confirmed by reading
  /// `EngineeringProjectService.newDocument`/`closeDocument` directly).
  String get id => _ensureId();

  static String _generateId() {
    final random = Random();
    return List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  /// Reads a document file, returning its Graph and Layout together.
  Future<({EngineeringGraph graph, DiagramLayoutState layout})> open(String filePath) async {
    final file = File(filePath);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final graph = EngineeringGraph.fromJson(decoded['graph'] as Map<String, Object?>);
    final layoutJson = decoded['layout'] as Map<String, Object?>?;
    final layout =
        layoutJson == null ? DiagramLayoutState.empty : DiagramLayoutState.fromJson(layoutJson);
    final metadataJson = decoded['metadata'] as Map<String, Object?>?;
    metadata = metadataJson == null
        ? DiagramDocumentMetadata.newDocument(title: _titleFromPath(filePath))
        : DiagramDocumentMetadata.fromJson(metadataJson);
    _documentId = decoded['documentId'] as String?;
    path = filePath;
    isDirty = false;
    return (graph: graph, layout: layout);
  }

  static String _titleFromPath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
  }

  /// Writes [graph]/[layout] to [filePath] — "Save As," which also
  /// becomes this document's new [path] going forward.
  Future<void> saveAs(String filePath, EngineeringGraph graph, DiagramLayoutState layout) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final now = DateTime.now();
    final isDefaultTitle = metadata.title.isEmpty || metadata.title == 'Untitled Diagram';
    metadata = metadata.copyWith(
      title: isDefaultTitle ? _titleFromPath(filePath) : metadata.title,
      createdAt: metadata.createdAt ?? now,
      modifiedAt: now,
    );
    final envelope = _envelope(graph, layout);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(envelope));
    path = filePath;
    isDirty = false;
  }

  Map<String, Object?> _envelope(EngineeringGraph graph, DiagramLayoutState layout) => {
        'schemaVersion': schemaVersion,
        'documentId': _ensureId(),
        'graph': graph.toJson(),
        'layout': layout.toJson(),
        'metadata': metadata.toJson(),
      };

  /// Writes to the document's current [path]. Throws [StateError] if the
  /// document has never been saved — the caller should prompt for a
  /// location via [saveAs] instead ("Save" requires an existing path;
  /// "Save As" always works and establishes one).
  Future<void> save(EngineeringGraph graph, DiagramLayoutState layout) async {
    final currentPath = path;
    if (currentPath == null) {
      throw StateError('This document has no file path yet — use saveAs() instead.');
    }
    await saveAs(currentPath, graph, layout);
    // A fresh explicit Save supersedes any stale autosave for this
    // document — remove it so recovery doesn't offer to "recover" data
    // the user just saved themselves.
    final id = _documentId;
    if (id != null) {
      final autosave = _autosaveFile(id);
      if (autosave.existsSync()) await autosave.delete();
    }
  }

  /// Writes the current [graph]/[layout] to a recovery file distinct
  /// from [path] — never the user's own save path. Intended to be
  /// called from a debounced timer after edits. Does not touch
  /// [isDirty] or [path]; this is not a user-visible Save.
  Future<void> autosave(EngineeringGraph graph, DiagramLayoutState layout) async {
    final id = _ensureId();
    await _autosaveDir().create(recursive: true);
    final envelope = {
      ..._envelope(graph, layout),
      'originalPath': path,
      'autosavedAt': DateTime.now().toIso8601String(),
    };
    await _autosaveFile(id).writeAsString(const JsonEncoder.withIndent('  ').convert(envelope));
  }

  /// Marks the document dirty — Diagram Studio calls this on every
  /// `EditingService.sessionChanges` emission once a document is open.
  void markDirty() => isDirty = true;

  /// Resets to a brand-new, unsaved, clean document (Close).
  void close() {
    path = null;
    isDirty = false;
    _documentId = null;
    metadata = DiagramDocumentMetadata.newDocument();
  }

  /// Scans the autosave directory for a recovery candidate for
  /// [forPath] (or for a never-saved document, when [forPath] is
  /// `null`) that is newer than [savedModifiedAt] (the on-disk file's
  /// own modified time, or `null` if there is no saved file at all).
  /// Returns `null` when there's nothing worth offering to recover.
  static Future<DiagramRecoveryCandidate?> findRecovery(
    String? forPath, {
    DateTime? savedModifiedAt,
  }) async {
    final dir = _autosaveDir();
    if (!dir.existsSync()) return null;
    DiagramRecoveryCandidate? best;
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.autosave.json')) continue;
      try {
        final decoded = jsonDecode(await entry.readAsString()) as Map<String, Object?>;
        final originalPath = decoded['originalPath'] as String?;
        if (originalPath != forPath) continue;
        final autosavedAtRaw = decoded['autosavedAt'] as String?;
        final autosavedAt = autosavedAtRaw == null ? null : DateTime.tryParse(autosavedAtRaw);
        if (autosavedAt == null) continue;
        if (savedModifiedAt != null && !autosavedAt.isAfter(savedModifiedAt)) continue;
        if (best == null || autosavedAt.isAfter(best.autosavedAt)) {
          best = DiagramRecoveryCandidate(
            autosaveFilePath: entry.path,
            originalPath: originalPath,
            autosavedAt: autosavedAt,
          );
        }
      } on FormatException {
        continue;
      }
    }
    return best;
  }

  /// Loads the Graph/Layout/Metadata out of a recovery candidate's
  /// autosave file so the caller can adopt it as the live document.
  Future<({EngineeringGraph graph, DiagramLayoutState layout})> recoverFrom(
    DiagramRecoveryCandidate candidate,
  ) async {
    final file = File(candidate.autosaveFilePath);
    final decoded = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final graph = EngineeringGraph.fromJson(decoded['graph'] as Map<String, Object?>);
    final layoutJson = decoded['layout'] as Map<String, Object?>?;
    final layout =
        layoutJson == null ? DiagramLayoutState.empty : DiagramLayoutState.fromJson(layoutJson);
    final metadataJson = decoded['metadata'] as Map<String, Object?>?;
    if (metadataJson != null) metadata = DiagramDocumentMetadata.fromJson(metadataJson);
    _documentId = decoded['documentId'] as String?;
    path = candidate.originalPath;
    isDirty = true;
    return (graph: graph, layout: layout);
  }
}

/// A recovery-worthy autosave file discovered by [DiagramDocument.
/// findRecovery] — enough for the caller to show "Recover unsaved
/// changes from <time>?" without reading the whole document yet.
class DiagramRecoveryCandidate {
  const DiagramRecoveryCandidate({
    required this.autosaveFilePath,
    required this.originalPath,
    required this.autosavedAt,
  });

  final String autosaveFilePath;
  final String? originalPath;
  final DateTime autosavedAt;
}

/// Document metadata (AP-DS-001A Documents review: "check what metadata
/// currently exists ... and ensure it's populated and displayed
/// somewhere sensible"). Deliberately small — title plus
/// created/modified timestamps, which is all the local JSON schema
/// needs; there is no authenticated user concept in a self-contained
/// local editor, so `author` stays free-text/optional rather than
/// wired to any identity system.
class DiagramDocumentMetadata {
  final String title;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final String? author;

  const DiagramDocumentMetadata({
    required this.title,
    this.createdAt,
    this.modifiedAt,
    this.author,
  });

  factory DiagramDocumentMetadata.newDocument({String? title}) => DiagramDocumentMetadata(
        title: title ?? 'Untitled Diagram',
        createdAt: DateTime.now(),
      );

  DiagramDocumentMetadata copyWith({
    String? title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? author,
  }) {
    return DiagramDocumentMetadata(
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      author: author ?? this.author,
    );
  }

  Map<String, Object?> toJson() => {
        'title': title,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
        if (author != null) 'author': author,
      };

  factory DiagramDocumentMetadata.fromJson(Map<String, Object?> json) {
    final createdRaw = json['createdAt'] as String?;
    final modifiedRaw = json['modifiedAt'] as String?;
    return DiagramDocumentMetadata(
      title: json['title'] as String? ?? 'Untitled Diagram',
      createdAt: createdRaw == null ? null : DateTime.tryParse(createdRaw),
      modifiedAt: modifiedRaw == null ? null : DateTime.tryParse(modifiedRaw),
      author: json['author'] as String?,
    );
  }
}
