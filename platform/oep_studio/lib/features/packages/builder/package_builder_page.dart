import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/foundation_runtime_service.dart';
import '../../../core/theme/studio_colors.dart';
import '../../../core/theme/studio_typography.dart';
import '../../../shared/widgets/studio_panel_header.dart';
import 'package_builder_controller.dart';

const _stepTitles = ['Select Objects', 'Dependencies', 'Validation', 'Metadata & Version', 'Build & Publish'];

/// The Package Builder wizard (Phase 6). Opened full-screen, mirroring
/// `AcquisitionWizardPage`'s established shell (header/step-rail/
/// content/footer) -- Package Builder is the second wizard-shaped
/// workflow in this app, not a reason to build a new generic wizard
/// framework for two consumers.
///
/// **Backend limitation, disclosed rather than worked around**:
/// inspection of `foundation_bridge.dart` before this file was written
/// found no `createPackage`, `buildPackage`, `signPackage`, or
/// `publishPackage` native entry point anywhere -- package *authoring*
/// has zero backend support today (only installing/inspecting/
/// validating/uninstalling *already-built* `.oep` archives is real,
/// via `PackageManagerPage`). `resolveDependencies`/`validatePackage`
/// both operate on an existing archive path, not a live in-progress
/// object selection, so they have nothing to call against during
/// authoring either. Only two steps have anywhere real to act:
/// **Select Objects** (real Engineering Objects from the open
/// repository) and **Metadata & Version** (a local form, held in
/// [PackageBuilderController] state, submitted nowhere since nothing
/// exists yet to submit it to). The remaining three steps are real UI
/// -- present, not hidden -- but honestly disabled with the specific
/// missing capability named, per this phase's "do not create fake
/// progress or fake package results" instruction.
class PackageBuilderPage extends ConsumerWidget {
  const PackageBuilderPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (context) => const PackageBuilderPage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(packageBuilderControllerProvider);
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

  Widget _stepContent(PackageBuilderController controller) {
    return switch (controller.stepIndex) {
      0 => _StepSelectObjects(controller: controller),
      1 => const _StepUnavailable(
          title: 'Dependencies',
          reason: 'Dependency analysis requires an already-built package archive '
              '(`FoundationBridge.resolveDependencies`) -- there is no API to analyze '
              'dependencies for a live, in-progress object selection before a package '
              'exists.',
        ),
      2 => const _StepUnavailable(
          title: 'Validation',
          reason: 'Package validation (`FoundationBridge.validatePackage`) also requires an '
              'already-built archive to validate -- the same limitation as Dependencies.',
        ),
      3 => _StepMetadata(controller: controller),
      _ => const _StepUnavailable(
          title: 'Build & Publish',
          reason: 'No `createPackage`, `buildPackage`, `signPackage`, or `publishPackage` API '
              'exists in the Foundation Bridge today -- package authoring, signing, and '
              'publishing are not yet implemented on the backend.',
        ),
    };
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.controller});
  final PackageBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return StudioPanelHeader(
      title: 'Package Builder',
      icon: Icons.inventory_2_outlined,
      iconColor: StudioColors.selection,
      trailing: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _WizardStepRail extends StatelessWidget {
  const _WizardStepRail({required this.controller});
  final PackageBuilderController controller;

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
              onTap: () => controller.goToStep(i),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.index, required this.title, required this.active, required this.onTap});
  final int index;
  final String title;
  final bool active;
  final VoidCallback onTap;

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
                backgroundColor: active ? StudioColors.selection : StudioColors.surfaceRaised,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 10, color: active ? Colors.white : StudioColors.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? StudioColors.textPrimary : StudioColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
  final PackageBuilderController controller;

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
          if (controller.stepIndex > 0) TextButton(onPressed: controller.back, child: const Text('Back')),
          const SizedBox(width: 8),
          if (!isLast) FilledButton(onPressed: controller.next, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _StepSelectObjects extends ConsumerWidget {
  const _StepSelectObjects({required this.controller});
  final PackageBuilderController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objects = ref.watch(foundationRuntimeServiceProvider).objectList ?? const [];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Objects', style: StudioTypography.pageTitle),
          const SizedBox(height: 4),
          Text(
            'Real Engineering Objects from the open repository (${objects.length} available). '
            '${controller.selectedObjectIds.length} selected.',
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (objects.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No Engineering Objects in the open repository.', style: TextStyle(color: StudioColors.textSecondary)),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: objects.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final object = objects[index];
                  final selected = controller.selectedObjectIds.contains(object.objectId);
                  return CheckboxListTile(
                    dense: true,
                    value: selected,
                    onChanged: (_) => controller.toggleObject(object),
                    title: Text(object.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
                    subtitle: Text(object.category.label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StepMetadata extends StatelessWidget {
  const _StepMetadata({required this.controller});
  final PackageBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Metadata & Version', style: StudioTypography.pageTitle),
          const SizedBox(height: 4),
          const Text(
            'Held locally for this session only -- there is no `createPackage` API yet to submit it to.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 420,
            child: Column(
              children: [
                TextFormField(
                  initialValue: controller.packageName,
                  decoration: const InputDecoration(labelText: 'Package Name'),
                  onChanged: (value) => controller.setMetadata(name: value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: controller.packageVersion,
                  decoration: const InputDecoration(labelText: 'Version', hintText: 'e.g. 1.0.0'),
                  onChanged: (value) => controller.setMetadata(version: value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: controller.packageAuthor,
                  decoration: const InputDecoration(labelText: 'Author'),
                  onChanged: (value) => controller.setMetadata(author: value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: controller.packageDescription,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  onChanged: (value) => controller.setMetadata(description: value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepUnavailable extends StatelessWidget {
  const _StepUnavailable({required this.title, required this.reason});
  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: StudioTypography.pageTitle),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StudioColors.surfaceRaised,
              border: Border.all(color: StudioColors.borderSubtle),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: StudioColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Not yet available. $reason',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12.5, height: 1.4),
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
