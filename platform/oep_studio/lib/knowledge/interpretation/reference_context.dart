import 'package:engineering_engine/engineering_engine.dart'
    show
        KnowledgeObject,
        KnowledgeRelationship,
        KnowledgeRuntime,
        ReferenceDiscovery,
        RuntimeIdentity,
        SymbolBindingAdapter;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../inference/canonical_json.dart';
import '../models/evidence_link.dart';
import '../models/evidence_origin.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/ocr_page_result.dart';
import '../models/source_material.dart';

/// WP-EKE-017: the deterministic, provenance-preserving context a FUTURE
/// interpretation step may use. It does not interpret anything.
///
/// ```text
/// OBSERVATION          evidence directly present in the source (OCR, regions,
///                      explicitly sourced human annotations / candidates)
/// REFERENCE KNOWLEDGE  authoritative knowledge retrieved through
///                      ReferenceDiscovery and resolved by KnowledgeRuntime
/// INTERPRETATION       a future inference process's conclusion   (NOT here)
/// ACCEPTED TRUTH       reviewed + committed engineering knowledge (NOT here)
/// ```
///
/// Existing canonical models are reused as they are (`OcrPageResult`,
/// `EvidenceRegion`, `EvidenceLink`, `KnowledgeCandidate`, `SourceMaterial`,
/// the runtime's own `KnowledgeObject`/`KnowledgeRelationship`); nothing is
/// re-modelled.

/// Why a Reference item is being retrieved (WP-EKE-017 §6).
enum ReferenceRetrievalPurpose {
  symbolIdentification('symbol_identification'),
  componentClassification('component_classification'),
  terminalInterpretation('terminal_interpretation'),
  relationshipInterpretation('relationship_interpretation'),
  propertyInterpretation('property_interpretation'),
  terminology('terminology'),
  standardReference('standard_reference');

  const ReferenceRetrievalPurpose(this.wireName);

  final String wireName;
}

enum ReferenceContextErrorCode {
  /// The request itself is malformed (empty query, bad limit, ...).
  invalidRequest,

  /// Queries were requested but no Reference stack (runtime + discovery) was
  /// supplied. Evidence-only contexts (no queries) do not need one.
  referenceKnowledgeUnavailable,

  /// OCR results for one source disagree about the source fingerprint.
  inconsistentSourceIdentity,
}

class ReferenceContextException implements Exception {
  final ReferenceContextErrorCode code;
  final String message;

  const ReferenceContextException(this.code, this.message);

  @override
  String toString() => 'ReferenceContextException(${code.name}): $message';
}

/// One retrieval request: a purpose plus explicit search terms for
/// `ReferenceDiscovery`. There is no query language and no "load everything"
/// operation.
class ReferenceContextQuery {
  /// Deterministic per-query result limit applied after ranking/filtering.
  static const int defaultMaxResults = 10;

  /// Largest `maxResults` accepted.
  static const int maxAllowedResults = 50;

  final ReferenceRetrievalPurpose purpose;

  /// Passed to `ReferenceDiscovery.search` unchanged (its own normalization
  /// applies; nothing fuzzy is added here).
  final String query;

  /// Keep only Reference objects whose `objectType` is one of these (exact
  /// match, e.g. `Symbol`, `Component`). Empty = no type filter. Non-matching
  /// hits are excluded, not errors.
  final List<String> objectTypes;

  /// Only include relationships of these types for retrieved objects. Empty =
  /// all incident relationships.
  final List<String> relationshipTypes;
  final bool requireAllTerms;
  final int maxResults;

  /// Optional: the evidence regions this retrieval is about. Recorded as
  /// provenance; it does not change what is retrieved.
  final List<String> evidenceRegionIds;

