import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../acquisition_wizard_controller.dart';

/// Wizard Steps 5 ("Acquire Artifact") + 6 ("Live Progress") combined
/// into one screen -- mechanically they're the same real operation
/// (`AcquisitionWizardController.run()`), just before/during/after
/// states of it. "Do NOT require multiple button presses... the backend
/// should automatically progress until Completed or Failed."
class WizardStepAcquire extends StatelessWidget {
  const WizardStepAcquire({super.key, required this.controller});

  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.runStatus == AcquisitionRunStatus.idle) {
      return _IdleView(controller: controller);
    }
    return _ProgressView(controller: controller);
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ready to acquire',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'OEP will now connect to the source, download the artifact, verify its integrity with a real '
            'SHA-256 hash, extract its metadata, and publish it into the permanent Reference Vault -- '
            'automatically, start to finish. You will not need to press this again.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 8),
          _SummaryLine('Knowledge Type', controller.knowledgeType ?? '—'),
          _SummaryLine('Source', controller.sourceName ?? '—'),
          _SummaryLine('URL', controller.originalUrl),
          _SummaryLine('Scope', controller.scopeKind),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.run,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Acquire Engineering Knowledge'),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12))),
        ],
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    final running = controller.runStatus == AcquisitionRunStatus.running;
    final failed = controller.runStatus == AcquisitionRunStatus.failed;
    final completed = controller.runStatus == AcquisitionRunStatus.completed;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (running)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else if (completed)
                const Icon(Icons.check_circle, color: StudioColors.success, size: 20)
              else
                const Icon(Icons.error, color: StudioColors.error, size: 20),
              const SizedBox(width: 10),
              Text(
                running ? 'Acquiring…' : (completed ? 'Acquisition Complete' : 'Acquisition Failed'),
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (failed && controller.failureMessage != null) ...[
            const SizedBox(height: 8),
            Text(controller.failureMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12.5)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.run,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Live Acquisition Log', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StudioColors.surfaceSunken,
                border: Border.all(color: StudioColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                itemCount: controller.log.length,
                itemBuilder: (context, index) {
                  final entry = controller.log[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_time(entry.timestamp)}  ${entry.message}',
                      style: TextStyle(
                        color: entry.isError ? StudioColors.error : StudioColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
