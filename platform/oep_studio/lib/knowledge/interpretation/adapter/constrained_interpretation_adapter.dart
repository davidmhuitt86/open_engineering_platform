import 'dart:convert';

import '../../inference/inference_record.dart';
import '../../inference/reference_usage.dart';
import '../reference_context.dart';
import 'interpretation_provider.dart';
import 'interpretation_request.dart';
import 'provider_result.dart';

/// WP-EKE-018: the constrained interpretation adapter.
///
/// ```text
/// InterpretationRequest -> InterpretationProvider -> ProviderResult (untrusted)
///   -> validation -> InferenceRecord (+ ReferenceUsage) -> Human Review
/// ```
///
/// The adapter is an interpretation boundary, not an authority. It never
/// creates Engineering Objects, nodes or relationships, never touches the
/// Repository, `CommitPlanService` or Foundation, never accepts or promotes a
/// hypothesis, never retrieves Reference Knowledge, and never calculates,
/// normalizes or ranks confidence. It is given no handle to any of those.
///
/// It builds every authoritative field itself, from the request: source
/// identity, the context digest, the Reference package/runtime identity, usage
/// ids and each usage's reference identity/retrieval provenance/symbol binding.
/// Provider claims about those are only checked, never copied. Invalid provider
/// output is never silently dropped: it becomes an explicit error diagnostic on
/// the record, and whatever is valid is kept as PARTIAL (or FAILED when nothing
/// valid remains).
///
/// The adapter is deterministic in its validation, provenance construction,
/// ordering and identity handling; a provider (a future model) may not be.
/// Timestamps come from an injectable clock and never enter any identity.
class ConstrainedInterpretationAdapter {
  final InterpretationProvider provider;
  final DateTime Function() _clock;

