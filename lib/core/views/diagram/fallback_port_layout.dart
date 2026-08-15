import '../../graph/models/port.dart';
import '../../symbols/models/symbol_port.dart';

/// OEP Diagram Studio -- Phase 14 (UI Layout Ratification): the ONE
/// shared fallback port-geometry computation, used everywhere a node
/// has no visual Symbol asset (no authored `SymbolPort` positions) but
/// does have real `EngineeringNode.ports` -- pin rendering
/// (`graph_view_panel.dart`), wire-endpoint anchoring
/// (`diagram_view.dart`), and drag-to-connect anchoring
/// (`diagram_studio_page.dart`) all call this SAME function so a pin's
/// visual position, the wire that reaches it, and the point a
/// connection-drag starts from always agree -- never three independent
/// (and, before this fix, disagreeing) computations.
///
/// [exit] is the edge ports sit on -- 'up'/'down'/'left'/'right',
/// matching the `legacy_wiring_sim_v2` reference's own per-module
/// `exit` convention (transcribed into `EngineeringNode.metadata['exit']`
/// by the TRX300 import). Defaults to 'down' (bottom edge), preserving
/// the fallback behavior established before [exit] existed, for any
/// node/diagram that doesn't set it.
List<SymbolPort> fallbackPorts(List<Port> ports, {String exit = 'down'}) {
  final count = ports.length;
  if (count == 0) return const [];
  return [
    for (var i = 0; i < count; i++)
      SymbolPort(
        id: ports[i].id,
        displayName: ports[i].name,
        connectionType: ports[i].type,
        direction: ports[i].direction,
        x: switch (exit) {
          'left' => 0.0,
          'right' => 1.0,
          _ => (i + 1) / (count + 1),
        },
        y: switch (exit) {
          'up' => 0.0,
          'left' || 'right' => (i + 1) / (count + 1),
          _ => 1.0,
        },
      ),
  ];
}
