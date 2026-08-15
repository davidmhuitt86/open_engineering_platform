import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/theme/studio_colors.dart';

/// The Studio/Workspace Selection screen (OEP First Startup UI, Phase
/// 0A; approved render `01_First_Launch_Onboarding.png`, panel 4).
///
/// **Scope-locked**: visual + selectable only. Tiles list only Studios
/// that actually exist as real, working [StudioDestination]s today
/// (Diagram, Knowledge, Engineering Acquisition, Repository,
/// Engineering Exchange, AI Engineering Copilot, Engineering
/// Intelligence) -- the render's fictional "Automotive Installer" /
/// "Simulation Workspace" / "Review Workspace" tiles have no
/// implementation anywhere in this codebase and are not shown.
///
/// Selecting a tile highlights it; "Continue" hands the chosen
/// [StudioDestination] to [onLaunch] when supplied -- the caller (now
/// `OnboardingFlow`/`OepBootApp`) decides what launching means. `null`
/// (the default, and what every pre-existing standalone-screen test
/// still constructs) preserves the original placeholder-dialog
/// behavior, since Studio launch used to be explicitly out of scope
/// for this screen alone.
class WorkspaceSelectionScreen extends StatefulWidget {
  const WorkspaceSelectionScreen({super.key, this.onLaunch});

  final void Function(StudioDestination destination)? onLaunch;

  @override
  State<WorkspaceSelectionScreen> createState() => _WorkspaceSelectionScreenState();
}

const _availableStudios = [
  StudioDestination.diagram,
  StudioDestination.knowledge,
  StudioDestination.acquisition,
  StudioDestination.repository,
  StudioDestination.exchange,
  StudioDestination.copilot,
  StudioDestination.engineeringIntelligence,
];

class _WorkspaceSelectionScreenState extends State<WorkspaceSelectionScreen> {
  StudioDestination? _selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 640,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: StudioColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StudioColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Your Workspace',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the Studio that best matches your current engineering activity.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final destination in _availableStudios)
                    _WorkspaceTile(
                      destination: destination,
                      selected: _selected == destination,
                      onTap: () => setState(() => _selected = destination),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    key: const Key('workspace-continue-button'),
                    onPressed: _selected == null ? null : () => _continue(context),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continue(BuildContext context) {
    final onLaunch = widget.onLaunch;
    if (onLaunch != null) {
      onLaunch(_selected!);
      return;
    }
    unawaited(_showContinueMessage(context));
  }

  Future<void> _showContinueMessage(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_selected!.label),
        content: const Text('Studio launch will be implemented in the next phase.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.destination, required this.selected, required this.onTap});

  final StudioDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioColors.selectedRowBackground : StudioColors.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('workspace-tile-${destination.path}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? StudioColors.selection : StudioColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.icon, size: 24, color: selected ? StudioColors.selection : StudioColors.textSecondary),
              const SizedBox(height: 10),
              Text(
                destination.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? StudioColors.textPrimary : StudioColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