  ConstrainedInterpretationAdapter(this.provider, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Runs one interpretation and returns the finished [InferenceRecord].
  ///
  /// [onRecord] is called at each lifecycle step (queued, running, finished) so
  /// the caller can persist each through the ordinary session path. [isCancelled]
  /// is consulted before the provider runs and after it returns; output produced
  /// after cancellation is discarded, and a provider-declared cancelled result
  /// keeps only what validates.
  ///
  /// Throws [InterpretationAdapterException] only before a record exists (an
  /// empty id or an objective the provider does not support).
  Future<InferenceRecord> interpret(
    InterpretationRequest request, {
    required String inferenceId,
    void Function(InferenceRecord record)? onRecord,
    bool Function()? isCancelled,
  }) async {
    if (inferenceId.trim().isEmpty) {
      throw const InterpretationAdapterException(
        InterpretationFailureCode.invalidRequest,
        'An interpretation needs an inferenceId.',
      );
    }
    if (!provider.supportedObjectives.contains(request.objective)) {
      throw InterpretationAdapterException(
        InterpretationFailureCode.unsupportedObjective,
        'Provider "${provider.identity.adapterId}" does not support '
        '${request.objective.wireName}.',
      );
    }
    bool cancelled() => isCancelled?.call() ?? false;
    final context = request.context;

    var record = InferenceRecord(
      inferenceId: inferenceId,
      source: InferenceSourceIdentity(
        sourceMaterialId: request.sourceMaterialId,
        sourceFingerprint: context.sourceFingerprint,
        pages: request.pages,
      ),
      referenceContext: InferenceReferenceContextIdentity.of(context),
      adapter: _adapterProvenance(request),
      queuedAt: _clock(),
    );
    onRecord?.call(record);

    if (cancelled()) {
      record = record.finish(InferenceRecordStatus.cancelled, _clock());
      onRecord?.call(record);
      return record;
    }
    record = record.markRunning(_clock());
    onRecord?.call(record);

    final ProviderResult result;
    try {
      result = await provider.interpret(request, isCancelled: isCancelled);
    } on ProviderResultException catch (e) {
      return _finishFailed(record, onRecord, e.code, e.message);
    } on InterpretationProviderException catch (e) {
      return _finishFailed(
        record,
        onRecord,
        InterpretationFailureCode.providerFailure,
        e.message,
      );
    } catch (e) {
      return _finishFailed(
        record,
        onRecord,
        InterpretationFailureCode.providerFailure,
        'The provider failed unexpectedly: $e',
      );
    }

    // Output produced after cancellation is never made durable.
    if (cancelled() && result.outcome != ProviderOutcome.cancelled) {
      record = record.finish(
        InferenceRecordStatus.cancelled,
        _clock(),
        warnings: const [
          InferenceDiagnostic(
            code: 'output_discarded_after_cancellation',
            message:
                'The provider returned output after the inference was cancelled; it was not recorded.',
          ),
        ],
      );
      onRecord?.call(record);
      return record;
    }

    final fatal = _resultLevelProblem(request, result);
    if (fatal != null) {
      return _finishFailed(record, onRecord, fatal.$1, fatal.$2);
    }

    final v = _Validation(request, result, inferenceId)..run();
    final hasOutput = v.hypotheses.isNotEmpty ||
        v.statements.isNotEmpty ||
        v.usages.isNotEmpty;
    final hasProblems = v.errors.isNotEmpty ||
        result.outcome == ProviderOutcome.partial ||
        result.errors.isNotEmpty ||
        result.referenceContextInsufficient.isNotEmpty;

    final errors = <InferenceDiagnostic>[
      ...result.errors.where(_wellFormed),
      ...v.errors,
      if (result.outcome == ProviderOutcome.partial)
        const InferenceDiagnostic(
          code: 'incomplete_provider_result',
          message: 'The provider reported its result as incomplete.',
        ),
      for (final need in result.referenceContextInsufficient)
        InferenceDiagnostic(
          code: InterpretationFailureCode.referenceContextInsufficient.wireName,
          message: need,
        ),
    ];
    final malformedProviderDiagnostics = [
      ...result.warnings,
      ...result.errors,
    ].where((d) => !_wellFormed(d));
    for (final _ in malformedProviderDiagnostics) {
      errors.add(
        const InferenceDiagnostic(
          code: 'incomplete_provider_result',
          message:
              'A provider diagnostic lacked a code or message and was not recorded.',
        ),
      );
    }

    final InferenceRecordStatus status;
    if (result.outcome == ProviderOutcome.cancelled) {
      status = InferenceRecordStatus.cancelled;
    } else if (!hasProblems && errors.isEmpty) {
      status = InferenceRecordStatus.completed;
    } else {
      status = hasOutput
          ? InferenceRecordStatus.partial
          : InferenceRecordStatus.failed;
    }

    try {
      record = record.finish(
        status,
        _clock(),
        evidenceUsed: v.evidenceUsed,
        hypotheses: v.hypotheses,
        statements: v.statements,
        referenceUsage: v.usages,
        warnings: result.warnings.where(_wellFormed).toList(),
        errors: errors,
      );
      record.requireReferenceUsageMatches(context);
    } on InferenceRecordException catch (e) {
      // A validation defect must never yield an inconsistent durable record.
      return _finishFailed(
        record,
        onRecord,
        InterpretationFailureCode.invalidReferenceUsage,
        'The validated output was inconsistent with the record: ${e.message}',
      );
    }
    onRecord?.call(record);
    return record;
  }

  InferenceAdapterProvenance _adapterProvenance(InterpretationRequest request) {
    final id = provider.identity;
    return InferenceAdapterProvenance(
      adapterId: id.adapterId,
      provider: id.provider,
      modelName: id.modelName,
      modelVersion: id.modelVersion,
      // The provider's own version if it has one, else the instruction version
      // the adapter itself sent; nothing is invented.
      promptVersion: id.promptVersion ?? request.instructionVersion,
      // The schema the adapter requested and will validate against.
      outputSchemaVersion: request.outputSchemaVersion.toString(),
    );
  }

  InferenceRecord _finishFailed(
    InferenceRecord running,
    void Function(InferenceRecord)? onRecord,
    InterpretationFailureCode code,
    String message,
  ) {
    final failed = running.finish(
      InferenceRecordStatus.failed,
      _clock(),
      errors: [InferenceDiagnostic(code: code.wireName, message: message)],
    );
    onRecord?.call(failed);
    return failed;
  }

  static bool _wellFormed(InferenceDiagnostic d) =>
      d.code.trim().isNotEmpty && d.message.trim().isNotEmpty;

  /// Problems with the result as a whole (its schema, or what it claims to
  /// have received). Any of these means none of its content is trusted.
  (InterpretationFailureCode, String)? _resultLevelProblem(
    InterpretationRequest request,
    ProviderResult result,
  ) {
    if (result.schemaVersion != request.outputSchemaVersion) {
      return (
        InterpretationFailureCode.unsupportedProviderSchema,
        'Provider result schemaVersion ${result.schemaVersion} is not the '
            'requested ${request.outputSchemaVersion}.',
      );
    }
    final digest = request.context.digest;
    if (result.claimedContextDigest != null &&
        result.claimedContextDigest != digest) {
      return (
        InterpretationFailureCode.invalidContextIdentity,
        'The provider claims a different Reference Context than it was given.',
      );
    }
    final claimed = result.claimedPackage;
    if (claimed != null) {
      final actual = request.context.reference;
      if (actual == null ||
          jsonEncode(claimed.toJson()) != jsonEncode(actual.toJson())) {
        return (
          InterpretationFailureCode.invalidContextIdentity,
          'The provider claims a Reference package/runtime identity that does '
              'not match the supplied context.',
        );
      }
    }
    return null;
  }
}

/// Validates one [ProviderResult] against its [InterpretationRequest]. Every
/// rejected item yields an error diagnostic; nothing is dropped silently.
class _Validation {
  final InterpretationRequest request;
  final ProviderResult result;
  final String inferenceId;

