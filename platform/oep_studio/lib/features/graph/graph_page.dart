import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/navigation/workspace_aware_navigation.dart';
import '../../shared/widgets/studio_panel_header.dart';
import '../../shared/widgets/studio_search_field.dart';
import 'engineering_graph_view.dart';

/// The Knowledge Graph (Phase 5): a real visualization of Engineering
/// Objects and Relationships from the connected repository --
/// `FoundationServiceState.objectList`/`relationshipList`, the same
/// Foundation-provided data the Repository/Objects/Relationships pages
/// already read, not a separate or fabricated data source. Node
/// selection drives the same `FoundationRuntimeNotifier.selectObject`
/// every other Studio page uses, so the shared, shell-level Property
/// Inspector shows the selected object without this page needing its
/// own inspector.
///
/// **Backend limitation, disclosed rather than worked around**: this
/// app has no "Candidate Engineering Object" (AI-generated, pre-commit)
/// concept anywhere in its backend today -- only committed,
/// Foundation-confirmed Objects/Relationships exist once a repository
/// is open. This page shows exactly that real data, honestly empty
/// when none exists, never a fabricated demonstration graph.
class GraphPage extends ConsumerStatefulWidget {
  const GraphPage({super.key});

  @override
  ConsumerState<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<GraphPage> {
  final _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    if (!foundation.isRepositoryOpen) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'No Repository Open',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a repository from the Dashboard to visualize its Engineering Objects.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openOrActivateDestination(context, ref, StudioDestination.dashboard),
              child: const Text('Open Repository'),
            ),
          ],
        ),
      );
    }

    final objects = foundation.objectList ?? const [];
    if (objects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 48, color: StudioColors.textDisabled),
            SizedBox(height: 16),
            Text(
              'No Engineering Objects Yet',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'This repository has no Engineering Objects to graph yet.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final relationships = foundation.relationshipList ?? const [];
    final visibleObjects = _filter.isEmpty
        ? objects
        : objects.where((object) => object.name.toLowerCase().contains(_filter.toLowerCase())).toList();
    final visibleIds = visibleObjects.map((object) => object.objectId).toSet();
    final visibleRelationships =
        relationships.where((r) => visibleIds.contains(r.sourceObjectId) && visibleIds.contains(r.targetObjectId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioPanelHeader(
          title: 'Knowledge Graph',
          icon: Icons.hub_outlined,
          iconColor: StudioColors.selection,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${objects.length} object(s) · ${relationships.length} relationship(s)',
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                child: StudioSearchField(
                  controller: _filterController,
                  onChanged: (value) => setState(() => _filter = value),
                  hintText: 'Filter by name…',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleObjects.isEmpty
              ? const Center(
                  child: Text('No objects match this filter.', style: TextStyle(color: StudioColors.textSecondary)),
                )
              : Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: StudioColors.surfaceSunken,
                    border: Border.all(color: StudioColors.borderSubtle),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: EngineeringGraphView(
                    objects: visibleObjects,
                    relationships: visibleRelationships,
                    selectedObjectId: foundation.selectedObject?.objectId,
                    onSelectObject: (object) => ref.read(foundationRuntimeServiceProvider.notifier).selectObject(object),
                  ),
                ),
        ),
      ],
    );
  }
}
