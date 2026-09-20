import 'package:engineering_engine/engineering_engine.dart'
    show
        KnowledgeObject,
        KnowledgeRelationship,
        ReferenceDiscovery,
        ReferenceSearchHit,
        SymbolBindingAdapter,
        SymbolBindingErrorCode,
        SymbolBindingException;

import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/ocr_page_result.dart';
import 'reference_context.dart';

/// Builds a [DiagramInterpretationReferenceContext] (WP-EKE-017).
///
/// It **orchestrates** existing authorities and owns none of them:
///
/// ```text
/// evidence selection ->  ReferenceDiscovery.search  (deterministic term match)
///                    ->  KnowledgeRuntime.getObject / relationshipsForObject
///                    ->  SymbolBindingAdapter.resolve (optional integration view)
/// ```
///
/// It does not interpret, infer, call a model, parse Reference Library files,
/// read `reference.db`/indexes, mutate the Engineering Graph, the Repository,
/// the KnowledgeSession, the Reference Knowledge or its inputs, or persist
/// anything. It accepts no LLM/vision/inference collaborator by design.
class DiagramInterpretationReferenceContextBuilder {
  /// `null` builds evidence-only contexts; requesting queries then throws
  /// `referenceKnowledgeUnavailable`.
  final ReferenceKnowledgeSources? reference;

  const DiagramInterpretationReferenceContextBuilder({this.reference});

  DiagramInterpretationReferenceContext build(ReferenceContextRequest request) {
    final sources = reference;
    if (request.queries.isNotEmpty && sources == null) {
      throw const ReferenceContextException(
        ReferenceContextErrorCode.referenceKnowledgeUnavailable,
        'Reference retrieval was requested but no Reference stack '
        '(KnowledgeRuntime + ReferenceDiscovery) was supplied.',
      );
    }

    final evidence = request.evidence;
    final selected = evidence == null ? null : _selectEvidence(evidence);

    final items = <ReferenceContextItem>[];
    final outcomes = <ReferenceQueryOutcome>[];
    final relationshipIndex = <String, _RelationshipAccumulator>{};
    ReferenceContextIdentity? identity;

    if (sources != null) {
      identity = ReferenceContextIdentity.of(sources.runtime.identity);
    }

    for (var i = 0; i < request.queries.length; i++) {
      final query = request.queries[i];
      final s = sources!;
      final filtered = <(ReferenceSearchHit, KnowledgeObject)>[];
      for (final hit in s.discovery.search(
        query.query,
        requireAllTerms: query.requireAllTerms,
      )) {
        // Discovery yields ids; the runtime is the authority for the object.
        final object = s.runtime.getObject(hit.objectId);
        if (query.objectTypes.isNotEmpty &&
            !query.objectTypes.contains(object.objectType)) {
          continue;
        }
        filtered.add((hit, object));
      }
      final returned = filtered.length > query.maxResults
          ? filtered.sublist(0, query.maxResults)
          : filtered;
      outcomes.add(
        ReferenceQueryOutcome(
          queryIndex: i,
          query: query,
          totalMatches: filtered.length,
          returned: returned.length,
        ),
      );

      final normalized = ReferenceDiscovery.normalizeQuery(query.query);
      for (var rank = 0; rank < returned.length; rank++) {
        final (hit, object) = returned[rank];
        items.add(
          ReferenceContextItem(
            object: object,
            purpose: query.purpose,
            identity: identity!,
            retrieval: ReferenceRetrieval(
              queryIndex: i,
              queryText: query.query,
              normalizedTerms: normalized,
              matchedTerms: hit.matchedTerms,
              score: hit.score,
              rank: rank + 1,
              evidenceRegionIds: query.evidenceRegionIds,
            ),
            symbolBinding:
                object.objectType == SymbolBindingAdapter.symbolObjectType
                    ? _bindingView(s, object)
                    : null,
          ),
        );

        // Reference relationships touching this object, exactly as the
        // runtime defines them (both directions; sorted by id).
        for (final relationship
            in s.runtime.relationshipsForObject(object.id)) {
          if (query.relationshipTypes.isNotEmpty &&
              !query.relationshipTypes
                  .contains(relationship.relationshipType)) {
            continue;
          }
          relationshipIndex
              .putIfAbsent(
                  relationship.id, () => _RelationshipAccumulator(relationship))
              .add(query.purpose.wireName, object.id);
        }
      }
    }

    final relationships = [
      for (final id in (relationshipIndex.keys.toList()..sort()))
        relationshipIndex[id]!.build(),
    ];

    return DiagramInterpretationReferenceContext(
      source: evidence?.source,
      sourceFingerprint: selected?.sourceFingerprint,
      page: evidence?.page,
      ocrPages: selected?.ocrPages ?? const [],
      evidenceRegions: selected?.regions ?? const [],
      evidenceLinks: selected?.links ?? const [],
      candidates: selected?.candidates ?? const [],
      reference: identity,
      items: items,
      relationships: relationships,
      queryOutcomes: outcomes,
    );
  }

