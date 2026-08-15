import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../models/ai_processing_status.dart';
import '../models/ai_suggestion.dart';
import '../models/ai_suggestion_status.dart';
import '../models/knowledge_candidate_type.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/source_material.dart';
import '../services/ai_provider_registry.dart';
import '../widgets/knowledge_placeholder.dart';

enum _SortField { newest, confidence, type }

/// The AI Review Workspace (Work Package 016 — Property Inspector "AI
/// Suggestion"/"AI Review"; Connection Manager "Current AI
/// Suggestion"). A dialog scoped to one Source Material — every AI
/// Suggestion is analyzed from one source's own evidence — mirroring
/// the Entity Review Workspace's/Context Explorer's own identical
/// scoping choice, opened from a new "AI Suggestions" toolbar button on
/// the OCR Layer Viewer.
Future<void> showAiReviewWorkspaceDialog(BuildContext context, {required SourceMaterial source}) {
  return showDialog<void>(context: context, builder: (context) => _AiReviewWorkspaceDialog(source: source));
}

class _AiReviewWorkspaceDialog extends ConsumerStatefulWidget {
  const _AiReviewWorkspaceDialog({required this.source});

  final SourceMaterial source;

  @override
  ConsumerState<_AiReviewWorkspaceDialog> createState() => _AiReviewWorkspaceDialogState();
}