  ReferenceContextQuery({
    required this.purpose,
    required this.query,
    Iterable<String> objectTypes = const [],
    Iterable<String> relationshipTypes = const [],
    this.requireAllTerms = false,
    this.maxResults = defaultMaxResults,
    Iterable<String> evidenceRegionIds = const [],
  })  : objectTypes = List.unmodifiable(({...objectTypes}.toList()..sort())),
        relationshipTypes =
            List.unmodifiable(({...relationshipTypes}.toList()..sort())),
        evidenceRegionIds =
            List.unmodifiable(({...evidenceRegionIds}.toList()..sort())) {
    if (query.trim().isEmpty) {
      throw const ReferenceContextException(
        ReferenceContextErrorCode.invalidRequest,
        'A retrieval query must not be empty.',
      );
    }
    if (maxResults < 1 || maxResults > maxAllowedResults) {
      throw ReferenceContextException(
        ReferenceContextErrorCode.invalidRequest,
        'maxResults must be between 1 and $maxAllowedResults (was $maxResults).',
      );
    }
  }

  Map<String, Object?> toJson() => {
        'purpose': purpose.wireName,
        'query': query,
        'objectTypes': objectTypes,
        'relationshipTypes': relationshipTypes,
        'requireAllTerms': requireAllTerms,
        'maxResults': maxResults,
        'evidenceRegionIds': evidenceRegionIds,
      };
}

/// The source evidence a context is built from, using the existing models.
/// Anything not belonging to [source] (and, when set, [page]) is excluded.
class DiagramEvidenceInput {
  final SourceMaterial source;

  /// 1-based page to restrict to; `null` = every page present.
  final int? page;
  final List<OcrPageResult> ocrPages;
  final List<EvidenceRegion> evidenceRegions;
  final List<EvidenceLink> evidenceLinks;
  final List<KnowledgeCandidate> candidates;

  const DiagramEvidenceInput({
    required this.source,
    this.page,
    this.ocrPages = const [],
    this.evidenceRegions = const [],
    this.evidenceLinks = const [],
    this.candidates = const [],
  });
}

class ReferenceContextRequest {
  /// Optional: a Reference-only context needs no source evidence.
  final DiagramEvidenceInput? evidence;

  /// Retrievals, in the caller's order (that order is part of the input and is
  /// preserved in the context). Empty = evidence-only context.
  final List<ReferenceContextQuery> queries;

  const ReferenceContextRequest({this.evidence, this.queries = const []});
}

/// The Reference stack a context is built against. All three are the
/// authoritative services themselves; the builder owns none of them.
class ReferenceKnowledgeSources {
  final KnowledgeRuntime runtime;
  final ReferenceDiscovery discovery;

  /// Optional integration layer (WP-EKE-016). When absent, symbol bindings are
  /// reported as `notEvaluated`.
  final SymbolBindingAdapter? symbolBinding;

  const ReferenceKnowledgeSources({
    required this.runtime,
    required this.discovery,
    this.symbolBinding,
  });
}

/// The Reference package + runtime that supplied the context, exactly as
/// `KnowledgeRuntime.identity` reports them (not an inference model identity,
/// not a second version).
class ReferenceContextIdentity {
  final String packageId;
  final String packageVersion;
  final String schemaVersion;
  final String compilerVersion;
  final String contentHash;
  final String runtimeVersion;
  final String runtimeBuild;

  const ReferenceContextIdentity({
    required this.packageId,
    required this.packageVersion,
    required this.schemaVersion,
    required this.compilerVersion,
    required this.contentHash,
    required this.runtimeVersion,
    required this.runtimeBuild,
  });

  factory ReferenceContextIdentity.of(RuntimeIdentity identity) =>
      ReferenceContextIdentity(
        packageId: identity.packageId,
        packageVersion: identity.packageVersion,
        schemaVersion: identity.schemaVersion,
        compilerVersion: identity.compilerVersion,
        contentHash: identity.contentHash,
        runtimeVersion: identity.runtimeVersion,
        runtimeBuild: identity.runtimeBuild,
      );

