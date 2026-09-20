import '../reference_context.dart';

/// WP-EKE-018: the input an interpretation provider receives.
///
/// ```text
/// evidence + DiagramInterpretationReferenceContext
///   -> InterpretationRequest -> InterpretationProvider -> ProviderResult (UNTRUSTED)
///   -> ConstrainedInterpretationAdapter (validation) -> InferenceRecord
/// ```
///
/// The request carries the authoritative Reference Context. A provider has no
/// other route to Reference Knowledge: it is not handed the Reference Library,
/// the OERP package, `search.idx`/`graph.idx`, `reference.db`, the
/// `KnowledgeRuntime` or `ReferenceDiscovery`, and the adapter rejects any
/// claim about reference objects that are not in this context.

/// Why an interpretation is requested. This is the existing frozen WP-EKE-017
/// vocabulary ([ReferenceRetrievalPurpose]); no new objective was added.
typedef InterpretationObjective = ReferenceRetrievalPurpose;

/// Typed adapter failures. The wire names are stored as
/// `InferenceDiagnostic.code` on the resulting record.
enum InterpretationFailureCode {
  invalidRequest('invalid_request'),
  unsupportedObjective('unsupported_objective'),
  unsupportedProviderSchema('unsupported_provider_schema'),
  unsupportedProviderField('unsupported_provider_field'),
  invalidContextIdentity('invalid_context_identity'),
  invalidEvidenceReference('invalid_evidence_reference'),
  unknownReferenceObject('unknown_reference_object'),
  invalidReferenceUsage('invalid_reference_usage'),
  malformedHypothesis('malformed_hypothesis'),
  malformedStatement('malformed_statement'),
  providerFailure('provider_failure'),
  incompleteProviderResult('incomplete_provider_result'),
  referenceContextInsufficient('reference_context_insufficient');

  const InterpretationFailureCode(this.wireName);

  final String wireName;
}

/// A failure raised before any inference record exists (an unusable request or
/// an unsupported objective).
class InterpretationAdapterException implements Exception {
  final InterpretationFailureCode code;
  final String message;

  const InterpretationAdapterException(this.code, this.message);

  @override
  String toString() =>
      'InterpretationAdapterException(${code.wireName}): $message';
}

class InterpretationRequest {
  /// The provider output schema this build understands (`ProviderResult`).
  static const int currentOutputSchemaVersion = 1;

  /// Why interpretation is requested.
  final InterpretationObjective objective;

  /// The exact Reference Context the provider receives and the resulting
  /// record will be bound to. It holds the scoped evidence (source, OCR,
  /// regions, links, candidates) and the authoritative Reference items,
  /// relationships and symbol-binding views.
  final DiagramInterpretationReferenceContext context;

  /// Optional narrowing of the evidence to specific regions (sorted, unique).
  /// Empty = every region in the context. Anything not selected is not
  /// exposed as interpretable evidence.
  final List<String> selectedEvidenceRegionIds;

  /// Version of the instruction the adapter sends (provenance; the adapter
  /// assumes no provider prompt format and stores no secrets).
  final String? instructionVersion;

  /// The `ProviderResult.schemaVersion` the adapter will accept.
  final int outputSchemaVersion;

  InterpretationRequest({
    required this.objective,
    required this.context,
    Iterable<String> selectedEvidenceRegionIds = const [],
    this.instructionVersion,
    this.outputSchemaVersion = currentOutputSchemaVersion,
  }) : selectedEvidenceRegionIds = List.unmodifiable(
          ({...selectedEvidenceRegionIds}.toList()..sort()),
        ) {
    if (context.source == null) {
      throw const InterpretationAdapterException(
        InterpretationFailureCode.invalidRequest,
        'An interpretation request needs source evidence (the context has no source).',
      );
    }
    final known = {for (final r in context.evidenceRegions) r.id};
    for (final id in this.selectedEvidenceRegionIds) {
      if (!known.contains(id)) {
        throw InterpretationAdapterException(
          InterpretationFailureCode.invalidRequest,
          'Selected evidence region "$id" is not in the supplied context.',
        );
      }
    }
    if (outputSchemaVersion != currentOutputSchemaVersion) {
      throw InterpretationAdapterException(
        InterpretationFailureCode.invalidRequest,
        'Unsupported output schema version $outputSchemaVersion '
        '(supported: $currentOutputSchemaVersion).',
      );
    }
  }

  /// The regions in interpretation scope, in the context's order.
  List<String> get scopedRegionIds => [
        for (final r in context.evidenceRegions)
          if (selectedEvidenceRegionIds.isEmpty ||
              selectedEvidenceRegionIds.contains(r.id))
            r.id,
      ];

  /// The `SourceMaterial.id` the interpretation is about.
  String get sourceMaterialId => context.source!.id;

  /// Pages in scope: the context's page filter, else the pages present in its
  /// OCR results and regions.
  List<int> get pages {
    if (context.page != null) return [context.page!];
    final set = <int>{
      for (final p in context.ocrPages) p.page,
      for (final r in context.evidenceRegions) r.page,
    };
    return set.toList()..sort();
  }
}
