import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// AP-DS-005 Simulation State Overlay — a pure presentation `Stack` layer
/// over the canvas, structurally identical to AP-DS-003's
/// `DiagramIntelligenceOverlay` (same `Positioned.fill` + `pan`/`zoom`
/// transform math, same `layout.positionOf(nodeId)` node-id -> screen
/// translation). No engineering logic lives here: every marker/highlight
/// this paints is driven entirely by a [SimulationStateSnapshot] +
/// [VerificationReport] the host page already obtained from
/// `DiagramSimulationService` — this widget only renders what the
/// Simulation Engine already computed.
///
/// Renders, per the governing spec's "Visualization" list:
/// - Power/Ground/Signal state: a colored dot per node (green = powered +
///   grounded / "functional", amber = powered only, blue-gray =
///   unpowered).
/// - Faults: a red ring around any node/relationship endpoint that is the
///   target of an active [SimulationFault].
/// - Warnings: an amber ring for nodes named in a
///   [VerificationSeverity.warning] finding (errors take the fault-red
///   ring; this is the "no fault but still flagged" case).
/// - Propagation/Dependencies: an optional highlighted path
///   ([propagationPathNodeIds]) — e.g. the path returned by a
///   `PropagationReport`.
class SimulationStateOverlay extends StatelessWidget {
  const SimulationStateOverlay({
    super.key,
    required this.layout,
    required this.pan,
    required this.zoom,
    this.snapshot,
    this.verification,
    this.activeFaultNodeIds = const {},
    this.propagationPathNodeIds = const {},
    this.onNodeTap,
  });

  final DiagramLayoutState layout;
  final Point2D pan;
  final double zoom;

  /// The current computed simulation state — `null` (renders nothing)
  /// until a session has been created/run at least once.
  final SimulationStateSnapshot? snapshot;

  /// The most recent Verification pass, used only to source Warning
  /// markers (node ids named in a `VerificationSeverity.warning` finding).
  final VerificationReport? verification;

  /// Node ids that are the direct target of an active [SimulationFault]
  /// (a node fault, or a relationship fault translated to its endpoints
  /// by the host page) — rendered with a red fault ring.
  final Set<String> activeFaultNodeIds;

  /// Node ids along a highlighted propagation/dependency path (e.g. from
  /// a `PropagationReport.path`) — rendered with a connecting highlight.
  final Set<String> propagationPathNodeIds;

  final void Function(String nodeId)? onNodeTap;

  static const double _defaultNodeSize = 100;
  static const double _dotSize = 14;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    final warningNodeIds = <String>{
      for (final f in verification?.findings ?? const [])
        if (f.severity == VerificationSeverity.warning && f.nodeId != null) f.nodeId!,
    };
    return Stack(
      children: [
        for (final nodeId in propagationPathNodeIds) _pathHighlight(nodeId),
        if (snapshot != null) for (final nodeId in layout.positions.keys) _stateDot(nodeId, snapshot),
        for (final nodeId in activeFaultNodeIds) _ring(nodeId, StudioColors.error, Icons.bolt),
        for (final nodeId in warningNodeIds.difference(activeFaultNodeIds)) _ring(nodeId, StudioColors.warning, Icons.warning_amber_rounded),
      ],
    );
  }

  Size2D _sizeOf(String nodeId) => layout.sizeOf(nodeId) ?? const Size2D(_defaultNodeSize, _defaultNodeSize);

  Widget _pathHighlight(String nodeId) {
    final position = layout.positionOf(nodeId);
    if (position == null) return const SizedBox.shrink();
    final size = _sizeOf(nodeId);
    final left = pan.dx + zoom * position.dx;
    final top = pan.dy + zoom * position.dy;
    return Positioned(
      left: left - 3,
      top: top - 3,
      width: size.width * zoom + 6,
      height: size.height * zoom + 6,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: StudioColors.selection, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget _stateDot(String nodeId, SimulationStateSnapshot snapshot) {
    final position = layout.positionOf(nodeId);
    if (position == null) return const SizedBox.shrink();
    final left = pan.dx + zoom * position.dx;
    final top = pan.dy + zoom * position.dy;
    final powered = snapshot.isPowered(nodeId);
    final grounded = snapshot.isGrounded(nodeId);
    final Color color;
    final String label;
    if (powered && grounded) {
      color = StudioColors.success;
      label = 'Functional (powered + grounded)';
    } else if (powered) {
      color = StudioColors.warning;
      label = 'Powered, not grounded';
    } else if (grounded) {
      color = StudioColors.info;
      label = 'Grounded, not powered';
    } else {
      color = StudioColors.inactive;
      label = 'Unpowered';
    }
    return Positioned(
      left: left - _dotSize / 2,
      top: top - _dotSize / 2,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onNodeTap == null ? null : () => onNodeTap!(nodeId),
          child: Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: StudioColors.surfaceRaised, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(String nodeId, Color color, IconData icon) {
    final position = layout.positionOf(nodeId);
    if (position == null) return const SizedBox.shrink();
    final size = _sizeOf(nodeId);
    final screenX = pan.dx + zoom * (position.dx + size.width);
    final screenY = pan.dy + zoom * position.dy;
    return Positioned(
      left: screenX - 9,
      top: screenY - 9,
      child: IgnorePointer(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}
