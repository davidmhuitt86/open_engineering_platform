import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../electrical/studio_electrical_solver.dart';
import '../instruments/multimeter/multimeter_controller.dart';
import '../webview/legacy_v2_state_adapter.dart';
import 'circuit_search.dart';
import 'trace_controller.dart';
import 'trace_highlight_plan.dart';

/// PRODUCT-READINESS-009 — the real Diagram Studio Trace Inspector.
/// Pure presentation/orchestration: every path/diagnostic shown here comes
/// from [TraceController.result] (`TraceResult`, produced by the
/// authoritative `TraceEngine` -- optionally fed a real
/// `ElectricalSolver -> SolvedElectricalState` for conducting/current-flow
/// modes, §1/§41). This widget performs NO graph traversal and NO
/// electrical computation of its own.
///
/// **Target selection** (§5): the trace target follows the live diagram
/// selection (the same `EngineeringProjectState.selection` mirroring path
/// the DMM instrument already uses) -- selecting a component in the
/// diagram is a first-class trace target, never requiring the user to
/// select a wire first. A genuinely multi-terminal component additionally
/// offers a terminal picker (§6) for a more specific "from THIS terminal"
/// trace, never a silently-guessed one.
///
/// **Highlighting** (§11): every result is translated (via
/// [buildTraceHighlightPlan]) and pushed into the REAL, already-rendered
/// V2 diagram through [LegacyV2StateAdapter.applyTraceHighlight] -- never
/// a duplicate/synthesized diagram.
class TraceInspectorPanel extends ConsumerStatefulWidget {
  const TraceInspectorPanel({super.key});

  @override
  ConsumerState<TraceInspectorPanel> createState() =>
      _TraceInspectorPanelState();
}

class _TraceInspectorPanelState extends ConsumerState<TraceInspectorPanel> {
  GraphSelection? _lastHandledSelectionForTarget;
  Object? _lastTraceTriggerSignature;
  TraceResult? _lastAppliedResult;
  TraceHighlightPlan? _lastAppliedPlan;
  bool _highlightCleared = true;
  LegacyV2StateAdapter? _adapter;
  String? _pendingTerminalPickNodeId;

  /// PRODUCT-READINESS-010 §33 — "Trace from source" instead of "Trace
  /// from target": when true, a single-node selection resolves to the
  /// nearest real, recognized source component in the graph rather than
  /// the selected component itself, since tracing FORWARD from a source
  /// identifies the real blocking switch, while tracing from a load only
  /// ever reports the nearest wire (PRODUCT-READINESS-009 §7's own
  /// disclosed finding — addressed here as a user-facing option, never by
  /// changing `TraceEngine` itself to cosmetically rename anything).
  bool _traceFromSource = false;
  String? _diagnosingComponentLabel;

  @override
  void dispose() {
    // §32 — a trace's own visual highlight must not outlive this panel
    // (the diagram returning to normal when the panel is closed/disposed,
    // not just when the user explicitly clears it).
    _adapter?.clearTraceHighlight();
    super.dispose();
  }

  /// §5 — a single selected component or relationship becomes the trace
  /// target automatically; a multi-selection or an empty selection leaves
  /// whatever target is already set alone (never clears a deliberate
  /// target on a stray deselect elsewhere in the diagram).
  void _deriveTargetFromSelection(TraceController controller,
      GraphSelection selection, EngineeringGraph? graph) {
    setState(() => _pendingTerminalPickNodeId = null);
    if (selection.nodeIds.length == 1) {
      final selectedId = selection.nodeIds.single;
      if (_traceFromSource && graph != null) {
        final selectedNode = graph.nodes[selectedId];
        if (selectedNode != null &&
            !isRecognizedSourceComponent(selectedNode, null)) {
          final source = _nearestRecognizedSource(graph);
          if (source != null) {
            setState(
                () => _diagnosingComponentLabel = selectedNode.displayName);
            controller.setTarget(TraceTarget.component(source.id));
            return;
          }
        }
      }
      setState(() => _diagnosingComponentLabel = null);
      controller.setTarget(TraceTarget.component(selectedId));
    } else if (selection.relationshipIds.length == 1) {
      setState(() => _diagnosingComponentLabel = null);
      controller.setTarget(
          TraceTarget.relationship(selection.relationshipIds.single));
    }
  }

