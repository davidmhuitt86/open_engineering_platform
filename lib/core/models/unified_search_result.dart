import 'package:flutter/material.dart' show IconData, Icons;
import 'package:engineering_engine/engineering_engine.dart' as engine;

import 'search_result.dart' as foundation;

/// Which system a [UnifiedSearchResult] actually came from — needed
/// because Foundation's `SearchProvider`, the Engineering Engine's
/// `SearchProvider` (WORK_PACKAGE_025, ENGINE-TASK-000121), and EAM's
/// own REST-backed lists (WP-PLAT-020) are three entirely separate,
/// unmodified systems being *merged for display* here, not unified into
/// one search implementation. EAM has no full-text search endpoint of
/// its own (see `docs/API_REFERENCE.md`) — its contribution is a
/// best-effort, client-side filter over already-cached Sources/Jobs/
/// Vault entries, documented as such in `UnifiedSearchService`.
enum UnifiedSearchOrigin { foundation, engine, acquisition, exchange }

/// What kind of thing a [UnifiedSearchResult] points at, in a form
/// `unified_navigation.dart` can switch on without importing either
/// underlying (and confusingly same-named) `SearchResultKind` enum
/// itself — computed once, here, where both are already disambiguated
/// via import prefixes.
enum UnifiedSearchResultCategory {
  knowledgeObject,
  knowledgeRelationship,
  diagramNode,
  diagramRelationship,
  symbol,
  annotation,
  layer,
  acquisitionSource,
  acquisitionJob,
  acquisitionVaultEntry,
  exchangePackage,
  exchangePublisher,
}

/// A single row in the unified Search page (WORK_PACKAGE_025,
/// ENGINE-TASK-000121) — wraps whichever of the two pre-existing,
/// completely unrelated `SearchResult` types actually produced a match:
///
/// * `oep_studio`'s own `SearchResult` (`lib/core/models/search_result.dart`)
///   — decodes Foundation's native `oep_object_search_result_t`/
///   `oep_relationship_search_result_t` structs directly.
/// * `oep_engine`'s own `SearchResult` (`package:engineering_engine`) —
///   Engineering Graph/Diagram Layout search (nodes, relationships,
///   symbols, annotations, layers).
///
/// Neither source type is renamed, merged, or otherwise touched —
/// see `docs/UNIFIED_SEARCH.md` for why. This class only adds the
/// three fields WORK_PACKAGE_025 requires every result to carry:
/// [objectTypeLabel], [owningWorkspaceLabel], [repositoryLocation].
class UnifiedSearchResult {
  const UnifiedSearchResult._({
    required this.origin,
    required this.category,
    required this.id,
    required this.label,
    required this.objectTypeLabel,
    required this.owningWorkspaceLabel,
    required this.repositoryLocation,
    this.foundationResult,
    this.engineResult,
  });

  final UnifiedSearchOrigin origin;
  final UnifiedSearchResultCategory category;
  final String id;
  final String label;
  final String objectTypeLabel;
  final String owningWorkspaceLabel;
  final String repositoryLocation;

  /// Set only when [origin] is [UnifiedSearchOrigin.foundation].
  final foundation.SearchResult? foundationResult;

  /// Set only when [origin] is [UnifiedSearchOrigin.engine].
  final engine.SearchResult? engineResult;

  factory UnifiedSearchResult.fromFoundation(
    foundation.SearchResult result, {
    required String repositoryLocation,
  }) {
    return UnifiedSearchResult._(
      origin: UnifiedSearchOrigin.foundation,
      category: switch (result.kind) {
        foundation.SearchResultKind.object => UnifiedSearchResultCategory.knowledgeObject,
        foundation.SearchResultKind.relationship => UnifiedSearchResultCategory.knowledgeRelationship,
      },
      id: result.id,
      label: result.name,
      objectTypeLabel: result.typeLabel,
      owningWorkspaceLabel: 'Knowledge Studio',
      repositoryLocation: repositoryLocation,
      foundationResult: result,
    );
  }

