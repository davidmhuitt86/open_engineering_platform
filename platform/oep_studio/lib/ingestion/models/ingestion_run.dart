import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'ingestion_run_status.dart';
import 'stage_result.dart';

/// One processing attempt against one immutable Vault Object
/// (AP-INGEST-001 § 6, WP-INGEST-001 § 6.2).
class IngestionRun {
  const IngestionRun({
    required this.runId,
    required this.vaultObjectId,
    required this.contentHash,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.pipelineVersion,
    required this.parserId,
    required this.parserVersion,
    required this.processorVersions,
    required this.processingConfiguration,
    required this.stageResults,
    this.diagnostics = const [],
  });

  final String runId;
  final String vaultObjectId;

  /// The `VaultObjectInput.contentHash` this run processed
  /// (AP-INGEST-001 § 22 / WP-INGEST-006 § 5's processing-identity tuple:
  /// "Vault Object identity + content/version identity"). Populated from
  /// the same SHA-256 hex digest `VaultObjectInput.fromFile` already
  /// computes — not a second, independent hash of anything.
  final String contentHash;

  final DateTime startedAt;
  final DateTime? completedAt;
  final IngestionRunStatus status;

  /// Identifies this build of the UIF pipeline itself (AP-INGEST-001
  /// § 22 Idempotency and Processing Identity) — independent of
  /// [parserVersion]/[processorVersions], which identify the individual
  /// stage implementations invoked.
  final String pipelineVersion;

  final String parserId;
  final String parserVersion;

  /// Which version of each reused processor (OCR engine, entity
  /// extraction pattern library, ...) this run invoked — e.g.
  /// `{'ocr': 'Tesseract 5.4.0.20240606', 'entityExtraction': 'engineering_pattern_library-1'}`.
  final Map<String, String> processorVersions;

  /// The processing configuration in effect for this run (e.g. OCR render
  /// DPI) — part of AP-INGEST-001 § 22's processing-identity tuple.
  final Map<String, dynamic> processingConfiguration;

  final List<StageResult> stageResults;

  /// Run-level diagnostics (WP-INGEST-007 § 14) -- distinct from
  /// [StageResult.diagnostics], which are always about a *specific*
  /// stage. Empty for an ordinary run. Populated with
  /// [interruptionDiagnostic] only when [reconciledIfInterrupted] finds
  /// this run persisted as non-terminal (QUEUED/RUNNING) with no live
  /// execution behind it -- never touched by normal stage execution.
  /// Deliberately excluded from [processingIdentity]'s constituent
  /// inputs, for the same reason [runId]/[startedAt]/[completedAt]/
  /// [status] are: it is outcome/execution metadata, not part of the
  /// processing definition.
  final List<String> diagnostics;

  /// The exact diagnostic [reconciledIfInterrupted] records
  /// (WP-INGEST-007 § 14: "Exact wording may vary. The important
  /// requirement is that the diagnostic clearly identifies interruption
  /// rather than ordinary stage failure.").
  static const String interruptionDiagnostic = 'Execution interrupted before completion.';

  /// Returns a new [IngestionRun] with every field identical except
  /// those explicitly overridden -- the smallest general-purpose way to
  /// produce an updated snapshot of an in-progress run without
  /// reconstructing every field at every call site. [transitionTo] is
  /// the status-validated entry point built on top of this; call this
  /// directly only to update non-status fields (e.g. enriching a QUEUED/
  /// RUNNING run with the parser it selected) while remaining in the
  /// same status.
  IngestionRun copyWith({
    DateTime? completedAt,
    IngestionRunStatus? status,
    String? parserId,
    String? parserVersion,
    Map<String, String>? processorVersions,
    Map<String, dynamic>? processingConfiguration,
    List<StageResult>? stageResults,
    List<String>? diagnostics,
  }) => IngestionRun(
    runId: runId,
    vaultObjectId: vaultObjectId,
    contentHash: contentHash,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    status: status ?? this.status,
    pipelineVersion: pipelineVersion,
    parserId: parserId ?? this.parserId,
    parserVersion: parserVersion ?? this.parserVersion,
    processorVersions: processorVersions ?? this.processorVersions,
    processingConfiguration: processingConfiguration ?? this.processingConfiguration,
    stageResults: stageResults ?? this.stageResults,
    diagnostics: diagnostics ?? this.diagnostics,
  );

  /// Validates and applies a lifecycle transition (WP-INGEST-007 § 6/
  /// § 7) -- the smallest transition-validation mechanism this work
  /// package authorizes, built directly on
  /// [IngestionRunStatus.canTransitionTo]. Throws [StateError] for any
  /// transition that status forbids (in particular, every terminal
  /// status forbids every transition -- TEST-007-016).
  IngestionRun transitionTo(
    IngestionRunStatus next, {
    DateTime? completedAt,
    List<StageResult>? stageResults,
    List<String>? diagnostics,
  }) {
    if (!status.canTransitionTo(next)) {
      throw StateError('Illegal ingestion run lifecycle transition: ${status.name} -> ${next.name} (runId=$runId).');
    }
    return copyWith(status: next, completedAt: completedAt, stageResults: stageResults, diagnostics: diagnostics);
  }

