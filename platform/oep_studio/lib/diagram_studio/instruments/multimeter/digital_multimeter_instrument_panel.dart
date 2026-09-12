import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../../core/services/engineering_project_service.dart';
import '../../electrical/studio_electrical_solver.dart';
import '../../webview/legacy_v2_state_adapter.dart';
import 'multimeter_controller.dart';

/// PRODUCT-READINESS-008 — the real Diagram Studio DMM instrument
/// surface. Pure presentation/orchestration: every electrical value shown
/// here comes from [MultimeterController.electricalResult]
/// (`ElectricalMeasurementResult`, produced by the authoritative
/// `ElectricalSolver -> SolvedElectricalState -> ElectricalMeasurementQuery`
/// chain — §1/§19). This widget performs NO electrical computation of its
/// own; it only decides WHEN to ask (mode/probe/operating-context change)
/// and HOW to render what comes back.
///
/// **Probe placement** (§5/§6): tap RED or BLACK to arm it, then select a
/// single node in the live diagram (the existing selection-mirroring
/// path V2 clicks already drive, `EngineeringProjectState.selection`) —
/// a single-terminal component assigns immediately; a multi-terminal
/// component shows an inline terminal picker (never a silently-guessed
/// terminal, §6).
///
/// **Operating context** (§10/§14): watches
/// [legacyV2OperatingContextFamily] (the live, translated V2 switch/key
/// state) so a real switch change in the WebView automatically produces
/// a new measurement here, with no manual reload.
///
/// **Visual design**: a real handheld-DMM face — direct request, matched
/// as closely as the docked side-panel format allows against a supplied
/// reference rendering (dark case, blue accent trim, LCD screen with
/// mode/reading/bargraph, a real rotary-dial mode selector, jack-styled
/// probe controls, embossed footer plate). Every control that actually
/// does something is wired to the exact same logic/state as before the
/// restyle; controls the reference shows that this app has no real
/// behavior for (AUTO/RANGE/HOLD/REL/MIN-MAX) render as inert chrome —
/// never a fake handler for something that doesn't actually happen (same
/// "no invented affordance" principle `oep_instruments`' own
/// `DigitalMultimeterPanel` already established).
class DigitalMultimeterInstrumentPanel extends ConsumerStatefulWidget {
  const DigitalMultimeterInstrumentPanel({super.key});

  @override
  ConsumerState<DigitalMultimeterInstrumentPanel> createState() => _DigitalMultimeterInstrumentPanelState();
}

class _DigitalMultimeterInstrumentPanelState extends ConsumerState<DigitalMultimeterInstrumentPanel> {
  /// §26 (PRODUCT-READINESS-004 generation semantics) — one monotonic
  /// counter for the lifetime of this panel instance, matching the same
  /// per-consumer-owned-counter convention `OipHostBridgeService` already
  /// established.
  final ElectricalSolutionGenerationCounter _generationCounter = ElectricalSolutionGenerationCounter();

  String? _armedProbe; // 'red' | 'black' | null
  EngineeringNode? _pendingTerminalPickNode;
  bool _showDebug = false;

  /// §8/§9 stale-result protection at the TRIGGER level: only schedule a
  /// new [MultimeterController.measureElectrical] call when the real
  /// inputs (probes/mode/operating context/graph identity) actually
  /// changed since the last one — never re-solving at build/frame rate.
  Object? _lastTriggerSignature;
  GraphSelection? _lastHandledSelection;

  /// §16/PRODUCT-READINESS-009 §33 — the one shared production solver
  /// configuration (`studio_electrical_solver.dart`), the same
  /// PRODUCTION-precise reference resolver PRODUCT-READINESS-006B
  /// validated against the real, full-harness `diagram7.json`, not a
  /// second, independently-maintained copy.
  ElectricalSolver get _solver => buildStudioElectricalSolver();

  void _armProbe(String probe) {
    setState(() {
      _armedProbe = _armedProbe == probe ? null : probe;
      _pendingTerminalPickNode = null;
    });
  }

  void _clearProbe(MultimeterController controller, String probe) {
    if (probe == 'red') {
      controller.setProbeA(null);
    } else {
      controller.setProbeB(null);
    }
  }

