import '../../graph/models/port.dart';

/// A connection port as defined on a Symbol (SDD-028).
///
/// Distinct from [Port] on [EngineeringNode]: the Engineering Graph carries
/// no layout (SDD-024), but a Symbol's ports legitimately need geometric
/// placement to render connection anchors — that's rendering data, not
/// engineering knowledge, so it lives here rather than on the graph model.
class SymbolPort {
  final String id;
  final String displayName;
  final String connectionType;
  final PortDirection direction;

  /// Normalized position within the symbol's geometry bounds (0..1, 0..1).
  final double x;
  final double y;

  /// Degrees, clockwise.
  final double rotation;
  final bool visible;

  const SymbolPort({
    required this.id,
    required this.displayName,
    required this.connectionType,
    this.direction = PortDirection.unspecified,
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.visible = true,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'connectionType': connectionType,
        'direction': direction.name,
        'x': x,
        'y': y,
        'rotation': rotation,
        'visible': visible,
      };

  factory SymbolPort.fromJson(Map<String, Object?> json) => SymbolPort(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        connectionType: json['connectionType'] as String? ?? 'generic',
        direction: PortDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => PortDirection.unspecified,
        ),
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        visible: json['visible'] as bool? ?? true,
      );
}
