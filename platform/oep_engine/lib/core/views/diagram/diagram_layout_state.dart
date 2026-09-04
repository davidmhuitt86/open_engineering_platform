import 'diagram_annotation.dart';
import 'diagram_geometry.dart';
import 'diagram_layer.dart';
import 'node_transform.dart';

/// Per-node visual position, tracked as a sibling of the Engineering Graph
/// — never as fields on it.
///
/// SDD-024 Architecture Rule 5: "Layout is not Engineering Knowledge... The
/// graph contains no visual layout information." WORK_PACKAGE_021's Move
/// System is satisfied by routing position through the same
/// command/undo-redo system as graph edits (bundled into
/// `EditingSession { graph, layout }`), not by adding coordinate fields to
/// `EngineeringNode`. See docs/ARCHITECTURE_DECISIONS.md ADR-011.
///
/// WORK_PACKAGE_023 adds four more layout-only sibling maps, each
/// following the exact same pattern as [positions]: [wireOverrides]
/// (manual wire routes, ENGINE-TASK-000099), [annotations] (labels/notes,
/// ENGINE-TASK-000100), [layers]/[layerAssignments] (drafting layers,
/// ENGINE-TASK-000101), and [transforms] (per-node rotation/mirror,
/// ENGINE-TASK-000102). None of it is Engineering Graph data — SDD-024
/// lists Rotation/Layer/Visibility as example Visual Layout data
/// alongside Position.
///
/// [wireSegmentOffsets] (AP-DIAGRAM-V2-BRIDGE-SAVE-001) is a fifth,
/// deliberately separate sibling — **not** a variant of [wireOverrides].
/// [wireOverrides] is an *absolute* point list that fully replaces
/// automatic routing until cleared (OEP's own native Insert-Vertex/
/// Drag-Segment/Drag-Corner gestures all produce this shape — see
/// `wire_editing.dart`'s own doc comment: a one-shot freeze, not something
/// that follows endpoint movement). The Legacy Wiring Simulator V2 bridge
/// needs to represent a genuinely different semantic: V2 stores, per wire,
/// a *scalar perpendicular offset per automatically-computed "movable
/// segment" index* (`wireRoutes[wireId][segIdx]`, confirmed by direct
/// read of `js/diagram/renderer.js`'s `route()`/`drawWires()`), which V2
/// itself recomputes the automatic base route for and reapplies these
/// offsets to on *every draw* — so a manual V2 route adjustment survives
/// an endpoint/module move, unlike an OEP [wireOverrides] entry. OEP's
/// Engine has no automatic-routing-recompute-and-reapply pipeline for
/// this to hook into, and does not need one: V2 is the only consumer that
/// ever interprets or reapplies this data (via its own already-existing
/// `route()`), so this field is purely durable, opaque storage for it —
/// segment index -> scalar offset, exactly V2's own shape, never
/// interpreted by the Engine itself. Storing it here (layout/presentation
/// state) rather than on `EngineeringRelationship` keeps it out of
/// Engineering Knowledge, consistent with every other field in this class.
class DiagramLayoutState {
  final Map<String, Point2D> positions;
  final Map<String, List<Point2D>> wireOverrides;
  final Map<String, DiagramAnnotation> annotations;
  final Map<String, DiagramLayer> layers;

  /// Node-or-annotation id -> layer id.
  final Map<String, String> layerAssignments;
  final Map<String, NodeTransform> transforms;

  /// Per-node explicit size (AP-DS-001A resize support). A node with no
  /// entry here renders at [DiagramLayout.nodeSize] x
  /// [DiagramLayout.nodeSize], same fallback pattern as [positions].
  final Map<String, Size2D> sizes;

  /// Relationship id -> (movable-segment-index -> scalar perpendicular
  /// offset). See class doc comment — this is the Legacy V2 bridge's own
  /// relative route-adjustment representation, verbatim, kept entirely
  /// separate from [wireOverrides].
  final Map<String, Map<int, double>> wireSegmentOffsets;

  const DiagramLayoutState({
    this.positions = const {},
    this.wireOverrides = const {},
    this.annotations = const {},
    this.layers = const {},
    this.layerAssignments = const {},
    this.transforms = const {},
    this.sizes = const {},
    this.wireSegmentOffsets = const {},
  });

  static const DiagramLayoutState empty = DiagramLayoutState();

