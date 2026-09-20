import 'dart:convert';

import '../interpretation/reference_context.dart';
import 'reference_usage.dart';

/// WP-INGEST-013: the durable audit record of ONE attempt to interpret
/// engineering evidence.
///
/// ```text
/// Evidence -> DiagramInterpretationReferenceContext -> InferenceRecord
///          -> Human Review -> Candidate -> explicit Repository commit
/// ```
///
/// An [InferenceRecord] is **not** an Engineering Object, node, relationship,
/// Repository truth, a commit, a `KnowledgeCandidate`, a Reference Library or
/// a `ReferenceUsage` (a future, separate boundary). A hypothesis it holds is a
/// *proposal*; even `HypothesisStatus.accepted` means "accepted as an inference
/// review outcome", never "accepted engineering truth". Nothing here creates
/// or promotes anything.
///
/// It reuses existing identities (`SourceMaterial.id`, the OCR
/// `sourceFingerprint`, `EvidenceRegion.id`, `EvidenceLink.id`, candidate ids,
/// Reference object ids) by reference; it copies no evidence and no Reference
/// Knowledge.

/// A programmatic violation of an [InferenceRecord] invariant (illegal
/// lifecycle transition, duplicate ids, ...). Malformed *persisted* data
/// surfaces as a [FormatException] instead, matching how
/// `KnowledgeSessionStorage.load` already reports corrupted sessions.
class InferenceRecordException implements Exception {
  final String message;
  const InferenceRecordException(this.message);

  @override
  String toString() => 'InferenceRecordException: $message';
}

/// Mirrors `IngestionRunStatus` (same members and transitions) so inference
/// and ingestion runs share one lifecycle vocabulary without coupling the
/// two types.
enum InferenceRecordStatus {
  queued,
  running,
  completed,
  partial,
  failed,
  cancelled;

  bool get isTerminal =>
      this == completed ||
      this == partial ||
      this == failed ||
      this == cancelled;

  bool canTransitionTo(InferenceRecordStatus next) {
    switch (this) {
      case queued:
        return next == running || next == failed || next == cancelled;
      case running:
        return next == completed ||
            next == partial ||
            next == failed ||
            next == cancelled;
      case completed:
      case partial:
      case failed:
      case cancelled:
        return false;
    }
  }
}

/// A hypothesis's review state *within the inference record*. `accepted` is
/// not engineering truth; a decision is final (a change of mind is a new
/// hypothesis or a new record).
enum HypothesisStatus { proposed, accepted, rejected }

/// Which adapter/model produced the record. Vendor-neutral: only [adapterId]
/// is required. No API, secret or configuration lives here.
class InferenceAdapterProvenance {
  final String adapterId;
  final String? provider;
  final String? modelName;
  final String? modelVersion;

  /// Instruction/prompt version, where applicable.
  final String? promptVersion;

  /// Version of the output schema the adapter was asked to produce.
  final String? outputSchemaVersion;

  const InferenceAdapterProvenance({
    required this.adapterId,
    this.provider,
    this.modelName,
    this.modelVersion,
    this.promptVersion,
    this.outputSchemaVersion,
  });

  Map<String, Object?> toJson() => {
        'adapterId': adapterId,
        'provider': provider,
        'modelName': modelName,
        'modelVersion': modelVersion,
        'promptVersion': promptVersion,
        'outputSchemaVersion': outputSchemaVersion,
      };

  factory InferenceAdapterProvenance.fromJson(Map<String, dynamic> json) =>
      InferenceAdapterProvenance(
        adapterId: _requiredString(json, 'adapterId'),
        provider: json['provider'] as String?,
        modelName: json['modelName'] as String?,
        modelVersion: json['modelVersion'] as String?,
        promptVersion: json['promptVersion'] as String?,
        outputSchemaVersion: json['outputSchemaVersion'] as String?,
      );
}

/// The source the inference consumed: existing canonical identity only.
class InferenceSourceIdentity {
  /// `SourceMaterial.id`.
  final String sourceMaterialId;

  /// The existing canonical content identity (`OcrPageResult.sourceFingerprint`);
  /// `null` when the source had none. No second hash is introduced.
  final String? sourceFingerprint;

  /// Page scope (1-based), sorted and unique; empty = the whole source.
  final List<int> pages;

