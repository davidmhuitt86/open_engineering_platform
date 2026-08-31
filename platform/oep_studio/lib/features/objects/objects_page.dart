import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/engineering_object_summary.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import '../../core/theme/studio_typography.dart';
import '../../shared/navigation/workspace_aware_navigation.dart';
import '../../shared/widgets/studio_panel_header.dart';
import '../../shared/widgets/studio_search_field.dart';
import 'object_list_query.dart';

/// The Object Explorer (STUDIO-TASK-000006/008): displays Engineering
/// Objects within the Repository Explorer category currently selected
/// in the Connection Manager, from `FoundationServiceState.objectList`
/// (Work Package 004's Current Object List, populated via
/// `oep_object_store_list`). Read-only browsing only — no creation,
/// editing, or deletion. Sorting and filtering remain Studio
/// responsibilities (`ObjectListQuery`), applied client-side to
/// whatever Foundation returned — Studio never re-sorts or re-derives
/// counts Foundation already computed.
class ObjectsPage extends ConsumerStatefulWidget {
  const ObjectsPage({super.key});

  @override
  ConsumerState<ObjectsPage> createState() => _ObjectsPageState();
}

class _ObjectsPageState extends ConsumerState<ObjectsPage> {
  ObjectListQuery _query = const ObjectListQuery();

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final category = foundation.selectedCategory;

    if (category == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'No Category Selected',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a category in the Repository Explorer to browse its objects.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openOrActivateDestination(context, ref, StudioDestination.repository),
              child: const Text('Go to Repository Explorer'),
            ),
          ],
        ),
      );
    }

    final objectsInCategory = foundation.objectsInSelectedCategory;
    final visibleObjects = objectsInCategory == null ? null : _query.apply(objectsInCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioPanelHeader(title: category.label, icon: category.icon, iconColor: StudioColors.selection),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: StudioSearchField(
                  onChanged: (value) => setState(() => _query = _query.copyWith(searchText: value)),
                  hintText: 'Filter objects…',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ObjectSortField>(
                    value: _query.sortField,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: ObjectSortField.name, child: Text('Sort: Name')),
                      DropdownMenuItem(value: ObjectSortField.type, child: Text('Sort: Type')),
                      DropdownMenuItem(value: ObjectSortField.author, child: Text('Sort: Author')),
                    ],
                    onChanged: (field) {
                      if (field != null) setState(() => _query = _query.copyWith(sortField: field));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    onChanged: (value) => setState(
                      () => _query = value.isEmpty
                          ? _query.copyWith(clearAuthorFilter: true)
                          : _query.copyWith(authorFilter: value),
                    ),
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Filter by author…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _ObjectListHeader(),
        const Divider(height: 1),
        Expanded(
          child: switch (visibleObjects) {
            null => const Center(
              child: Text(
                'Objects couldn\'t be loaded for this repository.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
              ),
            ),
            [] => const Center(
              child: Text(
                'No objects found in this category.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
              ),
            ),
            final objects => ListView.builder(
              itemCount: objects.length,
              itemBuilder: (context, index) {
                final object = objects[index];
                return _ObjectRow(
                  object: object,
                  onTap: () => ref.read(foundationRuntimeServiceProvider.notifier).selectObject(object),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}

class _ObjectListHeader extends StatelessWidget {
  const _ObjectListHeader();

  @override
  Widget build(BuildContext context) {
    const style = StudioTypography.fieldLabel;
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24),
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('TYPE', style: style)),
          Expanded(flex: 2, child: Text('AUTHOR', style: style)),
          Expanded(flex: 1, child: Text('VERSION', style: style)),
        ],
      ),
    );
  }
}

class _ObjectRow extends StatelessWidget {
  const _ObjectRow({required this.object, required this.onTap});

  final EngineeringObjectSummary object;
  final VoidCallback onTap;

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
              SizedBox(width: 24, child: Icon(object.category.icon, size: 15, color: StudioColors.textSecondary)),
              Expanded(
                flex: 3,
                child: Text(object.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  object.category.label,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(object.author, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  object.version,
                  style: StudioTheme.monoTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