  /// §33 — the first real, recognized source component in the graph
  /// (`isRecognizedSourceComponent`, the same production reference-role
  /// classifier the DMM/solver already use — never a new source-detection
  /// algorithm). `null` if the graph genuinely has none.
  EngineeringNode? _nearestRecognizedSource(EngineeringGraph graph) {
    for (final node in graph.nodes.values) {
      if (isRecognizedSourceComponent(node, null)) return node;
    }
    return null;
  }

  void _setTargetFromSearch(
      TraceController controller, CircuitSearchEntry entry,
      {TraceMode? mode}) {
    setState(() {
      _diagnosingComponentLabel = null;
      _pendingTerminalPickNodeId = null;
    });
    if (mode != null) controller.setMode(mode);
    if (entry.isTerminal) {
      controller.setTarget(TraceTarget.terminal(entry.terminalMatch!.terminal));
    } else if (entry.isRelationship) {
      controller.setTarget(TraceTarget.relationship(entry.targetId));
    } else {
      controller.setTarget(TraceTarget.component(entry.targetId));
    }
    _selectInDiagram(entry.isRelationship ? null : entry.targetId,
        entry.isRelationship ? entry.targetId : null);
  }

  /// §8/§31 — schedules a new trace (deferred past the current frame,
  /// never synchronously during `build()`) only when the real inputs
  /// changed -- never at frame rate.
  void _maybeScheduleTrace(TraceController controller, EngineeringGraph? graph,
      ElectricalOperatingContext operatingContext) {
    if (graph == null || controller.target == null) return;
    final signature =
        (controller.target, controller.mode, operatingContext, graph);
    if (signature == _lastTraceTriggerSignature) return;
    _lastTraceTriggerSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.runTrace(
          graph: graph,
          solver: buildStudioElectricalSolver(),
          operatingContext: operatingContext);
    });
  }

  /// §11/§29 — pushes (or clears) the real diagram highlight whenever the
  /// controller's own result identity actually changes; never re-applies
  /// on every rebuild.
  void _maybeApplyHighlight(TraceController controller,
      LegacyV2StateAdapter? adapter, EngineeringGraph? graph) {
    _adapter = adapter;
    if (adapter == null) return;
    final result = controller.result;
    if (result == null) {
      if (_highlightCleared) return;
      _highlightCleared = true;
      _lastAppliedResult = null;
      _lastAppliedPlan = null;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => adapter.clearTraceHighlight());
      return;
    }
    if (graph == null || identical(result, _lastAppliedResult)) return;
    _lastAppliedResult = result;
    _highlightCleared = false;
    final plan = buildTraceHighlightPlan(graph, result);
    _lastAppliedPlan = plan;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => adapter.applyTraceHighlight(plan));
  }

  /// §17 — "Fit Circuit": re-uses the last plan already pushed to the
  /// diagram (never recomputes/re-solves — this is pure camera
  /// movement).
  void _fitCircuit() {
    final adapter = _adapter;
    final plan = _lastAppliedPlan;
    if (adapter == null || plan == null) return;
    adapter.fitTraceHighlight(plan);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(traceRuntimeServiceProvider);
    final projectState = ref.watch(engineeringProjectServiceProvider);
    final graph = projectState.session?.graph;
    final operatingContext =
        ref.watch(legacyV2OperatingContextFamily(primaryDiagramInstanceId));
    final adapter = ref.watch(legacyV2AdapterFamily(primaryDiagramInstanceId));

    if (controller == null) {
      return const _TraceMessage(text: 'No diagram session is active yet.');
    }

    if (graph != null &&
        projectState.selection != _lastHandledSelectionForTarget) {
      _lastHandledSelectionForTarget = projectState.selection;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _deriveTargetFromSelection(controller, projectState.selection, graph);
      });
    }

    _maybeScheduleTrace(controller, graph, operatingContext);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        _maybeApplyHighlight(controller, adapter, graph);
        return _buildContent(
            context, controller, graph, projectState.selection);
      },
    );
  }

  EngineeringNode? _selectedNode(
      EngineeringGraph? graph, GraphSelection selection) {
    if (graph == null || selection.nodeIds.length != 1) return null;
    return graph.nodes[selection.nodeIds.single];
  }

  Widget _buildContent(BuildContext context, TraceController controller,
      EngineeringGraph? graph, GraphSelection selection) {
    final selectedNode = _selectedNode(graph, selection);
    final projectState = ref.read(engineeringProjectServiceProvider);
    final layout = projectState.session?.layout;
    final symbols = projectState.engine?.registry.symbols;
    final result = controller.result;

    return DecoratedBox(
      decoration: const BoxDecoration(color: StudioColors.surface),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (graph != null && layout != null && symbols != null)
              _CircuitSearchSection(
                graph: graph,
                layout: layout,
                symbols: symbols,
                onLocate: (entry) => _selectInDiagram(
                    entry.isRelationship ? null : entry.targetId,
                    entry.isRelationship ? entry.targetId : null),
                onTrace: (entry, mode) =>
                    _setTargetFromSearch(controller, entry, mode: mode),
                onMeasure: (entry) => _armProbeFromTerminal(entry),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeSelector(
                      selected: controller.mode, onSelect: controller.setMode),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                setState(() => _traceFromSource = !_traceFromSource);
                if (graph != null) {
                  _deriveTargetFromSelection(controller, selection, graph);
                }
              },
              child: Row(
                children: [
                  Checkbox(
                    value: _traceFromSource,
                    onChanged: (v) {
                      setState(() => _traceFromSource = v ?? false);
                      if (graph != null) {
                        _deriveTargetFromSelection(
                            controller, selection, graph);
                      }
                    },
                  ),
                  const Text('Trace from source (why isn\'t it working?)',
                      style: TextStyle(
                          fontSize: 11, color: StudioColors.textSecondary)),
                ],
              ),
            ),
            if (_diagnosingComponentLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Diagnosing power to: $_diagnosingComponentLabel',
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: StudioColors.textSecondary)),
              ),
            _TargetSummary(
              target: controller.target,
              graph: graph,
              onClear: () => controller.clear(),
            ),
            if (selectedNode != null && selectedNode.ports.length > 1) ...[
              const SizedBox(height: 8),
              _TerminalPicker(
                node: selectedNode,
                pickedPortId: _pendingTerminalPickNodeId == selectedNode.id
                    ? controller.target?.terminal?.portId
                    : null,
                onPickComponent: () {
                  setState(() => _pendingTerminalPickNodeId = null);
                  controller.setTarget(TraceTarget.component(selectedNode.id));
                },
                onPickTerminal: (portId) {
                  setState(() => _pendingTerminalPickNodeId = selectedNode.id);
                  controller.setTarget(TraceTarget.terminal(
                      ProbePoint(nodeId: selectedNode.id, portId: portId)));
                },
              ),
            ],
            const SizedBox(height: 12),
            if (result != null)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _lastAppliedPlan == null ? null : _fitCircuit,
                    icon: const Icon(Icons.center_focus_strong, size: 14),
                    label: const Text('Fit Circuit',
                        style: TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(
                    onPressed: result.sourceTerminals.length == 1 &&
                            result.returnTerminals.length == 1
                        ? () => _measureCircuit(result)
                        : null,
                    icon: const Icon(Icons.electrical_services, size: 14),
                    label: const Text('Measure Circuit',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            _CircuitSummaryView(
                result: result,
                solvedState: controller.lastSolvedState,
                graph: graph),
            if (result != null) ...[
              const SizedBox(height: 8),
              _BranchTreeView(
                result: result,
                graph: graph,
                onStepTap: (nodeId, relationshipId) =>
                    _selectInDiagram(nodeId, relationshipId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// §20 — a terminal search result's own "Measure from here": arms the
  /// EXISTING DMM red probe with the real terminal (§20: "reuse the
  /// existing DMM probe architecture... the search layer only supplies
  /// the engineering target" -- no electrical solving happens here).
  void _armProbeFromTerminal(CircuitSearchEntry entry) {
    final match = entry.terminalMatch;
    if (match == null) return;
    final dmm = ref.read(multimeterRuntimeServiceProvider);
    dmm?.setProbeA(match.terminal);
  }

  /// §21 — "Measure Circuit": only ever called when exactly one source and
  /// one return terminal were identified (the button is disabled
  /// otherwise, §21: "If multiple terminals are possible, require
  /// explicit selection" -- never fabricated).
  void _measureCircuit(TraceResult result) {
    final dmm = ref.read(multimeterRuntimeServiceProvider);
    if (dmm == null) return;
    dmm.setProbeA(result.sourceTerminals.single);
    dmm.setProbeB(result.returnTerminals.single);
  }

  void _selectInDiagram(String? nodeId, String? relationshipId) {
    final engine = ref.read(engineeringProjectServiceProvider).engine;
    if (engine == null) return;
    // §10 — clicking a path step selects the ACTUAL diagram object; a
    // wire hop is more specific than its own endpoint node, so it wins
    // when both are available.
    if (relationshipId != null) {
      engine.registry.selection.selectRelationship(relationshipId);
    } else if (nodeId != null) {
      engine.registry.selection.selectNode(nodeId);
    }
  }
}

class _TraceMessage extends StatelessWidget {
  const _TraceMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        color: StudioColors.surface,
        padding: const EdgeInsets.all(16),
        child: Text(text,
            style: const TextStyle(
                color: StudioColors.textSecondary, fontSize: 12)),
      );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelect});

  final TraceMode selected;
  final ValueChanged<TraceMode> onSelect;

  static const _labels = {
    TraceMode.physical: 'Physical',
    TraceMode.conducting: 'Conducting',
    TraceMode.currentFlow: 'Current Flow',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final mode in TraceMode.values)
          ChoiceChip(
            label: Text(_labels[mode]!, style: const TextStyle(fontSize: 11)),
            selected: mode == selected,
            onSelected: (_) => onSelect(mode),
          ),
      ],
    );
  }
}

