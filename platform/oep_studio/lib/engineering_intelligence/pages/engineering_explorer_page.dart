import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge.dart';
import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/models/engineering_object_summary.dart';
import '../../core/models/object_category.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/ei_widgets.dart';

/// Engineering Explorer (WP-EKE-008): browses Engineering Objects,
/// Relationships, Packages, Publishers, Knowledge Domains, and
/// Engineering Types, and lets the user navigate through semantic
/// relationships by tapping a related object.
///
/// Object enumeration reuses `FoundationRuntimeService.objectList` (the
/// same Current Object List the pre-existing Object Explorer already
/// populates via [FoundationBridge.listObjects] — WP-EKE-008 does not
/// duplicate that fetch). Relationship browsing goes through the
/// Engineering Knowledge Graph Engine's Runtime Graph query surface
/// (WP-EKE-001: [FoundationBridge.loadEngineeringGraph]/
/// [FoundationBridge.engineRelatedObjects]/
/// [FoundationBridge.engineQueryByType]/
/// [FoundationBridge.engineQueryByDomain]), which is loaded on demand
/// the first time it's needed.
class EngineeringExplorerPage extends ConsumerStatefulWidget {
  const EngineeringExplorerPage({super.key});

  @override
  ConsumerState<EngineeringExplorerPage> createState() => _EngineeringExplorerPageState();
}

class _EngineeringExplorerPageState extends ConsumerState<EngineeringExplorerPage> {
  String _search = '';
  ObjectCategory? _typeFilter;
  String? _selectedObjectId;
  bool _graphLoaded = false;
  bool _loadingGraph = false;
  List<String>? _relatedObjectIds;
  String? _error;

  FoundationBridge? get _bridge => ref.read(foundationRuntimeServiceProvider.notifier).bridge;

  Future<void> _ensureGraphLoaded() async {
    if (_graphLoaded || _loadingGraph) return;
    final bridge = _bridge;
    if (bridge == null) return;
    setState(() => _loadingGraph = true);
    try {
      bridge.loadEngineeringGraph();
      setState(() => _graphLoaded = true);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loadingGraph = false);
    }
  }

  Future<void> _selectObject(String objectId) async {
    setState(() {
      _selectedObjectId = objectId;
      _relatedObjectIds = null;
      _error = null;
    });
    await _ensureGraphLoaded();
    final bridge = _bridge;
    if (bridge == null || !_graphLoaded) return;
    try {
      final related = bridge.engineRelatedObjects(objectId);
      setState(() => _relatedObjectIds = related);
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final allObjects = foundation.objectList ?? const <EngineeringObjectSummary>[];
    final byId = {for (final o in allObjects) o.objectId: o};

    final visible = allObjects.where((o) {
      if (_typeFilter != null && o.category != _typeFilter) return false;
      if (_search.isEmpty) return true;
      final needle = _search.toLowerCase();
      return o.name.toLowerCase().contains(needle) || o.objectId.toLowerCase().contains(needle);
    }).toList();

    final selected = _selectedObjectId != null ? byId[_selectedObjectId] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 16),
                            hintText: 'Search objects…',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 34,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ObjectCategory?>(
                          value: _typeFilter,
                          hint: const Text('All Types', style: TextStyle(fontSize: 12)),
                          dropdownColor: StudioColors.surfaceRaised,
                          style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Types')),
                            for (final c in ObjectCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
                          ],
                          onChanged: (v) => setState(() => _typeFilter = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${visible.length} of ${allObjects.length} Engineering Objects',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? const EiEmptyState(icon: Icons.category_outlined, message: 'No Engineering Objects found.')
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final o = visible[index];
                            final isSelected = o.objectId == _selectedObjectId;
                            return Material(
                              color: isSelected ? StudioColors.selection.withValues(alpha: 0.12) : Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectObject(o.objectId),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(o.category.icon, size: 15, color: StudioColors.textSecondary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(o.name,
                                                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                                            Text(o.category.label,
                                                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) EiErrorBanner(message: _error!),
                  if (selected == null)
                    const EiEmptyState(icon: Icons.touch_app_outlined, message: 'Select an object to inspect it.')
                  else ...[
                    EiSectionCard(
                      title: selected.name,
                      icon: selected.category.icon,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EiKeyValueRow('Object ID', selected.objectId),
                          EiKeyValueRow('Type', selected.category.label),
                          EiKeyValueRow('Author', selected.author),
                          EiKeyValueRow('Version', selected.version),
                          if (selected.description.isNotEmpty) EiKeyValueRow('Description', selected.description),
                          if (selected.tags.isNotEmpty) EiKeyValueRow('Tags', selected.tags.join(', ')),
                        ],
                      ),
                    ),
                    EiSectionCard(
                      title: 'Related Objects (Semantic Relationships)',
                      icon: Icons.hub_outlined,
                      trailing: _loadingGraph
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                      child: _relatedObjectIds == null
                          ? const Text('Loading…', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12))
                          : _relatedObjectIds!.isEmpty
                              ? const Text('No directly related objects.',
                                  style: TextStyle(color: StudioColors.textSecondary, fontSize: 12))
                              : Column(
                                  children: [
                                    for (final relatedId in _relatedObjectIds!)
                                      Builder(builder: (context) {
                                        final related = byId[relatedId];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(related?.category.icon ?? Icons.circle_outlined,
                                              size: 15, color: StudioColors.textSecondary),
                                          title: Text(related?.name ?? relatedId,
                                              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                                          onTap: () => _selectObject(relatedId),
                                        );
                                      }),
                                  ],
                                ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
