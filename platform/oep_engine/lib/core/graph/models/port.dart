/// Direction a [Port] permits current/flow/signal to travel.
enum PortDirection { input, output, bidirectional, unspecified }

/// A connection point defined by a Symbol or present on an [EngineeringNode].
///
/// Ports determine valid connections (SDD-027). Port *appearance* (position,
/// rotation) is Symbol/rendering data (SDD-028), not engineering knowledge —
/// this model carries only the engineering-meaningful fields.
class Port {
  final String id;
  final String name;
  final PortDirection direction;
  final String type;
  final Map<String, Object?> metadata;

  const Port({
    required this.id,
    required this.name,
    this.direction = PortDirection.unspecified,
    this.type = 'generic',
    this.metadata = const {},
  });

  Port copyWith({
    String? id,
    String? name,
    PortDirection? direction,
    String? type,
    Map<String, Object?>? metadata,
  }) {
    return Port(
      id: id ?? this.id,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'direction': direction.name,
        'type': type,
        'metadata': metadata,
      };

  factory Port.fromJson(Map<String, Object?> json) => Port(
        id: json['id'] as String,
        name: json['name'] as String,
        direction: PortDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => PortDirection.unspecified,
        ),
        type: json['type'] as String? ?? 'generic',
        metadata: Map<String, Object?>.from(
          json['metadata'] as Map? ?? const {},
        ),
      );

  @override
  bool operator ==(Object other) => other is Port && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
