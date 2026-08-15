import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/search_scope.dart';
import '../../core/models/unified_search_result.dart';
import '../../core/routing/studio_registry.dart';

/// Merges every registered Studio's search contribution into one result
/// list (WORK_PACKAGE_025, ENGINE-TASK-000121 "Shared Search"; EAM
/// contribution added WP-PLAT-020). As of WP-STUDIO-021, this class no
/// longer knows about Foundation, the Engineering Engine, or EAM
/// individually — each Studio's search logic now lives behind its own
/// [StudioSearchProvider], registered on [StudioRegistry.defaultRegistry]
/// alongside that Studio's route and settings page. This class is purely
/// the merge-and-order step; see `studio_registry.dart` for what each
/// Studio actually searches.
abstract final class UnifiedSearchService {
  /// Runs [query] against every Studio registered on
  /// [StudioRegistry.defaultRegistry] that contributes a search
  /// provider, concatenating all result sets in registration order
  /// (Knowledge, then Diagram, then Acquisition today — never
  /// reordered/interleaved). Propagates `FoundationBridgeException` on
  /// a failed Knowledge/Foundation search exactly as before this
  /// refactor — callers keep their own existing error-dialog handling.
  static List<UnifiedSearchResult> search(
    WidgetRef ref, {
    required String query,
    SearchScope scope = SearchScope.repository,
  }) {
    final results = <UnifiedSearchResult>[];
    for (final provider in StudioRegistry.defaultRegistry.searchProviders) {
      results.addAll(provider(ref, query, scope));
    }
    return results;
  }
}
