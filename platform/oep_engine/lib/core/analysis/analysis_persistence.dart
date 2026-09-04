import 'dart:convert';
import 'dart:io';

import '../knowledge/knowledge_runtime.dart';
import 'models/analysis_result.dart';

/// Persists [AnalysisResult] evidence independently from
/// `DiagramDocument`/`DiagramWorkspaceState`/`DiagramTabsStorage`/
/// `DiagramStudioSettings` (AP-EK-020 §26, §40). Saving/reloading an
/// analysis never touches diagram engineering data — this store only
/// ever reads/writes its own file.
///
/// Follows the same plain `File.writeAsString(jsonEncode(...))` /
/// `readAsString()` + `jsonDecode` idiom `DiagramDocument` already uses
/// (`platform/oep_studio/lib/diagram_studio/host/diagram_document.dart`)
/// — no new persistence abstraction is introduced.
///
/// One JSON file per `documentId`, holding every analysis ever run
/// against that document (§26 "Document → Analysis History → Analysis
/// A/B/C"). Each entry keeps its own identity; nothing is ever mutated
/// or overwritten in place — `save` always appends.
class AnalysisPersistenceStore {
  final Directory root;

  const AnalysisPersistenceStore(this.root);

  File _fileFor(String documentId) => File(
    '${root.path}${Platform.pathSeparator}$documentId.analysis-history.json',
  );

  Future<void> save(AnalysisResult result) async {
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    final file = _fileFor(result.documentId);
    final history = await _readHistory(file);
    // AnalysisResult is immutable evidence: overwriting an entry with
    // the same analysisId is intentionally impossible via this API —
    // only appending a new entry is supported (§27 "must not mutate
    // Analysis A into Analysis B").
    if (history.any((r) => r['analysisId'] == result.analysisId)) {
      throw StateError(
        'Analysis "${result.analysisId}" has already been persisted; analyses are immutable.',
      );
    }
    history.add(result.toJson());
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'documentId': result.documentId, 'analyses': history}),
    );
  }

  Future<List<Map<String, Object?>>> _readHistory(File file) async {
    if (!file.existsSync()) return [];
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return (decoded['analyses'] as List)
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList();
  }

  /// All analyses ever recorded for [documentId], oldest first —
  /// includes analyses now stale for the document's current version;
  /// callers decide currency via `documentVersion` comparison
  /// (AP-EK-020 §27), this store never deletes or reclassifies history.
  Future<List<AnalysisResult>> history(
    String documentId, {
    KnowledgeRuntime? runtime,
  }) async {
    final entries = await _readHistory(_fileFor(documentId));
    return entries
        .map((e) => AnalysisResult.fromJson(e, runtime: runtime))
        .toList();
  }

  Future<AnalysisResult?> byId(
    String documentId,
    String analysisId, {
    KnowledgeRuntime? runtime,
  }) async {
    final all = await history(documentId, runtime: runtime);
    for (final result in all) {
      if (result.analysisId == analysisId) return result;
    }
    return null;
  }

  /// The most recently-saved analysis whose `documentVersion` matches
  /// [documentVersion] — i.e. the current, non-stale analysis, if one
  /// exists (AP-EK-020 §27).
  Future<AnalysisResult?> current(
    String documentId,
    String documentVersion, {
    KnowledgeRuntime? runtime,
  }) async {
    final all = await history(documentId, runtime: runtime);
    for (final result in all.reversed) {
      if (result.documentVersion == documentVersion) return result;
    }
    return null;
  }
}
