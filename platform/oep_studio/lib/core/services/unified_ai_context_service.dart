import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../diagram_studio/ai/diagram_prompt_context.dart';
import '../../knowledge/models/ai_request.dart';
import 'engineering_project_service.dart';
import 'foundation_runtime_service.dart';
import 'foundation_runtime_state.dart';

/// AI Workspace Integration (WORK_PACKAGE_025, ENGINE-TASK-000124) —
/// assembles one `AiRequest` carrying "unified project context":
/// Knowledge, Engineering Graph, the selected object, related evidence,
/// the active diagram, and validation results. Reuses the existing,
/// already-shipped `DiagramPromptContext` assembler for the Engineering
/// Graph/selection portion (unchanged), then appends two sections
/// neither existing assembler emits today — Validation and Related
/// Evidence — before handing the request to the same
/// `AiProviderRegistry`/`AiProvider.complete` contract every other AI
/// call in Studio already uses (`DiagramAiService`, `AiAnalysisService`).
/// No new provider is introduced.
abstract final class UnifiedAiContextService {
  /// Builds the unified request. When a diagram is active, the
  /// Engineering Graph + selection form the base context (via
  /// `DiagramPromptContext`); otherwise a minimal Knowledge-Session-level
  /// summary is used instead, since `PromptService`'s own existing
  /// method requires OCR/Entity/Context arguments specific to analyzing
  /// one Source Material — not a shape this general-purpose entry point
  /// can honestly fill in in Knowledge Studio's own way without
  /// fabricating them (see `docs/ENGINEERING_PROJECT.md`).
  static AiRequest buildProjectContext(WidgetRef ref, {String? question}) {
    final projectState = ref.read(engineeringProjectServiceProvider);
    final foundation = ref.read(foundationRuntimeServiceProvider);
    final session = projectState.session;

    final base = session != null
        ? DiagramPromptContext.buildSelectionRequest(
            graph: session.graph,
            selection: projectState.selection,
            question: question,
          )
        : _knowledgeOnlyRequest(foundation, question: question);

    final buffer = StringBuffer(base.userPrompt);

    final report = projectState.validationReport;
    if (report != null && report.findings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('# Validation');
      for (final finding in report.findings) {
        buffer.writeln('- [${finding.severity.name}] ${finding.code}: ${finding.message}');
      }
    }

    if (session != null) {
      final evidenceLines = <String>[];
      for (final nodeId in projectState.selection.nodeIds) {
        final node = session.graph.nodes[nodeId];
        if (node == null) continue;
        for (final link in node.evidenceLinks) {
          final source = foundation.sourceMaterials.where((s) => s.id == link.sourceReference).firstOrNull;
          evidenceLines.add('- ${node.displayName}: ${source?.originalFileName ?? link.sourceReference}');
        }
      }
      if (evidenceLines.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('# Related Evidence');
        evidenceLines.forEach(buffer.writeln);
      }
    }

    return AiRequest(
      id: base.id,
      systemPrompt: base.systemPrompt,
      userPrompt: buffer.toString(),
      sourceId: base.sourceId,
      referencedEntityIds: base.referencedEntityIds,
      referencedContextIds: base.referencedContextIds,
      evidenceLabels: base.evidenceLabels,
      createdTime: base.createdTime,
    );
  }

  static AiRequest _knowledgeOnlyRequest(FoundationServiceState foundation, {String? question}) {
    final session = foundation.knowledgeSession;
    final buffer = StringBuffer();
    buffer.writeln('# Knowledge Session');
    buffer.writeln(session == null ? 'No active Knowledge Session.' : 'Session: ${session.name}');
    buffer.writeln();
    buffer.writeln('# Question');
    buffer.writeln(question?.trim().isNotEmpty == true ? question!.trim() : 'Summarize the current context.');
    return AiRequest(
      id: EngineIds.generate('ai_request'),
      systemPrompt: 'You are an assistant helping an engineer with their Open Engineering Platform project. '
          'Answer using only the context provided; never invent data that is not listed.',
      userPrompt: buffer.toString(),
      sourceId: session?.id ?? 'none',
      referencedEntityIds: const [],
      referencedContextIds: const [],
      evidenceLabels: const {},
      createdTime: DateTime.now(),
    );
  }
}
