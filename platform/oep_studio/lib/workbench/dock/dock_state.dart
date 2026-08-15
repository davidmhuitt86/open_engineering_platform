/// WP-DS-006 Engineering Workbench — where a [DockManager]-driven dock
/// currently renders. Generalizes WP-DS-005A's Instrument Dock
/// `DockPosition` (bottom/floating/left/right) by adding [hidden] as an
/// explicit, persisted state distinct from merely `visible: false` — the
/// governing spec lists Hidden as its own dock capability, alongside
/// Left/Right/Bottom/Floating/Auto-hide.
enum DockSide { left, right, bottom, floating, hidden }

/// Persisted + live state for one dock region managed by a [DockManager]
/// (governing spec's Dock Manager section: Left/Right/Bottom/Floating/
/// Hidden/Auto-hide/Resize/Tabbed docks/Layout persistence).
class DockManagerState {
  const DockManagerState({
    this.side = DockSide.bottom,
    this.visible = false,
    this.autoHide = false,
    this.size = 320,
    this.floatingLeft = 120,
    this.floatingTop = 120,
    this.floatingWidth = 420,
    this.floatingHeight = 360,
    this.activeClientId,
  });

  final DockSide side;
  final bool visible;

  /// When `true` and not hovered/focused, a docked (non-floating,
  /// non-hidden) dock collapses to a thin strip showing only its tab bar.
  final bool autoHide;

  /// Height (bottom dock) or width (left/right dock) in logical pixels.
  final double size;

  final double floatingLeft;
  final double floatingTop;
  final double floatingWidth;
  final double floatingHeight;

  /// The tab currently selected, or `null` if none/registry empty.
  final String? activeClientId;

  DockManagerState copyWith({
    DockSide? side,
    bool? visible,
    bool? autoHide,
    double? size,
    double? floatingLeft,
    double? floatingTop,
    double? floatingWidth,
    double? floatingHeight,
    String? activeClientId,
    bool clearActiveClientId = false,
  }) {
    return DockManagerState(
      side: side ?? this.side,
      visible: visible ?? this.visible,
      autoHide: autoHide ?? this.autoHide,
      size: size ?? this.size,
      floatingLeft: floatingLeft ?? this.floatingLeft,
      floatingTop: floatingTop ?? this.floatingTop,
      floatingWidth: floatingWidth ?? this.floatingWidth,
      floatingHeight: floatingHeight ?? this.floatingHeight,
      activeClientId: clearActiveClientId ? null : (activeClientId ?? this.activeClientId),
    );
  }

  Map<String, Object?> toJson() => {
        'side': side.name,
        'visible': visible,
        'autoHide': autoHide,
        'size': size,
        'floatingLeft': floatingLeft,
        'floatingTop': floatingTop,
        'floatingWidth': floatingWidth,
        'floatingHeight': floatingHeight,
        if (activeClientId != null) 'activeClientId': activeClientId,
      };

  factory DockManagerState.fromJson(Map<String, Object?> json) => DockManagerState(
        side: DockSide.values.firstWhere((s) => s.name == json['side'], orElse: () => DockSide.bottom),
        visible: json['visible'] as bool? ?? false,
        autoHide: json['autoHide'] as bool? ?? false,
        size: (json['size'] as num?)?.toDouble() ?? 320,
        floatingLeft: (json['floatingLeft'] as num?)?.toDouble() ?? 120,
        floatingTop: (json['floatingTop'] as num?)?.toDouble() ?? 120,
        floatingWidth: (json['floatingWidth'] as num?)?.toDouble() ?? 420,
        floatingHeight: (json['floatingHeight'] as num?)?.toDouble() ?? 360,
        activeClientId: json['activeClientId'] as String?,
      );

  static const DockManagerState initial = DockManagerState();
}