  final List<InferenceDiagnostic> errors = [];
  final List<InferenceHypothesis> hypotheses = [];
  final List<InferenceStatement> statements = [];
  final List<ReferenceUsage> usages = [];
  final List<InferenceEvidenceReference> evidenceUsed = [];

  late final Set<String> _scopedRegions = request.scopedRegionIds.toSet();
  late final Map<String, int> _regionPage = {
    for (final r in request.context.evidenceRegions) r.id: r.page,
  };
  late final Set<String> _linkIds = {
    for (final l in request.context.evidenceLinks)
      if (_scopedRegions.contains(l.regionId)) l.id,
  };
  late final Set<String> _candidateIds = {
    for (final l in request.context.evidenceLinks)
      if (_scopedRegions.contains(l.regionId)) l.candidateId,
  };
  late final Set<int> _ocrPages = {
    for (final p in request.context.ocrPages) p.page
  };
  late final Set<String> _contextObjectIds = {
    for (final i in request.context.items) i.referenceObjectId,
  };

  _Validation(this.request, this.result, this.inferenceId);

  void _err(InterpretationFailureCode code, String message) =>
      errors.add(InferenceDiagnostic(code: code.wireName, message: message));

  void run() {
    _hypotheses();
    _statements();
    _usages();
    _collectEvidenceUsed();
  }

  // ---- hypotheses -----------------------------------------------------------

  void _hypotheses() {
    final counts = <String, int>{};
    for (final h in result.hypotheses) {
      counts[h.hypothesisId] = (counts[h.hypothesisId] ?? 0) + 1;
    }
    for (final h in result.hypotheses) {
      final label = 'hypothesis "${h.hypothesisId}"';
      if (h.hypothesisId.trim().isEmpty ||
          h.category.trim().isEmpty ||
          h.proposedValue.trim().isEmpty) {
        _err(InterpretationFailureCode.malformedHypothesis,
            'A hypothesis needs a hypothesisId, category and proposedValue.');
        continue;
      }
      if (counts[h.hypothesisId]! > 1) {
        _err(InterpretationFailureCode.malformedHypothesis,
            '$label is declared more than once; every declaration is rejected.');
        continue;
      }
      final HypothesisStatus status;
      switch (h.status) {
        case 'proposed':
          status = HypothesisStatus.proposed;
        case 'rejected':
          status = HypothesisStatus.rejected;
        default:
          _err(
              InterpretationFailureCode.malformedHypothesis,
              '$label has status "${h.status}"; a provider may only propose or '
              'reject. Acceptance is a human review outcome.');
          continue;
      }
      final confidence = _confidence(label, h.confidence);
      if (h.confidence != null && confidence == null) continue;
      if (h.evidence.isEmpty) {
        _err(InterpretationFailureCode.invalidEvidenceReference,
            '$label cites no evidence; an untraceable hypothesis is rejected.');
        continue;
      }
      final evidence = <InferenceEvidenceReference>[];
      var evidenceOk = true;
      for (final e in h.evidence) {
        final ref = _evidence(label, e);
        if (ref == null) {
          evidenceOk = false;
          break;
        }
        evidence.add(ref);
      }
      if (!evidenceOk) continue;
      final unknown =
          h.referenceObjectIds.where((id) => !_contextObjectIds.contains(id));
      if (unknown.isNotEmpty) {
        _err(
            InterpretationFailureCode.unknownReferenceObject,
            '$label cites Reference object(s) not in the supplied context: '
            '${(unknown.toList()..sort()).join(', ')}.');
        continue;
      }
      hypotheses.add(
        InferenceHypothesis(
          hypothesisId: h.hypothesisId,
          category: h.category,
          proposedValue: h.proposedValue,
          label: h.label,
          status: status,
          statusReason: h.statusReason,
          evidence: evidence,
          referenceObjectIds: h.referenceObjectIds,
          confidence: confidence,
          rationale: h.rationale,
        ),
      );
    }
  }

