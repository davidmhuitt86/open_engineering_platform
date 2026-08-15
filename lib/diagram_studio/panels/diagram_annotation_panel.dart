import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/oep_list_view.dart';

/// Annotation panel — a flat list of every Diagram Layout annotation,
/// tap to select, double-tap to edit its text (WORK_PACKAGE_024,
/// ENGINE-TASK-000114; `oep_engine/docs/ANNOTATION_SYSTEM.md`).
class DiagramAnnotationPanel extends StatelessWidget {
  const DiagramAnnotationPanel({
    required this.annotations,
    required this.selectedAnnotationIds,
    required this.onSelectAnnotation,
    required this.onEditAnnotation,
    required this.onDeleteAnnotation,
    super.key,
  });

  final List<DiagramAnnotation> annotations;
  final Set<String> selectedAnnotationIds;
  final void Function(String annotationId) onSelectAnnotation;
  final void Function(String annotationId) onEditAnnotation;
  final void Function(String annotationId) onDeleteAnnotation;

  @override
  Widget build(BuildContext context) {
    return OEPListView(
      items: annotations,
      emptyMessage: 'No annotations yet. Add one from the Annotations toolbar.',
      itemBuilder: (context, annotation) {
        final isSelected = selectedAnnotationIds.contains(annotation.id);
        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            selected: isSelected,
            selectedTileColor: StudioColors.selectedRowBackground,
            title: Text(
              annotation.text.isEmpty ? '(empty)' : annotation.text,
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              annotation.type.name,
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
            ),
            onTap: () => onSelectAnnotation(annotation.id),
            onLongPress: () => onEditAnnotation(annotation.id),
            trailing: IconButton(
              iconSize: 16,
              tooltip: 'Delete annotation',
              icon: const Icon(Icons.delete_outline, color: StudioColors.error),
              onPressed: () => onDeleteAnnotation(annotation.id),
            ),
          ),
        );
      },
    );
  }
}