/// §5/§8 — a compact, real (never fabricated) description of the current
/// trace target, and a way to clear it (§29).
class _TargetSummary extends StatelessWidget {
  const _TargetSummary(
      {required this.target, required this.graph, required this.onClear});

  final TraceTarget? target;
  final EngineeringGraph? graph;
  final VoidCallback onClear;

  String _describe() {
    final t = target;
    if (t == null) return 'Select a component or wire in the diagram to trace.';
    switch (t.kind) {
      case TraceTargetKind.component:
        final node = graph?.nodes[t.componentId];
        return 'Trace from: ${node?.displayName ?? t.componentId}';
      case TraceTargetKind.terminal:
        final terminal = t.terminal!;
        final node = graph?.nodes[terminal.nodeId];
        final port = node?.ports.where((p) => p.id == terminal.portId);
        final portName = (port != null && port.isNotEmpty)
            ? port.first.name
            : terminal.portId;
        return 'Trace from: ${node?.displayName ?? terminal.nodeId} · $portName';
      case TraceTargetKind.relationship:
        final relationship = graph?.relationships[t.relationshipId];
        return 'Trace from wire: ${relationship?.id ?? t.relationshipId}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(6),
        color: StudioColors.surfaceSunken,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_describe(),
                style: const TextStyle(
                    fontSize: 11, color: StudioColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          if (target != null)
            InkWell(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: StudioColors.textSecondary)),
        ],
      ),
    );
  }
}

