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
class DiagramLayoutState {
  final Map<String, Point2D> positions;
  final Map<String, List<Point2D>> wireOverrides;
  final Map<String, DiagramAnnotation> annotations;
  final Map<String, DiagramLayer> layers;

  /// Node-or-annotation id -> layer id.
  final Map<String, String> layerAssignments;
  final Map<String, NodeTransform> transforms;

  const DiagramLayoutState({
    this.positions = const {},
    this.wireOverrides = const {},
    this.annotations = const {},
    this.layers = const {},
    this.layerAssignments = const {},
    this.transforms = const {},
  });

  static const DiagramLayoutState empty = DiagramLayoutState();

  DiagramLayoutState copyWith({
    Map<String, Point2D>? positions,
    Map<String, List<Point2D>>? wireOverrides,
    Map<String, DiagramAnnotation>? annotations,
    Map<String, DiagramLayer>? layers,
    Map<String, String>? layerAssignments,
    Map<String, NodeTransform>? transforms,
  }) {
    return DiagramLayoutState(
      positions: positions ?? this.positions,
      wireOverrides: wireOverrides ?? this.wireOverrides,
      annotations: annotations ?? this.annotations,
      layers: layers ?? this.layers,
      layerAssignments: layerAssignments ?? this.layerAssignments,
      transforms: transforms ?? this.transforms,
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

  List<Point2D>? wireOverrideOf(String relationshipId) => wireOverrides[relationshipId];

  DiagramLayoutState withWireOverride(String relationshipId, List<Point2D> points) {
    return copyWith(wireOverrides: {...wireOverrides, relationshipId: points});
  }

  /// Restores automatic routing for [relationshipId] by clearing its
  /// manual override.
  DiagramLayoutState withoutWireOverride(String relationshipId) {
    final next = {...wireOverrides}..remove(relationshipId);
    return copyWith(wireOverrides: next);
  }

  // --- Annotations (WORK_PACKAGE_023, ENGINE-TASK-000100) -------------

  DiagramAnnotation? annotationOf(String annotationId) => annotations[annotationId];

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

  NodeTransform transformOf(String nodeId) => transforms[nodeId] ?? NodeTransform.identity;

  DiagramLayoutState withTransform(String nodeId, NodeTransform transform) {
    return copyWith(transforms: {...transforms, nodeId: transform});
  }

  DiagramLayoutState withoutTransform(String nodeId) {
    final next = {...transforms}..remove(nodeId);
    return copyWith(transforms: next);
  }

  // --- Serialization ----------------------------------------------------

  Map<String, Object?> toJson() => {
        'positions': positions.map((id, p) => MapEntry(id, {'dx': p.dx, 'dy': p.dy})),
        'wireOverrides': wireOverrides.map(
          (id, points) => MapEntry(id, points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList()),
        ),
        'annotations': annotations.map((id, a) => MapEntry(id, a.toJson())),
        'layers': layers.map((id, l) => MapEntry(id, l.toJson())),
        'layerAssignments': layerAssignments,
        'transforms': transforms.map((id, t) => MapEntry(id, t.toJson())),
      };

  factory DiagramLayoutState.fromJson(Map<String, Object?> json) {
    final rawPositions = json['positions'] as Map? ?? const {};
    final rawWireOverrides = json['wireOverrides'] as Map? ?? const {};
    final rawAnnotations = json['annotations'] as Map? ?? const {};
    final rawLayers = json['layers'] as Map? ?? const {};
    final rawLayerAssignments = json['layerAssignments'] as Map? ?? const {};
    final rawTransforms = json['transforms'] as Map? ?? const {};

    Point2D pointFrom(Object? value) {
      final point = value as Map;
      return Point2D((point['dx'] as num).toDouble(), (point['dy'] as num).toDouble());
    }

    return DiagramLayoutState(
      positions: rawPositions.map((id, value) => MapEntry(id as String, pointFrom(value))),
      wireOverrides: rawWireOverrides.map((id, value) => MapEntry(
            id as String,
            (value as List).map(pointFrom).toList(),
          )),
      annotations: rawAnnotations.map((id, value) => MapEntry(
            id as String,
            DiagramAnnotation.fromJson(Map<String, Object?>.from(value as Map)),
          )),
      layers: rawLayers.map((id, value) => MapEntry(
            id as String,
            DiagramLayer.fromJson(Map<String, Object?>.from(value as Map)),
          )),
      layerAssignments: Map<String, String>.from(rawLayerAssignments),
      transforms: rawTransforms.map((id, value) => MapEntry(
            id as String,
            NodeTransform.fromJson(Map<String, Object?>.from(value as Map)),
          )),
    );
  }
}