  void _assignProbe(MultimeterController controller, ProbePoint point) {
    if (_armedProbe == 'red') {
      controller.setProbeA(point);
    } else if (_armedProbe == 'black') {
      controller.setProbeB(point);
    }
    setState(() {
      _armedProbe = null;
      _pendingTerminalPickNode = null;
    });
  }

  /// §5/§6 — resolves a single-node selection into a probe assignment,
  /// prompting an inline terminal picker for a genuinely multi-terminal
  /// component rather than guessing.
  void _handleSelectionForArmedProbe(MultimeterController controller, EngineeringGraph graph, GraphSelection selection) {
    if (_armedProbe == null) return;
    if (selection.nodeIds.length != 1) return;
    final node = graph.nodes[selection.nodeIds.single];
    if (node == null) return;
    if (node.ports.length <= 1) {
      final portId = node.ports.isEmpty ? null : node.ports.single.id;
      _assignProbe(controller, ProbePoint(nodeId: node.id, portId: portId));
    } else {
      setState(() => _pendingTerminalPickNode = node);
    }
  }

  /// §8/§9 — schedules a new measurement (deferred past the current
  /// frame, never synchronously during `build()`) only when the real
  /// inputs changed. [MultimeterController.measureElectrical] itself
  /// guards against a superseded call overwriting a newer one.
  void _maybeScheduleMeasurement(MultimeterController controller, EngineeringGraph? graph, ElectricalOperatingContext operatingContext) {
    if (graph == null) return;
    final signature = (controller.probeA, controller.probeB, controller.selectedType, operatingContext, graph);
    if (signature == _lastTriggerSignature) return;
    _lastTriggerSignature = signature;
    if (controller.probeA == null || controller.probeB == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.measureElectrical(
        graph: graph,
        solver: _solver,
        generationCounter: _generationCounter,
        operatingContext: operatingContext,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(multimeterRuntimeServiceProvider);
    final projectState = ref.watch(engineeringProjectServiceProvider);
    final graph = projectState.session?.graph;
    final operatingContext = ref.watch(legacyV2OperatingContextFamily(primaryDiagramInstanceId));

    if (controller == null) {
      return _DmmBezel(
        child: _DmmMessage(
          text: 'Open or create a diagram first — the multimeter needs an active diagram session to measure against.',
        ),
      );
    }

    if (_armedProbe != null && graph != null && projectState.selection != _lastHandledSelection) {
      _lastHandledSelection = projectState.selection;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleSelectionForArmedProbe(controller, graph, projectState.selection);
      });
    }

    _maybeScheduleMeasurement(controller, graph, operatingContext);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildContent(context, controller, graph),
    );
  }

  Widget _buildContent(BuildContext context, MultimeterController controller, EngineeringGraph? graph) {
    return _DmmBezel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandHeader(),
          const SizedBox(height: 8),
          _LcdScreen(mode: controller.selectedType, result: controller.electricalResult),
          const SizedBox(height: 6),
          const _Tagline(),
          const SizedBox(height: 10),
          _PhysicalButtonRow(showDebug: _showDebug, onToggleDebug: () => setState(() => _showDebug = !_showDebug)),
          if (_showDebug) _DebugPanel(result: controller.electricalResult),
          const SizedBox(height: 14),
          _RotaryDial(selected: controller.selectedType, onSelect: controller.setType),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ProbeJack(
                  label: 'RED',
                  color: const Color(0xFFE53E3E),
                  armed: _armedProbe == 'red',
                  assigned: controller.probeA,
                  graph: graph,
                  onArm: () => _armProbe('red'),
                  onClear: () => _clearProbe(controller, 'red'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProbeJack(
                  label: 'BLACK',
                  color: const Color(0xFF16181D),
                  ringColor: const Color(0xFF4A5568),
                  armed: _armedProbe == 'black',
                  assigned: controller.probeB,
                  graph: graph,
                  onArm: () => _armProbe('black'),
                  onClear: () => _clearProbe(controller, 'black'),
                ),
              ),
            ],
          ),
          // Placing a lead is a two-step action: arm RED/BLACK above,
          // then click the actual component in the diagram canvas (V2's
          // own selection, mirrored into `EngineeringProjectState.selection`
          // by `LegacyV2StateAdapter`) — nothing in this panel itself is
          // clicked to "place" it.
          if (_armedProbe != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10141C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2B3542)),
              ),
              child: Text(
                'Click a component in the diagram to place the ${_armedProbe == 'red' ? 'RED' : 'BLACK'} lead.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3BF)),
              ),
            ),
          ],
          if (_pendingTerminalPickNode != null) ...[
            const SizedBox(height: 8),
            _TerminalPicker(
              node: _pendingTerminalPickNode!,
              onPick: (portId) => _assignProbe(controller, ProbePoint(nodeId: _pendingTerminalPickNode!.id, portId: portId)),
            ),
          ],
          const SizedBox(height: 12),
          const _FooterPlate(),
        ],
      ),
    );
  }
}