  factory ReferenceContextIdentity.fromJson(Map<String, dynamic> json) =>
      ReferenceContextIdentity(
        packageId: json['packageId'] as String,
        packageVersion: json['packageVersion'] as String,
        schemaVersion: json['schemaVersion'] as String,
        compilerVersion: json['compilerVersion'] as String,
        contentHash: json['contentHash'] as String,
        runtimeVersion: json['runtimeVersion'] as String,
        runtimeBuild: json['runtimeBuild'] as String,
      );

  Map<String, Object?> toJson() => {
        'packageId': packageId,
        'packageVersion': packageVersion,
        'schemaVersion': schemaVersion,
        'compilerVersion': compilerVersion,
        'contentHash': contentHash,
        'runtimeVersion': runtimeVersion,
        'runtimeBuild': runtimeBuild,
      };
}

/// Why an item was retrieved, in `ReferenceDiscovery`'s own deterministic
/// terms. `score`/`rank` are match counts and list positions, **not**
/// confidence or probability.
class ReferenceRetrieval {
  /// Index of the originating query in the request.
  final int queryIndex;
  final String queryText;

  /// `ReferenceDiscovery.normalizeQuery(queryText)`.
  final List<String> normalizedTerms;

  /// The query tokens this object matched in `search.idx` (sorted).
  final List<String> matchedTerms;

  /// Distinct query tokens matched (`ReferenceSearchHit.score`).
  final int score;

  /// 1-based position among this query's results after the object-type filter.
  final int rank;

  /// Evidence regions the query declared it was about (provenance only).
  final List<String> evidenceRegionIds;

  ReferenceRetrieval({
    required this.queryIndex,
    required this.queryText,
    required List<String> normalizedTerms,
    required List<String> matchedTerms,
    required this.score,
    required this.rank,
    required List<String> evidenceRegionIds,
  })  : normalizedTerms = List.unmodifiable(normalizedTerms),
        matchedTerms = List.unmodifiable(matchedTerms),
        evidenceRegionIds = List.unmodifiable(evidenceRegionIds);

  /// A human-readable rationale; the structured fields above are the record.
  String get rationale => 'search.idx term match for "$queryText" '
      '(matched: ${matchedTerms.join(", ")}; score $score; rank $rank)';

  factory ReferenceRetrieval.fromJson(Map<String, dynamic> json) =>
      ReferenceRetrieval(
        queryIndex: json['queryIndex'] as int,
        queryText: json['queryText'] as String,
        normalizedTerms: [
          for (final t in json['normalizedTerms'] as List) t as String
        ],
        matchedTerms: [
          for (final t in json['matchedTerms'] as List) t as String
        ],
        score: json['score'] as int,
        rank: json['rank'] as int,
        evidenceRegionIds: [
          for (final t in json['evidenceRegionIds'] as List) t as String
        ],
      );

  Map<String, Object?> toJson() => {
        'source': 'ReferenceDiscovery.search',
        'queryIndex': queryIndex,
        'queryText': queryText,
        'normalizedTerms': normalizedTerms,
        'matchedTerms': matchedTerms,
        'score': score,
        'rank': rank,
        'evidenceRegionIds': evidenceRegionIds,
        'rationale': rationale,
      };
}

enum SymbolBindingStatus {
  /// An explicit binding exists and resolves.
  bound,

  /// The Reference Symbol has no binding. Valid; nothing is inferred.
  absent,

  /// A binding exists but does not resolve (see [ReferenceSymbolBindingView.errorCode]).
  invalid,

  /// No `SymbolBindingAdapter` was supplied.
  notEvaluated,
}

/// The WP-EKE-016 integration view for a retrieved Reference Symbol. Both
/// identities are kept; the Reference object stays authoritative. This view
/// makes **no** claim that the Engine rendering is visually equivalent to the
/// Reference Symbol: [notes] carries the binding's own caveat verbatim.
class ReferenceSymbolBindingView {
  final String referenceSymbolId;
  final SymbolBindingStatus status;
  final String? engineSymbolId;
  final String? notes;
  final String? errorCode;

