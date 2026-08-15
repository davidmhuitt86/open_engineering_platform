import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../acquisition_wizard_controller.dart';

const _packages = [
  'core_reference',
  'electrical_reference',
  'physics_reference',
  'math_reference',
  'materials_reference',
  'Custom package…',
];

/// Wizard Step 9 -- "Publish."
///
/// The summary items shown are real: the artifact genuinely is stored
/// (Step 5-6 already published it to the real Reference Vault --
/// `POST /vault`), its SHA-256 was genuinely computed and verified, and
/// its Chain of Custody was genuinely recorded (`ChainOfCustodyStorage`).
///
/// **The "destination package" selector is a disclosed placeholder.**
/// `oep_acquisition`'s Reference Vault is a single, flat,
/// content-addressable store (`POST /vault` -- no package/collection
/// concept anywhere in its schema); routing an artifact into
/// `core_reference` vs. `electrical_reference` etc. doesn't exist at the
/// backend yet. Selecting one here doesn't silently do nothing -- it's
/// visibly informational, not a working control, until a future backend
/// work package adds real package routing to the Vault.
class WizardStepPublish extends StatefulWidget {
  const WizardStepPublish({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  State<WizardStepPublish> createState() => _WizardStepPublishState();
}

class _WizardStepPublishState extends State<WizardStepPublish> {
  String _package = _packages.first;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final published = c.runStatus == AcquisitionRunStatus.completed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Publish',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (!published)
            const Text('Run acquisition first (Step 5) before publishing.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5))
          else ...[
            _StatusLine('Artifact Stored', true, detail: c.vaultPath),
            _StatusLine('SHA-256 Verified', true, detail: c.sha256Hash),
            _StatusLine('Chain of Custody Established', true, detail: 'Recorded for ${c.engineer}'),
            const _StatusLine('Candidate Objects Created', false, detail: 'Requires the Knowledge Engine (not built yet)'),
            const _StatusLine('Ready for Knowledge Studio', false, detail: 'Requires Candidate Objects above'),
            const SizedBox(height: 20),
            const Text('Destination package', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButton<String>(
              value: _package,
              items: [for (final p in _packages) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _package = v!),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: StudioColors.surfaceRaised,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Package routing is not implemented in the Reference Vault backend yet -- the artifact is '
                'stored in the shared Vault regardless of the selection above. This will become real once a '
                'future backend work package adds package/collection support.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.done, {this.detail});
  final String label;
  final bool done;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 16,
              color: done ? StudioColors.success : StudioColors.textDisabled),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: done ? StudioColors.textPrimary : StudioColors.textDisabled, fontSize: 13)),
                if (detail != null)
                  Text(detail!, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