  InferenceSourceIdentity({
    required this.sourceMaterialId,
    this.sourceFingerprint,
    Iterable<int> pages = const [],
  }) : pages = List.unmodifiable(({...pages}.toList()..sort()));

  Map<String, Object?> toJson() => {
        'sourceMaterialId': sourceMaterialId,
        'sourceFingerprint': sourceFingerprint,
        'pages': pages,
      };

  factory InferenceSourceIdentity.fromJson(Map<String, dynamic> json) =>
      InferenceSourceIdentity(
        sourceMaterialId: _requiredString(json, 'sourceMaterialId'),
        sourceFingerprint: json['sourceFingerprint'] as String?,
        pages: [for (final p in (json['pages'] as List? ?? const [])) p as int],
      );
}

/// The exact Reference Context consumed: its deterministic digest
/// (`DiagramInterpretationReferenceContext.digest`) plus the Reference
/// package/runtime identity that supplied it (`null` for an evidence-only
/// context). Source identity and Reference identity stay separate. The
/// context itself is not stored here.
class InferenceReferenceContextIdentity {
  final String contextDigest;
  final ReferenceContextIdentity? reference;

  const InferenceReferenceContextIdentity({
    required this.contextDigest,
    this.reference,
  });

  factory InferenceReferenceContextIdentity.of(
    DiagramInterpretationReferenceContext context,
  ) =>
      InferenceReferenceContextIdentity(
        contextDigest: context.digest,
        reference: context.reference,
      );

  Map<String, Object?> toJson() => {
        'contextDigest': contextDigest,
        'reference': reference?.toJson(),
      };

  factory InferenceReferenceContextIdentity.fromJson(
          Map<String, dynamic> json) =>
      InferenceReferenceContextIdentity(
        contextDigest: _requiredString(json, 'contextDigest'),
        reference: json['reference'] == null
            ? null
            : ReferenceContextIdentity.fromJson(
                json['reference'] as Map<String, dynamic>),
      );
}

enum InferenceEvidenceType {
  evidenceRegion,
  evidenceLink,
  ocrPage,
  knowledgeCandidate,
}

/// A pointer to existing evidence by its stable identity. For [ocrPage] the
/// [id] is the `SourceMaterial.id` and [page] is required (an OCR page's
/// identity is `(sourceId, page)`); for the others [id] is the model's own id
/// and [page] is optional context.
class InferenceEvidenceReference {
  final InferenceEvidenceType type;
  final String id;
  final int? page;

  const InferenceEvidenceReference(
      {required this.type, required this.id, this.page});

  Map<String, Object?> toJson() => {'type': type.name, 'id': id, 'page': page};

  factory InferenceEvidenceReference.fromJson(Map<String, dynamic> json) {
    final type = _enumByName(
        InferenceEvidenceType.values, json['type'], 'evidence type');
    final ref = InferenceEvidenceReference(
      type: type,
      id: _requiredString(json, 'id'),
      page: json['page'] as int?,
    );
    if (type == InferenceEvidenceType.ocrPage && ref.page == null) {
      throw const FormatException(
          'An ocrPage evidence reference requires a page.');
    }
    return ref;
  }
}

/// A confidence value *as supplied by the inference provider*. It is not a
/// calibrated probability unless [calibrated] is explicitly true, and it is
/// never invented for deterministic facts (OCR, regions, retrieval scores,
/// human annotations).
class InferenceConfidence {
  final double value;

  /// Where the value came from, e.g. "provider-reported".
  final String? basis;

  /// `true` only when the source explicitly establishes calibration.
  final bool calibrated;

  const InferenceConfidence(
      {required this.value, this.basis, this.calibrated = false});

  Map<String, Object?> toJson() =>
      {'value': value, 'basis': basis, 'calibrated': calibrated};

  factory InferenceConfidence.fromJson(Map<String, dynamic> json) {
    final value = (json['value'] as num).toDouble();
    if (!value.isFinite) {
      throw const FormatException('Confidence value must be finite.');
    }
    return InferenceConfidence(
      value: value,
      basis: json['basis'] as String?,
      calibrated: json['calibrated'] as bool? ?? false,
    );
  }
}

/// One proposed interpretation of some evidence. Rejected alternatives are
/// retained, never discarded.
class InferenceHypothesis {
  final String hypothesisId;

  /// What kind of thing is proposed (free-form category, e.g. `component`,
  /// `symbol`, `relationship`, `terminal`); not an Engineering Object type.
  final String category;