  const ReferenceSymbolBindingView({
    required this.referenceSymbolId,
    required this.status,
    this.engineSymbolId,
    this.notes,
    this.errorCode,
  });

  factory ReferenceSymbolBindingView.fromJson(Map<String, dynamic> json) =>
      ReferenceSymbolBindingView(
        referenceSymbolId: json['referenceSymbolId'] as String,
        status: SymbolBindingStatus.values.byName(json['status'] as String),
        engineSymbolId: json['engineSymbolId'] as String?,
        notes: json['notes'] as String?,
        errorCode: json['errorCode'] as String?,
      );

  Map<String, Object?> toJson() => {
        'referenceSymbolId': referenceSymbolId,
        'status': status.name,
        'engineSymbolId': engineSymbolId,
        'notes': notes,
        'errorCode': errorCode,
      };
}

/// One retrieved Reference object and why it is in the context.
class ReferenceContextItem {
  /// The runtime's own authoritative object (identity, type, name, domain,
  /// tags, provenance id).
  final KnowledgeObject object;
  final ReferenceRetrievalPurpose purpose;
  final ReferenceRetrieval retrieval;

  /// The Reference package/runtime that supplied [object].
  final ReferenceContextIdentity identity;

  /// Present only when [object] is a `Symbol`.
  final ReferenceSymbolBindingView? symbolBinding;

  const ReferenceContextItem({
    required this.object,
    required this.purpose,
    required this.retrieval,
    required this.identity,
    this.symbolBinding,
  });

  String get referenceObjectId => object.id;
  String get objectType => object.objectType;

  Map<String, Object?> toJson() => {
        'referenceObjectId': referenceObjectId,
        'objectType': objectType,
        'object': object.toJson(),
        'purpose': purpose.wireName,
        'retrieval': retrieval.toJson(),
        'identity': identity.toJson(),
        if (symbolBinding != null) 'symbolBinding': symbolBinding!.toJson(),
      };
}

/// A Reference Knowledge relationship (the runtime's own, unconverted) that
/// touches a retrieved object. It is not an `EngineeringRelationship` and
/// nothing is inferred.
class ReferenceContextRelationship {
  final KnowledgeRelationship relationship;

  /// Purposes of the retrievals that caused inclusion (sorted, unique).
  final List<String> purposes;

  /// Retrieved object ids this relationship touches (sorted, unique).
  final List<String> retrievedObjectIds;

  ReferenceContextRelationship({
    required this.relationship,
    required List<String> purposes,
    required List<String> retrievedObjectIds,
  })  : purposes = List.unmodifiable(purposes),
        retrievedObjectIds = List.unmodifiable(retrievedObjectIds);

  Map<String, Object?> toJson() => {
        'relationship': relationship.toJson(),
        'purposes': purposes,
        'retrievedObjectIds': retrievedObjectIds,
      };
}

/// What each query returned, so an empty or truncated retrieval is visible.
class ReferenceQueryOutcome {
  final int queryIndex;
  final ReferenceContextQuery query;

  /// Hits after the object-type filter, before truncation.
  final int totalMatches;
  final int returned;

  const ReferenceQueryOutcome({
    required this.queryIndex,
    required this.query,
    required this.totalMatches,
    required this.returned,
  });

  bool get truncated => returned < totalMatches;

  Map<String, Object?> toJson() => {
        'queryIndex': queryIndex,
        'query': query.toJson(),
        'totalMatches': totalMatches,
        'returned': returned,
        'truncated': truncated,
      };
}

/// The immutable snapshot handed to a future interpreter. Never a global
/// cache: each build creates a new one that reflects the package/runtime it
/// was built against.
class DiagramInterpretationReferenceContext {
  /// The source the evidence belongs to (`null` for a Reference-only context).
  final SourceMaterial? source;

