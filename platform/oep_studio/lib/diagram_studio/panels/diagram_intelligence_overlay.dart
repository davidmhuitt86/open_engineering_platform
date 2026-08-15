import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// AP-DS-003 canvas overlays (Validation Overlay + Analysis Overlay) --
/// a pure presentation `Stack` layer, positioned using the exact same
/// `pan`/`zoom` transform `DiagramStudioPage` already drives
/// `GraphViewPanel`'s `InteractiveViewer` with (`screen = pan + zoom *
/// scenePosition`, per `GraphViewPanel._visibleSceneRect`'s own doc
/// comment) -- never a modification to `GraphViewPanel` itself, which
/// stays frozen in `oep_engine`. Every marker/highlight this paints is
/// driven entirely by [validationNodeIds]/[analysisNodeIds], which the
/// host page derives from `DiagramIntelligenceService.validate()` /
/// `.analyzeNode()` results translated through `nodeIdFor` -- no
/// validation/analysis logic lives here, only rendering of results
/// already computed by the Engineering Intelligence Platform.
class DiagramIntelligenceOverlay extends StatelessWidget {
  const DiagramIntelligenceOverlay({
    super.key,
    required this.layout,
    required this.pan,
    required this.zoom,
    this.validationNodeIds = const {},
    this.analysisNodeIds = const {},
    this.validationSummary,
    this.analysisSummary,
    this.onValidationMarkerTap,
  });

  final DiagramLayoutState layout;
  final Point2D pan;
  final double zoom;

  /// Canvas node ids with a live Validation finding (Error/Warning
  /// marker) -- translated from `validate()`'s Foundation object ids via
  /// `DiagramIntelligenceService.nodeIdFor`.
  final Set<String> validationNodeIds;

  /// Canvas node ids highlighted by the most recent Analysis run
  /// (Dependency/Impact/Reachability/Root-Cause) -- translated from
  /// `analyzeNode()`'s returned object ids the same way.
  final Set<String> analysisNodeIds;

  /// Hover-explanation text shown on every validation marker -- the
  /// Engineering Validation Engine's own `OepWorkflowResult.summary`,
  /// not a Studio-computed message.
  final String? validationSummary;

  final String? analysisSummary;

  /// Click-to-inspect: fired with the canvas node id when a validation
  /// marker is tapped.
  final void Function(String nodeId)? onValidationMarkerTap;

  static const double _defaultNodeSize = 100;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final nodeId in analysisNodeIds) _analysisHighlight(nodeId),
        for (final nodeId in validationNodeIds) _validationMarker(nodeId),
      ],
    );
  }

  Widget _analysisHighlight(String nodeId) {
    final position = layout.positionOf(nodeId);
    if (position == null) return const SizedBox.shrink();
    final size = layout.sizeOf(nodeId) ?? const Size2D(_defaultNodeSize, _defaultNodeSize);
    final left = pan.dx + zoom * position.dx;
    final top = pan.dy + zoom * position.dy;
    return Positioned(
      left: left - 4,
      top: top - 4,
      width: size.width * zoom + 8,
      height: size.height * zoom + 8,
      child: IgnorePointer(
        child: Tooltip(
          message: analysisSummary ?? 'Analysis result',
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: StudioColors.info, width: 2.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: StudioColors.info.withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _validationMarker(String nodeId) {
    final position = layout.positionOf(nodeId);
    if (position == null) return const SizedBox.shrink();
    final size = layout.sizeOf(nodeId) ?? const Size2D(_defaultNodeSize, _defaultNodeSize);
    final screenX = pan.dx + zoom * (position.dx + size.width);
    final screenY = pan.dy + zoom * position.dy;
    return Positioned(
      left: screenX - 9,
      top: screenY - 9,
      child: Tooltip(
        message: validationSummary ?? 'Validation finding — click to inspect',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onValidationMarkerTap == null ? null : () => onValidationMarkerTap!(nodeId),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: StudioColors.error,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.priority_high, size: 12, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
