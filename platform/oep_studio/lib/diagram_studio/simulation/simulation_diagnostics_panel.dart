import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import '../panels/intelligence_panel_shared.dart';
import 'diagram_simulation_service.dart';

/// AP-DS-005 Engineering Diagnostics display — renders `FaultReport`/
/// `PropagationReport`/`PowerReport`/`GroundReport`/`VerificationReport`/
/// `SimulationReport`, each fetched from [DiagramSimulationService]
/// (which is itself a thin pass-through to `SimulationEngine`). No
/// diagnosis logic lives here — every report is already a computed,
/// final fact from the engine; this widget only formats it. Reuses
/// `intelligence_panel_shared.dart`'s `IntelligenceBusyBar` for the busy
/// indicator, matching AP-DS-003's visual precedent even though this
/// panel talks to a different engine.
class SimulationDiagnosticsPanel extends StatefulWidget {
  const SimulationDiagnosticsPanel({super.key, required this.simulation, required this.onSelectNode});

  final DiagramSimulationService simulation;
  final void Function(String nodeId) onSelectNode;

  @override
  State<SimulationDiagnosticsPanel> createState() => _SimulationDiagnosticsPanelState();
}

class _SimulationDiagnosticsPanelState extends State<SimulationDiagnosticsPanel> {
  VerificationReport? _verification;
  FaultReport? _faultReport;
  PowerReport? _powerReport;
  GroundReport? _groundReport;
  SimulationReport? _simulationReport;
  PropagationReport? _propagationReport;
  final TextEditingController _propagationTargetController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void dispose() {
    _propagationTargetController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!widget.simulation.hasSession) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verification = await widget.simulation.verify();
      final faultReport = await widget.simulation.faultReport();
      final powerReport = await widget.simulation.powerReport();
      final groundReport = await widget.simulation.groundReport();
      final simulationReport = await widget.simulation.simulationReport();
      if (!mounted) return;
      setState(() {
        _verification = verification;
        _faultReport = faultReport;
        _powerReport = powerReport;
        _groundReport = groundReport;
        _simulationReport = simulationReport;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runPropagation() async {
    final target = _propagationTargetController.text.trim();
    if (target.isEmpty) return;
    setState(() => _busy = true);
    try {
      final report = await widget.simulation.propagationReport(target);
      if (mounted) setState(() => _propagationReport = report);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.simulation.hasSession) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: EiEmptyState(icon: Icons.fact_check_outlined, message: 'No simulation session yet. Create one from the Sessions tab.'),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Engineering Diagnostics', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
              ElevatedButton.icon(
                key: const Key('diagnostics_refresh_button'),
                onPressed: _busy ? null : refresh,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (_error != null) EiErrorBanner(message: _error!),
          IntelligenceBusyBar(busy: _busy),
          if (_simulationReport != null) _simulationReportCard(_simulationReport!),
          if (_verification != null) _verificationCard(_verification!),
          if (_faultReport != null) _faultReportCard(_faultReport!),
          if (_powerReport != null) _domainReportCard('Power Report', Icons.bolt, _powerReport!),
          if (_groundReport != null) _domainReportCard('Ground Report', Icons.vertical_align_bottom, _groundReport!),
          EiSectionCard(
            title: 'Propagation Report',
            icon: Icons.route,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('propagation_target_field'),
                        controller: _propagationTargetController,
                        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                        decoration: const InputDecoration(hintText: 'Target node id', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const Key('propagation_run_button'),
                      onPressed: _busy ? null : _runPropagation,
                      child: const Text('Trace'),
                    ),
                  ],
                ),
                if (_propagationReport != null) ...[
                  const SizedBox(height: 8),
                  EiKeyValueRow('Signal', _propagationReport!.type.name),
                  EiKeyValueRow('Reachable', _propagationReport!.reachable ? 'Yes' : 'No',
                      valueColor: _propagationReport!.reachable ? StudioColors.success : StudioColors.error),
                  if (_propagationReport!.path.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_propagationReport!.path.join(' → '), style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5, fontFamily: 'Consolas')),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _simulationReportCard(SimulationReport report) {
    return EiSectionCard(
      title: 'Simulation Report',
      icon: Icons.summarize_outlined,
      trailing: EiChip(report.verificationPassed ? 'Passed' : 'Failed', color: report.verificationPassed ? StudioColors.success : StudioColors.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EiKeyValueRow('Session', report.sessionName),
          EiKeyValueRow('Active Faults', '${report.activeFaultCount}'),
          EiKeyValueRow('Errors', '${report.errorCount}', valueColor: report.errorCount > 0 ? StudioColors.error : null),
          EiKeyValueRow('Warnings', '${report.warningCount}', valueColor: report.warningCount > 0 ? StudioColors.warning : null),
          EiKeyValueRow('Functional Nodes', '${report.functionalNodeCount} / ${report.totalNodeCount}'),
        ],
      ),
    );
  }

  Widget _verificationCard(VerificationReport report) {
    return EiSectionCard(
      title: 'Verification Report (${report.findings.length} findings)',
      icon: Icons.rule,
      trailing: EiChip(report.passed ? 'Passed' : 'Failed', color: report.passed ? StudioColors.success : StudioColors.error),
      child: report.findings.isEmpty
          ? const Text('No findings.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final finding in report.findings)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          finding.severity == VerificationSeverity.error
                              ? Icons.error_outline
                              : finding.severity == VerificationSeverity.warning
                                  ? Icons.warning_amber_outlined
                                  : Icons.info_outline,
                          size: 14,
                          color: finding.severity == VerificationSeverity.error
                              ? StudioColors.error
                              : finding.severity == VerificationSeverity.warning
                                  ? StudioColors.warning
                                  : StudioColors.info,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: finding.nodeId == null ? null : () => widget.onSelectNode(finding.nodeId!),
                            child: Text(
                              '[${finding.check.name}] ${finding.message}',
                              style: TextStyle(
                                color: finding.nodeId == null ? StudioColors.textPrimary : StudioColors.selection,
                                fontSize: 11.5,
                              ),
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

  Widget _faultReportCard(FaultReport report) {
    return EiSectionCard(
      title: 'Fault Report (${report.activeFaultCount})',
      icon: Icons.bug_report_outlined,
      child: report.impacts.isEmpty
          ? const Text('No active faults.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final impact in report.impacts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${impact.fault.type.name} — ${impact.fault.targetId}', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5)),
                        Text('Blocks: ${impact.blockedNodeIds.isEmpty ? "(nothing)" : impact.blockedNodeIds.join(", ")}',
                            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _domainReportCard(String title, IconData icon, DomainStatusReport report) {
    return EiSectionCard(
      title: '$title (${report.reachableNodeIds.length} reachable)',
      icon: icon,
      trailing: report.unreachableExpectedNodeIds.isEmpty ? null : EiChip('${report.unreachableExpectedNodeIds.length} unexpected', color: StudioColors.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EiKeyValueRow('Reachable', '${report.reachableNodeIds.length}'),
          if (report.unreachableExpectedNodeIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final id in report.unreachableExpectedNodeIds) ActionChip(label: Text(id, style: const TextStyle(fontSize: 10.5)), onPressed: () => widget.onSelectNode(id))],
              ),
            ),
        ],
      ),
    );
  }
}
