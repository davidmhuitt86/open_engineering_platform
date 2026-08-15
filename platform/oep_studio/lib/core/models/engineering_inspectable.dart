import 'package:engineering_engine/engineering_engine.dart';

/// Which kind of Engineering-domain object [EngineeringInspectable] wraps.
enum EngineeringInspectableKind {
  node,
  relationship,
  group,
  port,
  layer,
  annotation,
  wireOverride,

  /// WORK_PACKAGE_025, ENGINE-TASK-000122 — an `EvidenceLink` attached to
  /// a node or relationship. Previously only shown nested/summarized
  /// inside node/relationship properties ("N linked"); this gives it its
  /// own inspector mode so evidence navigation (ENGINE-TASK-000123) has
  /// somewhere to land.
  evidenceLink,
}

/// A single Engineering Graph/Diagram Layout object currently selected in
/// Diagram Studio, bridged into the shared Property Inspector's
/// mutually-exclusive selection (WORK_PACKAGE_024, ENGINE-TASK-000110).
///
/// Selection itself is owned by the Engineering Engine (`GraphSelection`/
/// `FocusState`, resolved through `EngineRegistry.selection` —
/// `docs/SELECTION_MODEL.md` in `oep_engine`) — Studio never reimplements
/// it. This value is only a *display* bridge: Diagram Studio listens to
/// the Engine's own selection/focus streams and wraps whichever single
/// object should currently be shown in the Property Inspector into one of
/// these, so `FoundationServiceState` needs exactly one new field instead
/// of seven. Exactly one of the typed accessors below is non-null,
/// matching [kind].
class EngineeringInspectable {
  final EngineeringInspectableKind kind;
  final EngineeringNode? node;
  final EngineeringRelationship? relationship;
  final EngineeringGroup? group;
  final Port? port;

  /// Only set alongside [port] — a bare [Port] doesn't know which node it
  /// belongs to.
  final String? portOwnerNodeId;
  final DiagramLayer? layer;
  final DiagramAnnotation? annotation;

  /// Only set alongside [wireOverridePoints] — the relationship a manual
  /// wire route override belongs to (`docs/WIRE_EDITING.md`).
  final String? wireOverrideRelationshipId;
  final List<Point2D>? wireOverridePoints;

  final EvidenceLink? evidenceLink;

  /// The id of the node or relationship [evidenceLink] is attached to —
  /// an `EvidenceLink` has no owner reference of its own (SDD-024: it's
  /// carried in the owning node/relationship's own `evidenceLinks` list).
  final String? evidenceLinkOwnerId;

  const EngineeringInspectable._({
    required this.kind,
    this.node,
    this.relationship,
    this.group,
    this.port,
    this.portOwnerNodeId,
    this.layer,
    this.annotation,
    this.wireOverrideRelationshipId,
    this.wireOverridePoints,
    this.evidenceLink,
    this.evidenceLinkOwnerId,
  });

  factory EngineeringInspectable.node(EngineeringNode node) =>
      EngineeringInspectable._(
          kind: EngineeringInspectableKind.node, node: node);

  factory EngineeringInspectable.relationship(
          EngineeringRelationship relationship) =>
      EngineeringInspectable._(
          kind: EngineeringInspectableKind.relationship,
          relationship: relationship);

  factory EngineeringInspectable.group(EngineeringGroup group) =>
      EngineeringInspectable._(
          kind: EngineeringInspectableKind.group, group: group);

  factory EngineeringInspectable.port(String ownerNodeId, Port port) =>
      EngineeringInspectable._(
        kind: EngineeringInspectableKind.port,
        port: port,
        portOwnerNodeId: ownerNodeId,
      );

  factory EngineeringInspectable.layer(DiagramLayer layer) =>
      EngineeringInspectable._(
          kind: EngineeringInspectableKind.layer, layer: layer);

  factory EngineeringInspectable.annotation(DiagramAnnotation annotation) =>
      EngineeringInspectable._(
          kind: EngineeringInspectableKind.annotation, annotation: annotation);

  factory EngineeringInspectable.wireOverride(
          String relationshipId, List<Point2D> points) =>
      EngineeringInspectable._(
        kind: EngineeringInspectableKind.wireOverride,
        wireOverrideRelationshipId: relationshipId,
        wireOverridePoints: points,
      );

  factory EngineeringInspectable.evidenceLink(String ownerId, EvidenceLink link) =>
      EngineeringInspectable._(
        kind: EngineeringInspectableKind.evidenceLink,
        evidenceLink: link,
        evidenceLinkOwnerId: ownerId,
      );
}
