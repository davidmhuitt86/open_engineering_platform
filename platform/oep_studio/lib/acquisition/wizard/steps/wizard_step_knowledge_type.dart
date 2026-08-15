import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../acquisition_wizard_controller.dart';

const knowledgeTypes = [
  'Engineering Standard',
  'Technical Paper',
  'Research Paper',
  'Textbook',
  'Datasheet',
  'Service Manual',
  'OEM Documentation',
  'Wiring Diagram',
  'Material Specification',
  'Physics Reference',
  'Mathematics Reference',
  'Other',
];

/// Wizard Step 1 -- "Explain why acquisition type matters."
class WizardStepKnowledgeType extends StatelessWidget {
  const WizardStepKnowledgeType({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What kind of knowledge are you acquiring?',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'OEP uses this to decide how the acquired material should later be interpreted -- a Wiring '
            'Diagram is read for Engineering Objects and connections; a Material Specification is read for '
            'properties and tolerances; a Standard is read as an authoritative reference other Engineering '
            'Objects can cite. Choosing correctly here means Knowledge Studio can make better sense of it '
            'once the Knowledge Engine reads it.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in knowledgeTypes)
                ChoiceChip(
                  label: Text(type),
                  selected: controller.knowledgeType == type,
                  onSelected: (_) => controller.setKnowledgeType(type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
