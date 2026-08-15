import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/candidate_validation_result.dart';
import '../models/context_validation_result.dart';
import '../models/engineering_context.dart';
import '../models/engineering_context_status.dart';
import '../models/engineering_context_type.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/source_material.dart';
import '../widgets/knowledge_placeholder.dart';

enum _SortField { page, type, confidence }

/// The Context Explorer (Work Package 015 STUDIO-TASK-000043):
/// "Provide a dedicated workspace for reviewing engineering contexts."
/// A dialog scoped to one Source Material, opened from the OCR Layer
/// Viewer — the same "dedicated dialog for a substantial new
/// interactive surface" precedent Work Packages 010/011/013/014
/// already set, keeping SDD-016's seven-panel layout frozen. Every
/// Engineering Context is itself scoped to a single source (its own
/// `pageStart`/`pageEnd`/`boundingRegion` are all source-relative), so
/// there is no session-wide context view, mirroring the Entity Review
/// Workspace's own identical scoping choice.
Future<void> showContextExplorerDialog(BuildContext context, {required SourceMaterial source}) {
  return showDialog<void>(context: context, builder: (context) => _ContextExplorerDialog(source: source));
}

class _ContextExplorerDialog extends ConsumerStatefulWidget {
  const _ContextExplorerDialog({required this.source});

  final SourceMaterial source;

  @override
  ConsumerState<_ContextExplorerDialog> createState() => _ContextExplorerDialogState();
}

class _ContextExplorerDialogState extends ConsumerState<_ContextExplorerDialog> {
  EngineeringContextStatus? _statusFilter;
  _SortField _sortField = _SortField.page;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _detectionError;
  final Set<String> _expanded = {};

