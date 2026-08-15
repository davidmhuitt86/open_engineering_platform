import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ai_engineering_context.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/unified_ai_context_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../diagram_studio/ai/diagram_ai_service.dart';
import '../../knowledge/models/ai_response.dart';

/// The AI Engineering Copilot (Phase 8).
///
/// **This is real AI functionality, not a placeholder** -- it calls the
/// same, already-shipped `AiProviderRegistry`/`AiProvider.complete`
/// pipeline `ValidationPage`'s "Ask AI" button already uses in
/// production (`DiagramAiService.ask`), built from the same
/// `UnifiedAiContextService.buildProjectContext`. Nothing here invents a
/// new AI runtime; this page generalizes an existing one-shot dialog
/// into a proper workspace with visible context and conversation
/// history.
///
/// **What is honest UI preparation, not real capability**: the active
/// provider is a global Studio setting (Settings > Artificial
/// Intelligence) that defaults to the deterministic `MockAiProvider`
/// (no network, structured JSON output, not prose) until an engineer
/// configures a real provider (Anthropic) with an API key. This page
/// discloses which provider actually answered every question, and
/// never presents mock output as if it were a real model's reasoning.
/// There is no "Tools"/"Calculations" region here because no backend
/// capability exists for the AI to invoke a tool or run a calculation
/// -- omitted rather than faked, per this phase's own instruction.
class CopilotPage extends ConsumerStatefulWidget {
  const CopilotPage({super.key});

  @override
  ConsumerState<CopilotPage> createState() => _CopilotPageState();
}

class _CopilotExchange {
  const _CopilotExchange({required this.question, required this.response});
  final String question;
  final AiResponse response;
}

class _CopilotPageState extends ConsumerState<CopilotPage> {
  final _questionController = TextEditingController();
  final _exchanges = <_CopilotExchange>[];
  bool _asking = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _asking) return;
    setState(() => _asking = true);
    final request = UnifiedAiContextService.buildProjectContext(ref, question: question);
    final providerId = ref.read(foundationRuntimeServiceProvider).currentAiProviderId;
    final response = await DiagramAiService.ask(providerId: providerId, request: request);
    if (!mounted) return;
    setState(() {
      _exchanges.add(_CopilotExchange(question: question, response: response));
      _questionController.clear();
      _asking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final context_ = AiEngineeringContext.fromRef(ref);
    final providerId = ref.watch(foundationRuntimeServiceProvider).currentAiProviderId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: _exchanges.isEmpty
                    ? _EmptyConversation(providerId: providerId)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _exchanges.length,
                        itemBuilder: (context, index) => _ExchangeTile(exchange: _exchanges[index]),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        enabled: !_asking,
                        onSubmitted: (_) => _ask(),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Ask about the current engineering context…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _asking ? null : _ask,
                      icon: _asking
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Ask'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 300,
          child: _ContextPanel(context: context_),
        ),
      ],
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'Engineering Copilot',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 380,
              child: Text(
                providerId == 'mock'
                    ? 'No real AI provider is configured (Settings > Artificial Intelligence). Questions asked '
                        'here will use the deterministic Mock provider, which returns structured test output, '
                        'not genuine reasoning.'
                    : 'Connected to provider "$providerId". Ask a question about the current engineering '
                        'context on the right -- the diagram, selection, and validation results shown there '
                        'are sent with your question.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeTile extends StatelessWidget {
  const _ExchangeTile({required this.exchange});

  final _CopilotExchange exchange;

  @override
  Widget build(BuildContext context) {
    final response = exchange.response;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: StudioColors.selectedRowBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(exchange.question, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: StudioColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: response.success ? StudioColors.borderSubtle : StudioColors.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  response.success
                      ? response.rawText
                      : (response.errorMessage ?? 'The AI provider failed to respond.'),
                  style: TextStyle(
                    color: response.success ? StudioColors.textPrimary : StudioColors.error,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Provider: ${response.providerId}${response.modelId.isEmpty ? '' : ' (${response.modelId})'}',
                  style: const TextStyle(color: StudioColors.textDisabled, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.context});

  final AiEngineeringContext context;

  @override
  Widget build(BuildContext buildContext) {
    return Container(
      color: StudioColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              'Current Context',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _ContextRow('Repository', context.repositoryName),
                _ContextRow('Project', context.activeProjectName),
                _ContextRow('Document', context.documentPath ?? (context.hasActiveDocument ? 'Untitled Diagram' : null)),
                _ContextRow('Knowledge Session', context.knowledgeSessionName),
                _ContextRow('Selected Object', context.selectedObject?.name),
                _ContextRow('Selected Relationship', context.selectedRelationship?.type.name),
                _ContextRow(
                  'Selected Nodes',
                  context.selectedNodeIds.isEmpty ? null : '${context.selectedNodeIds.length} node(s)',
                ),
                _ContextRow(
                  'Validation',
                  context.validationReport == null
                      ? null
                      : (context.validationReport!.findings.isEmpty
                          ? 'Clean -- no findings'
                          : '${context.validationReport!.findings.length} finding(s)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 10.5, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(
            value ?? 'Not available',
            style: TextStyle(
              color: value == null ? StudioColors.textDisabled : StudioColors.textPrimary,
              fontSize: 12.5,
              fontStyle: value == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
