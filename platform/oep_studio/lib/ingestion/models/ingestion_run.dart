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

  /// A deterministic, reproducible identity of the *processing definition
  /// + input combination* this run represents (AP-INGEST-001 § 22,
  /// WP-INGEST-006 § 5) — a SHA-256 hex digest of [vaultObjectId],
  /// [contentHash], [pipelineVersion], [parserId]/[parserVersion], and a
  /// canonical (sorted-key) serialization of [processorVersions] and
  /// [processingConfiguration].
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
    final canonical = <String>[
      vaultObjectId,
      contentHash,
      pipelineVersion,
      parserId,
      parserVersion,
      _canonicalStringMap(processorVersions),
      _canonicalJson(processingConfiguration),
    ].join('|');
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static String _canonicalStringMap(Map<String, String> map) {
    final keys = map.keys.toList()..sort();
    return keys.map((key) => '$key=${map[key]}').join(',');
  }

  /// Produces a stable string representation of [value] regardless of a
  /// `Map`'s original key insertion order, so semantically identical
  /// processing configurations always canonicalize identically.
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
  );
}