  /// The proposed value/interpretation (e.g. `resistor`).
  final String proposedValue;
  final String? label;
  final HypothesisStatus status;

  /// Why the status is what it is (e.g. a rejection reason), when known.
  final String? statusReason;

  /// The evidence this proposal rests on, in the provider's order.
  final List<InferenceEvidenceReference> evidence;

  /// Reference object ids (from the consumed Reference Context) this proposal
  /// relates to. Plain ids; the future `ReferenceUsage` boundary will attach
  /// richer usage records to the record, not to this list.
  final List<String> referenceObjectIds;
  final InferenceConfidence? confidence;
  final String? rationale;

  InferenceHypothesis({
    required this.hypothesisId,
    required this.category,
    required this.proposedValue,
    this.label,
    this.status = HypothesisStatus.proposed,
    this.statusReason,
    List<InferenceEvidenceReference> evidence = const [],
    List<String> referenceObjectIds = const [],
    this.confidence,
    this.rationale,
  })  : evidence = List.unmodifiable(evidence),
        referenceObjectIds = List.unmodifiable(referenceObjectIds) {
    if (hypothesisId.isEmpty || category.isEmpty || proposedValue.isEmpty) {
      throw const InferenceRecordException(
        'A hypothesis needs a hypothesisId, category and proposedValue.',
      );
    }
  }

  /// Records a review decision. Only a `proposed` hypothesis can be decided,
  /// and only to `accepted` or `rejected`.
  InferenceHypothesis decided(HypothesisStatus decision, {String? reason}) {
    if (status != HypothesisStatus.proposed) {
      throw InferenceRecordException(
        'Hypothesis "$hypothesisId" is already ${status.name}; a decision is final.',
      );
    }
    if (decision == HypothesisStatus.proposed) {
      throw const InferenceRecordException(
          'A decision must be accepted or rejected.');
    }
    return InferenceHypothesis(
      hypothesisId: hypothesisId,
      category: category,
      proposedValue: proposedValue,
      label: label,
      status: decision,
      statusReason: reason,
      evidence: evidence,
      referenceObjectIds: referenceObjectIds,
      confidence: confidence,
      rationale: rationale,
    );
  }

  Map<String, Object?> toJson() => {
        'hypothesisId': hypothesisId,
        'category': category,
        'proposedValue': proposedValue,
        'label': label,
        'status': status.name,
        'statusReason': statusReason,
        'evidence': [for (final e in evidence) e.toJson()],
        'referenceObjectIds': referenceObjectIds,
        'confidence': confidence?.toJson(),
        'rationale': rationale,
      };

  factory InferenceHypothesis.fromJson(Map<String, dynamic> json) =>
      InferenceHypothesis(
        hypothesisId: _requiredString(json, 'hypothesisId'),
        category: _requiredString(json, 'category'),
        proposedValue: _requiredString(json, 'proposedValue'),
        label: json['label'] as String?,
        status: _enumByName(
            HypothesisStatus.values, json['status'], 'hypothesis status'),
        statusReason: json['statusReason'] as String?,
        evidence: [
          for (final e in (json['evidence'] as List? ?? const []))
            InferenceEvidenceReference.fromJson(e as Map<String, dynamic>),
        ],
        referenceObjectIds: [
          for (final id in (json['referenceObjectIds'] as List? ?? const []))
            id as String,
        ],
        confidence: json['confidence'] == null
            ? null
            : InferenceConfidence.fromJson(
                json['confidence'] as Map<String, dynamic>),
        rationale: json['rationale'] as String?,
      );
}

/// A textual result statement that summarizes hypotheses (an interpretation
/// *statement*, distinct from the hypotheses themselves).
class InferenceStatement {
  final String statementId;
  final String text;
  final List<String> hypothesisIds;

  InferenceStatement({
    required this.statementId,
    required this.text,
    List<String> hypothesisIds = const [],
  }) : hypothesisIds = List.unmodifiable(hypothesisIds);

  Map<String, Object?> toJson() => {
        'statementId': statementId,
        'text': text,
        'hypothesisIds': hypothesisIds,
      };

  factory InferenceStatement.fromJson(Map<String, dynamic> json) =>
      InferenceStatement(
        statementId: _requiredString(json, 'statementId'),
        text: _requiredString(json, 'text'),
        hypothesisIds: [
          for (final id in (json['hypothesisIds'] as List? ?? const []))
            id as String
        ],
      );
}

