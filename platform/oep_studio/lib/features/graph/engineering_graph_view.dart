import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/engineering_object_summary.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/theme/studio_colors.dart';

/// A real node/edge visualization of Engineering Objects and their
/// Relationships (Phase 5 -- Knowledge Graph), scoped to exactly what
/// this app currently has: no separate "graph framework" abstraction,
/// just a `CustomPainter` over the two real lists Foundation already
/// provides (`FoundationServiceState.objectList`/`relationshipList`).
///
/// **Design-system gap**: ODS-C014 (Graph & Relationship View) is
/// "Architecture Draft" status -- its own § 10 "Public API" names
/// abstract concepts (Graph Provider, Node Provider, Edge Provider,
/// Layout Provider, Selection Model) with no concrete type signatures,
/// method names, or return types anywhere in the document. There is no
/// implementable contract to build a generic `OEPGraphView` against, so
/// this widget stays a plain, single-purpose Engineering Object graph
/// rather than a speculative general-purpose framework -- consistent
/// with this phase's own "do not build an unnecessarily large graph
/// framework" instruction. See `docs/ui_refactor/PHASE_5_NOTES.md`.
///
/// Layout is a small, deterministic force-directed placement (a few
/// spring-repulsion/attraction iterations from a stable per-object
/// starting position) -- legible for the tens-to-low-hundreds of
/// objects a real repository has today, not a virtualized/clustered
/// layout engine for graphs this app has no evidence it will ever need.
class EngineeringGraphView extends StatefulWidget {
  const EngineeringGraphView({
    required this.objects,
    required this.relationships,
    required this.onSelectObject,
    this.selectedObjectId,
    super.key,
  });

  final List<EngineeringObjectSummary> objects;
  final List<RelationshipSummary> relationships;
  final void Function(EngineeringObjectSummary object) onSelectObject;
  final String? selectedObjectId;

  @override
  State<EngineeringGraphView> createState() => _EngineeringGraphViewState();
}

class _EngineeringGraphViewState extends State<EngineeringGraphView> {
  Map<String, Offset> _positions = {};
  List<EngineeringObjectSummary> _layoutFor = const [];

  @override
  void initState() {
    super.initState();
    _computeLayout();
  }

  @override
  void didUpdateWidget(EngineeringGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.objects, widget.objects) || !identical(oldWidget.relationships, widget.relationships)) {
      _computeLayout();
    }
  }

  void _computeLayout() {
    final objects = widget.objects;
    const width = 1000.0;
    const height = 700.0;

    // Stable starting positions (a hash of each object's id, not
    // `Random()`) so the same graph always lays out the same way run
    // to run -- reproducible, not merely random-looking.
    final positions = <String, Offset>{
      for (final object in objects)
        object.objectId: Offset(
          width / 2 + (object.objectId.hashCode % 400 - 200),
          height / 2 + ((object.objectId.hashCode ~/ 400) % 300 - 150),
        ),
    };

    final adjacency = <String, List<String>>{};
    for (final relationship in widget.relationships) {
      adjacency.putIfAbsent(relationship.sourceObjectId, () => []).add(relationship.targetObjectId);
      adjacency.putIfAbsent(relationship.targetObjectId, () => []).add(relationship.sourceObjectId);
    }

    // A handful of Fruchterman-Reingold-style iterations: nodes repel
    // each other, connected nodes attract -- enough to untangle a
    // hash-based starting layout without a full physics engine.
    const iterations = 60;
    final k = math.sqrt((width * height) / math.max(objects.length, 1));
    for (var iteration = 0; iteration < iterations; iteration++) {
      final displacement = <String, Offset>{for (final object in objects) object.objectId: Offset.zero};

      for (var i = 0; i < objects.length; i++) {
        for (var j = i + 1; j < objects.length; j++) {
          final a = objects[i].objectId;
          final b = objects[j].objectId;
          var delta = positions[a]! - positions[b]!;
          if (delta.distance < 0.01) delta = Offset(0.01 * (i + 1), 0.01 * (j + 1));
          final repulsion = (k * k) / delta.distance;
          final direction = delta / delta.distance;
          displacement[a] = displacement[a]! + direction * repulsion;
          displacement[b] = displacement[b]! - direction * repulsion;
        }
      }

      for (final relationship in widget.relationships) {
        final a = relationship.sourceObjectId;
        final b = relationship.targetObjectId;
        if (!positions.containsKey(a) || !positions.containsKey(b)) continue;
        final delta = positions[a]! - positions[b]!;
        if (delta.distance < 0.01) continue;
        final attraction = (delta.distance * delta.distance) / k;
        final direction = delta / delta.distance;
        displacement[a] = displacement[a]! - direction * attraction;
        displacement[b] = displacement[b]! + direction * attraction;
      }

      for (final object in objects) {
        final id = object.objectId;
        final capped = displacement[id]!.distance < 1 ? displacement[id]! : (displacement[id]! / displacement[id]!.distance);
        positions[id] = positions[id]! + capped * 5;
      }
    }

    setState(() {
      _positions = positions;
      _layoutFor = objects;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_layoutFor != widget.objects) {
      // A rebuild landed between `didUpdateWidget` scheduling the
      // recompute and it finishing -- paint nothing rather than crash
      // on a stale/missing position for a since-added object.
      return const SizedBox.shrink();
    }

    return InteractiveViewer(
      constrained: false,
      minScale: 0.2,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(400),
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgePainter(positions: _positions, relationships: widget.relationships),
              ),
            ),
            for (final object in widget.objects)
              if (_positions[object.objectId] case final Offset position)
                Positioned(
                  left: position.dx - 56,
                  top: position.dy - 22,
                  child: _GraphNode(
                    object: object,
                    selected: object.objectId == widget.selectedObjectId,
                    onTap: () => widget.onSelectObject(object),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.positions, required this.relationships});

  final Map<String, Offset> positions;
  final List<RelationshipSummary> relationships;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StudioColors.borderSubtle
      ..strokeWidth = 1.2;
    for (final relationship in relationships) {
      final source = positions[relationship.sourceObjectId];
      final target = positions[relationship.targetObjectId];
      if (source == null || target == null) continue;
      canvas.drawLine(source, target, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.relationships != relationships;
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({required this.object, required this.selected, required this.onTap});

  final EngineeringObjectSummary object;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${object.name} (${object.category.label})',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 112,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? StudioColors.selectedRowBackground : StudioColors.surfaceRaised,
            border: Border.all(color: selected ? StudioColors.selection : StudioColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(object.category.icon, size: 14, color: StudioColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  object.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
