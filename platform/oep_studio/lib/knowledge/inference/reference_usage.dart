import '../interpretation/reference_context.dart';
import 'canonical_json.dart';

/// WP-INGEST-014: durable provenance of which authoritative Reference
/// Knowledge an inference actually USED, why, and in support of what.
///
/// ```text
/// Reference RETRIEVED  !=  Reference AVAILABLE  !=  Reference USED
///                      !=  Reference proved truth
/// ```
///
/// A `ReferenceContextItem` is retrieved evidence-of-availability; a
/// [ReferenceUsage] exists only when the inference explicitly relied on it. It
/// is provenance attached to one `InferenceRecord` (`referenceUsage`), not a
/// Reference Library object, a `KnowledgeRuntime` object, a discovery result,
/// an Engineering Object/Relationship, a candidate, an inference, a confidence
/// score or a commit. It mutates no Reference Knowledge, and it does not imply
/// that the reference *proves* the interpretation.
///
/// Reference identity is the authoritative Reference Library id
/// (`symbol.iec.resistor`); an Engine `SymbolDefinition` id (`resistor`) is
/// separate and appears only inside the preserved binding view.

/// A programmatic violation of a [ReferenceUsage] invariant. Malformed
/// persisted data surfaces as a [FormatException] instead.
class ReferenceUsageException implements Exception {
  final String message;
  const ReferenceUsageException(this.message);

  @override
  String toString() => 'ReferenceUsageException: $message';
}

/// How central the reference was to the interpretation it supported.
enum ReferenceUsageRole { primary, supporting }

class ReferenceUsage {
  /// The only `schemaVersion` this build understands.
  static const int currentSchemaVersion = 1;

  /// Unique per usage (caller-generated). It is not the semantic identity; see
  /// [semanticKey].
  final String usageId;
  final int schemaVersion;

  /// The owning `InferenceRecord.inferenceId`.
  final String inferenceId;

  /// The `DiagramInterpretationReferenceContext.digest` this usage came from.
  final String contextDigest;

  /// Authoritative Reference Library identity, as the runtime reports it.
  final String referenceObjectId;
  final String referenceObjectType;
  final String referenceObjectVersion;

  /// The exact Reference package/runtime the object was resolved against
  /// (`KnowledgeRuntime.identity`, via the context). No second version model.
  final ReferenceContextIdentity package;

  /// WHY THE REFERENCE WAS USED, stated explicitly by the adapter/reviewer (the
  /// frozen WP-EKE-017 purpose vocabulary). It is never inferred from the
  /// object type and may differ from why the object was retrieved
  /// ([retrieval]`.queryIndex` names the query that retrieved it).
  final ReferenceRetrievalPurpose purpose;
  final ReferenceUsageRole role;

  /// The stated reason this reference was relied upon (required).
  final String rationale;

  /// Sorted, unique ids of the existing evidence this usage helped interpret
  /// (`EvidenceRegion.id`) and of the hypotheses/statements it supported.
  final List<String> evidenceRegionIds;
  final List<String> hypothesisIds;
  final List<String> statementIds;

  /// Why/how it was RETRIEVED, copied from the context item (query, terms,
  /// retrieval score, rank). A retrieval score is not inference confidence and
  /// is never renamed as one.
  final ReferenceRetrieval? retrieval;

  /// Both identities when the object is a bound Symbol; the Reference id stays
  /// authoritative and no visual equivalence is implied.
  final ReferenceSymbolBindingView? symbolBinding;

  ReferenceUsage({
    required this.usageId,
    this.schemaVersion = currentSchemaVersion,
    required this.inferenceId,
    required this.contextDigest,
    required this.referenceObjectId,
    required this.referenceObjectType,
    required this.referenceObjectVersion,
    required this.package,
    required this.purpose,
    this.role = ReferenceUsageRole.supporting,
    required this.rationale,
    Iterable<String> evidenceRegionIds = const [],
    Iterable<String> hypothesisIds = const [],
    Iterable<String> statementIds = const [],
    this.retrieval,
    this.symbolBinding,
  })  : evidenceRegionIds =
            List.unmodifiable(({...evidenceRegionIds}.toList()..sort())),
        hypothesisIds =
            List.unmodifiable(({...hypothesisIds}.toList()..sort())),
        statementIds = List.unmodifiable(({...statementIds}.toList()..sort())) {
    if (usageId.isEmpty ||
        inferenceId.isEmpty ||
        contextDigest.isEmpty ||
        referenceObjectId.isEmpty ||
        referenceObjectType.isEmpty ||
        referenceObjectVersion.isEmpty) {
      throw const ReferenceUsageException(
        'A usage needs usageId, inferenceId, contextDigest and the reference '
        'object id, type and version.',
      );
    }
    if (rationale.trim().isEmpty) {
      throw const ReferenceUsageException(
          'A usage needs an explicit rationale (why it was used).');
    }
    if (schemaVersion != currentSchemaVersion) {
      throw ReferenceUsageException(
          'Unsupported ReferenceUsage schemaVersion $schemaVersion.');
    }
  }

