import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../models/candidate_validation_result.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_status.dart';

/// One row in the Engineering Review panel's Knowledge Candidate list
/// (Work Package 007/008: "Each proposal supports: Accept, Reject,
/// Edit, Delete"; Work Package 010: "Display: ... Validation Status,
/// Linked Evidence Count. Support: ... Duplicate").
class KnowledgeCandidateRow extends StatelessWidget {
  const KnowledgeCandidateRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    this.linkedToSelectedEvidence = false,
    this.validation,
    this.linkedEvidenceCount = 0,
    super.key,
  });

  final KnowledgeCandidate candidate;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Work Package 010 Candidate List: "Duplicate".
  final VoidCallback onDuplicate;

  /// Whether this candidate is linked to the currently-selected Evidence
  /// Region (Work Package 009 § Source Viewer Interaction: "Selecting
  /// Evidence Region → Highlights linked Knowledge Candidates").
  final bool linkedToSelectedEvidence;

  /// This candidate's computed validation result (Work Package 010
  /// STUDIO-TASK-000025), `null` only if no session's `candidateValidation`
  /// map has an entry for it yet (should not normally occur).
  final CandidateValidationResult? validation;

  /// How many Evidence Regions are linked to this candidate (Work
  /// Package 010 Candidate List: "Linked Evidence Count").
  final int linkedEvidenceCount;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? StudioColors.selection
        : (linkedToSelectedEvidence ? StudioColors.warning : null);
    return Material(
      color: color?.withValues(alpha: 0.10) ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Row(
            children: [
              Icon(candidate.type.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            candidate.type.label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.link, size: 11, color: StudioColors.textSecondary),
                        Text(
                          ' $linkedEvidenceCount',
                          style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (validation != null) _ValidationBadge(validation: validation!),
              const SizedBox(width: 6),
              _StatusBadge(status: candidate.status),
              if (candidate.isCommitted) ...[const SizedBox(width: 6), _CommittedBadge(candidate: candidate)],
              // `padding`/`constraints` shrink each button from Material's
              // default 48x48 tap target — five full-size IconButtons plus
              // the badges above no longer fit this row at the app's
              // documented minimum window width (1000 logical pixels,
              // `windows/runner/win32_window.cpp`) once Work Package 010
              // added a fifth (Duplicate) button; caught by Work Package
              // 011's window-resizing verification.
              IconButton(
                tooltip: 'Accept',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                color: StudioColors.success,
                onPressed: onAccept,
              ),
              IconButton(
                tooltip: 'Reject',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                color: StudioColors.error,
                onPressed: onReject,
              ),
              IconButton(
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Duplicate',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_outlined, size: 16),
                onPressed: onDuplicate,
              ),
              IconButton(
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  minimumSize: const Size(30, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationBadge extends StatelessWidget {
  const _ValidationBadge({required this.validation});

  final CandidateValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (validation.severity) {
      ValidationSeverity.error => (Icons.error_outline, StudioColors.error),
      ValidationSeverity.warning => (Icons.warning_amber_outlined, StudioColors.warning),
      ValidationSeverity.ok => (Icons.check_circle_outline, StudioColors.success),
    };
    return Tooltip(
      message: validation.issues.isEmpty ? 'No validation issues.' : validation.issues.join('\n'),
      child: Icon(icon, size: 15, color: color),
    );
  }
}

/// Marks a candidate that has already been committed to Foundation
/// (Work Package 012) — "Knowledge Candidates remain in the Knowledge
/// Session after commit," so a committed candidate still shows up here
/// but should read as already-in-Foundation rather than pending.
class _CommittedBadge extends StatelessWidget {
  const _CommittedBadge({required this.candidate});

  final KnowledgeCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Committed to Foundation as ${candidate.committedObjectId}',
      child: const Icon(Icons.cloud_done_outlined, size: 14, color: StudioColors.info),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final KnowledgeCandidateStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      KnowledgeCandidateStatus.accepted => StudioColors.success,
      KnowledgeCandidateStatus.rejected => StudioColors.error,
      KnowledgeCandidateStatus.pending => StudioColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}