  ReferenceSymbolBindingView _bindingView(
    ReferenceKnowledgeSources sources,
    KnowledgeObject symbol,
  ) {
    final adapter = sources.symbolBinding;
    if (adapter == null) {
      return ReferenceSymbolBindingView(
        referenceSymbolId: symbol.id,
        status: SymbolBindingStatus.notEvaluated,
      );
    }
    try {
      final resolved = adapter.resolve(symbol.id);
      return ReferenceSymbolBindingView(
        referenceSymbolId: symbol.id,
        status: SymbolBindingStatus.bound,
        engineSymbolId: resolved.engineSymbolId,
        notes: resolved.binding.notes,
      );
    } on SymbolBindingException catch (e) {
      // A missing binding is valid and explicit; nothing is substituted.
      return ReferenceSymbolBindingView(
        referenceSymbolId: symbol.id,
        status: e.code == SymbolBindingErrorCode.bindingMissing
            ? SymbolBindingStatus.absent
            : SymbolBindingStatus.invalid,
        errorCode: e.code.name,
      );
    }
  }

  _SelectedEvidence _selectEvidence(DiagramEvidenceInput input) {
    final sourceId = input.source.id;
    bool onPage(int page) => input.page == null || input.page == page;

    final ocrPages = input.ocrPages
        .where((p) => p.sourceId == sourceId && onPage(p.page))
        .toList()
      ..sort((a, b) => a.page.compareTo(b.page));

    final fingerprints = {
      for (final p in ocrPages)
        if (p.sourceFingerprint.isNotEmpty) p.sourceFingerprint,
    };
    if (fingerprints.length > 1) {
      throw ReferenceContextException(
        ReferenceContextErrorCode.inconsistentSourceIdentity,
        'OCR results for source "$sourceId" carry different source '
        'fingerprints: ${(fingerprints.toList()..sort()).join(", ")}.',
      );
    }

    final regions = input.evidenceRegions
        .where((r) => r.sourceId == sourceId && onPage(r.page))
        .toList()
      ..sort(_compareRegions);
    final regionIds = {for (final r in regions) r.id};

    final links = input.evidenceLinks
        .where((l) => regionIds.contains(l.regionId))
        .toList()
      ..sort((a, b) {
        final byCandidate = a.candidateId.compareTo(b.candidateId);
        if (byCandidate != 0) return byCandidate;
        final byRegion = a.regionId.compareTo(b.regionId);
        return byRegion != 0 ? byRegion : a.id.compareTo(b.id);
      });
    final candidateIds = {for (final l in links) l.candidateId};
    final candidates = input.candidates
        .where((c) => candidateIds.contains(c.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return _SelectedEvidence(
      sourceFingerprint: fingerprints.isEmpty ? null : fingerprints.single,
      ocrPages: ocrPages,
      regions: regions,
      links: links,
      candidates: candidates,
    );
  }

  static int _compareRegions(EvidenceRegion a, EvidenceRegion b) {
    final byPage = a.page.compareTo(b.page);
    if (byPage != 0) return byPage;
    final byY = a.y.compareTo(b.y);
    if (byY != 0) return byY;
    final byX = a.x.compareTo(b.x);
    return byX != 0 ? byX : a.id.compareTo(b.id);
  }
}

class _SelectedEvidence {
  final String? sourceFingerprint;
  final List<OcrPageResult> ocrPages;
  final List<EvidenceRegion> regions;
  final List<EvidenceLink> links;
  final List<KnowledgeCandidate> candidates;

  const _SelectedEvidence({
    required this.sourceFingerprint,
    required this.ocrPages,
    required this.regions,
    required this.links,
    required this.candidates,
  });
}

class _RelationshipAccumulator {
  final KnowledgeRelationship relationship;
  final Set<String> purposes = {};
  final Set<String> retrievedObjectIds = {};

  _RelationshipAccumulator(this.relationship);

  void add(String purpose, String objectId) {
    purposes.add(purpose);
    retrievedObjectIds.add(objectId);
  }

  ReferenceContextRelationship build() => ReferenceContextRelationship(
        relationship: relationship,
        purposes: purposes.toList()..sort(),
        retrievedObjectIds: retrievedObjectIds.toList()..sort(),
      );
}
