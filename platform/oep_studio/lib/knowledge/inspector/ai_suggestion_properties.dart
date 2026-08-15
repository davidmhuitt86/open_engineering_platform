import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/ai_conversation.dart';
import '../models/ai_suggestion.dart';
import '../models/engineering_context.dart';
import '../models/engineering_entity.dart';

/// Property Inspector's AI Suggestion mode (Work Package 016: "Extend
/// support for: AI Suggestion, AI Review, Prompt, Provider Metadata").
class AiSuggestionProperties extends StatelessWidget {
  const AiSuggestionProperties({
    required this.suggestion,
    required this.sourceName,
    required this.supportingEntities,
    required this.supportingContexts,
    this.conversation,
    super.key,
  });

  final AiSuggestion suggestion;
  final String sourceName;
  final List<EngineeringEntity> supportingEntities;
  final List<EngineeringContext> supportingContexts;

  /// The most recent `AiConversation`, shown only if it was the one
  /// that produced this suggestion (matching `sourceId` and
  /// `providerId`/`modelId`) — "No hidden prompts": the engineer can
  /// see the exact prompt this suggestion came from, when available.
  final AiConversation? conversation;

  @override
  Widget build(BuildContext context) {
    final matchingConversation =
        conversation != null &&
            conversation!.request.sourceId == suggestion.sourceId &&
            conversation!.response?.providerId == suggestion.providerId
        ? conversation
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Suggestion ID', value: suggestion.id, monospace: true),
        PropertyField(label: 'Suggested Type', value: suggestion.suggestedType.label),
        PropertyField(label: 'Suggested Name', value: suggestion.suggestedName),
        PropertyField(label: 'Suggested Description', value: suggestion.suggestedDescription),
        PropertyField(label: 'Confidence', value: '${(suggestion.confidence * 100).round()}%'),
        PropertyField(label: 'Reasoning', value: suggestion.reasoning),
        const SizedBox(height: 8),
        const Text('AI Review', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Status', value: _statusLabel(suggestion)),
        if (suggestion.isEdited) ...[
          PropertyField(label: 'Edited Type', value: suggestion.editedType?.label ?? '—'),
          PropertyField(label: 'Edited Name', value: suggestion.editedName ?? '—'),
          PropertyField(label: 'Edited Description', value: suggestion.editedDescription ?? '—'),
        ],
        if (suggestion.createdCandidateId != null)
          PropertyField(label: 'Knowledge Candidate', value: suggestion.createdCandidateId!, monospace: true),
        const SizedBox(height: 8),
        const Text('Supporting Evidence', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Source Material', value: sourceName),
        if (supportingContexts.isEmpty && supportingEntities.isEmpty)
          const Text('No supporting evidence recorded.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
        else ...[
          for (final entityContext in supportingContexts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Context: ${entityContext.title} (${entityContext.type.label})',
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5),
              ),
            ),
          for (final entity in supportingEntities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Entity: ${entity.normalizedValue} (${entity.type.label})',
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5),
              ),
            ),
        ],
        const SizedBox(height: 8),
        const Text('Provider Metadata', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PropertyField(label: 'Provider', value: suggestion.providerId),
        PropertyField(label: 'Model', value: suggestion.modelId),
        PropertyField(label: 'Generated', value: formatDateTime(suggestion.createdTime)),
        if (matchingConversation?.response case final response? when response.inputTokens != null || response.outputTokens != null) ...[
          const SizedBox(height: 8),
          const Text('Token Usage', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          PropertyField(label: 'Input Tokens', value: response.inputTokens?.toString() ?? '—'),
          PropertyField(label: 'Output Tokens', value: response.outputTokens?.toString() ?? '—'),
        ],
        if (matchingConversation?.response case final response? when response.stopReason != null || (response.rawMetadata?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          const Text('Response Metadata', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (response.stopReason != null) PropertyField(label: 'Stop Reason', value: response.stopReason!),
          for (final entry in (response.rawMetadata ?? const {}).entries)
            PropertyField(label: entry.key, value: entry.value.toString()),
        ],
        if (matchingConversation != null) ...[
          const SizedBox(height: 8),
          const Text('Prompt', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('System Prompt', style: TextStyle(color: StudioColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          SelectableText(
            matchingConversation.request.systemPrompt,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          const Text('User Prompt', style: TextStyle(color: StudioColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          SelectableText(
            matchingConversation.request.userPrompt,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  static String _statusLabel(AiSuggestion suggestion) {
    if (suggestion.isAccepted) return 'Accepted';
    if (suggestion.isEdited) return 'Edited';
    if (suggestion.isRejected) return 'Rejected';
    if (suggestion.isDeferred) return 'Deferred';
    return 'Pending';
  }
}