/// A warning or error the adapter (or reconciliation) reported.
class InferenceDiagnostic {
  final String code;
  final String message;

  const InferenceDiagnostic({required this.code, required this.message});

  Map<String, Object?> toJson() => {'code': code, 'message': message};

  factory InferenceDiagnostic.fromJson(Map<String, dynamic> json) =>
      InferenceDiagnostic(
        code: _requiredString(json, 'code'),
        message: _requiredString(json, 'message'),
      );
}

/// The durable record. Immutable: every lifecycle step returns a new value.
class InferenceRecord {
  /// The only persisted `schemaVersion` this build understands.
  static const int currentSchemaVersion = 1;

  /// The diagnostic recorded when a persisted non-terminal record is found
  /// with no live execution behind it (the `IngestionRun` convention).
  static const String interruptionCode = 'interrupted';
  static const String interruptionMessage =
      'Inference interrupted before completion.';

  /// Unique per attempt (random-ish, caller-generated). Re-running against the
  /// same evidence and Reference Context creates a new record with a new id;
  /// this is not a processing identity.
  final String inferenceId;
  final int schemaVersion;
  final InferenceSourceIdentity source;
  final InferenceReferenceContextIdentity referenceContext;
  final InferenceAdapterProvenance adapter;
  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final InferenceRecordStatus status;

  /// Existing evidence the run consumed, in the order supplied.
  final List<InferenceEvidenceReference> evidenceUsed;

  /// Kept in the order produced. Rejected alternatives stay here.
  final List<InferenceHypothesis> hypotheses;
  final List<InferenceStatement> statements;

  /// WP-INGEST-014: which Reference Knowledge this inference actually USED
  /// (provenance; retrieved-but-unused context items have none). Empty in
  /// records saved before it existed.
  final List<ReferenceUsage> referenceUsage;
  final List<InferenceDiagnostic> warnings;
  final List<InferenceDiagnostic> errors;

  InferenceRecord({
    required this.inferenceId,
    this.schemaVersion = currentSchemaVersion,
    required this.source,
    required this.referenceContext,
    required this.adapter,
    required this.queuedAt,
    this.startedAt,
    this.completedAt,
    this.status = InferenceRecordStatus.queued,
    List<InferenceEvidenceReference> evidenceUsed = const [],
    List<InferenceHypothesis> hypotheses = const [],
    List<InferenceStatement> statements = const [],
    List<ReferenceUsage> referenceUsage = const [],
    List<InferenceDiagnostic> warnings = const [],
    List<InferenceDiagnostic> errors = const [],
  })  : evidenceUsed = List.unmodifiable(evidenceUsed),
        hypotheses = List.unmodifiable(hypotheses),
        statements = List.unmodifiable(statements),
        referenceUsage = List.unmodifiable(referenceUsage),
        warnings = List.unmodifiable(warnings),
        errors = List.unmodifiable(errors) {
    if (inferenceId.isEmpty) {
      throw const InferenceRecordException(
          'An inference record needs an inferenceId.');
    }
    if (source.sourceMaterialId.isEmpty ||
        referenceContext.contextDigest.isEmpty ||
        adapter.adapterId.isEmpty) {
      throw const InferenceRecordException(
        'Source id, reference-context digest and adapter id are required.',
      );
    }
    final ids = <String>{};
    for (final h in this.hypotheses) {
      if (!ids.add(h.hypothesisId)) {
        throw InferenceRecordException(
            'Duplicate hypothesisId "${h.hypothesisId}".');
      }
    }
    for (final s in this.statements) {
      for (final id in s.hypothesisIds) {
        if (!ids.contains(id)) {
          throw InferenceRecordException(
            'Statement "${s.statementId}" refers to unknown hypothesis "$id".',
          );
        }
      }
    }
    _validateReferenceUsage(
        ids, {for (final s in this.statements) s.statementId});
    if (status == InferenceRecordStatus.queued &&
        (startedAt != null || completedAt != null)) {
      throw const InferenceRecordException(
          'A queued record has no start or completion time.');
    }
    if (status.isTerminal && completedAt == null) {
      throw const InferenceRecordException(
          'A terminal record needs a completedAt.');
    }
    if (!status.isTerminal && completedAt != null) {
      throw const InferenceRecordException(
          'A non-terminal record cannot have a completedAt.');
    }
  }