  /// The provider's confidence, unchanged; never calibrated, never adjusted.
  InferenceConfidence? _confidence(String label, ProviderConfidence? c) {
    if (c == null) return null;
    if (!c.value.isFinite) {
      _err(InterpretationFailureCode.malformedHypothesis,
          '$label has a confidence that is not a finite number.');
      return null;
    }
    if (c.calibrated) {
      _err(
          InterpretationFailureCode.malformedHypothesis,
          '$label claims a calibrated confidence; no provider contract '
          'establishes calibration.');
      return null;
    }
    return InferenceConfidence(
        value: c.value, basis: c.basis ?? 'provider-supplied');
  }

  /// Resolves a provider evidence reference against the request. The adapter
  /// fills in the authoritative page rather than trusting the provider's.
  InferenceEvidenceReference? _evidence(String label, ProviderEvidenceRef e) {
    final type = InferenceEvidenceType.values.where((t) => t.name == e.type);
    if (type.isEmpty) {
      _err(InterpretationFailureCode.invalidEvidenceReference,
          '$label cites an unknown evidence type "${e.type}".');
      return null;
    }
    switch (type.first) {
      case InferenceEvidenceType.evidenceRegion:
        if (!_scopedRegions.contains(e.id)) {
          _err(InterpretationFailureCode.invalidEvidenceReference,
              '$label cites evidence region "${e.id}", which is not in the interpretation scope.');
          return null;
        }
        if (e.page != null && e.page != _regionPage[e.id]) {
          _err(InterpretationFailureCode.invalidEvidenceReference,
              '$label cites region "${e.id}" on page ${e.page}, but it is on page ${_regionPage[e.id]}.');
          return null;
        }
        return InferenceEvidenceReference(
          type: InferenceEvidenceType.evidenceRegion,
          id: e.id,
          page: _regionPage[e.id],
        );
      case InferenceEvidenceType.evidenceLink:
        if (!_linkIds.contains(e.id)) {
          _err(InterpretationFailureCode.invalidEvidenceReference,
              '$label cites evidence link "${e.id}", which is not in the interpretation scope.');
          return null;
        }
        return InferenceEvidenceReference(
            type: InferenceEvidenceType.evidenceLink, id: e.id);
      case InferenceEvidenceType.knowledgeCandidate:
        if (!_candidateIds.contains(e.id)) {
          _err(InterpretationFailureCode.invalidEvidenceReference,
              '$label cites candidate "${e.id}", which is not linked to evidence in scope.');
          return null;
        }
        return InferenceEvidenceReference(
            type: InferenceEvidenceType.knowledgeCandidate, id: e.id);
      case InferenceEvidenceType.ocrPage:
        if (e.id != request.sourceMaterialId ||
            e.page == null ||
            !_ocrPages.contains(e.page)) {
          _err(InterpretationFailureCode.invalidEvidenceReference,
              '$label cites OCR page "${e.id}"/${e.page}, which is not part of the request (source and page must match).');
          return null;
        }
        return InferenceEvidenceReference(
          type: InferenceEvidenceType.ocrPage,
          id: e.id,
          page: e.page,
        );
    }
  }

  // ---- statements -----------------------------------------------------------

  void _statements() {
    final valid = {for (final h in hypotheses) h.hypothesisId};
    final counts = <String, int>{};
    for (final s in result.statements) {
      counts[s.statementId] = (counts[s.statementId] ?? 0) + 1;
    }
    for (final s in result.statements) {
      if (s.statementId.trim().isEmpty || s.text.trim().isEmpty) {
        _err(InterpretationFailureCode.malformedStatement,
            'A statement needs a statementId and text.');
        continue;
      }
      if (counts[s.statementId]! > 1) {
        _err(InterpretationFailureCode.malformedStatement,
            'statement "${s.statementId}" is declared more than once; every declaration is rejected.');
        continue;
      }
      final missing = s.hypothesisIds.where((id) => !valid.contains(id));
      if (missing.isNotEmpty) {
        _err(
            InterpretationFailureCode.malformedStatement,
            'statement "${s.statementId}" refers to hypotheses that were not accepted as valid: '
            '${(missing.toList()..sort()).join(', ')}.');
        continue;
      }
      statements.add(
        InferenceStatement(
          statementId: s.statementId,
          text: s.text,
          hypothesisIds: s.hypothesisIds,
        ),
      );
    }
  }

