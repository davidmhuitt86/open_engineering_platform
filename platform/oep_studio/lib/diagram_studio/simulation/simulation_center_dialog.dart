import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import 'diagram_simulation_service.dart';
import 'fault_injection_panel.dart';
import 'power_distribution_panel.dart';
import 'simulation_diagnostics_panel.dart';
import 'simulation_playback_controls.dart';
import 'simulation_sessions_panel.dart';

/// AP-DS-005: the single entry point for Engineering Verification &
/// Simulation — the one dialog `diagram_studio_page.dart` opens, exactly
/// mirroring AP-DS-004's `PublishingCenterDialog` precedent (a tabbed
/// `AlertDialog`, one toolbar/document-bar icon button as the only
/// integration point into that large, shared file — see
/// `IMPLEMENTATION_STATUS.md`'s recorded lesson from AP-DS-004 about
/// minimizing footprint there).
///
/// Ties together: Sessions (create/resume/duplicate/compare/delete/
/// export), Playback (play/pause/resume/reset/step/timeline/bookmarks/
/// replay/speed), Power Distribution, Fault Injection, and Engineering
/// Diagnostics — every tab reads/writes through the single
/// [DiagramSimulationService] instance the host page owns, so all tabs
/// stay consistent with one live `SimulationSession`.
class SimulationCenterDialog extends StatefulWidget {
  const SimulationCenterDialog({
    super.key,
    required this.simulation,
    required this.graph,
    required this.onSelectNode,
    required this.onSessionStateChanged,
  });

  final DiagramSimulationService simulation;
  final EngineeringGraph graph;
  final void Function(String nodeId) onSelectNode;

  /// Invoked after any action that may have changed session state
  /// (session created/resumed/stepped/faulted/etc.) so the host page can
  /// refresh the canvas overlay outside this dialog.
  final VoidCallback onSessionStateChanged;

  static Future<void> show(
    BuildContext context, {
    required DiagramSimulationService simulation,
    required EngineeringGraph graph,
    required void Function(String nodeId) onSelectNode,
    required VoidCallback onSessionStateChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SimulationCenterDialog(
        simulation: simulation,
        graph: graph,
        onSelectNode: onSelectNode,
        onSessionStateChanged: onSessionStateChanged,
      ),
    );
  }

  @override
  State<SimulationCenterDialog> createState() => _SimulationCenterDialogState();
}

class _SimulationCenterDialogState extends State<SimulationCenterDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  void _refresh() {
    if (mounted) setState(() {});
    widget.onSessionStateChanged();
  }

  void _selectAndClose(String nodeId) {
    widget.onSelectNode(nodeId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: const Text('Engineering Verification & Simulation', style: TextStyle(color: StudioColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 760,
        height: 600,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: StudioColors.selection,
              unselectedLabelColor: StudioColors.textSecondary,
              tabs: const [
                Tab(text: 'Sessions'),
                Tab(text: 'Playback'),
                Tab(text: 'Power Distribution'),
                Tab(text: 'Fault Injection'),
                Tab(text: 'Diagnostics'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  SimulationSessionsPanel(simulation: widget.simulation, graph: widget.graph, onSessionChanged: _refresh),
                  SimulationPlaybackControls(simulation: widget.simulation, onChanged: _refresh),
                  PowerDistributionPanel(simulation: widget.simulation, onSelectNode: _selectAndClose),
                  FaultInjectionPanel(simulation: widget.simulation, graph: widget.graph, onChanged: _refresh),
                  SimulationDiagnosticsPanel(simulation: widget.simulation, onSelectNode: _selectAndClose),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
