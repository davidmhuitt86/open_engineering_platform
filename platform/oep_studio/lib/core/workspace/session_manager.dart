import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../knowledge/services/knowledge_session_storage.dart';
import '../routing/studio_destination.dart';
import '../services/foundation_runtime_service.dart';
import 'workspace_manager.dart';

/// Reads the Knowledge Session listing `SessionManager.listAll` merges
/// in — a real `Future<SessionBrowserListing>` in production
/// (`FoundationRuntimeNotifier.listKnowledgeSessions`), and injectable
/// in tests so they never depend on whatever Knowledge Sessions
/// genuinely exist on disk (which can be large — real, meaningful
/// project data this class must never assume is small or disposable).
typedef KnowledgeSessionsLoader = Future<SessionBrowserListing> Function();

/// One entry in [SessionManager.listAll] — a small, read-only summary
/// of a workspace/session that exists somewhere in the Platform,
/// regardless of which Studio owns its actual persistence.
class WorkspaceSessionSummary {
  const WorkspaceSessionSummary({
    required this.destination,
    required this.label,
    required this.identifier,
    this.lastModified,
  });

  /// Which Studio owns this session/workspace.
  final StudioDestination destination;

  /// Human-readable name — a session's own name, or a document's file
  /// path for Diagram Studio (which has no separate "name," only a
  /// path).
  final String label;

  /// The identifier the owning Studio would use to reopen this
  /// (a Knowledge Session id, or a Diagram document path).
  final String identifier;

  /// `null` for a Diagram workspace — the recent-workspace list
  /// (`WorkspaceManager`) doesn't track modification times, only paths.
  final DateTime? lastModified;
}

/// A thin, read-only aggregator (WP-STUDIO-029) over every Studio's own
/// existing session/workspace list — Knowledge Studio's Curation
/// Sessions (`FoundationRuntimeNotifier.listKnowledgeSessions`) and
/// Diagram Studio's recent documents (`WorkspaceManager.recentWorkspaces`).
///
/// [SessionManager] owns no persistence of its own and duplicates
/// neither Studio's storage — it only merges what each already exposes
/// into one list, for a future cross-Studio "Recent Workspaces" surface
/// (not built by this Work Package) to eventually read. Acquisition
/// Studio contributes nothing here: its state lives server-side, not as
/// a local file/session a user opens and closes.
abstract final class SessionManager {
  /// Every known Knowledge Curation Session plus every recently opened
  /// Diagram document, most-recently-touched first within each group
  /// (Knowledge sessions by [WorkspaceSessionSummary.lastModified],
  /// Diagram workspaces in [WorkspaceManager.recentWorkspaces]'s own
  /// order), Knowledge sessions listed before Diagram workspaces.
  ///
  /// Propagates whatever `FoundationBridgeException`
  /// `listKnowledgeSessions` itself would — this class adds no error
  /// handling of its own on top of what Foundation's runtime service
  /// already provides.
  static Future<List<WorkspaceSessionSummary>> listAll(
    WidgetRef ref, {
    WorkspaceManager? workspaceManager,
    KnowledgeSessionsLoader? knowledgeSessionsLoader,
  }) async {
    final loadKnowledgeSessions =
        knowledgeSessionsLoader ?? ref.read(foundationRuntimeServiceProvider.notifier).listKnowledgeSessions;
    final listing = await loadKnowledgeSessions();

    final knowledgeSummaries = [
      for (final record in listing.sessions)
        WorkspaceSessionSummary(
          destination: StudioDestination.knowledge,
          label: record.session.name,
          identifier: record.session.id,
          lastModified: record.session.lastModified,
        ),
    ]..sort((a, b) => b.lastModified!.compareTo(a.lastModified!));

    final manager = workspaceManager ?? WorkspaceManager.instance;
    final diagramSummaries = [
      for (final path in manager.recentWorkspaces)
        WorkspaceSessionSummary(
          destination: StudioDestination.diagram,
          label: path,
          identifier: path,
        ),
    ];

    return [...knowledgeSummaries, ...diagramSummaries];
  }
}
