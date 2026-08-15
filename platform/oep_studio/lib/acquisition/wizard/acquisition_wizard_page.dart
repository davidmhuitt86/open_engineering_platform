import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import 'acquisition_wizard_controller.dart';
import 'steps/wizard_step_acquire.dart';
import 'steps/wizard_step_candidate_preview.dart';
import 'steps/wizard_step_chain_of_custody.dart';
import 'steps/wizard_step_knowledge_type.dart';
import 'steps/wizard_step_official_source.dart';
import 'steps/wizard_step_publish.dart';
import 'steps/wizard_step_review.dart';
import 'steps/wizard_step_scope.dart';

const _stepTitles = [
  'Knowledge Type',
  'Official Source',
  'Chain of Custody',
  'Acquisition Scope',
  'Acquire & Progress',
  'Candidate Preview',
  'Engineering Review',
  'Publish',
];

/// The Engineering Acquisition Wizard -- "the primary method by which
/// engineers import knowledge into OEP." Opened full-screen from
/// `AcquisitionStudioPage`'s "Acquire Engineering Knowledge" button.
///
/// Steps 5 ("Acquire Artifact") and 6 ("Live Progress") share one page
/// (`WizardStepAcquire`) since they're mechanically the same operation's
/// before/during state -- `_stepTitles` above reflects that (8 entries
/// covering the spec's 9 steps).
class AcquisitionWizardPage extends ConsumerWidget {
  const AcquisitionWizardPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (context) => const AcquisitionWizardPage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(acquisitionWizardControllerProvider);

    return Scaffold(
      backgroundColor: StudioColors.background,
      body: Column(
        children: [
          _WizardHeader(controller: controller),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WizardStepRail(controller: controller),
                const VerticalDivider(width: 1),
                Expanded(child: _stepContent(controller)),
              ],
            ),
          ),
          const Divider(height: 1),
          _WizardFooter(controller: controller),
        ],
      ),
    );
  }

  Widget _stepContent(AcquisitionWizardController controller) {
    return switch (controller.stepIndex) {
      0 => WizardStepKnowledgeType(controller: controller),
      1 => WizardStepOfficialSource(controller: controller),
      2 => WizardStepChainOfCustody(controller: controller),
      3 => WizardStepScope(controller: controller),
      4 => WizardStepAcquire(controller: controller),
      5 => const WizardStepCandidatePreview(),
      6 => const WizardStepReview(),
      _ => WizardStepPublish(controller: controller),
    };
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          const Icon(Icons.auto_stories_outlined, size: 18, color: StudioColors.selection),
          const SizedBox(width: 10),
          const Text('Acquire Engineering Knowledge',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _WizardStepRail extends StatelessWidget {
  const _WizardStepRail({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: StudioColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < _stepTitles.length; i++)
            _RailItem(
              index: i,
              title: _stepTitles[i],
              active: controller.stepIndex == i,
              reachable: i <= controller.stepIndex,
              onTap: i <= controller.stepIndex ? () => controller.goToStep(i) : null,
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.index, required this.title, required this.active, required this.reachable, this.onTap});
  final int index;
  final String title;
  final bool active;
  final bool reachable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? StudioColors.selection.withValues(alpha: 0.14) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: active
                    ? StudioColors.selection
                    : (reachable ? StudioColors.surfaceRaised : StudioColors.surfaceSunken),
                child: Text('${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: active ? Colors.white : StudioColors.textSecondary,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: reachable ? StudioColors.textPrimary : StudioColors.textDisabled,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({required this.controller});
  final AcquisitionWizardController controller;

  @override
  Widget build(BuildContext context) {
    final isLast = controller.stepIndex == _stepTitles.length - 1;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          Text('Step ${controller.stepIndex + 1} of ${_stepTitles.length}',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          const Spacer(),
          if (controller.stepIndex > 0)
            TextButton(onPressed: controller.back, child: const Text('Back')),
          const SizedBox(width: 8),
          if (!isLast)
            FilledButton(
              onPressed: controller.canGoNext ? controller.next : null,
              child: const Text('Next'),
            )
          else
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Done'),
            ),
        ],
      ),
    );
  }
}