  /// The first context picked for a Merge, awaiting a second pick —
  /// local UI state for the two-tap Merge flow (STUDIO-TASK-000043
  /// doesn't specify a mechanic, so a "pick one, then pick another"
  /// flow was chosen as the simplest possible interaction for a binary
  /// operation).
  String? _mergeFirstId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detect());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _detect() {
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).detectContextsForSource(widget.source.id);
      if (mounted) setState(() => _detectionError = null);
    } on KnowledgeValidationException catch (error) {
      setState(() => _detectionError = error.message);
    }
  }

  void _accept(EngineeringContext context) {
    ref.read(foundationRuntimeServiceProvider.notifier).acceptContext(context.id);
  }

  void _ignore(EngineeringContext context) {
    ref.read(foundationRuntimeServiceProvider.notifier).ignoreContext(context.id);
  }

  void _navigateToSource(EngineeringContext context) {
    ref.read(foundationRuntimeServiceProvider.notifier).selectContext(context);
    Navigator.of(this.context).pop();
  }

  Future<void> _split(EngineeringContext context) async {
    final page = await showDialog<int>(
      context: this.context,
      builder: (dialogContext) => _SplitContextDialog(context: context),
    );
    if (page == null || !mounted) return;
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).splitContext(context.id, page);
    } on KnowledgeValidationException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: this.context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text('Couldn\'t Split Context'),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  void _tapMerge(EngineeringContext context) {
    final first = _mergeFirstId;
    if (first == null) {
      setState(() => _mergeFirstId = context.id);
      return;
    }
    if (first == context.id) {
      setState(() => _mergeFirstId = null);
      return;
    }
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).mergeContexts(first, context.id);
    } on KnowledgeValidationException {
      // Both contexts are always from this same source in this dialog,
      // so this cannot actually fire here — defensive only.
    }
    setState(() => _mergeFirstId = null);
  }

  List<EngineeringContext> _applyFiltersAndSort(List<EngineeringContext> contexts, EngineeringContextType? typeFilter) {
    var result = contexts;
    if (typeFilter != null) result = result.where((c) => c.type == typeFilter).toList();
    final status = _statusFilter;
    if (status != null) result = result.where((c) => c.status == status).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) => c.title.toLowerCase().contains(query)).toList();
    }
    result = [...result];
    switch (_sortField) {
      case _SortField.page:
        result.sort((a, b) {
          final pageCompare = a.pageStart.compareTo(b.pageStart);
          return pageCompare != 0 ? pageCompare : a.title.compareTo(b.title);
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
    final allContexts = foundation.engineeringContextsForSource(widget.source.id);
    final typeFilter = foundation.contextTypeFilter;
    final filtered = _applyFiltersAndSort(allContexts, typeFilter);
    final validation = foundation.contextValidation;
    final hasActiveFilter = typeFilter != null || _statusFilter != null || _searchQuery.isNotEmpty;

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
                      'Context Explorer — ${widget.source.originalFileName}',
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
              typeFilter: typeFilter,
              statusFilter: _statusFilter,
              sortField: _sortField,
              searchController: _searchController,
              onTypeFilterChanged: (value) =>
                  ref.read(foundationRuntimeServiceProvider.notifier).setContextTypeFilter(value),
              onStatusFilterChanged: (value) => setState(() => _statusFilter = value),
              onSortFieldChanged: (value) => setState(() => _sortField = value),
              onSearchChanged: (value) => setState(() => _searchQuery = value),
            ),
            const Divider(height: 1),
            if (_detectionError != null)
              _Banner(icon: Icons.error_outline, color: StudioColors.error, message: _detectionError!),
            if (_mergeFirstId != null)
              _Banner(
                icon: Icons.merge_type,
                color: StudioColors.selection,
                message: 'Select another context to merge with, or tap it again to cancel.',
              ),
            Expanded(
              child: allContexts.isEmpty
                  ? const KnowledgePlaceholder(message: 'No engineering contexts were detected on this source yet.')
                  : hasActiveFilter
                  ? _buildFlatList(filtered, validation)
                  : _buildTree(allContexts, validation),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatList(List<EngineeringContext> contexts, Map<String, ContextValidationResult> validation) {
    if (contexts.isEmpty) {
      return const KnowledgePlaceholder(message: 'No contexts match the current filter.');
    }
    return ListView.separated(
      itemCount: contexts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _contextRow(contexts[index], validation, depth: 0),
    );
  }

  Widget _buildTree(List<EngineeringContext> allContexts, Map<String, ContextValidationResult> validation) {
    final topLevel = _applyFiltersAndSort(
      allContexts.where((c) => c.parentContextId == null).toList(),
      null,
    );
    final rows = <Widget>[];
    for (final context in topLevel) {
      rows.add(_contextRow(context, validation, depth: 0));
      if (_expanded.contains(context.id)) {
        final children = _applyFiltersAndSort(
          allContexts.where((c) => c.parentContextId == context.id).toList(),
          null,
        );
        for (final child in children) {
          rows.add(_contextRow(child, validation, depth: 1));
        }
      }
    }
    if (rows.isEmpty) {
      return const KnowledgePlaceholder(message: 'No contexts match the current filter.');
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => rows[index],
    );
  }

  Widget _contextRow(EngineeringContext context, Map<String, ContextValidationResult> validation, {required int depth}) {
    final foundation = ref.read(foundationRuntimeServiceProvider);
    final hasChildren = foundation.engineeringContexts.any((c) => c.parentContextId == context.id);
    final expanded = _expanded.contains(context.id);
    return _ContextRow(
      key: ValueKey(context.id),
      context: context,
      depth: depth,
      hasChildren: hasChildren,
      expanded: expanded,
      validation: validation[context.id],
      selected: foundation.selectedContext?.id == context.id,
      mergePending: _mergeFirstId == context.id,
      onToggleExpand: () => setState(() {
        if (expanded) {
          _expanded.remove(context.id);
        } else {
          _expanded.add(context.id);
        }
      }),
      onTap: () => ref.read(foundationRuntimeServiceProvider.notifier).selectContext(context),
      onAccept: () => _accept(context),
      onIgnore: () => _ignore(context),
      onSplit: () => _split(context),
      onMerge: () => _tapMerge(context),
      onNavigate: () => _navigateToSource(context),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.message});

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 11.5))),
        ],
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

  final EngineeringContextType? typeFilter;
  final EngineeringContextStatus? statusFilter;
  final _SortField sortField;
  final TextEditingController searchController;
  final ValueChanged<EngineeringContextType?> onTypeFilterChanged;
  final ValueChanged<EngineeringContextStatus?> onStatusFilterChanged;
  final ValueChanged<_SortField> onSortFieldChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<EngineeringContextType?>(
                value: typeFilter,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                hint: const Text('All Types', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Types')),
                  for (final type in EngineeringContextType.values)
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
              child: DropdownButton<EngineeringContextStatus?>(
                value: statusFilter,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                hint: const Text('All Statuses', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: EngineeringContextStatus.pending, child: Text('Pending')),
                  DropdownMenuItem(value: EngineeringContextStatus.accepted, child: Text('Accepted')),
                  DropdownMenuItem(value: EngineeringContextStatus.ignored, child: Text('Ignored')),
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
                hintText: 'Search context titles…',
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

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    super.key,
    required this.context,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.validation,
    required this.selected,
    required this.mergePending,
    required this.onToggleExpand,
    required this.onTap,
    required this.onAccept,
    required this.onIgnore,
    required this.onSplit,
    required this.onMerge,
    required this.onNavigate,
  });

  final EngineeringContext context;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final ContextValidationResult? validation;
  final bool selected;
  final bool mergePending;
  final VoidCallback onToggleExpand;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;
  final VoidCallback onSplit;
  final VoidCallback onMerge;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext buildContext) {
    return Material(
      color: mergePending
          ? StudioColors.selection.withValues(alpha: 0.18)
          : (selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + depth * 24, 6, 12, 6),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: hasChildren
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 18),
                        onPressed: onToggleExpand,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Icon(context.type.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    Text(
                      '${context.type.label} — page ${context.pageStart}-${context.pageEnd} — ${context.childEntityIds.length} entities',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${(context.confidence * 100).round()}%',
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
              _StatusBadge(status: context.status),
              IconButton(
                tooltip: 'Navigate to Source',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.open_in_new, size: 15),
                onPressed: onNavigate,
              ),
              IconButton(
                tooltip: 'Split',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.call_split, size: 15),
                onPressed: context.pageStart < context.pageEnd ? onSplit : null,
              ),
              IconButton(
                tooltip: 'Merge',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.merge_type, size: 15),
                onPressed: onMerge,
              ),
              IconButton(
                tooltip: 'Accept',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.check_circle_outline, size: 15),
                color: StudioColors.success,
                onPressed: context.isAccepted ? null : onAccept,
              ),
              IconButton(
                tooltip: 'Ignore',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.visibility_off_outlined, size: 15),
                onPressed: context.isIgnored ? null : onIgnore,
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

  final EngineeringContextStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EngineeringContextStatus.pending => ('Pending', StudioColors.warning),
      EngineeringContextStatus.accepted => ('Accepted', StudioColors.success),
      EngineeringContextStatus.ignored => ('Ignored', StudioColors.textDisabled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _SplitContextDialog extends StatefulWidget {
  const _SplitContextDialog({required this.context});

  final EngineeringContext context;

  @override
  State<_SplitContextDialog> createState() => _SplitContextDialogState();
}

class _SplitContextDialogState extends State<_SplitContextDialog> {
  late int _splitPage = widget.context.pageStart;

  @override
  Widget build(BuildContext context) {
    final ctx = widget.context;
    final maxPage = ctx.pageEnd - 1;
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Split Context'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${ctx.title}" spans pages ${ctx.pageStart}-${ctx.pageEnd}. '
            'Choose the last page of the first half (pages ${ctx.pageStart}-$maxPage).',
            style: const TextStyle(fontSize: 12.5, color: StudioColors.textSecondary),
          ),
          const SizedBox(height: 12),
          DropdownButton<int>(
            value: _splitPage,
            isExpanded: true,
            dropdownColor: StudioColors.surfaceRaised,
            items: [
              for (var page = ctx.pageStart; page <= maxPage; page++)
                DropdownMenuItem(value: page, child: Text('Page $page')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _splitPage = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(_splitPage), child: const Text('Split')),
      ],
    );
  }
}