/// The outer device body: dark case, blue accent trim down both edges
/// (the reference's own vertical LED strips), rounded corners — scaled
/// to fit a docked side panel rather than a full phone screen.
class _DmmBezel extends StatelessWidget {
  const _DmmBezel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08090B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A1D23), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EdgeStrip(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: child,
            ),
          ),
          _EdgeStrip(),
        ],
      ),
    );
  }
}

class _EdgeStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B82F6), Color(0xFF1B4F91), Color(0xFF3B82F6)],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.55), blurRadius: 6, spreadRadius: 0.5)],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OEP',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 26, margin: const EdgeInsets.only(top: 2), color: const Color(0xFF2B3542)),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'OPEN ENGINEERING\nPLATFORM',
              style: const TextStyle(color: Color(0xFF8FA3BF), fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, height: 1.3),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'ENGINEER\nREPAIR\nLEARN\nBUILD',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFF4A5568), fontSize: 6.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// The LCD-look display: mode title, big digital readout + unit, a
/// bargraph, and the AUTO/RANGE/HOLD/REL/MIN-MAX button row — matching
/// the reference screen. Every value here is the same
/// [ElectricalMeasurementResult] the plain-chip version rendered.
class _LcdScreen extends StatelessWidget {
  const _LcdScreen({required this.mode, required this.result});

  final MeasurementType mode;
  final ElectricalMeasurementResult? result;

  static const _modeLabels = {
    MeasurementType.voltageDc: 'DC Voltage',
    MeasurementType.voltageAc: 'AC Voltage',
    MeasurementType.resistance: 'Resistance',
    MeasurementType.continuity: 'Continuity',
    MeasurementType.diode: 'Diode',
    MeasurementType.current: 'Current',
    MeasurementType.power: 'Power',
  };

  static const _modeSymbols = {
    MeasurementType.voltageDc: 'DC\n⎓',
    MeasurementType.voltageAc: 'AC\n~',
    MeasurementType.resistance: 'Ω',
    MeasurementType.continuity: '•)))',
    MeasurementType.diode: '-|>|-',
    MeasurementType.current: 'A\n⎓',
    MeasurementType.power: 'W',
  };

  static const _units = {
    MeasurementType.voltageDc: 'V',
    MeasurementType.voltageAc: 'V',
    MeasurementType.resistance: 'Ω',
    MeasurementType.current: 'A',
    MeasurementType.power: 'W',
  };

  (String, String, Color) _display() {
    final reading = result?.reading;
    if (reading == null) return ('----', '', const Color(0xFF3A4A5F));
    switch (reading.state) {
      case ElectricalReadingState.valid:
        final value = reading.value!;
        final formatted = value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
        final unit = reading.unit.isNotEmpty ? reading.unit : (_units[mode] ?? '');
        return (formatted, unit, Colors.white);
      case ElectricalReadingState.open:
      case ElectricalReadingState.overload:
        return ('OL', '', const Color(0xFFF6C453));
      case ElectricalReadingState.fault:
        return ('FAULT', '', const Color(0xFFE53E3E));
      case ElectricalReadingState.unsupported:
        return ('UNSUPP', '', const Color(0xFF3A4A5F));
      case ElectricalReadingState.unknown:
      case ElectricalReadingState.unreached:
        return ('----', '', const Color(0xFF3A4A5F));
    }
  }