  // ---- reference usage ------------------------------------------------------

  void _usages() {
    final validHypotheses = {for (final h in hypotheses) h.hypothesisId};
    final validStatements = {for (final s in statements) s.statementId};
    final seen = <String>{};
    for (var i = 0; i < result.referenceUsage.length; i++) {
      final u = result.referenceUsage[i];
      final label = 'reference usage #${i + 1} ("${u.referenceObjectId}")';
      final candidates = request.context.items.where(
        (item) =>
            item.referenceObjectId == u.referenceObjectId &&
            (u.queryIndex == null || item.retrieval.queryIndex == u.queryIndex),
      );
      if (candidates.isEmpty) {
        _err(
            InterpretationFailureCode.unknownReferenceObject,
            '$label is not an item of the supplied Reference Context; the adapter does not '
            'search for or accept reference objects it was not given.');
        continue;
      }
      final item = candidates.first;
      final purposes = ReferenceRetrievalPurpose.values
          .where((p) => p.wireName == u.purpose);
      if (purposes.isEmpty) {
        _err(InterpretationFailureCode.invalidReferenceUsage,
            '$label has unknown purpose "${u.purpose}".');
        continue;
      }
      final roles = ReferenceUsageRole.values.where((r) => r.name == u.role);
      if (roles.isEmpty) {
        _err(InterpretationFailureCode.invalidReferenceUsage,
            '$label has unknown role "${u.role}".');
        continue;
      }
      if (u.rationale.trim().isEmpty) {
        _err(InterpretationFailureCode.invalidReferenceUsage,
            '$label needs a rationale (why it was used).');
        continue;
      }
      final badRegions =
          u.evidenceRegionIds.where((id) => !_scopedRegions.contains(id));
      if (badRegions.isNotEmpty) {
        _err(InterpretationFailureCode.invalidEvidenceReference,
            '$label cites evidence region(s) not in scope: ${(badRegions.toList()..sort()).join(', ')}.');
        continue;
      }
      if (u.hypothesisIds.any((h) => !validHypotheses.contains(h)) ||
          u.statementIds.any((s) => !validStatements.contains(s))) {
        _err(InterpretationFailureCode.invalidReferenceUsage,
            '$label refers to a hypothesis or statement that was not accepted as valid.');
        continue;
      }
      final claim = u.claimedEngineSymbolId;
      if (claim != null) {
        final binding = item.symbolBinding;
        if (binding == null ||
            binding.status != SymbolBindingStatus.bound ||
            binding.engineSymbolId != claim) {
          _err(
              InterpretationFailureCode.invalidReferenceUsage,
              '$label claims Engine symbol "$claim", which does not match the '
              'context\'s binding; the adapter never accepts an invented mapping.');
          continue;
        }
      }
      final ReferenceUsage usage;
      try {
        usage = ReferenceUsage.fromContextItem(
          usageId: '$inferenceId-usage-${i + 1}',
          inferenceId: inferenceId,
          context: request.context,
          item: item,
          purpose: purposes.first,
          rationale: u.rationale,
          role: roles.first,
          evidenceRegionIds: u.evidenceRegionIds,
          hypothesisIds: u.hypothesisIds,
          statementIds: u.statementIds,
        );
      } on ReferenceUsageException catch (e) {
        _err(InterpretationFailureCode.invalidReferenceUsage,
            '$label: ${e.message}');
        continue;
      }
      if (!seen.add(usage.semanticKey)) {
        _err(InterpretationFailureCode.invalidReferenceUsage,
            '$label duplicates an earlier usage (same reference, purpose, evidence and hypotheses).');
        continue;
      }
      usages.add(usage);
    }
  }

  /// The evidence the run relied on, derived by the adapter (never supplied by
  /// the provider): the references of valid hypotheses, then usage regions, in
  /// first-appearance order without repeats.
  void _collectEvidenceUsed() {
    final seen = <String>{};
    void add(InferenceEvidenceReference r) {
      if (seen.add('${r.type.name}|${r.id}|${r.page}')) evidenceUsed.add(r);
    }

    for (final h in hypotheses) {
      h.evidence.forEach(add);
    }
    for (final u in usages) {
      for (final id in u.evidenceRegionIds) {
        add(InferenceEvidenceReference(
          type: InferenceEvidenceType.evidenceRegion,
          id: id,
          page: _regionPage[id],
        ));
      }
    }
  }
}
