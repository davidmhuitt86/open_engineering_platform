import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import 'diagram_simulation_service.dart';

/// AP-DS-005 Power Distribution panel — a domain-level summary of
/// Power/Ground Domains, Fuse/Relay Paths, Powered/Unpowered Devices, and
/// Inactive Paths, sourced directly from
/// [PowerDistributionCalculator.compute] (via
/// [DiagramSimulationService.powerDistribution]) — no recomputation here,
/// only presentation of the [PowerDistributionView] the engine already
/// returned. Follows `lib/diagram_studio/panels/` conventions (`EiSectionCard`/
/// `EiChip`/`EiKeyValueRow`, same as `KnowledgeSessionsPanel`).
class PowerDistributionPanel extends StatefulWidget {
  const PowerDistributionPanel({super.key, required this.simulation, required this.onSelectNode});

  final DiagramSimulationService simulation;
  final void Function(String nodeId) onSelectNode;

  @override
  State<PowerDistributionPanel> createState() => _PowerDistributionPanelState();
}

class _PowerDistributionPanelState extends State<PowerDistributionPanel> {
  PowerDistributionView? _view;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    if (!widget.simulation.hasSession) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final view = await widget.simulation.powerDistribution();
      if (mounted) setState(() => _view = view);
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
        child: EiEmptyState(icon: Icons.electrical_services_outlined, message: 'No simulation session yet. Create one from the Sessions tab.'),
      );
    }
    final view = _view;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Power Distribution', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
              ElevatedButton.icon(
                key: const Key('power_refresh_button'),
                onPressed: _busy ? null : refresh,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Recompute'),
              ),
            ],
          ),
          if (_error != null) EiErrorBanner(message: _error!),
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: LinearProgressIndicator(minHeight: 2)),
          if (view != null) ...[
            const SizedBox(height: 8),
            EiSectionCard(
              title: 'Power Domains (${view.powerDomains.length})',
              icon: Icons.bolt,
              child: view.powerDomains.isEmpty
                  ? const Text('No powered domains.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (var i = 0; i < view.powerDomains.length; i++) _domainRow('Domain ${i + 1}', view.powerDomains[i])],
                    ),
            ),
            EiSectionCard(
              title: 'Ground Domains (${view.groundDomains.length})',
              icon: Icons.vertical_align_bottom,
              child: view.groundDomains.isEmpty
                  ? const Text('No grounded domains.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (var i = 0; i < view.groundDomains.length; i++) _domainRow('Domain ${i + 1}', view.groundDomains[i])],
                    ),
            ),
            EiSectionCard(
              title: 'Fuse Paths (${view.fusePaths.length})',
              icon: Icons.electric_bolt,
              child: view.fusePaths.isEmpty
                  ? const Text('No powered fuse paths.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
                  : Column(children: [for (final path in view.fusePaths) _pathRow(path)]),
            ),
            EiSectionCard(
              title: 'Relay Paths (${view.relayPaths.length})',
              icon: Icons.settings_input_component,
              child: view.relayPaths.isEmpty
                  ? const Text('No powered relay paths.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
                  : Column(children: [for (final path in view.relayPaths) _pathRow(path)]),
            ),
            EiSectionCard(
              title: 'Devices',
              icon: Icons.devices_other,
              trailing: EiChip('${view.poweredDeviceIds.length} powered / ${view.unpoweredDeviceIds.length} unpowered'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EiKeyValueRow('Powered', '${view.poweredDeviceIds.length}', valueColor: StudioColors.success),
                  EiKeyValueRow('Unpowered', '${view.unpoweredDeviceIds.length}', valueColor: StudioColors.inactive),
                ],
              ),
            ),
            EiSectionCard(
              title: 'Inactive Paths (${view.inactivePathRelationshipIds.length})',
              icon: Icons.link_off,
              child: view.inactivePathRelationshipIds.isEmpty
                  ? const Text('No inactive relationships.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final id in view.inactivePathRelationshipIds) EiChip(id, color: StudioColors.inactive)],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _domainRow(String label, List<String> nodeIds) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text('$label:', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          for (final nodeId in nodeIds)
            ActionChip(
              label: Text(nodeId, style: const TextStyle(fontSize: 10.5)),
              onPressed: () => widget.onSelectNode(nodeId),
            ),
        ],
      ),
    );
  }

  Widget _pathRow(List<String> path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(path.join(' → '), style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5, fontFamily: 'Consolas')),
    );
  }
}
