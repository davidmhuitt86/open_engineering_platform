import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/relationship_summary.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import '../../core/theme/studio_typography.dart';
import '../../shared/navigation/explorer_navigation.dart';
import '../../shared/navigation/workspace_aware_navigation.dart';
import '../../shared/widgets/studio_panel_header.dart';
import '../../shared/widgets/studio_search_field.dart';
import '../../shared/widgets/studio_utility_button.dart';
import 'relationship_list_query.dart';

/// The Relationship Explorer (STUDIO-TASK-000009/000011): visibility
/// into the relationships connecting Engineering Objects, read-only.
/// Consumes only the Connection Manager (`foundationRuntimeServiceProvider`)
/// — never the Foundation Bridge directly.
///
/// Backed by live Foundation data since Work Package 006
/// (`FoundationServiceState.relationshipList`, populated via
/// `oep_relationship_store_list`). Sorting and filtering
/// (`RelationshipListQuery`) are applied client-side to whatever
/// Foundation returned — Studio never re-sorts the raw list itself.
class RelationshipsPage extends ConsumerStatefulWidget {
  const RelationshipsPage({super.key});

  @override
  ConsumerState<RelationshipsPage> createState() => _RelationshipsPageState();
}

class _RelationshipsPageState extends ConsumerState<RelationshipsPage> {
  RelationshipListQuery _query = const RelationshipListQuery();

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
              'Open a repository from the Dashboard to browse its relationships.',
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

    final relationships = foundation.relationshipList;
    final visibleRelationships = relationships == null ? null : _query.apply(relationships);
    final selectedRelationship = foundation.selectedRelationship;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioPanelHeader(
          title: 'Relationships',
          icon: Icons.hub_outlined,
          iconColor: StudioColors.selection,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioUtilityButton(
                label: 'Go To Source',
                icon: Icons.north_east,
                onPressed: selectedRelationship == null
                    ? null
                    : () => goToObject(context, ref, selectedRelationship.sourceObjectId),
              ),
              const SizedBox(width: 8),
              StudioUtilityButton(
                label: 'Go To Target',
                icon: Icons.south_east,
                onPressed: selectedRelationship == null
                    ? null
                    : () => goToObject(context, ref, selectedRelationship.targetObjectId),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: StudioSearchField(
                  onChanged: (value) => setState(
                    () => _query = value.isEmpty
                        ? _query.copyWith(clearSourceFilter: true)
                        : _query.copyWith(sourceFilter: value),
                  ),
                  hintText: 'Filter by source…',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StudioSearchField(
                  onChanged: (value) => setState(
                    () => _query = value.isEmpty
                        ? _query.copyWith(clearTargetFilter: true)
                        : _query.copyWith(targetFilter: value),
                  ),
                  hintText: 'Filter by target…',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StudioSearchField(
                  onChanged: (value) => setState(
                    () => _query = value.isEmpty
                        ? _query.copyWith(clearAuthorFilter: true)
                        : _query.copyWith(authorFilter: value),
                  ),
                  hintText: 'Filter by author…',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RelationshipSortField>(
                    value: _query.sortField,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: RelationshipSortField.type, child: Text('Sort: Type')),
                      DropdownMenuItem(value: RelationshipSortField.source, child: Text('Sort: Source')),
                      DropdownMenuItem(value: RelationshipSortField.target, child: Text('Sort: Target')),
                      DropdownMenuItem(value: RelationshipSortField.author, child: Text('Sort: Author')),
                    ],
                    onChanged: (field) {
                      if (field != null) setState(() => _query = _query.copyWith(sortField: field));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _RelationshipListHeader(),
        const Divider(height: 1),
        Expanded(
          child: switch (visibleRelationships) {
            null => const _RelationshipsCouldNotBeLoaded(),
            [] => const _NoRelationshipsFound(),
            final relationships => ListView.builder(
              itemCount: relationships.length,
              itemBuilder: (context, index) {
                final relationship = relationships[index];
                return _RelationshipRow(
                  relationship: relationship,
                  onTap: () => ref.read(foundationRuntimeServiceProvider.notifier).selectRelationship(relationship),
                  onDoubleTapSource: () => goToObject(context, ref, relationship.sourceObjectId),
                  onDoubleTapTarget: () => goToObject(context, ref, relationship.targetObjectId),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}

class _RelationshipsCouldNotBeLoaded extends StatelessWidget {
  const _RelationshipsCouldNotBeLoaded();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Relationships couldn\'t be loaded for this repository.',
        style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _NoRelationshipsFound extends StatelessWidget {
  const _NoRelationshipsFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hub_outlined, size: 40, color: StudioColors.textDisabled),
          const SizedBox(height: 16),
          const Text(
            'No Relationships Found',
            style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Relationships connect Engineering Objects together. '
              'They will appear here once created — future editing tools '
              'will let you define them directly within Studio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipListHeader extends StatelessWidget {
  const _RelationshipListHeader();

  @override
  Widget build(BuildContext context) {
    const style = StudioTypography.fieldLabel;
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24),
          Expanded(flex: 2, child: Text('TYPE', style: style)),
          Expanded(flex: 3, child: Text('SOURCE', style: style)),
          Expanded(flex: 3, child: Text('TARGET', style: style)),
          Expanded(flex: 2, child: Text('AUTHOR', style: style)),
        ],
      ),
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({
    required this.relationship,
    required this.onTap,
    required this.onDoubleTapSource,
    required this.onDoubleTapTarget,
  });

  final RelationshipSummary relationship;
  final VoidCallback onTap;

  /// Double-clicking the Source cell navigates to the Source Object
  /// (STUDIO-TASK-000011 "Relationship Navigation") — the same
  /// destination as the "Go To Source" toolbar button.
  final VoidCallback onDoubleTapSource;
  final VoidCallback onDoubleTapTarget;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Icon(relationship.type.icon, size: 15, color: StudioColors.textSecondary)),
              Expanded(
                flex: 2,
                child: Text(
                  relationship.type.label,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 3,
                child: InkWell(
                  onDoubleTap: onDoubleTapSource,
                  child: Text(
                    relationship.sourceObjectName,
                    style: StudioTheme.monoTextStyle,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: InkWell(
                  onDoubleTap: onDoubleTapTarget,
                  child: Text(
                    relationship.targetObjectName,
                    style: StudioTheme.monoTextStyle,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  relationship.author,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