  /// A purely visual bargraph -- proportional to the reading's own
  /// magnitude against a nearby round headroom, clamped to [0,1]. Never
  /// a second measurement path: it reads the exact same resolved value
  /// the digits above show, nothing computed independently.
  double _barFraction(num? value) {
    if (value == null) return 0;
    final magnitude = value.abs().toDouble();
    if (magnitude <= 0) return 0;
    final headroom = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000].firstWhere(
      (h) => magnitude <= h,
      orElse: () => (magnitude * 1.2).ceil(),
    );
    return (magnitude / headroom).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final (text, unit, color) = _display();
    final fraction = result?.reading.isValid == true ? _barFraction(result!.reading.value) : 0.0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF060B14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF16283E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu, size: 13, color: Color(0xFF5B85B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_modeLabels[mode] ?? mode.name, style: const TextStyle(color: Color(0xFF9FC7F5), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _modeSymbols[mode] ?? '',
                style: const TextStyle(color: Color(0xFF5B85B8), fontSize: 9, fontWeight: FontWeight.w700, height: 1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(unit, style: const TextStyle(color: Color(0xFF9FC7F5), fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: const Color(0xFF16283E),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
            ),
          ),
          const SizedBox(height: 8),
          const _LcdButtonRow(),
        ],
      ),
    );
  }
}

/// AUTO/RANGE/HOLD/REL/MIN-MAX pill row from the reference LCD. Only
/// "AUTO" reflects real state (this panel has no manual-range mode, so
/// it's always effectively auto) — the rest are inert chrome, per this
/// class's own doc comment on never inventing a fake handler.
class _LcdButtonRow extends StatelessWidget {
  const _LcdButtonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LcdPill(label: 'AUTO', active: true),
        SizedBox(width: 4),
        _LcdPill(label: 'RANGE', active: false),
        SizedBox(width: 4),
        _LcdPill(label: 'HOLD', active: false),
        SizedBox(width: 4),
        _LcdPill(label: 'REL', active: false),
        SizedBox(width: 4),
        _LcdPill(label: 'MIN/MAX', active: false),
      ],
    );
  }
}

class _LcdPill extends StatelessWidget {
  const _LcdPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B78D6).withValues(alpha: 0.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFF223449), width: 0.8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: active ? const Color(0xFF9FC7F5) : const Color(0xFF4A6178)),
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'P R E C I S I O N   I N   P R A C T I C E',
        style: TextStyle(color: Color(0xFF3A4658), fontSize: 7, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The physical MODE/RANGE/HOLD/REL/Hz% button row. Only "MODE" (this
/// panel's own existing debug-inspection toggle, repurposed as the one
/// real secondary button available) is wired; the rest render inert.
class _PhysicalButtonRow extends StatelessWidget {
  const _PhysicalButtonRow({required this.showDebug, required this.onToggleDebug});

  final bool showDebug;
  final VoidCallback onToggleDebug;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PhysicalButton(icon: Icons.info_outline, label: showDebug ? 'HIDE' : 'INFO', active: showDebug, onTap: onToggleDebug)),
        const SizedBox(width: 5),
        const Expanded(child: _PhysicalButton(icon: Icons.bar_chart, label: 'RANGE', active: false, onTap: null)),
        const SizedBox(width: 5),
        const Expanded(child: _PhysicalButton(icon: Icons.h_mobiledata, label: 'HOLD', active: false, onTap: null)),
        const SizedBox(width: 5),
        const Expanded(child: _PhysicalButton(icon: Icons.change_history, label: 'REL', active: false, onTap: null)),
        const SizedBox(width: 5),
        const Expanded(child: _PhysicalButton(icon: Icons.graphic_eq, label: 'Hz %', active: false, onTap: null)),
      ],
    );
  }
}

