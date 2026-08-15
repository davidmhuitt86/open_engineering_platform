import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/ai_suggestion_status.dart';
import '../review/engineering_review_panel.dart';
import '../sessions/session_header.dart';
import '../widgets/knowledge_panel.dart';
import '../widgets/knowledge_placeholder.dart';
import 'commit_preview_panel.dart';
import 'import_queue_panel.dart';
import 'source_viewer_panel.dart';

/// The Knowledge Studio workspace (Work Package 007 STUDIO-TASK-000013;
/// Work Package 008; SDD-013, SDD-016). Registers as a Studio workspace
/// like every other Primary Workspace page — same Navigation Rail,
/// Connection Manager, theme, and window layout (`StudioShell`), per
/// this work package's Navigation requirement: "No separate application
/// shall be created."
///
/// Import Queue, Source Viewer, Engineering Review, and Commit Summary
/// carry real functionality as of Work Package 008; AI Suggestions as
/// of Work Package 016 (a session-wide status summary — the actual
/// per-source review workflow lives in the AI Review Workspace dialog,
/// opened from the OCR Layer Viewer, the same "frozen panel shows a
/// summary, a dialog carries the actual workflow" split every other
/// evidence-review surface since Work Package 013 already uses).
/// Repository Matches remains placeholder content — repository
/// matching has no Public C API surface yet, see
/// `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations.
class KnowledgeStudioPage extends StatelessWidget {
  const KnowledgeStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SessionHeader(),
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'Import Queue',
                        icon: Icons.upload_file_outlined,
                        child: ImportQueuePanel(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'Source Viewer',
                        icon: Icons.visibility_outlined,
                        child: SourceViewerPanel(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'AI Suggestions',
                        icon: Icons.auto_awesome_outlined,
                        child: _AiSuggestionsSummary(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Expanded(
                      child: KnowledgePanel(
                        title: 'Repository Matches',
                        icon: Icons.compare_arrows_outlined,
                        child: KnowledgePlaceholder(
                          message: 'Possible existing repository matches will appear here.',
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: KnowledgePanel(
                        title: 'Engineering Review',
                        icon: Icons.fact_check_outlined,
                        child: const EngineeringReviewPanel(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 2,
                child: KnowledgePanel(
                  title: 'Commit Summary',
                  icon: Icons.summarize_outlined,
                  child: const CommitPreviewPanel(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The "AI Suggestions" panel's own content (Work Package 016) — a
/// session-wide status summary, not the review workflow itself (that
/// lives in the per-source AI Review Workspace dialog, reached from
/// the OCR Layer Viewer's "AI Suggestions" toolbar button — the same
/// split every other evidence-review surface already uses: a small
/// summary in the frozen panel, the actual workflow in a dialog).
class _AiSuggestionsSummary extends ConsumerWidget {
  const _AiSuggestionsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final suggestions = foundation.aiSuggestions;
    if (suggestions.isEmpty) {
      return const KnowledgePlaceholder(
        message:
            'No AI Suggestions yet. Open a source\'s OCR Layer Viewer, '
            'then "AI Suggestions," to run analysis.',
      );
    }
    final counts = <AiSuggestionStatus, int>{};
    for (final suggestion in suggestions) {
      counts[suggestion.status] = (counts[suggestion.status] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${suggestions.length} total suggestion(s)', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
          const SizedBox(height: 8),
          for (final status in AiSuggestionStatus.values)
            if (counts[status] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${_statusLabel(status)}: ${counts[status]}',
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                ),
              ),
          const SizedBox(height: 8),
          const Text(
            'Open a source\'s OCR Layer Viewer, then "AI Suggestions," to review.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(AiSuggestionStatus status) {
    switch (status) {
      case AiSuggestionStatus.pending:
        return 'Pending';
      case AiSuggestionStatus.accepted:
        return 'Accepted';
      case AiSuggestionStatus.edited:
        return 'Edited';
      case AiSuggestionStatus.rejected:
        return 'Rejected';
      case AiSuggestionStatus.deferred:
        return 'Deferred';
    }
  }
}
