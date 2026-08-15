import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';
import '../services/knowledge_session_service.dart';

/// Evidence Linking (Work Package 009 STUDIO-TASK-000021): "Support
/// linking: Knowledge Candidate ↓ Evidence Region. One candidate may
/// reference multiple regions. One region may support multiple
/// candidates." Both directions open the same kind of checklist —
/// toggling a row immediately links/unlinks (autosaved by the
/// Connection Manager like every other mutation; there is no separate
/// "Save" step here either) — so this file has one dialog shell and two
/// thin entry points for which side is fixed and which side is being
/// picked from.
Future<void> showLinkEvidenceRegionsDialog(BuildContext context, {required String candidateId}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LinkEvidenceDialog(
      title: 'Link Evidence Regions',
      itemLabel: (foundation, regionId) {
        final region = _find(foundation.evidenceRegions, (region) => region.id == regionId);
        if (region == null) return regionId;
        final source = _find(foundation.sourceMaterials, (source) => source.id == region.sourceId);
        final sourceName = source?.originalFileName ?? region.sourceId;
        return '$sourceName — ${region.label} (Page ${region.page})';
      },
      itemIds: (foundation) => foundation.evidenceRegions.map((region) => region.id).toList(),
      isLinked: (foundation, regionId) => KnowledgeSessionService.isEvidenceLinked(
        candidateId: candidateId,
        regionId: regionId,
        existingLinks: foundation.evidenceLinks,
      ),
      onToggle: (notifier, foundation, regionId, linked) {
        if (linked) {
          final link = _find(
            foundation.evidenceLinks,
            (link) => link.candidateId == candidateId && link.regionId == regionId,
          );
          if (link != null) notifier.unlinkEvidence(link.id);
        } else {
          notifier.linkEvidence(candidateId: candidateId, regionId: regionId);
        }
      },
      emptyMessage: 'No Evidence Regions exist yet. Draw one in the PDF Source Viewer first.',
    ),
  );
}

Future<void> showLinkKnowledgeCandidatesDialog(BuildContext context, {required String regionId}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LinkEvidenceDialog(
      title: 'Link Knowledge Candidates',
      itemLabel: (foundation, candidateId) {
        final candidate = _find(foundation.candidates, (candidate) => candidate.id == candidateId);
        return candidate?.name ?? candidateId;
      },
      itemIds: (foundation) => foundation.candidates.map((candidate) => candidate.id).toList(),
      isLinked: (foundation, candidateId) => KnowledgeSessionService.isEvidenceLinked(
        candidateId: candidateId,
        regionId: regionId,
        existingLinks: foundation.evidenceLinks,
      ),
      onToggle: (notifier, foundation, candidateId, linked) {
        if (linked) {
          final link = _find(
            foundation.evidenceLinks,
            (link) => link.candidateId == candidateId && link.regionId == regionId,
          );
          if (link != null) notifier.unlinkEvidence(link.id);
        } else {
          notifier.linkEvidence(candidateId: candidateId, regionId: regionId);
        }
      },
      emptyMessage: 'No Knowledge Candidates exist yet. Add one in the Engineering Review panel first.',
    ),
  );
}

T? _find<T>(List<T> items, bool Function(T item) test) {
  final matches = items.where(test);
  return matches.isEmpty ? null : matches.first;
}

class _LinkEvidenceDialog extends ConsumerWidget {
  const _LinkEvidenceDialog({
    required this.title,
    required this.itemLabel,
    required this.itemIds,
    required this.isLinked,
    required this.onToggle,
    required this.emptyMessage,
  });

  final String title;
  final String Function(FoundationServiceState foundation, String id) itemLabel;
  final List<String> Function(FoundationServiceState foundation) itemIds;
  final bool Function(FoundationServiceState foundation, String id) isLinked;
  final void Function(FoundationRuntimeNotifier notifier, FoundationServiceState foundation, String id, bool linked)
  onToggle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final ids = itemIds(foundation);

    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(title),
      content: SizedBox(
        width: 420,
        height: 360,
        child: ids.isEmpty
            ? Center(
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              )
            : ListView(
                children: [
                  for (final id in ids)
                    CheckboxListTile(
                      dense: true,
                      value: isLinked(foundation, id),
                      title: Text(
                        itemLabel(foundation, id),
                        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                      ),
                      onChanged: (checked) => onToggle(notifier, foundation, id, !(checked ?? false)),
                    ),
                ],
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
    );
  }
}