/// §6 — a real, never-guessed terminal picker: choosing "Whole component"
/// resets to the component-level target; choosing a specific terminal
/// narrows the trace to that terminal only.
class _TerminalPicker extends StatelessWidget {
  const _TerminalPicker(
      {required this.node,
      required this.pickedPortId,
      required this.onPickComponent,
      required this.onPickTerminal});

  final EngineeringNode node;
  final String? pickedPortId;
  final VoidCallback onPickComponent;
  final ValueChanged<String> onPickTerminal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: StudioColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${node.displayName} has multiple terminals — trace from:',
              style: const TextStyle(
                  fontSize: 11, color: StudioColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Whole component',
                    style: TextStyle(fontSize: 11)),
                selected: pickedPortId == null,
                onSelected: (_) => onPickComponent(),
              ),
              for (final port in node.ports)
                ChoiceChip(
                  label: Text(port.name, style: const TextStyle(fontSize: 11)),
                  selected: pickedPortId == port.id,
                  onSelected: (_) => onPickTerminal(port.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// PRODUCT-READINESS-010 §12/§13/§16/§31 — the Circuit Summary: source/
/// return identification, blocked-path diagnostics, and (via
/// [CircuitSummary.derive]) real component/wire/branch counts plus
/// whatever solved current/voltage the Engine actually produced -- using
/// only real names/IDs from the graph, never TRX300-specific hardcoding
/// in this generic panel, and never a fabricated 0/estimate for a value
/// the Engine itself reports as unsupported/unreached.
class _CircuitSummaryView extends StatelessWidget {
  const _CircuitSummaryView(
      {required this.result, required this.solvedState, required this.graph});

  final TraceResult? result;
  final SolvedElectricalState? solvedState;
  final EngineeringGraph? graph;

  String _terminalName(ProbePoint terminal) {
    final node = graph?.nodes[terminal.nodeId];
    final name = node?.displayName ?? terminal.nodeId;
    if (terminal.portId == null) return name;
    final matches =
        node?.ports.where((p) => p.id == terminal.portId) ?? const <Port>[];
    final port = matches.isEmpty ? terminal.portId! : matches.first.name;
    return '$name · $port';
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) {
      return const Text('No trace yet.',
          style: TextStyle(fontSize: 11, color: StudioColors.textSecondary));
    }
    if (r.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: StudioColors.surfaceSunken,
            borderRadius: BorderRadius.circular(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No path found.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: StudioColors.textPrimary)),
            for (final d in r.diagnostics)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(d.message.isNotEmpty ? d.message : d.code.name,
                    style: const TextStyle(
                        fontSize: 11, color: StudioColors.textSecondary)),
              ),
          ],
        ),
      );
    }
    final summary = CircuitSummary.derive(r, solvedState: solvedState);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: StudioColors.surfaceSunken,
          borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.paths.length} path${r.paths.length == 1 ? '' : 's'} found',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: StudioColors.textPrimary)),
          if (r.sourceTerminals.isNotEmpty) ...[
            const SizedBox(height: 6),
            _labeledRow(
                'SOURCE',
                r.sourceTerminals.map(_terminalName).join(', '),
                StudioColors.error),
          ] else
            _labeledRow('SOURCE', 'Not resolved', StudioColors.textSecondary),
          if (r.returnTerminals.isNotEmpty)
            _labeledRow(
                'RETURN',
                r.returnTerminals.map(_terminalName).join(', '),
                StudioColors.textPrimary)
          else
            _labeledRow('RETURN', 'Not resolved', StudioColors.textSecondary),
          const SizedBox(height: 4),
          _labeledRow('STATE', summary.overallConductingState.name,
              StudioColors.textPrimary),
          if (summary.current != null)
            _labeledRow(
                'CURRENT',
                '${summary.current!.value} ${summary.current!.unit}',
                StudioColors.textPrimary),
          if (summary.sourceVoltage != null)
            _labeledRow(
                'VOLTAGE',
                '${summary.sourceVoltage!.value} ${summary.sourceVoltage!.unit}',
                StudioColors.textPrimary),
          _labeledRow('COMPONENTS', '${summary.componentCount}',
              StudioColors.textPrimary),
          _labeledRow(
              'WIRES', '${summary.wireCount}', StudioColors.textPrimary),
          _labeledRow(
              'BRANCHES', '${summary.branchCount}', StudioColors.textPrimary),
          _labeledRow(
              'BLOCKED',
              summary.isBlocked ? 'Yes' : 'No',
              summary.isBlocked
                  ? StudioColors.warning
                  : StudioColors.textPrimary),
          for (final path in r.paths)
            if (path.blockingStep != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Path blocked at: ${_terminalName(path.blockingStep!.terminal)}${path.blockingReason != null ? ' — ${path.blockingReason}' : ''}',
                  style: const TextStyle(
                      fontSize: 11, color: StudioColors.warning),
                ),
              ),
        ],
      ),
    );
  }

  Widget _labeledRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            style:
                const TextStyle(fontSize: 11, color: StudioColors.textPrimary),
            children: [
              TextSpan(
                  text: '$label  ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

/// PRODUCT-READINESS-010 §14/§15 — the real branch tree (built by the
/// Engine-owned [buildCircuitBranchTree] from [TraceResult.paths]'s own,
/// already-computed [TracePathStep] sequences -- never a textual path
/// independently re-traversed in the UI, §14). Parallel branches (e.g. a
/// splice feeding two headlights) render as a genuine tree, never
/// collapsed into one linear path (§15). Clicking any node selects the
/// real diagram object it represents (§16).
class _BranchTreeView extends StatelessWidget {
  const _BranchTreeView(
      {required this.result, required this.graph, required this.onStepTap});

  final TraceResult result;
  final EngineeringGraph? graph;
  final void Function(String? nodeId, String? relationshipId) onStepTap;

  String _terminalName(ProbePoint terminal) {
    final node = graph?.nodes[terminal.nodeId];
    final name = node?.displayName ?? terminal.nodeId;
    if (terminal.portId == null) return name;
    final matches =
        node?.ports.where((p) => p.id == terminal.portId) ?? const <Port>[];
    final port = matches.isEmpty ? terminal.portId! : matches.first.name;
    return '$name · $port';
  }

  @override
  Widget build(BuildContext context) {
    final tree = buildCircuitBranchTree(result.paths);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final root in tree) _branchNodeTile(root, depth: 0),
      ],
    );
  }

  Widget _branchNodeTile(CircuitBranchNode node, {required int depth}) {
    final label = '${_terminalName(node.terminal)}'
        '${node.viaRelationshipId != null ? '  (via ${node.viaRelationshipId})' : ''}';
    final row = InkWell(
      onTap: () => onStepTap(node.terminal.nodeId, node.viaRelationshipId),
      child: Padding(
        padding: EdgeInsets.only(left: depth * 14.0, top: 3, bottom: 3),
        child: Row(
          children: [
            if (node.children.length > 1)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.call_split,
                    size: 11, color: StudioColors.textSecondary),
              ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: node.isBlockingStep
                      ? StudioColors.warning
                      : StudioColors.textPrimary,
                  fontWeight:
                      node.isBlockingStep ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (node.children.isEmpty) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        for (final child in node.children)
          _branchNodeTile(child, depth: depth + 1)
      ],
    );
  }
}

