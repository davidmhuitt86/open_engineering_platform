import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../models/knowledge_session.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/session_status.dart';
import '../workspaces/knowledge_graph_dialog.dart';
import 'new_session_dialog.dart';
import 'session_browser_dialog.dart';

/// The Knowledge Studio session header: shows the active session's
/// name/status/counts and the controls to advance or cancel it (Work
/// Package 007 Session Workflow), open the Session Browser, close the
/// active session, or create one (Work Package 008). A dismissible
/// banner surfaces [FoundationServiceState.knowledgeStorageError] when
/// the most recent autosave or Session Browser action failed.
class SessionHeader extends ConsumerWidget {
  const SessionHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final session = foundation.knowledgeSession;
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: StudioColors.surface,
            border: Border(bottom: BorderSide(color: StudioColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 18, color: StudioColors.selection),
                  const SizedBox(width: 10),
                  Expanded(
                    child: session == null
                        ? const Text(
                            'No Knowledge Curation Session',
                            style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
                          )
                        : _SessionSummary(session: session, foundation: foundation),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => showSessionBrowserDialog(context),
                    child: const Text('Sessions'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => showNewSessionDialog(context), child: const Text('New Session')),
                ],
              ),
              if (session != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: _actions(context, notifier, session)),
              ],
            ],
          ),
        ),
        if (foundation.knowledgeStorageError != null)
          _StorageErrorBanner(
            message: foundation.knowledgeStorageError!,
            onDismiss: notifier.clearKnowledgeStorageError,
          ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, FoundationRuntimeNotifier notifier, KnowledgeSession session) {
    final next = _nextStatus(session.status);
    return [
      OutlinedButton(
        onPressed: () => showKnowledgeGraphDialog(context),
        child: const Text('Knowledge Graph'),
      ),
      if (next != null)
        OutlinedButton(
          onPressed: () => _advance(context, notifier, next),
          child: Text(_advanceLabel(next)),
        ),
      if (session.status != SessionStatus.cancelled)
        OutlinedButton(
          onPressed: () => _advance(context, notifier, SessionStatus.cancelled),
          style: OutlinedButton.styleFrom(foregroundColor: StudioColors.error),
          child: const Text('Cancel Session'),
        ),
      IconButton(
        tooltip: 'Close Session',
        icon: const Icon(Icons.close, size: 18),
        onPressed: notifier.closeKnowledgeSession,
      ),
    ];
  }

  void _advance(BuildContext context, FoundationRuntimeNotifier notifier, SessionStatus to) {
    try {
      notifier.advanceKnowledgeSession(to);
    } on KnowledgeValidationException catch (error) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text('Couldn\'t Update Session'),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  static SessionStatus? _nextStatus(SessionStatus current) => switch (current) {
    SessionStatus.created => SessionStatus.preparing,
    SessionStatus.preparing => SessionStatus.reviewing,
    SessionStatus.reviewing => SessionStatus.readyToCommit,
    SessionStatus.readyToCommit || SessionStatus.cancelled => null,
  };

  static String _advanceLabel(SessionStatus next) => switch (next) {
    SessionStatus.preparing => 'Start Preparing',
    SessionStatus.reviewing => 'Start Review',
    SessionStatus.readyToCommit => 'Mark Ready to Commit',
    SessionStatus.created || SessionStatus.cancelled => next.label,
  };
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session, required this.foundation});

  final KnowledgeSession session;
  final FoundationServiceState foundation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            session.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        _StatusChip(status: session.status),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            'Candidates: ${foundation.knowledgeCandidateCount}  '
            'Accepted: ${foundation.knowledgeAcceptedCount}  '
            'Rejected: ${foundation.knowledgeRejectedCount}  '
            'Pending: ${foundation.knowledgePendingCount}  '
            'Relationships: ${foundation.knowledgeRelationshipCandidateCount}  '
            'Sources: ${foundation.knowledgeSourceCount}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _StorageErrorBanner extends StatelessWidget {
  const _StorageErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: StudioColors.error.withValues(alpha: 0.14),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: StudioColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 15),
            color: StudioColors.error,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SessionStatus.created => StudioColors.info,
      SessionStatus.preparing => StudioColors.warning,
      SessionStatus.reviewing => StudioColors.selection,
      SessionStatus.readyToCommit => StudioColors.success,
      SessionStatus.cancelled => StudioColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}
