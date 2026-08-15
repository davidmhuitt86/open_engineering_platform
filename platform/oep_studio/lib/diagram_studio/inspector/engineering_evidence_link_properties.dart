import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/navigation/evidence_navigation.dart';
import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected `EvidenceLink` (WORK_PACKAGE_025,
/// ENGINE-TASK-000122) — the one Property Inspector gap WP024 left:
/// evidence links were only ever shown nested/summarized inside node/
/// relationship properties ("N linked"), never as their own selectable
/// object. A "Go to Evidence" action navigates to whatever the link's
/// `sourceReference`/`locator` resolve to in the active Knowledge
/// Session (ENGINE-TASK-000123) — see `docs/EVIDENCE_MODEL.md` in
/// `oep_studio` and this package's own `evidence_navigation.dart` for
/// the resolution convention.
class EngineeringEvidenceLinkProperties extends ConsumerWidget {
  const EngineeringEvidenceLinkProperties({required this.link, required this.ownerId, super.key});

  final EvidenceLink link;
  final String ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Evidence ID', value: link.id, monospace: true),
        PropertyField(label: 'Owning Node/Relationship', value: ownerId, monospace: true),
        PropertyField(label: 'Kind', value: link.kind.name),
        PropertyField(label: 'Source Reference', value: link.sourceReference, monospace: true),
        if (link.confidence != null)
          PropertyField(label: 'Confidence', value: link.confidence!.toStringAsFixed(2)),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => goToEvidence(context, ref, link),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Go to Evidence'),
        ),
      ],
    );
  }
}
