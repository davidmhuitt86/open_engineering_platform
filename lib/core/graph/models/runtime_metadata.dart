/// Transient, per-node/relationship runtime state.
///
/// SDD-027: "Runtime metadata shall never be persisted into Foundation."
/// [GraphSerializer] implementations must omit this from any saved
/// representation — it exists only for the lifetime of the running engine.
class RuntimeMetadata {
  final bool selected;
  final bool visible;
  final bool expanded;
  final bool highlighted;

  const RuntimeMetadata({
    this.selected = false,
    this.visible = true,
    this.expanded = false,
    this.highlighted = false,
  });

  RuntimeMetadata copyWith({
    bool? selected,
    bool? visible,
    bool? expanded,
    bool? highlighted,
  }) {
    return RuntimeMetadata(
      selected: selected ?? this.selected,
      visible: visible ?? this.visible,
      expanded: expanded ?? this.expanded,
      highlighted: highlighted ?? this.highlighted,
    );
  }

  static const RuntimeMetadata initial = RuntimeMetadata();
}
