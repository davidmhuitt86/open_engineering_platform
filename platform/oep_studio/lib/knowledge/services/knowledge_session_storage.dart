import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/knowledge_session_record.dart';
import '../models/knowledge_validation_exception.dart';

/// WP-INGEST-007 § 14/§ 17/§ 35: every real load of a session file is the
/// point at which a persisted `IngestionRun` that never reached a
/// terminal status (QUEUED/RUNNING -- meaning the application terminated
/// mid-ingestion, since a live execution always reaches a terminal
/// status before returning) is reconciled to FAILED with an explicit
/// interruption diagnostic. This is intentionally *not* a separate
/// "startup reconciliation pass" callers must remember to invoke --
/// [KnowledgeSessionStorage.load] is the one real persistence path every
/// caller (Session Browser, `FoundationRuntimeNotifier`, every test in
/// this repository) already goes through, so wiring reconciliation in
/// here is the only way to guarantee it always happens.
KnowledgeSessionRecord _reconcileInterruptedRuns(KnowledgeSessionRecord record) {
  if (record.ingestionRuns.every((run) => run.status.isTerminal)) return record;
  return KnowledgeSessionRecord(
    session: record.session,
    candidates: record.candidates,
    relationshipCandidates: record.relationshipCandidates,
    sources: record.sources,
    reviewDecisions: record.reviewDecisions,
    evidenceRegions: record.evidenceRegions,
    evidenceLinks: record.evidenceLinks,
    pageSelections: record.pageSelections,
    procedureSteps: record.procedureSteps,
    specificationDetails: record.specificationDetails,
    commitReports: record.commitReports,
    ocrPageResults: record.ocrPageResults,
    engineeringEntities: record.engineeringEntities,
    engineeringContexts: record.engineeringContexts,
    aiSuggestions: record.aiSuggestions,
    ingestionRuns: [for (final run in record.ingestionRuns) run.reconciledIfInterrupted()],
    derivedArtifacts: record.derivedArtifacts,
    normalizedProducts: record.normalizedProducts,
  );
}

/// The result of [KnowledgeSessionStorage.listAll]: every session that
/// loaded successfully, plus the IDs of any that didn't (Work Package
/// 008 Error Handling: "Corrupted session files ... Display
/// professional error messages") — the Session Browser shows both,
/// rather than either silently hiding corrupted sessions or letting
/// one corrupted file block the whole browser from opening.
class SessionBrowserListing {
  const SessionBrowserListing({required this.sessions, required this.corruptedSessionIds});

  final List<KnowledgeSessionRecord> sessions;
  final List<String> corruptedSessionIds;
}