class _PhysicalButton extends StatelessWidget {
  const _PhysicalButton({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16191F),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFF2B2F38)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 13, color: active ? const Color(0xFF9FC7F5) : const Color(0xFF6B7280)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w700, color: active ? const Color(0xFF9FC7F5) : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

/// A real rotary-dial mode selector: labels positioned around a circle
/// at the reference's own layout angles, with a pointer that rotates to
/// the selected mode. Click-based (not draggable) -- this lives in a
/// fixed-width docked side panel, not a full device face, but the visual
/// layout matches the reference as closely as that constraint allows.
/// The underlying interaction (tap a mode -> `controller.setType`) is
/// unchanged from before the restyle.
class _RotaryDial extends StatelessWidget {
  const _RotaryDial({required this.selected, required this.onSelect});

  final MeasurementType selected;
  final ValueChanged<MeasurementType> onSelect;

  // Angles in degrees, 0 = straight up, clockwise -- matching the
  // reference's own left-side-DC-through-AC-current, right-side-power
  // arrangement as closely as 7 (not 11) real positions allow.
  static const _positions = <(MeasurementType, String, double)>[
    (MeasurementType.voltageDc, 'V⎓', -55),
    (MeasurementType.voltageAc, 'V~', -30),
    (MeasurementType.resistance, 'Ω', -5),
    (MeasurementType.continuity, '•)))', 20),
    (MeasurementType.diode, '->|-', 45),
    (MeasurementType.current, 'A', 70),
    (MeasurementType.power, 'W', 95),
  ];

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    const labelRadius = 92.0;
    const pointerLength = 78.0;
    const center = Offset(size / 2, size / 2);
    final selectedAngle = _positions.firstWhere((p) => p.$1 == selected, orElse: () => _positions.first).$3;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Dial body -- one true center every pointer/label angle below
            // is computed against, so "the pointer points at the selected
            // label" is guaranteed by using the SAME formula for both,
            // never eyeballed offsets that can silently drift apart.
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0C0F14),
                border: Border.all(color: const Color(0xFF3B82F6), width: 3),
                boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.25), blurRadius: 16, spreadRadius: -4)],
              ),
            ),
            Container(
              width: size - 24,
              height: size - 24,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1B2836), width: 1)),
            ),
            // Pointer -- CustomPaint drawing a real line from the true
            // center to the exact same (center, angle) point `_DialLabel`
            // computes, rather than rotating a widget around its own
            // bounding-box center (which does NOT coincide with the
            // dial's true center and was why the pointer and the
            // selected label used to visibly disagree).
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(painter: _DialPointerPainter(center: center, angleDegrees: selectedAngle, length: pointerLength)),
            ),
            // Center knob
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B1E24),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              ),
            ),
            const Positioned(
              top: 8,
              child: Text('OFF', style: TextStyle(color: Color(0xFF6B7A8F), fontSize: 9, fontWeight: FontWeight.w700)),
            ),
            // Position labels, placed via trig around the dial ring --
            // the identical `center`/angle-to-offset formula the pointer
            // painter above uses.
            for (final position in _positions)
              _DialLabel(
                center: center,
                radius: labelRadius,
                angleDegrees: position.$3,
                text: position.$2,
                selected: position.$1 == selected,
                onTap: () => onSelect(position.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialPointerPainter extends CustomPainter {
  const _DialPointerPainter({required this.center, required this.angleDegrees, required this.length});

  final Offset center;
  final double angleDegrees;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final rad = (angleDegrees - 90) * math.pi / 180;
    final tip = Offset(center.dx + length * math.cos(rad), center.dy + length * math.sin(rad));
    final paint = Paint()
      ..color = const Color(0xFFF6C453)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, paint);
  }

  @override
  bool shouldRepaint(covariant _DialPointerPainter oldDelegate) =>
      oldDelegate.angleDegrees != angleDegrees || oldDelegate.center != center || oldDelegate.length != length;
}

class _DialLabel extends StatelessWidget {
  const _DialLabel({
    required this.center,
    required this.radius,
    required this.angleDegrees,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final Offset center;
  final double radius;
  final double angleDegrees;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rad = (angleDegrees - 90) * math.pi / 180;
    final dx = center.dx + radius * math.cos(rad);
    final dy = center.dy + radius * math.sin(rad);
    return Positioned(
      left: dx - 20,
      top: dy - 12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1B78D6).withValues(alpha: 0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: const Color(0xFF3B82F6)) : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF8FA3BF),
            ),
          ),
        ),
      ),
    );
  }
}