  /// Builds a usage FROM a retrieved context item, which is what makes a
  /// dangling reference impossible: the item must belong to [context], the
  /// package/runtime identity, object identity, retrieval provenance and symbol
  /// binding are taken from it (never reconstructed or re-searched), and every
  /// evidence region named must exist in [context]. The [purpose] and
  /// [rationale] are the caller's explicit statement of why it was USED.
  factory ReferenceUsage.fromContextItem({
    required String usageId,
    required String inferenceId,
    required DiagramInterpretationReferenceContext context,
    required ReferenceContextItem item,
    required ReferenceRetrievalPurpose purpose,
    required String rationale,
    ReferenceUsageRole role = ReferenceUsageRole.supporting,
    Iterable<String> evidenceRegionIds = const [],
    Iterable<String> hypothesisIds = const [],
    Iterable<String> statementIds = const [],
  }) {
    final belongs = context.items.any(
      (i) =>
          identical(i, item) ||
          (i.referenceObjectId == item.referenceObjectId &&
              i.retrieval.queryIndex == item.retrieval.queryIndex),
    );
    if (!belongs) {
      throw ReferenceUsageException(
        'Reference "${item.referenceObjectId}" is not an item of the referenced '
        'Reference Context; a usage cannot point outside its context.',
      );
    }
    final reference = context.reference;
    if (reference == null) {
      throw const ReferenceUsageException(
          'The referenced context has no Reference package identity.');
    }
    final regionIds = {for (final r in context.evidenceRegions) r.id};
    for (final id in evidenceRegionIds) {
      if (!regionIds.contains(id)) {
        throw ReferenceUsageException(
            'Evidence region "$id" is not in the referenced context.');
      }
    }
    return ReferenceUsage(
      usageId: usageId,
      inferenceId: inferenceId,
      contextDigest: context.digest,
      referenceObjectId: item.referenceObjectId,
      referenceObjectType: item.objectType,
      referenceObjectVersion: item.object.version,
      package: reference,
      purpose: purpose,
      role: role,
      rationale: rationale,
      evidenceRegionIds: evidenceRegionIds,
      hypothesisIds: hypothesisIds,
      statementIds: statementIds,
      retrieval: item.retrieval,
      symbolBinding: item.symbolBinding,
    );
  }

  /// The semantic identity used to detect duplicates: WHICH reference, for WHICH
  /// purpose, interpreting WHICH evidence and supporting WHICH hypotheses and
  /// statements. Structured canonical JSON (sorted keys, no delimiters, no
  /// timestamps), the same convention as `processingIdentity`. Two usages that
  /// differ in any part are distinct (auditable attribution); two with the same
  /// key are one semantic usage and are rejected as duplicates. Deduplicating by
  /// reference id alone is deliberately not done.
  String get semanticKey => canonicalJson({
        'referenceObjectId': referenceObjectId,
        'purpose': purpose.wireName,
        'evidenceRegionIds': evidenceRegionIds,
        'hypothesisIds': hypothesisIds,
        'statementIds': statementIds,
      });

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'usageId': usageId,
        'inferenceId': inferenceId,
        'contextDigest': contextDigest,
        'referenceObjectId': referenceObjectId,
        'referenceObjectType': referenceObjectType,
        'referenceObjectVersion': referenceObjectVersion,
        'package': package.toJson(),
        'purpose': purpose.wireName,
        'role': role.name,
        'rationale': rationale,
        'evidenceRegionIds': evidenceRegionIds,
        'hypothesisIds': hypothesisIds,
        'statementIds': statementIds,
        'retrieval': retrieval?.toJson(),
        'symbolBinding': symbolBinding?.toJson(),
      };

  /// Throws [FormatException] for malformed data, an unknown purpose/role, or
  /// an unsupported `schemaVersion` (never reinterpreted as another schema).
  factory ReferenceUsage.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int) {
      throw const FormatException(
          'ReferenceUsage is missing an integer schemaVersion.');
    }
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported ReferenceUsage schemaVersion $version (supported: $currentSchemaVersion).',
      );
    }
    String req(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) {
        throw FormatException('ReferenceUsage: missing "$key".');
      }
      return v;
    }

    List<String> ids(String key) =>
        [for (final v in (json[key] as List? ?? const [])) v as String];
    final purposeName = req('purpose');
    final purpose = ReferenceRetrievalPurpose.values
        .where((p) => p.wireName == purposeName);
    if (purpose.isEmpty) {
      throw FormatException('ReferenceUsage: unknown purpose "$purposeName".');
    }
    final roleName =
        json['role'] as String? ?? ReferenceUsageRole.supporting.name;
    final role = ReferenceUsageRole.values.where((r) => r.name == roleName);
    if (role.isEmpty) {
      throw FormatException('ReferenceUsage: unknown role "$roleName".');
    }
    final packageJson = json['package'];
    if (packageJson is! Map<String, dynamic>) {
      throw const FormatException('ReferenceUsage: missing package identity.');
    }
    try {
      return ReferenceUsage(
        usageId: req('usageId'),
        schemaVersion: version,
        inferenceId: req('inferenceId'),
        contextDigest: req('contextDigest'),
        referenceObjectId: req('referenceObjectId'),
        referenceObjectType: req('referenceObjectType'),
        referenceObjectVersion: req('referenceObjectVersion'),
        package: ReferenceContextIdentity.fromJson(packageJson),
        purpose: purpose.first,
        role: role.first,
        rationale: req('rationale'),
        evidenceRegionIds: ids('evidenceRegionIds'),
        hypothesisIds: ids('hypothesisIds'),
        statementIds: ids('statementIds'),
        retrieval: json['retrieval'] == null
            ? null
            : ReferenceRetrieval.fromJson(
                json['retrieval'] as Map<String, dynamic>),
        symbolBinding: json['symbolBinding'] == null
            ? null
            : ReferenceSymbolBindingView.fromJson(
                json['symbolBinding'] as Map<String, dynamic>),
      );
    } on ReferenceUsageException catch (e) {
      throw FormatException(e.message);
    }
  }
}