  /// Internal consistency of [referenceUsage] with this record (no context is
  /// needed): each usage belongs to this inference and to this record's context
  /// digest and Reference package/runtime, its hypothesis/statement links exist,
  /// and no two usages are the same semantic usage (same reference, purpose,
  /// evidence, hypotheses and statements). Usages that differ in any of those
  /// are distinct on purpose (auditable attribution).
  void _validateReferenceUsage(
      Set<String> hypothesisIds, Set<String> statementIds) {
    final usageIds = <String>{};
    final semantic = <String>{};
    final expectedPackage = referenceContext.reference?.toJson();
    for (final u in referenceUsage) {
      if (!usageIds.add(u.usageId)) {
        throw InferenceRecordException('Duplicate usageId "${u.usageId}".');
      }
      if (u.inferenceId != inferenceId) {
        throw InferenceRecordException(
          'Usage "${u.usageId}" belongs to inference "${u.inferenceId}", not "$inferenceId".',
        );
      }
      if (u.contextDigest != referenceContext.contextDigest) {
        throw InferenceRecordException(
          'Usage "${u.usageId}" was made against a different Reference Context.',
        );
      }
      if (expectedPackage == null ||
          jsonEncode(u.package.toJson()) != jsonEncode(expectedPackage)) {
        throw InferenceRecordException(
          "Usage \"${u.usageId}\" does not match the record's Reference package/runtime identity.",
        );
      }
      for (final h in u.hypothesisIds) {
        if (!hypothesisIds.contains(h)) {
          throw InferenceRecordException(
              'Usage "${u.usageId}" refers to unknown hypothesis "$h".');
        }
      }
      for (final st in u.statementIds) {
        if (!statementIds.contains(st)) {
          throw InferenceRecordException(
              'Usage "${u.usageId}" refers to unknown statement "$st".');
        }
      }
      if (!semantic.add(u.semanticKey)) {
        throw InferenceRecordException(
          'Usage "${u.usageId}" duplicates an existing usage of "${u.referenceObjectId}" '
          'for the same purpose, evidence and hypotheses.',
        );
      }
    }
  }

  /// Verifies this record's usages against the actual Reference Context it
  /// consumed: same digest, and every usage points at an object that really is
  /// an item of that context (with the same retrieval query) and at evidence
  /// regions that exist in it. A dangling usage is rejected; externally
  /// supplied Reference usage is not supported.
  void requireReferenceUsageMatches(
      DiagramInterpretationReferenceContext context) {
    if (context.digest != referenceContext.contextDigest) {
      throw const InferenceRecordException(
        'The supplied context is not the Reference Context this record consumed.',
      );
    }
    final regionIds = {for (final r in context.evidenceRegions) r.id};
    for (final u in referenceUsage) {
      final inContext = context.items.any(
        (i) =>
            i.referenceObjectId == u.referenceObjectId &&
            (u.retrieval == null ||
                i.retrieval.queryIndex == u.retrieval!.queryIndex),
      );
      if (!inContext) {
        throw InferenceRecordException(
          'Usage "${u.usageId}" points at "${u.referenceObjectId}", which is not an item of the consumed context.',
        );
      }
      for (final id in u.evidenceRegionIds) {
        if (!regionIds.contains(id)) {
          throw InferenceRecordException(
            'Usage "${u.usageId}" names evidence region "$id" that is not in the context.',
          );
        }
      }
    }
  }

  InferenceRecord _copy({
    DateTime? startedAt,
    DateTime? completedAt,
    InferenceRecordStatus? status,
    List<InferenceEvidenceReference>? evidenceUsed,
    List<InferenceHypothesis>? hypotheses,
    List<InferenceStatement>? statements,
    List<ReferenceUsage>? referenceUsage,
    List<InferenceDiagnostic>? warnings,
    List<InferenceDiagnostic>? errors,
  }) =>
      InferenceRecord(
        inferenceId: inferenceId,
        schemaVersion: schemaVersion,
        source: source,
        referenceContext: referenceContext,
        adapter: adapter,
        queuedAt: queuedAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        status: status ?? this.status,
        evidenceUsed: evidenceUsed ?? this.evidenceUsed,
        hypotheses: hypotheses ?? this.hypotheses,
        statements: statements ?? this.statements,
        referenceUsage: referenceUsage ?? this.referenceUsage,
        warnings: warnings ?? this.warnings,
        errors: errors ?? this.errors,
      );