  DiagramLayoutState copyWith({
    Map<String, Point2D>? positions,
    Map<String, List<Point2D>>? wireOverrides,
    Map<String, DiagramAnnotation>? annotations,
    Map<String, DiagramLayer>? layers,
    Map<String, String>? layerAssignments,
    Map<String, NodeTransform>? transforms,
    Map<String, Size2D>? sizes,
    Map<String, Map<int, double>>? wireSegmentOffsets,
  }) {
    return DiagramLayoutState(
      positions: positions ?? this.positions,
      wireOverrides: wireOverrides ?? this.wireOverrides,
      annotations: annotations ?? this.annotations,
      layers: layers ?? this.layers,
      layerAssignments: layerAssignments ?? this.layerAssignments,
      transforms: transforms ?? this.transforms,
      sizes: sizes ?? this.sizes,
      wireSegmentOffsets: wireSegmentOffsets ?? this.wireSegmentOffsets,
    );
  }

  // --- Positions (WORK_PACKAGE_021) -----------------------------------

  Point2D? positionOf(String nodeId) => positions[nodeId];

  DiagramLayoutState withPosition(String nodeId, Point2D position) {
    return copyWith(positions: {...positions, nodeId: position});
  }

  DiagramLayoutState withPositions(Map<String, Point2D> updates) {
    return copyWith(positions: {...positions, ...updates});
  }

  DiagramLayoutState withoutPosition(String nodeId) {
    final next = {...positions}..remove(nodeId);
    return copyWith(positions: next);
  }

  // --- Wire overrides (WORK_PACKAGE_023, ENGINE-TASK-000099) ----------

  List<Point2D>? wireOverrideOf(String relationshipId) =>
      wireOverrides[relationshipId];

  DiagramLayoutState withWireOverride(
    String relationshipId,
    List<Point2D> points,
  ) {
    return copyWith(wireOverrides: {...wireOverrides, relationshipId: points});
  }

  /// Restores automatic routing for [relationshipId] by clearing its
  /// manual override.
  DiagramLayoutState withoutWireOverride(String relationshipId) {
    final next = {...wireOverrides}..remove(relationshipId);
    return copyWith(wireOverrides: next);
  }

  // --- Wire segment offsets (AP-DIAGRAM-V2-BRIDGE-SAVE-001) -----------

  Map<int, double>? wireSegmentOffsetsOf(String relationshipId) =>
      wireSegmentOffsets[relationshipId];

  DiagramLayoutState withWireSegmentOffsets(
    String relationshipId,
    Map<int, double> offsets,
  ) {
    return copyWith(
      wireSegmentOffsets: {...wireSegmentOffsets, relationshipId: offsets},
    );
  }

  /// Clears all V2-originated route-segment offsets for [relationshipId]
  /// (V2's own "Reset Route" — `delete wireRoutes[wireId]`, a whole-wire
  /// clear, not per-segment).
  DiagramLayoutState withoutWireSegmentOffsets(String relationshipId) {
    final next = {...wireSegmentOffsets}..remove(relationshipId);
    return copyWith(wireSegmentOffsets: next);
  }

  // --- Annotations (WORK_PACKAGE_023, ENGINE-TASK-000100) -------------

  DiagramAnnotation? annotationOf(String annotationId) =>
      annotations[annotationId];

  DiagramLayoutState withAnnotation(DiagramAnnotation annotation) {
    return copyWith(annotations: {...annotations, annotation.id: annotation});
  }

  DiagramLayoutState withoutAnnotation(String annotationId) {
    final next = {...annotations}..remove(annotationId);
    return copyWith(annotations: next);
  }

  // --- Layers (WORK_PACKAGE_023, ENGINE-TASK-000101) -------------------

  DiagramLayer? layerById(String layerId) => layers[layerId];

  DiagramLayoutState withLayer(DiagramLayer layer) {
    return copyWith(layers: {...layers, layer.id: layer});
  }

  /// Removes a layer definition and unassigns every entity that was on it
  /// (they fall back to "no layer" — always visible/unlocked) rather than
  /// leaving a dangling layer reference.
  DiagramLayoutState withoutLayer(String layerId) {
    final nextLayers = {...layers}..remove(layerId);
    final nextAssignments = {...layerAssignments}
      ..removeWhere((_, assignedLayerId) => assignedLayerId == layerId);
    return copyWith(layers: nextLayers, layerAssignments: nextAssignments);
  }

  String? layerOf(String entityId) => layerAssignments[entityId];

  Set<String> entitiesOnLayer(String layerId) {
    return {
      for (final entry in layerAssignments.entries)
        if (entry.value == layerId) entry.key,
    };
  }

