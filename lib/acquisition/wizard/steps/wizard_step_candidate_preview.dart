import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';

const _candidateCategories = [
  'Engineering Objects',
  'Relationships',
  'Equations',
  'Units',
  'Materials',
  'Symbols',
  'Behaviors',
  'Validation Rules',
  'Evidence',
];

/// Wizard Step 7 -- "Candidate Knowledge Preview."
///
/// **Honestly disclosed as not yet available.** Generating Candidate
/// Engineering Objects from an acquired artifact (equations, materials,
/// symbols, behaviors, ...) requires the Engineering Knowledge Engine,
/// which is explicitly Milestone 2 of `oep_acquisition` -- not built
/// anywhere in the backend today (its own README: "Everything the
/// Engineering Knowledge Engine covers... is explicitly out of scope for
/// Milestone 1"). Rather than fabricate example candidate objects that
/// don't actually exist, this step shows exactly what it will look like
/// once that engine exists, with every category honestly empty.
class WizardStepCandidatePreview extends StatelessWidget {
  const WizardStepCandidatePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Candidate Knowledge Preview',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudioColors.warning.withValues(alpha: 0.1),
              border: Border.all(color: StudioColors.warning.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.construction, size: 16, color: StudioColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not yet available. Turning an acquired document into Candidate Engineering Objects '
                    '(equations, materials, symbols, behaviors...) requires the Engineering Knowledge Engine, '
                    'which has not been built yet. Your artifact is safely stored in the Reference Vault '
                    'regardless -- this step will populate automatically once that engine exists.',
                    style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final category in _candidateCategories)
            ExpansionTile(
              title: Text(category, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
              subtitle: const Text('0 candidates', style: TextStyle(color: StudioColors.textDisabled, fontSize: 11)),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nothing extracted yet.', style: TextStyle(color: StudioColors.textDisabled, fontSize: 12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
