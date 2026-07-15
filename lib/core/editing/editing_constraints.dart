/// An axis a drag can be locked to (WORK_PACKAGE_023, ENGINE-TASK-000103).
/// Named `ConstraintAxis`, not `Axis`, to avoid colliding with Flutter's
/// own `Axis` enum in any host that imports both.
enum ConstraintAxis { x, y }

/// Configurable editing-behavior constraints (WORK_PACKAGE_023,
/// ENGINE-TASK-000103). Part of [ViewState] — the same role
/// [GridSettings] already plays: a toggle-able editing preference, never
/// Engineering Knowledge and never Diagram Layout. Constraints are
/// advisory: the Demonstration Host consults `constraint_math.dart`'s
/// pure functions before issuing a command; no `EditingCommand` itself
/// is aware of constraints (see docs/EDITING_CONSTRAINTS.md).
class EditingConstraints {
  /// When enabled, a drag is locked to whichever of x/y has the larger
  /// delta from the drag's start point ("Orthogonal Movement").
  final bool orthogonalMovement;

  /// When set, a drag is locked to exactly this axis ("Axis Lock"),
  /// taking priority over [orthogonalMovement].
  final ConstraintAxis? axisLock;

  /// When set, rotation snaps to multiples of this many degrees
  /// ("Angle Constraint").
  final double? angleConstraintDegrees;

  /// Wire segments/corners may never be dragged shorter than this
  /// ("Minimum Wire Length").
  final double minimumWireLength;

  /// Future-ready placeholder ("Minimum Bend Radius") — orthogonal
  /// routing has no curved bends, so no current routing provider reads
  /// this; it exists so a future curved-routing provider has a config
  /// slot to consume without another `ViewState`/`EditingConstraints`
  /// change.
  final double? minimumBendRadius;

  const EditingConstraints({
    this.orthogonalMovement = false,
    this.axisLock,
    this.angleConstraintDegrees,
    this.minimumWireLength = 8,
    this.minimumBendRadius,
  });

  static const EditingConstraints defaults = EditingConstraints();

  EditingConstraints copyWith({
    bool? orthogonalMovement,
    ConstraintAxis? axisLock,
    bool clearAxisLock = false,
    double? angleConstraintDegrees,
    bool clearAngleConstraint = false,
    double? minimumWireLength,
    double? minimumBendRadius,
    bool clearMinimumBendRadius = false,
  }) {
    return EditingConstraints(
      orthogonalMovement: orthogonalMovement ?? this.orthogonalMovement,
      axisLock: clearAxisLock ? null : (axisLock ?? this.axisLock),
      angleConstraintDegrees: clearAngleConstraint
          ? null
          : (angleConstraintDegrees ?? this.angleConstraintDegrees),
      minimumWireLength: minimumWireLength ?? this.minimumWireLength,
      minimumBendRadius:
          clearMinimumBendRadius ? null : (minimumBendRadius ?? this.minimumBendRadius),
    );
  }

  Map<String, Object?> toJson() => {
        'orthogonalMovement': orthogonalMovement,
        'axisLock': axisLock?.name,
        'angleConstraintDegrees': angleConstraintDegrees,
        'minimumWireLength': minimumWireLength,
        'minimumBendRadius': minimumBendRadius,
      };

  factory EditingConstraints.fromJson(Map<String, Object?> json) => EditingConstraints(
        orthogonalMovement: json['orthogonalMovement'] as bool? ?? false,
        axisLock: json['axisLock'] == null
            ? null
            : ConstraintAxis.values.firstWhere((a) => a.name == json['axisLock']),
        angleConstraintDegrees: (json['angleConstraintDegrees'] as num?)?.toDouble(),
        minimumWireLength: (json['minimumWireLength'] as num?)?.toDouble() ?? 8,
        minimumBendRadius: (json['minimumBendRadius'] as num?)?.toDouble(),
      );
}
