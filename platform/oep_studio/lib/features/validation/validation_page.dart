import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/unified_ai_context_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../diagram_studio/ai/diagram_ai_service.dart';
import '../../shared/navigation/unified_navigation.dart';
import '../../shared/widgets/validation_findings_list.dart';

/// The global Validation Workspace (WORK_PACKAGE_025, ENGINE-TASK-000125)
/// — replaces the previous bare placeholder stub. Shows the active
/// diagram's live `ValidationReport` (`engineeringProjectServiceProvider`,
/// recomputed automatically on every graph edit since WORK_PACKAGE_025's
/// Engine hoist made it reachable outside Diagram Studio), with
/// click-to-navigate (jumps to and selects the affected diagram
/// element), Suggested Fixes per finding, and an "Ask AI" entry point.
/// Validation logic itself is unchanged and remains entirely
/// Engine-owned (`ValidationProvider`/`ValidationService` in
/// `oep_engine`) — this page only displays and navigates.
class ValidationPage extends ConsumerWidget {
  const ValidationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(engineeringProjectServiceProvider);
    final report = projectState.validationReport;
    final findings = report?.findings ?? const [];

    if (projectState.engine == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 48, color: StudioColors.textDisabled),
              SizedBox(height: 16),
              Text(
                'No Diagram Loaded',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Open Diagram Studio to load a diagram and see its validation results here.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 18, color: StudioColors.selection),
              const SizedBox(width: 10),
              const Text(
                'Validation',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                findings.isEmpty ? 'Clean — no findings' : '${findings.length} finding(s)',
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Revalidate',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(engineeringProjectServiceProvider.notifier).revalidate(),
              ),
              if (findings.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _askAi(context, ref),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: const Text('Ask AI'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ValidationFindingsList(
            report: report,
            onFindingTap: (finding) => goToValidationResult(context, ref, finding),
          ),
        ),
      ],
    );
  }

  Future<void> _askAi(BuildContext context, WidgetRef ref) async {
    final request = UnifiedAiContextService.buildProjectContext(
      ref,
      question: 'Explain these validation findings and how to resolve them.',
    );
    // The current AI provider is a global Studio setting (Settings >
    // Artificial Intelligence), the same one every other AI entry
    // point already reads — no new provider selection here.
    final providerId = ref.read(foundationRuntimeServiceProvider).currentAiProviderId;
    final response = await DiagramAiService.ask(providerId: providerId, request: request);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Explanation'),
        content: SingleChildScrollView(
          child: Text(response.success ? response.rawText : (response.errorMessage ?? 'The AI provider failed to respond.')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
