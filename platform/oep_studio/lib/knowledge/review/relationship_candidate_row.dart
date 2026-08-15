import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import 'relationship_candidate_list_query.dart';

/// One row in the Relationship Candidate view (Work Package 008
/// STUDIO-TASK-000017 Relationship View: "Display: Source, Relationship
/// Type, Target"). Only Edit/Delete — relationship candidates carry no
/// accept/reject status (see `RelationshipCandidate`'s doc comment).
class RelationshipCandidateRow extends StatelessWidget {
  const RelationshipCandidateRow({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ResolvedRelationshipCandidate entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final relationship = entry.relationship;
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.sourceName, overflow: TextOverflow.ellipsis, style: StudioTheme.monoTextStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  relationship.type.label,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(entry.targetName, overflow: TextOverflow.ellipsis, style: StudioTheme.monoTextStyle),
              ),
              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 16), onPressed: onEdit),
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 16), onPressed: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}
