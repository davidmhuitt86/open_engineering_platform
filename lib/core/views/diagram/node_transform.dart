/// Per-node visual transform — rotation and mirroring
/// (WORK_PACKAGE_023, ENGINE-TASK-000102).
///
/// A sibling of node position, tracked in [DiagramLayoutState] exactly
/// the same way — SDD-024 explicitly lists Rotation as example Visual
/// Layout data, so this is layout, never Engineering Graph state.
class NodeTransform {
  /// Degrees, clockwise, `0` = unrotated.
  final double rotation;
  final bool flipHorizontal;
  final bool flipVertical;

  const NodeTransform({
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  static const NodeTransform identity = NodeTransform();

  NodeTransform copyWith({
    double? rotation,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    return NodeTransform(
      rotation: rotation ?? this.rotation,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
    );
  }

  Map<String, Object?> toJson() => {
        'rotation': rotation,
        'flipHorizontal': flipHorizontal,
        'flipVertical': flipVertical,
      };

  factory NodeTransform.fromJson(Map<String, Object?> json) {
    return NodeTransform(
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NodeTransform &&
      other.rotation == rotation &&
      other.flipHorizontal == flipHorizontal &&
      other.flipVertical == flipVertical;

  @override
  int get hashCode => Object.hash(rotation, flipHorizontal, flipVertical);
}