class _AiReviewWorkspaceDialogState extends ConsumerState<_AiReviewWorkspaceDialog> {
  AiSuggestionStatus? _statusFilter;
  _SortField _sortField = _SortField.newest;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _analysisError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    setState(() => _analysisError = null);
    try {
      await ref.read(foundationRuntimeServiceProvider.notifier).runAiAnalysisForSource(widget.source.id);
    } on KnowledgeValidationException catch (error) {
      if (mounted) setState(() => _analysisError = error.message);
    } catch (error) {
      if (mounted) setState(() => _analysisError = error.toString());
    }
  }

  void _accept(AiSuggestion suggestion) {
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).acceptAiSuggestion(suggestion.id);
    } on KnowledgeValidationException catch (error) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: StudioColors.surfaceRaised,
          title: const Text('Couldn\'t Accept Suggestion'),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  void _reject(AiSuggestion suggestion) {
    ref.read(foundationRuntimeServiceProvider.notifier).rejectAiSuggestion(suggestion.id);
  }

  void _defer(AiSuggestion suggestion) {
    ref.read(foundationRuntimeServiceProvider.notifier).deferAiSuggestion(suggestion.id);
  }

  Future<void> _edit(AiSuggestion suggestion) async {
    final result = await showDialog<({KnowledgeCandidateType type, String name, String description})>(
      context: context,
      builder: (context) => _EditSuggestionDialog(suggestion: suggestion),
    );
    if (result == null || !mounted) return;
    ref.read(foundationRuntimeServiceProvider.notifier).editAiSuggestion(
      suggestion.id,
      type: result.type,
      name: result.name,
      description: result.description,
    );
  }

  List<AiSuggestion> _filteredSorted(List<AiSuggestion> suggestions) {
    var result = suggestions;
    final status = _statusFilter;
    if (status != null) result = result.where((suggestion) => suggestion.status == status).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where(
            (suggestion) =>
                suggestion.effectiveName.toLowerCase().contains(query) ||
                suggestion.effectiveDescription.toLowerCase().contains(query),
          )
          .toList();
    }
    result = [...result];
    switch (_sortField) {
      case _SortField.newest:
        result.sort((a, b) => b.createdTime.compareTo(a.createdTime));
      case _SortField.confidence:
        result.sort((a, b) => b.confidence.compareTo(a.confidence));
      case _SortField.type:
        result.sort((a, b) => a.effectiveType.label.compareTo(b.effectiveType.label));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final screen = MediaQuery.of(context).size;
    final allSuggestions = foundation.aiSuggestionsForSource(widget.source.id);
    final suggestions = _filteredSorted(allSuggestions);
    final processingStatus = foundation.aiProcessingStatus[widget.source.id] ?? AiProcessingStatus.notAnalyzed;
    final availableModels = AiProviderRegistry.defaultRegistry.availableModels;

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
                      'AI Review Workspace — ${widget.source.originalFileName}',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: foundation.currentAiProviderId,
                        isExpanded: true,
                        dropdownColor: StudioColors.surfaceRaised,
                        style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                        items: [
                          for (final model in availableModels)
                            DropdownMenuItem(value: model.providerId, child: Text(model.displayName)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(foundationRuntimeServiceProvider.notifier).setCurrentAiProvider(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: processingStatus == AiProcessingStatus.analyzing ? null : _runAnalysis,
                    icon: processingStatus == AiProcessingStatus.analyzing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: Text(processingStatus == AiProcessingStatus.analyzing ? 'Analyzing…' : 'Run Analysis'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _FilterBar(
              statusFilter: _statusFilter,
              sortField: _sortField,
              searchController: _searchController,
              onStatusFilterChanged: (value) => setState(() => _statusFilter = value),
              onSortFieldChanged: (value) => setState(() => _sortField = value),
              onSearchChanged: (value) => setState(() => _searchQuery = value),
            ),
            const Divider(height: 1),
            if (_analysisError != null)
              Container(
                width: double.infinity,
                color: StudioColors.error.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: StudioColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_analysisError!, style: const TextStyle(color: StudioColors.error, fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: suggestions.isEmpty
                  ? KnowledgePlaceholder(
                      message: allSuggestions.isEmpty
                          ? 'No AI Suggestions yet. Select a provider and choose "Run Analysis."'
                          : 'No suggestions match the current filter.',
                    )
                  : ListView.separated(
                      itemCount: suggestions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return _SuggestionRow(
                          suggestion: suggestion,
                          selected: foundation.selectedAiSuggestion?.id == suggestion.id,
                          onTap: () => ref.read(foundationRuntimeServiceProvider.notifier).selectAiSuggestion(suggestion),
                          onAccept: () => _accept(suggestion),
                          onEdit: () => _edit(suggestion),
                          onReject: () => _reject(suggestion),
                          onDefer: () => _defer(suggestion),
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
    required this.statusFilter,
    required this.sortField,
    required this.searchController,
    required this.onStatusFilterChanged,
    required this.onSortFieldChanged,
    required this.onSearchChanged,
  });

  final AiSuggestionStatus? statusFilter;
  final _SortField sortField;
  final TextEditingController searchController;
  final ValueChanged<AiSuggestionStatus?> onStatusFilterChanged;
  final ValueChanged<_SortField> onSortFieldChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AiSuggestionStatus?>(
                value: statusFilter,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                hint: const Text('All Statuses', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: AiSuggestionStatus.pending, child: Text('Pending')),
                  DropdownMenuItem(value: AiSuggestionStatus.accepted, child: Text('Accepted')),
                  DropdownMenuItem(value: AiSuggestionStatus.edited, child: Text('Edited')),
                  DropdownMenuItem(value: AiSuggestionStatus.rejected, child: Text('Rejected')),
                  DropdownMenuItem(value: AiSuggestionStatus.deferred, child: Text('Deferred')),
                ],
                onChanged: onStatusFilterChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_SortField>(
                value: sortField,
                isExpanded: true,
                dropdownColor: StudioColors.surfaceRaised,
                style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: _SortField.newest, child: Text('Sort: Newest')),
                  DropdownMenuItem(value: _SortField.confidence, child: Text('Sort: Confidence')),
                  DropdownMenuItem(value: _SortField.type, child: Text('Sort: Type')),
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
                hintText: 'Search suggestion name/description…',
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

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.selected,
    required this.onTap,
    required this.onAccept,
    required this.onEdit,
    required this.onReject,
    required this.onDefer,
  });

  final AiSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onReject;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    final evidenceCount = suggestion.supportingEntityIds.length + suggestion.supportingContextIds.length;
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(suggestion.effectiveType.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.effectiveName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    Text(
                      '${suggestion.effectiveType.label} — $evidenceCount supporting item(s) — '
                      '"${suggestion.effectiveDescription}"',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${(suggestion.confidence * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: suggestion.status),
              IconButton(
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.edit_outlined, size: 15),
                onPressed: suggestion.isAccepted ? null : onEdit,
              ),
              IconButton(
                tooltip: 'Accept',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.check_circle_outline, size: 15),
                color: StudioColors.success,
                onPressed: suggestion.isAccepted ? null : onAccept,
              ),
              IconButton(
                tooltip: 'Reject',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.cancel_outlined, size: 15),
                onPressed: suggestion.isAccepted ? null : onReject,
              ),
              IconButton(
                tooltip: 'Defer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.schedule_outlined, size: 15),
                onPressed: suggestion.isAccepted ? null : onDefer,
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

  final AiSuggestionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AiSuggestionStatus.pending => ('Pending', StudioColors.warning),
      AiSuggestionStatus.accepted => ('Accepted', StudioColors.success),
      AiSuggestionStatus.edited => ('Edited', StudioColors.info),
      AiSuggestionStatus.rejected => ('Rejected', StudioColors.textDisabled),
      AiSuggestionStatus.deferred => ('Deferred', StudioColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _EditSuggestionDialog extends StatefulWidget {
  const _EditSuggestionDialog({required this.suggestion});

  final AiSuggestion suggestion;

  @override
  State<_EditSuggestionDialog> createState() => _EditSuggestionDialogState();
}

class _EditSuggestionDialogState extends State<_EditSuggestionDialog> {
  late KnowledgeCandidateType _type = widget.suggestion.effectiveType;
  late final _nameController = TextEditingController(text: widget.suggestion.effectiveName);
  late final _descriptionController = TextEditingController(text: widget.suggestion.effectiveDescription);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Edit Suggestion'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<KnowledgeCandidateType>(
              value: _type,
              isExpanded: true,
              dropdownColor: StudioColors.surfaceRaised,
              items: [
                for (final type in KnowledgeCandidateType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop((
            type: _type,
            name: _nameController.text,
            description: _descriptionController.text,
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
