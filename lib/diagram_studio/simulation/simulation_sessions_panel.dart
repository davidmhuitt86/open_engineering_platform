import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import 'diagram_simulation_service.dart';

/// AP-DS-005 Session Management UI — Create/Save (Export)/Resume/
/// Duplicate/Compare/Delete/Export, structurally following
/// `KnowledgeSessionsPanel`'s precedent (list + inspect-on-tap +
/// row-action icons), backed here by [DiagramSimulationService] instead
/// of `FoundationBridge`'s EIP session calls — the Simulation Engine's
/// session lifecycle is a distinct, pure-Dart facility (see that
/// service's own doc comment), so this panel talks to it directly rather
/// than routing through Foundation.
class SimulationSessionsPanel extends StatefulWidget {
  const SimulationSessionsPanel({
    super.key,
    required this.simulation,
    required this.graph,
    required this.onSessionChanged,
  });

  final DiagramSimulationService simulation;
  final EngineeringGraph graph;

  /// Invoked whenever the current session id changes (create/resume/
  /// duplicate/import/delete-of-current) so the host dialog's other tabs
  /// (which read `simulation.currentSession` directly) refresh.
  final VoidCallback onSessionChanged;

  @override
  State<SimulationSessionsPanel> createState() => _SimulationSessionsPanelState();
}

class _SimulationSessionsPanelState extends State<SimulationSessionsPanel> {
  bool _busy = false;
  String? _error;
  String? _compareWithId;
  SimulationCompareResult? _compareResult;
  Map<String, Object?>? _exportedJson;

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
        widget.onSessionChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.simulation.allSessionIds;
    final currentId = widget.simulation.currentSessionId;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Simulation Sessions (${ids.length})', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
              ),
              ElevatedButton.icon(
                key: const Key('sim_create_session'),
                onPressed: _busy ? null : () => _run(() => widget.simulation.createSession(widget.graph, name: 'Session ${DateTime.now().toIso8601String()}')),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Create'),
              ),
            ],
          ),
          if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: LinearProgressIndicator(minHeight: 2)),
          if (_error != null) EiErrorBanner(message: _error!),
          if (ids.isEmpty && !_busy)
            const EiEmptyState(icon: Icons.folder_off_outlined, message: 'No simulation sessions yet. Create one to get started.')
          else
            for (final id in ids)
              Material(
                color: id == currentId ? StudioColors.selection.withValues(alpha: 0.1) : Colors.transparent,
                child: InkWell(
                  onTap: () => _run(() => widget.simulation.resumeSession(id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(id, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5, fontFamily: 'Consolas'))),
                        IconButton(tooltip: 'Resume', iconSize: 15, icon: const Icon(Icons.play_circle_outline), onPressed: () => _run(() => widget.simulation.resumeSession(id))),
                        IconButton(
                          tooltip: 'Duplicate',
                          iconSize: 15,
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => _run(() async {
                            await widget.simulation.resumeSession(id);
                            await widget.simulation.duplicateSession();
                          }),
                        ),
                        IconButton(tooltip: 'Delete', iconSize: 15, icon: const Icon(Icons.delete_outline), onPressed: () => _run(() => widget.simulation.deleteSession(id))),
                      ],
                    ),
                  ),
                ),
              ),
          if (currentId != null) ...[
            const Divider(color: StudioColors.borderSubtle, height: 24),
            EiSectionCard(
              title: 'Current Session',
              icon: Icons.folder_shared_outlined,
              trailing: EiChip(currentId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    key: const Key('sim_export_session'),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final json = await widget.simulation.exportSession();
                              if (mounted) setState(() => _exportedJson = json);
                            }),
                    icon: const Icon(Icons.ios_share, size: 15),
                    label: const Text('Export'),
                  ),
                  if (_exportedJson != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SelectableText('$_exportedJson', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5, fontFamily: 'Consolas')),
                    ),
                ],
              ),
            ),
          ],
          if (ids.length >= 2) ...[
            const Divider(color: StudioColors.borderSubtle, height: 24),
            EiSectionCard(
              title: 'Compare Sessions',
              icon: Icons.compare_arrows,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('sim_compare_with'),
                    initialValue: _compareWithId,
                    decoration: const InputDecoration(labelText: 'Compare current session against', isDense: true),
                    items: [for (final id in ids) DropdownMenuItem(value: id, child: Text(id, style: const TextStyle(fontSize: 11)))],
                    onChanged: (v) => setState(() => _compareWithId = v),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('sim_compare_run'),
                    onPressed: _busy || currentId == null || _compareWithId == null
                        ? null
                        : () => _run(() async {
                              final result = await widget.simulation.compareSessions(currentId, _compareWithId!);
                              if (mounted) setState(() => _compareResult = result);
                            }),
                    child: const Text('Compare'),
                  ),
                  if (_compareResult != null) ...[
                    const SizedBox(height: 8),
                    EiChip(_compareResult!.identical ? 'Identical' : '${_compareResult!.differences.length} differences',
                        color: _compareResult!.identical ? StudioColors.success : StudioColors.warning),
                    for (final diff in _compareResult!.differences)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${diff.nodeId}: powered ${diff.poweredA}→${diff.poweredB}, grounded ${diff.groundedA}→${diff.groundedB}, functional ${diff.functionalA}→${diff.functionalB}',
                          style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
