import 'dart:convert';
import 'dart:io';

import '../models/knowledge_session_record.dart';
import '../models/knowledge_validation_exception.dart';

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
  static Future<void> save(KnowledgeSessionRecord record) async {
    try {
      await sessionDirectory(record.session.id).create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await _sessionFile(record.session.id).writeAsString(encoder.convert(record.toJson()));
    } on IOException catch (error) {
      throw KnowledgeValidationException('Couldn\'t save session "${record.session.name}": ${error.toString()}');
    }
  }

  /// Loads one session by ID. Throws [KnowledgeValidationException] —
  /// translated from either a missing file or a JSON/structural parse
  /// failure — for "Corrupted session files".
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
    try {
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return KnowledgeSessionRecord.fromJson(json);
    } on FormatException catch (error) {
      throw KnowledgeValidationException(
        'This session file is corrupted and could not be loaded (${error.message}).',
      );
    } on TypeError {
      throw const KnowledgeValidationException('This session file is corrupted and could not be loaded.');
    }
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
    if (!directory.existsSync()) return;
    try {
      await directory.delete(recursive: true);
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