  InferenceRecord _transition(InferenceRecordStatus next) {
    if (!status.canTransitionTo(next)) {
      throw InferenceRecordException(
        'Illegal inference transition ${status.name} -> ${next.name}.',
      );
    }
    return this;
  }

  /// QUEUED -> RUNNING.
  InferenceRecord markRunning(DateTime at) {
    _transition(InferenceRecordStatus.running);
    return _copy(status: InferenceRecordStatus.running, startedAt: at);
  }

  /// RUNNING (or QUEUED for failed/cancelled) -> a terminal status. Whatever
  /// outputs are supplied are preserved for every terminal status: PARTIAL,
  /// FAILED and CANCELLED keep useful intermediate results. Omitted outputs
  /// keep their current value. No candidate or repository object is created.
  InferenceRecord finish(
    InferenceRecordStatus terminal,
    DateTime at, {
    List<InferenceEvidenceReference>? evidenceUsed,
    List<InferenceHypothesis>? hypotheses,
    List<InferenceStatement>? statements,
    List<ReferenceUsage>? referenceUsage,
    List<InferenceDiagnostic>? warnings,
    List<InferenceDiagnostic>? errors,
  }) {
    if (!terminal.isTerminal) {
      throw InferenceRecordException(
          '${terminal.name} is not a terminal status.');
    }
    _transition(terminal);
    return _copy(
      status: terminal,
      completedAt: at,
      evidenceUsed: evidenceUsed,
      hypotheses: hypotheses,
      statements: statements,
      referenceUsage: referenceUsage,
      warnings: warnings,
      errors: errors,
    );
  }

  /// Records a review decision on one hypothesis of a finished record. It
  /// changes only that hypothesis's status and reason.
  InferenceRecord withHypothesisDecision(
    String hypothesisId,
    HypothesisStatus decision, {
    String? reason,
  }) {
    if (!status.isTerminal) {
      throw InferenceRecordException(
        'Hypotheses can be decided only on a finished record (status is ${status.name}).',
      );
    }
    if (!hypotheses.any((h) => h.hypothesisId == hypothesisId)) {
      throw InferenceRecordException(
          'No hypothesis "$hypothesisId" in $inferenceId.');
    }
    return _copy(
      hypotheses: [
        for (final h in hypotheses)
          if (h.hypothesisId == hypothesisId)
            h.decided(decision, reason: reason)
          else
            h,
      ],
    );
  }

  /// A persisted non-terminal record has no live execution behind it: it
  /// becomes FAILED with an explicit interruption error (cancellation stays
  /// distinct and is never inferred). Terminal records are returned unchanged.
  InferenceRecord reconciledIfInterrupted(DateTime at) {
    if (status.isTerminal) return this;
    return _copy(
      status: InferenceRecordStatus.failed,
      completedAt: completedAt ?? at,
      errors: [
        ...errors,
        const InferenceDiagnostic(
            code: interruptionCode, message: interruptionMessage),
      ],
    );
  }

  /// Checks that [this] is a legitimate successor of [previous] (used before
  /// replacing a stored record): identity and provenance are immutable; a
  /// non-terminal record may stay or make a legal transition; a finished
  /// record may change only by deciding `proposed` hypotheses. Existing
  /// records are never silently rewritten.
  void requireValidSuccessorOf(InferenceRecord previous) {
    String enc(Object? o) => jsonEncode(o);
    if (inferenceId != previous.inferenceId ||
        enc(source.toJson()) != enc(previous.source.toJson()) ||
        enc(referenceContext.toJson()) !=
            enc(previous.referenceContext.toJson()) ||
        enc(adapter.toJson()) != enc(previous.adapter.toJson()) ||
        queuedAt != previous.queuedAt ||
        schemaVersion != previous.schemaVersion) {
      throw const InferenceRecordException(
        'Inference identity, source, context, adapter and queue time are immutable.',
      );
    }
    if (previous.status.isTerminal) {
      final sameOutputs = enc([for (final e in evidenceUsed) e.toJson()]) ==
              enc([for (final e in previous.evidenceUsed) e.toJson()]) &&
          enc([for (final s in statements) s.toJson()]) ==
              enc([for (final s in previous.statements) s.toJson()]) &&
          enc([for (final u in referenceUsage) u.toJson()]) ==
              enc([for (final u in previous.referenceUsage) u.toJson()]) &&
          enc([for (final w in warnings) w.toJson()]) ==
              enc([for (final w in previous.warnings) w.toJson()]) &&
          enc([for (final e in errors) e.toJson()]) ==
              enc([for (final e in previous.errors) e.toJson()]);
      if (status != previous.status ||
          completedAt != previous.completedAt ||
          startedAt != previous.startedAt ||
          !sameOutputs ||
          hypotheses.length != previous.hypotheses.length) {
        throw const InferenceRecordException(
          'A finished inference record may change only by deciding proposed hypotheses.',
        );
      }
      for (var i = 0; i < hypotheses.length; i++) {
        final was = previous.hypotheses[i];
        final now = hypotheses[i];
        if (enc(now.toJson()) == enc(was.toJson())) continue;
        if (was.status != HypothesisStatus.proposed ||
            enc(was.decided(now.status, reason: now.statusReason).toJson()) !=
                enc(now.toJson())) {
          throw InferenceRecordException(
            'Hypothesis "${was.hypothesisId}" changed other than by a first decision.',
          );
        }
      }
      return;
    }
    if (status != previous.status && !previous.status.canTransitionTo(status)) {
      throw InferenceRecordException(
        'Illegal inference transition ${previous.status.name} -> ${status.name}.',
      );
    }
  }