/// PRODUCT-READINESS-010 §4/§5/§6/§19 — "Search Engineering Diagram": a
/// diagram-scoped search box over the CURRENTLY OPEN diagram's own real
/// graph/layout (via [searchCircuitEntities] -- reuses the existing,
/// Engine-owned [SearchService]/[searchTerminals], never a duplicated
/// index). Each result keeps its real engineering identity and offers
/// Locate/Trace/Measure actions, matching §36's own "Search -> select ->
/// Actions" workflow directly.
class _CircuitSearchSection extends StatefulWidget {
  const _CircuitSearchSection({
    required this.graph,
    required this.layout,
    required this.symbols,
    required this.onLocate,
    required this.onTrace,
    required this.onMeasure,
  });

  final EngineeringGraph graph;
  final DiagramLayoutState layout;
  final SymbolProvider symbols;
  final void Function(CircuitSearchEntry entry) onLocate;
  final void Function(CircuitSearchEntry entry, TraceMode mode) onTrace;
  final void Function(CircuitSearchEntry entry) onMeasure;

  @override
  State<_CircuitSearchSection> createState() => _CircuitSearchSectionState();
}

class _CircuitSearchSectionState extends State<_CircuitSearchSection> {
  final TextEditingController _controller = TextEditingController();
  List<CircuitSearchEntry> _results = const [];
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    setState(() {
      _results = searchCircuitEntities(
        graph: widget.graph,
        layout: widget.layout,
        symbols: widget.symbols,
        query: query,
      );
      _expanded = query.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _runSearch,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Search Engineering Diagram',
            prefixIcon: Icon(Icons.search, size: 16),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
                color: StudioColors.surfaceSunken,
                borderRadius: BorderRadius.circular(6)),
            child: _results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('No engineering objects found',
                        style: TextStyle(
                            fontSize: 11, color: StudioColors.textSecondary)),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in _results) _resultTile(entry)
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _resultTile(CircuitSearchEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => widget.onLocate(entry),
            child: Row(
              children: [
                Icon(
                  entry.isTerminal
                      ? Icons.settings_input_component
                      : entry.isRelationship
                          ? Icons.power_input
                          : Icons.memory,
                  size: 12,
                  color: StudioColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(entry.label,
                        style: const TextStyle(
                            fontSize: 11, color: StudioColors.textPrimary))),
              ],
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              _actionChip('Trace Physical',
                  () => widget.onTrace(entry, TraceMode.physical)),
              _actionChip('Trace Conducting',
                  () => widget.onTrace(entry, TraceMode.conducting)),
              _actionChip('Trace Current Flow',
                  () => widget.onTrace(entry, TraceMode.currentFlow)),
              if (entry.isTerminal)
                _actionChip('Measure', () => widget.onMeasure(entry)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) => ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 9)),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