/// A probe control styled as a physical jack -- the RED/BLACK lead this
/// app actually models (not the reference's 4 physical fuse jacks, which
/// have no equivalent here: this app has exactly two logical probes).
class _ProbeJack extends StatelessWidget {
  const _ProbeJack({
    required this.label,
    required this.color,
    required this.armed,
    required this.assigned,
    required this.graph,
    required this.onArm,
    required this.onClear,
    this.ringColor,
  });

  final String label;
  final Color color;
  final Color? ringColor;
  final bool armed;
  final ProbePoint? assigned;
  final EngineeringGraph? graph;
  final VoidCallback onArm;
  final VoidCallback onClear;

  String _describe() {
    final point = assigned;
    if (point == null) return 'Not placed';
    final node = graph?.nodes[point.nodeId];
    final name = node?.displayName ?? point.nodeId;
    if (point.portId == null) return name;
    final matches = node?.ports.where((p) => p.id == point.portId) ?? const <Port>[];
    final port = matches.isEmpty ? point.portId! : matches.first.name;
    return '$name · $port';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onArm,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0F14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: armed ? const Color(0xFF3B82F6) : const Color(0xFF1B2836), width: armed ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1D23),
                border: Border.all(color: ringColor ?? color, width: 2.5),
              ),
              child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color == const Color(0xFF16181D) ? const Color(0xFF8FA3BF) : color, letterSpacing: 0.4)),
                      const Spacer(),
                      if (assigned != null)
                        InkWell(onTap: onClear, child: const Icon(Icons.close, size: 13, color: Color(0xFF6B7A8F))),
                    ],
                  ),
                  Text(
                    armed ? 'Select a terminal…' : _describe(),
                    style: TextStyle(fontSize: 10.5, color: armed ? const Color(0xFF9FC7F5) : Colors.white, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterPlate extends StatelessWidget {
  const _FooterPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2E38), Color(0xFF14161B)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A3F4A)),
      ),
      child: const Text(
        'OEP  |  ENGINEERING TO A HIGHER STANDARD',
        style: TextStyle(color: Color(0xFF9AA5B4), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }
}

class _DmmMessage extends StatelessWidget {
  const _DmmMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8FA3BF), fontSize: 12),
          ),
        ),
      );
}

/// §6 — a real, never-guessed terminal picker for a multi-terminal
/// component.
class _TerminalPicker extends StatelessWidget {
  const _TerminalPicker({required this.node, required this.onPick});

  final EngineeringNode node;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF10141C), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF2B3542))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${node.displayName} — pick a terminal', style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3BF))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final port in node.ports)
                ActionChip(
                  label: Text(port.name, style: const TextStyle(fontSize: 11)),
                  onPressed: () => onPick(port.id),
                  backgroundColor: const Color(0xFF1B2836),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// §26 — developer/debug inspection, hidden behind an explicit toggle.
class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.result});

  final ElectricalMeasurementResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final rows = <String, String>{
      'mode': r?.request.mode.name ?? '—',
      'state': r?.reading.state.name ?? '—',
      'value': r?.reading.value?.toString() ?? '—',
      'unit': r?.reading.unit ?? '—',
      'note': r?.reading.note ?? '—',
      'red terminal': r == null ? '—' : '${r.request.positiveTerminal.nodeId}${r.request.positiveTerminal.portId == null ? '' : ':${r.request.positiveTerminal.portId}'}',
      'black terminal': r == null ? '—' : '${r.request.negativeTerminal.nodeId}${r.request.negativeTerminal.portId == null ? '' : ':${r.request.negativeTerminal.portId}'}',
      'solution generation': r?.generation.toString() ?? '—',
      'diagram instance': primaryDiagramInstanceId,
    };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF0C0F14), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF1B2836))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(entry.key, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7A8F)))),
                  Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 10, color: Color(0xFF9FC7F5)), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
