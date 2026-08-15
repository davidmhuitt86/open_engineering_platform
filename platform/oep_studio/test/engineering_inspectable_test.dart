import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_studio/core/models/engineering_inspectable.dart';

/// Each `EngineeringInspectable` factory sets exactly the kind it
/// claims plus its own payload, and leaves every other payload field
/// null (WORK_PACKAGE_024, ENGINE-TASK-000110) — the invariant
/// `PropertyInspectorPanel._engineeringInspectableProperties` relies on
/// when it force-unwraps the field matching `kind`.
void main() {
  test('.node carries only the node payload', () {
    const node = EngineeringNode(id: 'n1', category: NodeCategory.component, displayName: 'Battery');
    final inspectable = EngineeringInspectable.node(node);

    expect(inspectable.kind, EngineeringInspectableKind.node);
    expect(inspectable.node, node);
    expect(inspectable.relationship, isNull);
    expect(inspectable.group, isNull);
    expect(inspectable.port, isNull);
    expect(inspectable.layer, isNull);
    expect(inspectable.annotation, isNull);
    expect(inspectable.wireOverrideRelationshipId, isNull);
  });

  test('.relationship carries only the relationship payload', () {
    const relationship = EngineeringRelationship(
      id: 'r1',
      relationshipType: RelationshipType.connectedTo,
      sourceNode: 'a',
      targetNode: 'b',
    );
    final inspectable = EngineeringInspectable.relationship(relationship);

    expect(inspectable.kind, EngineeringInspectableKind.relationship);
    expect(inspectable.relationship, relationship);
    expect(inspectable.node, isNull);
  });

  test('.port carries the port plus its owner node id', () {
    const port = Port(id: 'p1', name: 'Positive');
    final inspectable = EngineeringInspectable.port('n1', port);

    expect(inspectable.kind, EngineeringInspectableKind.port);
    expect(inspectable.port, port);
    expect(inspectable.portOwnerNodeId, 'n1');
    expect(inspectable.node, isNull);
  });

  test('.wireOverride carries the relationship id plus its points', () {
    const points = [Point2D(0, 0), Point2D(10, 10)];
    final inspectable = EngineeringInspectable.wireOverride('r1', points);

    expect(inspectable.kind, EngineeringInspectableKind.wireOverride);
    expect(inspectable.wireOverrideRelationshipId, 'r1');
    expect(inspectable.wireOverridePoints, points);
    expect(inspectable.annotation, isNull);
  });

  test('.layer and .annotation each carry only their own payload', () {
    const layer = DiagramLayer(id: 'l1', name: 'Power');
    final layerInspectable = EngineeringInspectable.layer(layer);
    expect(layerInspectable.kind, EngineeringInspectableKind.layer);
    expect(layerInspectable.layer, layer);
    expect(layerInspectable.annotation, isNull);

    final annotation = DiagramAnnotation(
      id: 'a1',
      type: AnnotationType.freeText,
      text: 'Note',
      position: const Point2D(0, 0),
    );
    final annotationInspectable = EngineeringInspectable.annotation(annotation);
    expect(annotationInspectable.kind, EngineeringInspectableKind.annotation);
    expect(annotationInspectable.annotation, annotation);
    expect(annotationInspectable.layer, isNull);
  });
}
