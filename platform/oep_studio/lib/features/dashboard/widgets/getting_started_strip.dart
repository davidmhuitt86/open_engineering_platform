import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';

/// The "Getting Started" section of the Dashboard, per
/// 001-OEP-STUDIO-DASHBOARD-v1.0.png.
class GettingStartedStrip extends StatelessWidget {
  const GettingStartedStrip({super.key});

  static const _steps = [
    _Step('Open or Create Repository', 'Open an existing repository or create a new one.'),
    _Step('Explore Objects', 'Browse and manage objects in your repository.'),
    _Step('Create Relationships', 'Define and manage relationships between objects.'),
    _Step('Validate Data', 'Run validation to ensure data integrity.'),
    _Step('Generate Outputs', 'Generate diagrams, reports, and documentation.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.rocket_launch_outlined, size: 18, color: StudioColors.selection),
                SizedBox(width: 10),
                Text(
                  'Getting Started',
                  style: TextStyle(
                    color: StudioColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                return isNarrow
                    ? Column(
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StepTile(index: i + 1, step: _steps[i]),
                            ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _steps.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.chevron_right, size: 16, color: StudioColors.textDisabled),
                              ),
                            Expanded(child: _StepTile(index: i + 1, step: _steps[i])),
                          ],
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step(this.title, this.description);

  final String title;
  final String description;
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: StudioColors.selection,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  color: StudioColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.description,
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
