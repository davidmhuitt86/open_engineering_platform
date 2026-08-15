import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../models/acquisition_connection_status.dart';
import '../panels/acquisition_jobs_panel.dart';
import '../panels/acquisition_pipeline_panel.dart';
import '../panels/acquisition_sources_panel.dart';
import '../panels/acquisition_vault_panel.dart';
import '../services/acquisition_runtime_service.dart';
import '../services/acquisition_runtime_state.dart';
import '../wizard/acquisition_wizard_page.dart';

/// The Engineering Acquisition workspace (WP-PLAT-020) -- registered as
/// a Studio workspace exactly like Knowledge Studio and Diagram Studio:
/// same Navigation Rail, theme, and window layout via `StudioShell`. Per
/// this Work Package's Definition of Done, the engineer should not
/// perceive Engineering Acquisition Management (EAM) as a separate
/// application -- this page is the only thing that changes; EAM's own
/// REST API (`oep_acquisition`) never has, and does not gain, any UI of
/// its own outside of Studio.
///
/// Layout mirrors Knowledge Studio's multi-panel row shape: Sources,
/// Jobs, and the Reference Vault across the top; the Pipeline
/// (Downloads -> Verifications -> Metadata for the selected job) below.
class AcquisitionStudioPage extends ConsumerStatefulWidget {
  const AcquisitionStudioPage({super.key});

  @override
  ConsumerState<AcquisitionStudioPage> createState() => _AcquisitionStudioPageState();
}

class _AcquisitionStudioPageState extends ConsumerState<AcquisitionStudioPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(acquisitionRuntimeServiceProvider.notifier).refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(acquisitionRuntimeServiceProvider);
    final notifier = ref.read(acquisitionRuntimeServiceProvider.notifier);

    return Column(
      children: [
        _ConnectionBanner(state: state, onRefresh: notifier.refreshAll),
        const _WizardEntryBar(),
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('OPERATIONAL DASHBOARDS',
                      style: TextStyle(color: StudioColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(child: AcquisitionSourcesPanel()),
                    VerticalDivider(width: 1),
                    Expanded(child: AcquisitionJobsPanel()),
                    VerticalDivider(width: 1),
                    Expanded(child: AcquisitionVaultPanel()),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(flex: 2, child: AcquisitionPipelinePanel()),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Wizard's entry point -- "Replace the primary acquisition workflow
/// with one button: Acquire Engineering Knowledge." The panels below
/// remain (per this same Work Package: "Retain the existing panels...
/// these become operational dashboards rather than the primary
/// workflow"), but this is now the first thing an engineer reaches for.
class _WizardEntryBar extends StatelessWidget {
  const _WizardEntryBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: StudioColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bring engineering knowledge into OEP',
                    style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'The Wizard walks you through acquiring, verifying, and preserving a real engineering '
                  'source -- with full Chain of Custody -- one guided step at a time.',
                  style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(AcquisitionWizardPage.route()),
            icon: const Icon(Icons.auto_stories_outlined, size: 18),
            label: const Text('Acquire Engineering Knowledge'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state, required this.onRefresh});

  final AcquisitionServiceState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isError = state.connectionStatus == AcquisitionConnectionStatus.networkError ||
        state.connectionStatus == AcquisitionConnectionStatus.serviceError ||
        state.lastError != null;

    if (!isError && !state.loading) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: isError ? StudioColors.error.withValues(alpha: 0.15) : StudioColors.surfaceRaised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (state.loading)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.error_outline, size: 16, color: StudioColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.loading
                  ? 'Loading from Engineering Acquisition…'
                  : (state.lastError ?? 'Could not reach the Engineering Acquisition service.'),
              style: TextStyle(
                color: isError ? StudioColors.error : StudioColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          if (!state.loading)
            TextButton(onPressed: onRefresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}
