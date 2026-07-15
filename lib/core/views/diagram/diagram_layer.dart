/// A drafting layer (WORK_PACKAGE_023, ENGINE-TASK-000101).
///
/// Layers belong to Diagram Layout, never the Engineering Graph (SDD-024
/// lists Layer explicitly as example Visual Layout data) — the graph
/// remains layer-independent, so removing every layer never loses
/// engineering knowledge, only visual organization.
class DiagramLayer {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final bool printVisible;

  /// Draw/panel order — lower draws first (further back).
  final int order;

  const DiagramLayer({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.printVisible = true,
    this.order = 0,
  });

  DiagramLayer copyWith({
    String? name,
    bool? visible,
    bool? locked,
    bool? printVisible,
    int? order,
  }) {
    return DiagramLayer(
      id: id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      printVisible: printVisible ?? this.printVisible,
      order: order ?? this.order,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'visible': visible,
        'locked': locked,
        'printVisible': printVisible,
        'order': order,
      };

  @override
  bool operator ==(Object other) {
    return other is DiagramLayer &&
        other.id == id &&
        other.name == name &&
        other.visible == visible &&
        other.locked == locked &&
        other.printVisible == printVisible &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(id, name, visible, locked, printVisible, order);

  factory DiagramLayer.fromJson(Map<String, Object?> json) {
    return DiagramLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      visible: json['visible'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      printVisible: json['printVisible'] as bool? ?? true,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}
