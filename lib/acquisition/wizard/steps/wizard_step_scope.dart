import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../acquisition_wizard_controller.dart';

const _scopeKinds = ['Entire Document', 'Selected Pages', 'Selected Chapters', 'Selected Sections'];

/// Wizard Step 4 -- "The complete artifact is ALWAYS stored in the
/// Reference Vault. Only the selected content is extracted into
/// Candidate Engineering Objects."
///
/// **Disclosed limitation**: `oep_acquisition` has no partial-extraction
/// concept at all yet -- it always acquires and stores the complete
/// artifact (there is no "download pages 4-9" capability at the HTTP/
/// connector layer). This step's selection is recorded as part of the
/// local Chain of Custody (`scopeDescription`) so intent is preserved,
/// but every acquisition today is functionally "Entire Document" at the
/// backend regardless of what's chosen here -- that only changes once a
/// future Knowledge Engine work package can act on it during extraction.
class WizardStepScope extends StatefulWidget {
  const WizardStepScope({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  State<WizardStepScope> createState() => _WizardStepScopeState();
}

class _WizardStepScopeState extends State<WizardStepScope> {
  late String _kind = widget.controller.scopeKind;
  late final _detail = TextEditingController(text: widget.controller.scopeDetail);

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Acquisition Scope',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'The complete artifact is always stored in the Reference Vault, byte-for-byte, regardless of '
            'what you choose here. This scope only describes what should later be extracted into '
            'Candidate Engineering Objects once the Knowledge Engine can act on it.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          // `RadioGroup` (not `RadioListTile.groupValue`/`onChanged`,
          // deprecated after Flutter 3.32) owns the selection for the
          // whole set.
          RadioGroup<String>(
            groupValue: _kind,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _kind = value);
              widget.controller.setScope(_kind, _detail.text);
            },
            child: Column(
              children: [
                for (final kind in _scopeKinds)
                  RadioListTile<String>(
                    value: kind,
                    dense: true,
                    title: Text(kind, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
                  ),
                const RadioListTile<String>(
                  value: 'Highlighted Regions',
                  dense: true,
                  enabled: false,
                  title: Text('Highlighted Regions',
                      style: TextStyle(color: StudioColors.textDisabled, fontSize: 13)),
                  subtitle: Text('Coming soon', style: TextStyle(color: StudioColors.textDisabled, fontSize: 11)),
                ),
              ],
            ),
          ),
          if (_kind != 'Entire Document') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _detail,
              onChanged: (v) => widget.controller.setScope(_kind, v),
              decoration: InputDecoration(
                isDense: true,
                labelText: switch (_kind) {
                  'Selected Pages' => 'Which pages? (e.g. 4-9, 12)',
                  'Selected Chapters' => 'Which chapters?',
                  'Selected Sections' => 'Which sections?',
                  _ => 'Detail',
                },
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