  factory UnifiedSearchResult.fromEngine(
    engine.SearchResult result, {
    required String repositoryLocation,
  }) {
    return UnifiedSearchResult._(
      origin: UnifiedSearchOrigin.engine,
      category: switch (result.kind) {
        engine.SearchResultKind.node => UnifiedSearchResultCategory.diagramNode,
        engine.SearchResultKind.relationship => UnifiedSearchResultCategory.diagramRelationship,
        engine.SearchResultKind.symbol => UnifiedSearchResultCategory.symbol,
        engine.SearchResultKind.annotation => UnifiedSearchResultCategory.annotation,
        engine.SearchResultKind.layer => UnifiedSearchResultCategory.layer,
      },
      id: result.id,
      label: result.label,
      objectTypeLabel: _engineKindLabel(result.kind),
      owningWorkspaceLabel: 'Diagram Studio',
      repositoryLocation: repositoryLocation,
      engineResult: result,
    );
  }

  /// Builds a result for one of EAM's Sources/Jobs/Vault entries
  /// (WP-PLAT-020). Unlike [fromFoundation]/[fromEngine], there is no
  /// wrapped EAM-native result type to carry — EAM has no search
  /// concept of its own for this to wrap; [id]/[label] are read
  /// straight from the already-fetched `AcquisitionServiceState` list
  /// entry that matched.
  factory UnifiedSearchResult.fromAcquisition({
    required UnifiedSearchResultCategory category,
    required String id,
    required String label,
    required String objectTypeLabel,
  }) {
    return UnifiedSearchResult._(
      origin: UnifiedSearchOrigin.acquisition,
      category: category,
      id: id,
      label: label,
      objectTypeLabel: objectTypeLabel,
      owningWorkspaceLabel: 'Engineering Acquisition',
      repositoryLocation: 'Engineering Acquisition',
    );
  }

  /// Builds a result for one of the Exchange's Marketplace
  /// packages/publishers (WP-EXC-010). Unlike [fromFoundation]/
  /// [fromEngine], and exactly like [fromAcquisition], there is no
  /// wrapped Exchange-native result type to carry -- [id]/[label] are
  /// read straight from the already-fetched `ExchangeServiceState` list
  /// entry that matched.
  factory UnifiedSearchResult.fromExchange({
    required UnifiedSearchResultCategory category,
    required String id,
    required String label,
    required String objectTypeLabel,
  }) {
    return UnifiedSearchResult._(
      origin: UnifiedSearchOrigin.exchange,
      category: category,
      id: id,
      label: label,
      objectTypeLabel: objectTypeLabel,
      owningWorkspaceLabel: 'Engineering Exchange',
      repositoryLocation: 'Engineering Exchange',
    );
  }

  IconData get icon => switch (category) {
        UnifiedSearchResultCategory.knowledgeObject => Icons.category_outlined,
        UnifiedSearchResultCategory.knowledgeRelationship => Icons.hub_outlined,
        UnifiedSearchResultCategory.diagramNode => Icons.widgets_outlined,
        UnifiedSearchResultCategory.diagramRelationship => Icons.polyline_outlined,
        UnifiedSearchResultCategory.symbol => Icons.category_outlined,
        UnifiedSearchResultCategory.annotation => Icons.sticky_note_2_outlined,
        UnifiedSearchResultCategory.layer => Icons.layers_outlined,
        UnifiedSearchResultCategory.acquisitionSource => Icons.verified_outlined,
        UnifiedSearchResultCategory.acquisitionJob => Icons.assignment_outlined,
        UnifiedSearchResultCategory.acquisitionVaultEntry => Icons.inventory_2_outlined,
        UnifiedSearchResultCategory.exchangePackage => Icons.inventory_2_outlined,
        UnifiedSearchResultCategory.exchangePublisher => Icons.storefront_outlined,
      };

  static String _engineKindLabel(engine.SearchResultKind kind) {
    switch (kind) {
      case engine.SearchResultKind.node:
        return 'Diagram Node';
      case engine.SearchResultKind.relationship:
        return 'Diagram Relationship';
      case engine.SearchResultKind.symbol:
        return 'Symbol';
      case engine.SearchResultKind.annotation:
        return 'Annotation';
      case engine.SearchResultKind.layer:
        return 'Layer';
    }
  }
}
