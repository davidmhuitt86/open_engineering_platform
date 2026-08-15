/// WP-DS-005A Instrument Dock — where the dock is docked.
///
/// `left`/`right` are accepted by the persisted state and the framework's
/// layout math, but `InstrumentDock` (the widget) only actually renders
/// `bottom` and `floating` today — see that file's class doc for the
/// disclosed scope boundary. Persisting `left`/`right` anyway means a
/// future dock-side implementation needs no migration of existing saved
/// layouts.
enum DockPosition { bottom, floating, left, right }

/// Persisted + live state for the Instrument Dock (WP-DS-005A "Instrument
/// Dock" section: bottom dock, floating window, resize, auto-hide, layout
/// persistence).
class InstrumentDockState {
  const InstrumentDockState({
    this.position = DockPosition.bottom,
    this.visible = false,
    this.autoHide = false,
    this.size = 320,
    this.floatingLeft = 120,
    this.floatingTop = 120,
    this.floatingWidth = 420,
    this.floatingHeight = 360,
    this.activeInstrumentId,
  });

  /// Where the dock currently renders.
  final DockPosition position;

  /// Whether the dock is currently shown at all.
  final bool visible;

  /// When `true` and not hovered/focused, a docked (non-floating) dock
  /// collapses to a thin strip showing only its tab bar — the "Auto-hide"
  /// requirement.
  final bool autoHide;

  /// Height (bottom dock) in logical pixels. Reused as width if a future
  /// left/right implementation lands.
  final double size;

  final double floatingLeft;
  final double floatingTop;
  final double floatingWidth;
  final double floatingHeight;

  /// The instrument tab currently selected, or `null` if none/registry
  /// empty.
  final String? activeInstrumentId;

  InstrumentDockState copyWith({
    DockPosition? position,
    bool? visible,
    bool? autoHide,
    double? size,
    double? floatingLeft,
    double? floatingTop,
    double? floatingWidth,
    double? floatingHeight,
    String? activeInstrumentId,
    bool clearActiveInstrumentId = false,
  }) {
    return InstrumentDockState(
      position: position ?? this.position,
      visible: visible ?? this.visible,
      autoHide: autoHide ?? this.autoHide,
      size: size ?? this.size,
      floatingLeft: floatingLeft ?? this.floatingLeft,
      floatingTop: floatingTop ?? this.floatingTop,
      floatingWidth: floatingWidth ?? this.floatingWidth,
      floatingHeight: floatingHeight ?? this.floatingHeight,
      activeInstrumentId: clearActiveInstrumentId ? null : (activeInstrumentId ?? this.activeInstrumentId),
    );
  }

  static const DockPosition _defaultPosition = DockPosition.bottom;

  Map<String, Object?> toJson() => {
        'position': position.name,
        'visible': visible,
        'autoHide': autoHide,
        'size': size,
        'floatingLeft': floatingLeft,
        'floatingTop': floatingTop,
        'floatingWidth': floatingWidth,
        'floatingHeight': floatingHeight,
        if (activeInstrumentId != null) 'activeInstrumentId': activeInstrumentId,
      };

  factory InstrumentDockState.fromJson(Map<String, Object?> json) => InstrumentDockState(
        position: DockPosition.values.firstWhere(
          (p) => p.name == json['position'],
          orElse: () => _defaultPosition,
        ),
        visible: json['visible'] as bool? ?? false,
        autoHide: json['autoHide'] as bool? ?? false,
        size: (json['size'] as num?)?.toDouble() ?? 320,
        floatingLeft: (json['floatingLeft'] as num?)?.toDouble() ?? 120,
        floatingTop: (json['floatingTop'] as num?)?.toDouble() ?? 120,
        floatingWidth: (json['floatingWidth'] as num?)?.toDouble() ?? 420,
        floatingHeight: (json['floatingHeight'] as num?)?.toDouble() ?? 360,
        activeInstrumentId: json['activeInstrumentId'] as String?,
      );

  static const InstrumentDockState initial = InstrumentDockState();
}