/// Local JSON persistence for Knowledge Curation Sessions (Work
/// Package 008 STUDIO-TASK-000015: "Sessions shall survive application
/// restart. Storage format shall be human-readable. JSON is
/// recommended. Persistence is local to Studio. Foundation shall
/// remain unaware of Knowledge Sessions.").
///
/// One directory per session under
/// `%APPDATA%/oep_studio/knowledge_sessions/<sessionId>/`, holding
/// `session.json` and a `sources/` subdirectory of copied Source
/// Material files — see `docs/KNOWLEDGE_SESSION_FORMAT.md` for the
/// full format. Uses `dart:io`/`Platform.environment` directly rather
/// than adding the `path_provider` package: this is already a
/// Windows-only desktop target (`file_selector` is used the same way),
/// and `path_provider`'s cross-platform channel code would be dead
/// weight here — consistent with this project's minimal-dependency
/// philosophy (`CLAUDE.md` in `oep_foundation`: "Before introducing any
/// dependency ask: Does the platform genuinely benefit?").
///
/// All I/O errors are translated to [KnowledgeValidationException] with
/// a professional message — never a raw [IOException] or stack trace
/// reaching the UI (Work Package 008 Error Handling: "No native
/// implementation details").
abstract final class KnowledgeSessionStorage {
  static Directory root() {
    final base =
        Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}oep_studio${Platform.pathSeparator}knowledge_sessions');
  }

  static Directory sessionDirectory(String sessionId) =>
      Directory('${root().path}${Platform.pathSeparator}$sessionId');

  static File _sessionFile(String sessionId) =>
      File('${sessionDirectory(sessionId).path}${Platform.pathSeparator}session.json');

  /// Where a session's copied Source Material files live (Work Package
  /// 008 STUDIO-TASK-000016).
  static Directory sourcesDirectory(String sessionId) =>
      Directory('${sessionDirectory(sessionId).path}${Platform.pathSeparator}sources');

  /// Writes `session.json`, creating the session's directory if
  /// needed. Called automatically after every mutation to the active
  /// session (see `FoundationRuntimeNotifier`'s autosave) — there is no
  /// separate explicit "Save" action to forget to click.
  ///
  /// INGEST-FOLLOWUP-006: writes for one session are serialized through a
  /// per-session queue, so fire-and-forget autosaves can never overlap on
  /// `session.json`. The record is encoded synchronously at call time
  /// (snapshot-at-request), each write runs strictly in request order, and
  /// the returned future completes or fails with its own write's result; a
  /// failed write does not stop later queued writes. Different sessions
  /// use different queues and never block each other.
  static Future<void> save(KnowledgeSessionRecord record) async {
    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(record.toJson());
    final sessionId = record.session.id;
    try {
      await _enqueue(sessionId, () => (_writer ?? _defaultWriter)(sessionId, json));
    } on IOException catch (error) {
      throw KnowledgeValidationException('Couldn\'t save session "${record.session.name}": ${error.toString()}');
    }
  }

  static final Map<String, Future<void>> _writeTails = {};

  static Future<void> _enqueue(String sessionId, Future<void> Function() operation) {
    final previous = _writeTails[sessionId] ?? Future<void>.value();
    final run = previous.then((_) => operation());
    final tail = run.then<void>((_) {}, onError: (Object _) {});
    _writeTails[sessionId] = tail;
    tail.whenComplete(() {
      if (identical(_writeTails[sessionId], tail)) _writeTails.remove(sessionId);
    });
    return run;
  }

  static Future<void> _defaultWriter(String sessionId, String json) async {
    await sessionDirectory(sessionId).create(recursive: true);
    await _sessionFile(sessionId).writeAsString(json);
  }

  static Future<void> Function(String sessionId, String json)? _writer;

  /// Test seam: replaces the physical write (pass `null` to restore).
  @visibleForTesting
  static void debugSetWriter(Future<void> Function(String sessionId, String json)? writer) => _writer = writer;

  /// Test seam: completes when every write queued so far has finished.
  @visibleForTesting
  static Future<void> flushPendingForTest() => Future.wait(List.of(_writeTails.values));

  /// Loads one session by ID. Throws [KnowledgeValidationException] —
  /// translated from either a missing file, a JSON/structural parse
  /// failure ("Corrupted session files"), or a failure to persist a
  /// reconciled interrupted run back to disk (see below).
  ///
  /// INGEST-FOLLOWUP-005 § durable reconciliation: when this load
  /// discovers a QUEUED/RUNNING run left behind by a previous process
  /// that never reached a terminal status (see [_reconcileInterruptedRuns]),
  /// the reconciled FAILED record is written back to `session.json`
  /// before returning -- not just handed back in memory -- via [save]
  /// itself (which never calls [load], so this can never recurse). That
  /// makes reconciliation a one-time event per interrupted run: the next
  /// [load] finds the run already FAILED on disk, `_reconcileInterruptedRuns`
  /// short-circuits (every run already terminal), and neither the
  /// diagnostic nor `completedAt` are touched again -- `completedAt` is
  /// therefore stable across every subsequent reload, generated exactly
  /// once at first reconciliation.
  static Future<KnowledgeSessionRecord> load(String sessionId) async {
    final file = _sessionFile(sessionId);
    if (!file.existsSync()) {
      throw const KnowledgeValidationException('That session could not be found.');
    }
    final String contents;
    try {
      contents = await file.readAsString();
    } on IOException catch (error) {
      throw KnowledgeValidationException('Couldn\'t read session file: ${error.toString()}');
    }
    final KnowledgeSessionRecord parsed;
    try {
      final json = jsonDecode(contents) as Map<String, dynamic>;
      parsed = KnowledgeSessionRecord.fromJson(json);
    } on FormatException catch (error) {
      throw KnowledgeValidationException(
        'This session file is corrupted and could not be loaded (${error.message}).',
      );
    } on TypeError {
      throw const KnowledgeValidationException('This session file is corrupted and could not be loaded.');
    }
    // Decided before reconciliation runs: whether there is anything to
    // reconcile at all, so an ordinary already-terminal session (the
    // overwhelming common case) never triggers a redundant write.
    final hasInterruptedRun = parsed.ingestionRuns.any((run) => !run.status.isTerminal);
    if (!hasInterruptedRun) return parsed;
    final reconciled = _reconcileInterruptedRuns(parsed);
    await save(reconciled);
    return reconciled;
  }

  /// Lists every persisted session for the Session Browser (Work
  /// Package 008 Session Browser). Corrupted sessions are reported
  /// separately rather than dropped silently or blocking the listing.
  static Future<SessionBrowserListing> listAll() async {
    final directory = root();
    if (!directory.existsSync()) {
      return const SessionBrowserListing(sessions: [], corruptedSessionIds: []);
    }
    final sessions = <KnowledgeSessionRecord>[];
    final corrupted = <String>[];
    for (final entry in directory.listSync()) {
      if (entry is! Directory) continue;
      final sessionId = entry.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      try {
        sessions.add(await load(sessionId));
      } on KnowledgeValidationException {
        corrupted.add(sessionId);
      }
    }
    sessions.sort((a, b) => b.session.lastModified.compareTo(a.session.lastModified));
    return SessionBrowserListing(sessions: sessions, corruptedSessionIds: corrupted);
  }

  /// Permanently removes a session and its Source Material files (Work
  /// Package 008 Session Browser: "Delete ... Deletion shall require
  /// confirmation" — the confirmation itself is a UI concern; this
  /// method performs the deletion unconditionally once called).
  static Future<void> delete(String sessionId) async {
    final directory = sessionDirectory(sessionId);
    if (!directory.existsSync() && !_writeTails.containsKey(sessionId)) return;
    try {
      // Queued behind pending saves so a late save cannot resurrect it.
      await _enqueue(sessionId, () async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
    } on IOException catch (error) {
      throw KnowledgeValidationException('Couldn\'t delete session: ${error.toString()}');
    }
  }

  /// Copies [sourceSessionId]'s Source Material files into
  /// [newRecord]'s session directory (whose `sources` entries must
  /// already reference paths under the *new* session's
  /// [sourcesDirectory] — see `KnowledgeSessionService.buildDuplicate`)
  /// and saves it. Used by Work Package 008 Session Browser's
  /// "Duplicate" action, so a duplicated session is fully independent
  /// of the original (editing or deleting one never affects the
  /// other's files).
  static Future<void> duplicateSourceFiles(String sourceSessionId, KnowledgeSessionRecord newRecord) async {
    final sourceDir = sourcesDirectory(sourceSessionId);
    if (!sourceDir.existsSync()) return;
    final targetDir = sourcesDirectory(newRecord.session.id);
    await targetDir.create(recursive: true);
    for (final entry in sourceDir.listSync()) {
      if (entry is! File) continue;
      final fileName = entry.uri.pathSegments.last;
      try {
        await entry.copy('${targetDir.path}${Platform.pathSeparator}$fileName');
      } on IOException catch (error) {
        throw KnowledgeValidationException('Couldn\'t duplicate source file "$fileName": ${error.toString()}');
      }
    }
  }
}
