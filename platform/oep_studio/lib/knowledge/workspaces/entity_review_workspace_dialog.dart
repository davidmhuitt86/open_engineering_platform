import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/candidate_validation_result.dart';
import '../models/engineering_entity.dart';
import '../models/engineering_entity_status.dart';
import '../models/engineering_entity_type.dart';
import '../models/entity_validation_result.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/source_material.dart';
import '../widgets/knowledge_placeholder.dart';

enum _SortField { page, type, confidence }

/// The Entity Review Workspace (Work Package 014 STUDIO-TASK-000039):
/// "Allow engineers to inspect extracted entities." A dialog, scoped to
/// one Source Material, opened from the OCR Layer Viewer's "Extract
/// Entities" button — entity extraction "operates only on OCR
/// evidence," so there is no session-wide entity view, only a
/// per-source one, the same scoping the OCR Layer Viewer itself uses.
Future<void> showEntityReviewWorkspaceDialog(BuildContext context, {required SourceMaterial source}) {
  return showDialog<void>(context: context, builder: (context) => _EntityReviewWorkspaceDialog(source: source));
}

class _EntityReviewWorkspaceDialog extends ConsumerStatefulWidget {
  const _EntityReviewWorkspaceDialog({required this.source});

  final SourceMaterial source;

  @override
  ConsumerState<_EntityReviewWorkspaceDialog> createState() => _EntityReviewWorkspaceDialogState();
}

class _EntityReviewWorkspaceDialogState extends ConsumerState<_EntityReviewWorkspaceDialog> {
  EngineeringEntityType? _typeFilter;
  EngineeringEntityStatus? _statusFilter;
  _SortField _sortField = _SortField.page;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _extractionError;

