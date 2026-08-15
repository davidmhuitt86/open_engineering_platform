import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import 'diagram_simulation_service.dart';

/// AP-DS-005 Fault Injection UI — select a target (node or relationship,
/// from the diagram's own graph) and one of the 10 [SimulationFaultType]
/// values, call `SimulationEngine.injectFault` (via
/// [DiagramSimulationService]); view/clear active faults via
/// `clearFault`/`restoreNormal`. No fault MEANING is computed here — this
/// panel only builds a [SimulationFault] value object and hands it to the
/// engine; every consequence (what becomes unreachable, which
/// verification findings fire) is entirely the engine's computation,
/// read back via [DiagramSimulationService.currentSession.activeFaults].
class FaultInjectionPanel extends StatefulWidget {
  const FaultInjectionPanel({super.key, required this.simulation, required this.graph, required this.onChanged});

  final DiagramSimulationService simulation;
  final EngineeringGraph graph;
  final VoidCallback onChanged;

  @override
  State<FaultInjectionPanel> createState() => _FaultInjectionPanelState();
}

class _FaultInjectionPanelState extends State<FaultInjectionPanel> {
  String? _targetId;
  bool _targetIsRelationship = false;
  SimulationFaultType _faultType = SimulationFaultType.openCircuit;
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onChanged();
      }
    }
  }

  Future<void> _inject() async {
    final targetId = _targetId;
    if (targetId == null) return;
    final fault = SimulationFault(
      id: EngineIds.generate('sim-fault'),
      type: _faultType,
      targetId: targetId,
      isRelationship: _targetIsRelationship,
      injectedAt: DateTime.now(),
      label: '${_faultType.name} on $targetId',
    );
    await _run(() => widget.simulation.injectFault(fault));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.simulation.currentSession;
    if (session == null) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: EiEmptyState(icon: Icons.bolt_outlined, message: 'No simulation session yet. Create one from the Sessions tab.'),
      );
    }
    final nodeIds = widget.graph.nodes.keys.toList()..sort();
    final relationshipIds = widget.graph.relationships.keys.toList()..sort();
    final activeFaults = session.activeFaults.active;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) EiErrorBanner(message: _error!),
          Text('Inject Fault', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<bool>(
                  key: const Key('fault_target_kind'),
                  initialValue: _targetIsRelationship,
                  decoration: const InputDecoration(labelText: 'Target kind', isDense: true),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Node')),
                    DropdownMenuItem(value: true, child: Text('Relationship')),
                  ],
                  onChanged: (value) => setState(() {
                    _targetIsRelationship = value ?? false;
                    _targetId = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('fault_target_id'),
            initialValue: _targetId,
            decoration: const InputDecoration(labelText: 'Target', isDense: true),
            items: [
              for (final id in (_targetIsRelationship ? relationshipIds : nodeIds)) DropdownMenuItem(value: id, child: Text(id)),
            ],
            onChanged: (value) => setState(() => _targetId = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SimulationFaultType>(
            key: const Key('fault_type'),
            initialValue: _faultType,
            decoration: const InputDecoration(labelText: 'Fault type', isDense: true),
            items: [
              for (final type in SimulationFaultType.values) DropdownMenuItem(value: type, child: Text(type.name)),
            ],
            onChanged: (value) => setState(() => _faultType = value ?? _faultType),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                key: const Key('fault_inject_button'),
                onPressed: _busy || _targetId == null ? null : _inject,
                icon: const Icon(Icons.flash_on, size: 16),
                label: const Text('Inject Fault'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('fault_restore_normal_button'),
                onPressed: _busy || activeFaults.isEmpty ? null : () => _run(widget.simulation.restoreNormal),
                icon: const Icon(Icons.healing, size: 16),
                label: const Text('Restore Normal'),
              ),
            ],
          ),
          const Divider(color: StudioColors.borderSubtle, height: 24),
          Text('Active Faults (${activeFaults.length})', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (activeFaults.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No active faults — nominal state.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
            )
          else
            for (final fault in activeFaults)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded, color: StudioColors.error, size: 16),
                title: Text(fault.type.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                subtitle: Text(
                  '${fault.isRelationship ? "relationship" : "node"}: ${fault.targetId}',
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5),
                ),
                trailing: IconButton(
                  tooltip: 'Clear fault',
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: _busy ? null : () => _run(() => widget.simulation.clearFault(fault.id)),
                ),
              ),
        ],
      ),
    );
  }
}