  /// The existing canonical content identity: the (single, agreed)
  /// `OcrPageResult.sourceFingerprint` of this source's OCR results. `null`
  /// when no OCR result carries one. No second hashing scheme is introduced.
  final String? sourceFingerprint;

  /// The page restriction applied, or `null` for all pages.
  final int? page;

  /// OCR pages, ascending by page; words in their own (reading) order with
  /// bounding boxes and confidence intact.
  final List<OcrPageResult> ocrPages;

  /// Ordered by (page, y, x, id).
  final List<EvidenceRegion> evidenceRegions;

  /// Ordered by (candidateId, regionId, id).
  final List<EvidenceLink> evidenceLinks;

  /// Candidates linked to an included region, ordered by id. Observations
  /// only: never Engineering Objects, never committed by this code.
  final List<KnowledgeCandidate> candidates;

  /// The Reference package/runtime, or `null` when no Reference stack was used
  /// (evidence-only build).
  final ReferenceContextIdentity? reference;

  /// In query order, then rank.
  final List<ReferenceContextItem> items;

  /// Ordered by relationship id.
  final List<ReferenceContextRelationship> relationships;
  final List<ReferenceQueryOutcome> queryOutcomes;

  DiagramInterpretationReferenceContext({
    required this.source,
    required this.sourceFingerprint,
    required this.page,
    required List<OcrPageResult> ocrPages,
    required List<EvidenceRegion> evidenceRegions,
    required List<EvidenceLink> evidenceLinks,
    required List<KnowledgeCandidate> candidates,
    required this.reference,
    required List<ReferenceContextItem> items,
    required List<ReferenceContextRelationship> relationships,
    required List<ReferenceQueryOutcome> queryOutcomes,
  })  : ocrPages = List.unmodifiable(ocrPages),
        evidenceRegions = List.unmodifiable(evidenceRegions),
        evidenceLinks = List.unmodifiable(evidenceLinks),
        candidates = List.unmodifiable(candidates),
        items = List.unmodifiable(items),
        relationships = List.unmodifiable(relationships),
        queryOutcomes = List.unmodifiable(queryOutcomes);

  /// A deterministic identity of this exact context: the SHA-256 hex digest of
  /// the structured canonical JSON (`canonicalJson`, the same convention as
  /// `IngestionRun.processingIdentity`) of [toJson]. Identical evidence,
  /// queries, Reference package/runtime and binding registry give the same
  /// digest; any change to them changes it. It lets an `InferenceRecord` name
  /// the exact context it consumed without storing the context.
  late final String digest =
      sha256.convert(utf8.encode(canonicalJson(toJson()))).toString();

  /// Regions a person drew/annotated (origin human): human observations, with
  /// annotator, status and any structured annotation intact on the region.
  List<EvidenceRegion> get humanObservations => List.unmodifiable(
        evidenceRegions.where((r) => r.origin == EvidenceOrigin.human),
      );

  bool get hasReferenceKnowledge => items.isNotEmpty;

  /// A deterministic serialization for tests/export. It is a **snapshot of the
  /// context**, not authoritative Reference Knowledge; nothing reads it back.
  Map<String, Object?> toJson() => {
        'kind': 'diagram_interpretation_reference_context',
        'snapshotNotice':
            'Serialized context snapshot; not authoritative Reference Knowledge '
                'and not an interpretation.',
        'source': source?.toJson(),
        'sourceFingerprint': sourceFingerprint,
        'page': page,
        'ocrPages': [for (final p in ocrPages) p.toJson()],
        'evidenceRegions': [for (final r in evidenceRegions) r.toJson()],
        'evidenceLinks': [for (final l in evidenceLinks) l.toJson()],
        'candidates': [for (final c in candidates) c.toJson()],
        'reference': reference?.toJson(),
        'queryOutcomes': [for (final o in queryOutcomes) o.toJson()],
        'items': [for (final i in items) i.toJson()],
        'relationships': [for (final r in relationships) r.toJson()],
      };
}