  // Work Package 015 STUDIO-TASK-000045: "Selecting a context updates:
  // ... Entity Viewer." Local filter mirroring the Context Explorer's
  // own selection — set to the selected context's own child entity ids
  // whenever a context belonging to this source becomes selected;
  // cleared explicitly via the banner's "Clear" action.
  Set<String>? _contextEntityFilter;
  String? _contextFilterTitle;
  String? _lastAppliedContextId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _extract());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _extract() {
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).extractEntitiesForSource(widget.source.id);
      if (mounted) setState(() => _extractionError = null);
    } on KnowledgeValidationException catch (error) {
      setState(() => _extractionError = error.message);
    }
  }

  Future<void> _accept(EngineeringEntity entity) async {
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).acceptEntity(entity.id);
    } on KnowledgeValidationException catch (error) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text('Couldn\'t Accept Entity'),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  void _ignore(EngineeringEntity entity) {
    ref.read(foundationRuntimeServiceProvider.notifier).ignoreEntity(entity.id);
  }

  void _navigateToSource(EngineeringEntity entity) {
    // Mirrors the Evidence Browser's own "Navigate" precedent
    // (`evidence_browser_dialog.dart`): select, then close — this
    // dialog is always opened from the still-open OCR Layer Viewer,
    // which watches `selectedEntity` and jumps to its page.
    ref.read(foundationRuntimeServiceProvider.notifier).selectEntity(entity);
    Navigator.of(context).pop();
  }

  List<EngineeringEntity> _filteredSorted(List<EngineeringEntity> entities) {
    var result = entities;
    final type = _typeFilter;
    if (type != null) result = result.where((entity) => entity.type == type).toList();
    final status = _statusFilter;
    if (status != null) result = result.where((entity) => entity.status == status).toList();
    final contextFilter = _contextEntityFilter;
    if (contextFilter != null) result = result.where((entity) => contextFilter.contains(entity.id)).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where(
            (entity) =>
                entity.extractedText.toLowerCase().contains(query) ||
                entity.normalizedValue.toLowerCase().contains(query),
          )
          .toList();
    }
    result = [...result];
    switch (_sortField) {
      case _SortField.page:
        result.sort((a, b) {
          final pageCompare = a.page.compareTo(b.page);
          return pageCompare != 0 ? pageCompare : a.characterStart.compareTo(b.characterStart);
        });
      case _SortField.type:
        result.sort((a, b) => a.type.label.compareTo(b.type.label));
      case _SortField.confidence:
        result.sort((a, b) => b.confidence.compareTo(a.confidence));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final screen = MediaQuery.of(context).size;
    final allEntities = foundation.engineeringEntitiesForSource(widget.source.id);
    final validation = foundation.entityValidation;

    final selectedContext = foundation.selectedContext;
    if (selectedContext != null &&
        selectedContext.sourceId == widget.source.id &&
        selectedContext.id != _lastAppliedContextId) {
      _lastAppliedContextId = selectedContext.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _contextEntityFilter = selectedContext.childEntityIds.toSet();
          _contextFilterTitle = selectedContext.title;
        });
      });
    } else if (selectedContext == null) {
      _lastAppliedContextId = null;
    }

    final entities = _filteredSorted(allEntities);

    return Dialog(
      backgroundColor: StudioColors.surfaceRaised,
      child: SizedBox(
        width: math.min(1000, screen.width * 0.9),
        height: math.min(760, screen.height * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Entity Review Workspace — ${widget.source.originalFileName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _FilterBar(
              typeFilter: _typeFilter,
              statusFilter: _statusFilter,
              sortField: _sortField,
              searchController: _searchController,
              onTypeFilterChanged: (value) => setState(() => _typeFilter = value),
              onStatusFilterChanged: (value) => setState(() => _statusFilter = value),
              onSortFieldChanged: (value) => setState(() => _sortField = value),
              onSearchChanged: (value) => setState(() => _searchQuery = value),
            ),
            const Divider(height: 1),
            if (_contextEntityFilter != null)
              Container(
                width: double.infinity,
                color: StudioColors.selection.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 14, color: StudioColors.selection),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Showing only entities in context "$_contextFilterTitle".',
                        style: const TextStyle(color: StudioColors.selection, fontSize: 11.5),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _contextEntityFilter = null;
                        _contextFilterTitle = null;
                        _lastAppliedContextId = null;
                      }),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            if (_extractionError != null)
              Container(
                width: double.infinity,
                color: StudioColors.error.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: StudioColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_extractionError!, style: const TextStyle(color: StudioColors.error, fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: entities.isEmpty
                  ? KnowledgePlaceholder(
                      message: allEntities.isEmpty
                          ? 'No engineering entities were recognized on this source yet.'
                          : 'No entities match the current filter.',
                    )
                  : ListView.separated(
                      itemCount: entities.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entity = entities[index];
                        return _EntityRow(
                          entity: entity,
                          validation: validation[entity.id],
                          selected: foundation.selectedEntity?.id == entity.id,
                          onTap: () => ref.read(foundationRuntimeServiceProvider.notifier).selectEntity(entity),
                          onAccept: () => _accept(entity),
                          onIgnore: () => _ignore(entity),
                          onNavigate: () => _navigateToSource(entity),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.statusFilter,
    required this.sortField,
    required this.searchController,
    required this.onTypeFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSortFieldChanged,
    required this.onSearchChanged,
  });

  final EngineeringEntityType? typeFilter;
  final EngineeringEntityStatus? statusFilter;
  final _SortField sortField;
  final TextEditingController searchController;
  final ValueChanged<EngineeringEntityType?> onTypeFilterChanged;
  final ValueChanged<EngineeringEntityStatus?> onStatusFilterChanged;
  final ValueChanged<_SortField> onSortFieldChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<EngineeringEntityType?>(
                value: typeFilter,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                hint: const Text('All Types', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Types')),
                  for (final type in EngineeringEntityType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: onTypeFilterChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<EngineeringEntityStatus?>(
                value: statusFilter,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                hint: const Text('All Statuses', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: EngineeringEntityStatus.pending, child: Text('Pending')),
                  DropdownMenuItem(value: EngineeringEntityStatus.accepted, child: Text('Accepted')),
                  DropdownMenuItem(value: EngineeringEntityStatus.ignored, child: Text('Ignored')),
                ],
                onChanged: onStatusFilterChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_SortField>(
                value: sortField,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: _SortField.page, child: Text('Sort: Page')),
                  DropdownMenuItem(value: _SortField.type, child: Text('Sort: Type')),
                  DropdownMenuItem(value: _SortField.confidence, child: Text('Sort: Confidence')),
                ],
                onChanged: (value) {
                  if (value != null) onSortFieldChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search extracted/normalized value…',
                prefixIcon: Icon(Icons.search, size: 16),
              ),
              onChanged: onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.entity,
    required this.validation,
    required this.selected,
    required this.onTap,
    required this.onAccept,
    required this.onIgnore,
    required this.onNavigate,
  });

  final EngineeringEntity entity;
  final EntityValidationResult? validation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(entity.type.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.normalizedValue,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    Text(
                      '${entity.type.label} — page ${entity.page} — "${entity.extractedText}"',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${(entity.confidence * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 8),
              if (validation != null && validation!.severity != ValidationSeverity.ok)
                Tooltip(
                  message: validation!.issues.join('\n'),
                  child: Icon(
                    validation!.severity == ValidationSeverity.error ? Icons.error_outline : Icons.warning_amber_outlined,
                    size: 15,
                    color: validation!.severity == ValidationSeverity.error ? StudioColors.error : StudioColors.warning,
                  ),
                ),
              const SizedBox(width: 8),
              _StatusBadge(status: entity.status),
              IconButton(
                tooltip: 'Navigate to Source',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(Icons.open_in_new, size: 16),
                onPressed: onNavigate,
              ),
              IconButton(
                tooltip: 'Accept',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                color: StudioColors.success,
                onPressed: entity.isAccepted ? null : onAccept,
              ),
              IconButton(
                tooltip: 'Ignore',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(Icons.visibility_off_outlined, size: 16),
                onPressed: entity.isIgnored ? null : onIgnore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EngineeringEntityStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EngineeringEntityStatus.pending => ('Pending', StudioColors.warning),
      EngineeringEntityStatus.accepted => ('Accepted', StudioColors.success),
      EngineeringEntityStatus.ignored => ('Ignored', StudioColors.textDisabled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}
