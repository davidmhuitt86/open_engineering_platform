import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';

/// Wizard Step 8 -- "Engineering Review" (Accept/Reject/Merge/Link
/// Existing/Edit Metadata/Notes on Candidate Engineering Objects).
///
/// **Honestly disclosed as not yet available**, same reason as Step 7
/// (`WizardStepCandidatePreview`): there are no Candidate Engineering
/// Objects to review yet without the Knowledge Engine. The controls
/// below are shown disabled, matching this codebase's own
/// `SettingsPlaceholderRow` precedent for "real UI, honestly not wired
/// up yet" rather than hiding the step entirely.
class WizardStepReview extends StatelessWidget {
  const WizardStepReview({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Engineering Review',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Once Candidate Engineering Objects exist, you would review each one here before anything is '
            'committed to the knowledge graph -- Accept it as-is, Reject it, Merge it into an existing '
            'object, Link it to one instead of creating a duplicate, or edit its metadata and leave a note '
            'for whoever reviews it next.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Opacity(
            opacity: 0.45,
            child: IgnorePointer(
              child: Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('Accept')),
                  Chip(label: Text('Reject')),
                  Chip(label: Text('Merge')),
                  Chip(label: Text('Link Existing')),
                  Chip(label: Text('Edit Metadata')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            enabled: false,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
              helperText: 'Not yet available -- no Candidate Engineering Objects exist to annotate.',
            ),
          ),
        ],
      ),
    );
  }
}