  /// Reconciles a persisted run that is still non-terminal (QUEUED or
  /// RUNNING) with no live execution behind it -- exactly what
  /// `KnowledgeSessionStorage.load` finds after the application
  /// terminated mid-ingestion (WP-INGEST-007 § 14/§ 17). Returns `this`
  /// unchanged for an already-terminal run (idempotent -- safe to call
  /// on every run on every load).
  ///
  /// Never resumes, reruns, or clones the run (§ 15); never fabricates a
  /// successful completion (§ 17) -- the resulting run is FAILED, with
  /// [interruptionDiagnostic] appended, and [completedAt] set only if it
  /// was not already set (an interrupted run never had a real
  /// completion time recorded, so this is not fabricating one -- it is
  /// recording when the interruption was *discovered*, distinguishable
  /// from an ordinary completion time by [diagnostics] alone).
  IngestionRun reconciledIfInterrupted() {
    if (status.isTerminal) return this;
    return transitionTo(
      IngestionRunStatus.failed,
      completedAt: completedAt ?? DateTime.now(),
      diagnostics: [...diagnostics, interruptionDiagnostic],
    );
  }

  /// A deterministic, reproducible identity of the *processing definition
  /// + input combination* this run represents (AP-INGEST-001 § 22,
  /// WP-INGEST-006 § 5) — a SHA-256 hex digest of a canonical, structured
  /// JSON representation of [vaultObjectId], [contentHash],
  /// [pipelineVersion], [parserId], [parserVersion], [processorVersions],
  /// and [processingConfiguration], each represented as its own properly
  /// JSON-encoded field (not concatenated into a delimited string), so a
  /// delimiter character occurring inside one field's value can never be
  /// confused with a field boundary. Map keys (at every nesting level,
  /// including nested [processingConfiguration] maps) are sorted for
  /// determinism regardless of Dart `Map` insertion order; list elements
  /// keep their original, semantically significant order.
  ///
  /// Deliberately excludes [runId], [startedAt]/[completedAt], and
  /// [status]: WP-INGEST-006 § 5/§ 15 requires the identity be
  /// "independent of timestamps... random session IDs... random UUIDs",
  /// and two runs against identical evidence with an identical processing
  /// definition must produce the same identity regardless of which
  /// generated `runId` or wall-clock time they happened to run under —
  /// this establishes the identity itself; it does not implement
  /// deduplication (WP-INGEST-006 § 6).
  String get processingIdentity {
    final structured = <String, dynamic>{
      'vaultObjectId': vaultObjectId,
      'contentHash': contentHash,
      'pipelineVersion': pipelineVersion,
      'parserId': parserId,
      'parserVersion': parserVersion,
      'processorVersions': processorVersions,
      'processingConfiguration': processingConfiguration,
    };
    final canonical = _canonicalJson(structured);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Produces a stable, structurally unambiguous JSON string
  /// representation of [value]: `Map` keys (at every nesting level) are
  /// sorted regardless of original insertion order, so semantically
  /// identical maps always canonicalize identically; `List` elements keep
  /// their original order, since list order is semantically significant
  /// (e.g. a processing-configuration list) and must not be normalized
  /// away; scalars are encoded with [jsonEncode], which preserves their
  /// JSON type (a string and a structurally-similar number never collide).
  static String _canonicalJson(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      final entries = keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',');
      return '{$entries}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'vaultObjectId': vaultObjectId,
    'contentHash': contentHash,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.name,
    'pipelineVersion': pipelineVersion,
    'parserId': parserId,
    'parserVersion': parserVersion,
    'processorVersions': processorVersions,
    'processingConfiguration': processingConfiguration,
    'stageResults': stageResults.map((result) => result.toJson()).toList(),
    'diagnostics': diagnostics,
  };

  /// Throws [FormatException]/[TypeError] on structurally invalid input —
  /// callers (`KnowledgeSessionRecord.fromJson` via
  /// `KnowledgeSessionStorage.load`) translate that into the existing
  /// "Corrupted session files" handling, exactly like every other model
  /// this record round-trips.
  factory IngestionRun.fromJson(Map<String, dynamic> json) => IngestionRun(
    runId: json['runId'] as String,
    vaultObjectId: json['vaultObjectId'] as String,
    // Falls back to '' for session files written before WP-INGEST-006
    // added this field, rather than throwing on an otherwise-valid older
    // session file.
    contentHash: json['contentHash'] as String? ?? '',
    startedAt: DateTime.parse(json['startedAt'] as String),
    completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
    status: IngestionRunStatus.values.byName(json['status'] as String),
    pipelineVersion: json['pipelineVersion'] as String,
    parserId: json['parserId'] as String,
    parserVersion: json['parserVersion'] as String,
    processorVersions: Map<String, String>.from(json['processorVersions'] as Map? ?? const {}),
    processingConfiguration: Map<String, dynamic>.from(json['processingConfiguration'] as Map? ?? const {}),
    stageResults: [
      for (final entry in (json['stageResults'] as List? ?? const []))
        StageResult.fromJson(entry as Map<String, dynamic>),
    ],
    // Falls back to [] for session files written before WP-INGEST-007
    // added this field, exactly like the [contentHash] fallback above.
    diagnostics: List<String>.from(json['diagnostics'] as List? ?? const []),
  );
}