  Map<String, Object?> toJson() => {
        'inferenceId': inferenceId,
        'schemaVersion': schemaVersion,
        'source': source.toJson(),
        'referenceContext': referenceContext.toJson(),
        'adapter': adapter.toJson(),
        'queuedAt': queuedAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'status': status.name,
        'evidenceUsed': [for (final e in evidenceUsed) e.toJson()],
        'hypotheses': [for (final h in hypotheses) h.toJson()],
        'statements': [for (final s in statements) s.toJson()],
        'referenceUsage': [for (final u in referenceUsage) u.toJson()],
        'warnings': [for (final w in warnings) w.toJson()],
        'errors': [for (final e in errors) e.toJson()],
      };

  /// Throws [FormatException] for malformed data or an unsupported
  /// `schemaVersion`; missing optional collections resolve to empty.
  factory InferenceRecord.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int) {
      throw const FormatException(
          'Inference record is missing an integer schemaVersion.');
    }
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported inference record schemaVersion $version (supported: $currentSchemaVersion).',
      );
    }
    try {
      return InferenceRecord(
        inferenceId: _requiredString(json, 'inferenceId'),
        schemaVersion: version,
        source: InferenceSourceIdentity.fromJson(_requiredMap(json, 'source')),
        referenceContext: InferenceReferenceContextIdentity.fromJson(
            _requiredMap(json, 'referenceContext')),
        adapter:
            InferenceAdapterProvenance.fromJson(_requiredMap(json, 'adapter')),
        queuedAt: DateTime.parse(_requiredString(json, 'queuedAt')),
        startedAt: json['startedAt'] == null
            ? null
            : DateTime.parse(json['startedAt'] as String),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        status: _enumByName(
            InferenceRecordStatus.values, json['status'], 'inference status'),
        evidenceUsed: [
          for (final e in (json['evidenceUsed'] as List? ?? const []))
            InferenceEvidenceReference.fromJson(e as Map<String, dynamic>),
        ],
        hypotheses: [
          for (final h in (json['hypotheses'] as List? ?? const []))
            InferenceHypothesis.fromJson(h as Map<String, dynamic>),
        ],
        statements: [
          for (final s in (json['statements'] as List? ?? const []))
            InferenceStatement.fromJson(s as Map<String, dynamic>),
        ],
        referenceUsage: [
          for (final u in (json['referenceUsage'] as List? ?? const []))
            ReferenceUsage.fromJson(u as Map<String, dynamic>),
        ],
        warnings: [
          for (final w in (json['warnings'] as List? ?? const []))
            InferenceDiagnostic.fromJson(w as Map<String, dynamic>),
        ],
        errors: [
          for (final e in (json['errors'] as List? ?? const []))
            InferenceDiagnostic.fromJson(e as Map<String, dynamic>),
        ],
      );
    } on InferenceRecordException catch (e) {
      throw FormatException(e.message);
    } on ReferenceUsageException catch (e) {
      throw FormatException(e.message);
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or empty required string "$key".');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Missing required object "$key".');
  }
  return value;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, String what) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('Unknown $what "$name".');
}
