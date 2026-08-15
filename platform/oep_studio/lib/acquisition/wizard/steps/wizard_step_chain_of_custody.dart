import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../acquisition_wizard_controller.dart';

class _FieldSpec {
  const _FieldSpec(this.label, this.why, this.getter, this.setter, {this.required = false});
  final String label;
  final String why;
  final String Function(AcquisitionWizardController) getter;
  final void Function(AcquisitionWizardController, String) setter;
  final bool required;
}

final _fields = <_FieldSpec>[
  _FieldSpec(
    'Original URL',
    'This is what OEP actually fetches, and the permanent link back to where this knowledge came from.',
    (c) => c.originalUrl,
    (c, v) => c.updateCustody(originalUrl: v),
    required: true,
  ),
  _FieldSpec(
    'Publisher',
    'This establishes permanent provenance -- who is responsible for this material\'s accuracy.',
    (c) => c.publisher,
    (c, v) => c.updateCustody(publisher: v),
  ),
  _FieldSpec(
    'Publication Date',
    'Engineering knowledge changes over time; this pins exactly which version of the truth you acquired.',
    (c) => c.publicationDate,
    (c, v) => c.updateCustody(publicationDate: v),
  ),
  _FieldSpec(
    'Revision',
    'Standards and datasheets get revised. This distinguishes this acquisition from a future, different one of the same document.',
    (c) => c.revision,
    (c, v) => c.updateCustody(revision: v),
  ),
  _FieldSpec(
    'License',
    'This ensures OEP only reuses material engineers are actually permitted to reuse.',
    (c) => c.license,
    (c, v) => c.updateCustody(license: v),
  ),
  _FieldSpec(
    'Language',
    'Lets Knowledge Studio and future engineers know what they are reading before they open it.',
    (c) => c.language,
    (c, v) => c.updateCustody(language: v),
  ),
  _FieldSpec(
    'Acquisition Method',
    'This allows future engineers to reproduce this acquisition exactly the way you did it.',
    (c) => c.acquisitionMethod,
    (c, v) => c.updateCustody(acquisitionMethod: v),
  ),
  _FieldSpec(
    'Engineer',
    'This ensures every Engineering Object can always be traced back to the person who brought it into OEP.',
    (c) => c.engineer,
    (c, v) => c.updateCustody(engineer: v),
    required: true,
  ),
];

/// Wizard Step 3 -- "Display an explanation beside every field
/// describing WHY it exists."
class WizardStepChainOfCustody extends StatefulWidget {
  const WizardStepChainOfCustody({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  State<WizardStepChainOfCustody> createState() => _WizardStepChainOfCustodyState();
}

class _WizardStepChainOfCustodyState extends State<WizardStepChainOfCustody> {
  late final _controllers = {for (final f in _fields) f.label: TextEditingController(text: f.getter(widget.controller))};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Engineering Chain of Custody',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'This ensures every Engineering Object can always be traced back to its original source -- the '
            'foundation of trusted engineering evidence. Stored alongside the artifact once acquisition '
            'completes.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          for (final field in _fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _controllers[field.label],
                      onChanged: (v) => field.setter(widget.controller, v),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: field.required ? '${field.label} *' : field.label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: StudioColors.textDisabled),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(field.why,
                                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