  DiagramLayoutState withLayerAssignment(String entityId, String? layerId) {
    final next = {...layerAssignments};
    if (layerId == null) {
      next.remove(entityId);
    } else {
      next[entityId] = layerId;
    }
    return copyWith(layerAssignments: next);
  }

  // --- Transforms (WORK_PACKAGE_023, ENGINE-TASK-000102) ---------------

  NodeTransform transformOf(String nodeId) =>
      transforms[nodeId] ?? NodeTransform.identity;

  DiagramLayoutState withTransform(String nodeId, NodeTransform transform) {
    return copyWith(transforms: {...transforms, nodeId: transform});
  }

  DiagramLayoutState withoutTransform(String nodeId) {
    final next = {...transforms}..remove(nodeId);
    return copyWith(transforms: next);
  }

  // --- Sizes (AP-DS-001A resize support) --------------------------------

  Size2D? sizeOf(String nodeId) => sizes[nodeId];

  DiagramLayoutState withSize(String nodeId, Size2D size) {
    return copyWith(sizes: {...sizes, nodeId: size});
  }

  DiagramLayoutState withoutSize(String nodeId) {
    final next = {...sizes}..remove(nodeId);
    return copyWith(sizes: next);
  }

  // --- Serialization ----------------------------------------------------

  Map<String, Object?> toJson() => {
    'positions': positions.map(
      (id, p) => MapEntry(id, {'dx': p.dx, 'dy': p.dy}),
    ),
    'wireOverrides': wireOverrides.map(
      (id, points) =>
          MapEntry(id, points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList()),
    ),
    'annotations': annotations.map((id, a) => MapEntry(id, a.toJson())),
    'layers': layers.map((id, l) => MapEntry(id, l.toJson())),
    'layerAssignments': layerAssignments,
    'transforms': transforms.map((id, t) => MapEntry(id, t.toJson())),
    'sizes': sizes.map(
      (id, s) => MapEntry(id, {'width': s.width, 'height': s.height}),
    ),
    'wireSegmentOffsets': wireSegmentOffsets.map(
      (id, offsets) => MapEntry(
        id,
        offsets.map((segIdx, offset) => MapEntry(segIdx.toString(), offset)),
      ),
    ),
  };

  factory DiagramLayoutState.fromJson(Map<String, Object?> json) {
    final rawPositions = json['positions'] as Map? ?? const {};
    final rawWireOverrides = json['wireOverrides'] as Map? ?? const {};
    final rawAnnotations = json['annotations'] as Map? ?? const {};
    final rawLayers = json['layers'] as Map? ?? const {};
    final rawLayerAssignments = json['layerAssignments'] as Map? ?? const {};
    final rawTransforms = json['transforms'] as Map? ?? const {};
    final rawSizes = json['sizes'] as Map? ?? const {};
    final rawWireSegmentOffsets =
        json['wireSegmentOffsets'] as Map? ?? const {};

    Point2D pointFrom(Object? value) {
      final point = value as Map;
      return Point2D(
        (point['dx'] as num).toDouble(),
        (point['dy'] as num).toDouble(),
      );
    }

    return DiagramLayoutState(
      positions: rawPositions.map(
        (id, value) => MapEntry(id as String, pointFrom(value)),
      ),
      wireOverrides: rawWireOverrides.map(
        (id, value) =>
            MapEntry(id as String, (value as List).map(pointFrom).toList()),
      ),
      annotations: rawAnnotations.map(
        (id, value) => MapEntry(
          id as String,
          DiagramAnnotation.fromJson(Map<String, Object?>.from(value as Map)),
        ),
      ),
      layers: rawLayers.map(
        (id, value) => MapEntry(
          id as String,
          DiagramLayer.fromJson(Map<String, Object?>.from(value as Map)),
        ),
      ),
      layerAssignments: Map<String, String>.from(rawLayerAssignments),
      transforms: rawTransforms.map(
        (id, value) => MapEntry(
          id as String,
          NodeTransform.fromJson(Map<String, Object?>.from(value as Map)),
        ),
      ),
      sizes: rawSizes.map((id, value) {
        final size = value as Map;
        return MapEntry(
          id as String,
          Size2D(
            (size['width'] as num).toDouble(),
            (size['height'] as num).toDouble(),
          ),
        );
      }),
      wireSegmentOffsets: rawWireSegmentOffsets.map(
        (id, value) => MapEntry(
          id as String,
          (value as Map).map(
            (segIdx, offset) => MapEntry(
              int.parse(segIdx as String),
              (offset as num).toDouble(),
            ),
          ),
        ),
      ),
    );
  }
}
