import 'package:flutter/widgets.dart';

/// WP-DS-006 Engineering Workbench — one Perspective's own dock content
/// providers. A [Perspective] never builds a full page; it supplies pieces
/// [EngineeringWorkbenchPage] arranges into the shared window structure
/// (Menu / Global Toolbar / Perspective Selector / Left Dock / Center
/// Workspace / Right Dock / Bottom Dock / Status Bar) — a Perspective owns
/// its content, never its chrome.
///
/// [toolbarProvider]/[leftPanelProvider]/[rightPanelProvider]/
/// [bottomPanelProvider] all return `null` when a Perspective has nothing
/// to contribute to that region (most Phase 1 Perspectives, honestly, do
/// not — see `perspectives/` for which ones are real vs. disclosed
/// placeholders).
class Perspective {
  const Perspective({
    required this.id,
    required this.title,
    required this.icon,
    required this.centerBuilder,
    this.toolbarProvider,
    this.leftPanelProvider,
    this.rightPanelProvider,
    this.bottomPanelProvider,
    this.defaultLayout = const PerspectiveLayout(),
    this.suppressWorkbenchStatusBar = false,
    this.sidebarSubItemsProvider,
  });

  /// Stable identifier — used for persisted "last active perspective" state
  /// and as the per-perspective layout file name (`layouts/<id>.json`), so
  /// it must never change once shipped.
  final String id;

  final String title;
  final IconData icon;

  /// This Perspective's Center Workspace content.
  final WidgetBuilder centerBuilder;

  final WidgetBuilder? toolbarProvider;
  final WidgetBuilder? leftPanelProvider;
  final WidgetBuilder? rightPanelProvider;
  final WidgetBuilder? bottomPanelProvider;

  /// The layout this Perspective starts with before any persisted layout
  /// is loaded for it (first launch, or a corrupted/missing layout file).
  final PerspectiveLayout defaultLayout;

  /// `true` when this Perspective's own [centerBuilder] already provides
  /// equivalent status feedback (the Diagram Perspective embeds
  /// `DiagramStudioPage`, which already sits under `StudioShell`'s own
  /// `StudioStatusBar`) — declarative per-Perspective configuration, not a
  /// hardcoded special case in [EngineeringWorkbenchPage] (the governing
  /// spec's "no switch statements for perspectives" constraint). A
  /// duplicate shell-level status bar on top of an already-chrome-heavy
  /// embedded page also has no vertical space to spare — see this
  /// project's Work Package notes for the regression this flag fixes.
  final bool suppressWorkbenchStatusBar;

  /// Optional real sub-items this Perspective contributes to the
  /// `WorkbenchSidebar`'s expanded submenu when this Perspective is the
  /// active one (e.g. Diagram's "Active Diagram / All Diagrams / Recent
  /// Diagrams"). `null` for a Perspective with nothing real to list yet —
  /// the sidebar shows no expand chevron for it rather than an empty
  /// submenu. A `BuildContext` builder (not a static list) since real
  /// sub-items need `context` to read live app state and dispatch real
  /// actions (open a recent file, navigate to an existing page).
  final List<PerspectiveSidebarItem> Function(BuildContext context)? sidebarSubItemsProvider;
}

/// One row inside a Perspective's expanded sidebar submenu.
class PerspectiveSidebarItem {
  const PerspectiveSidebarItem({
    required this.label,
    required this.onTap,
    this.active = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  /// `null` renders a small dot marker instead (matching the mockup's
  /// "Active Diagram" bullet style for the currently-open item).
  final IconData? icon;
}

/// One Perspective's dock visibility/sizing — the part of a Perspective's
/// layout [WorkbenchLayoutManager] persists independently per Perspective
/// (`diagram.json`, `simulation.json`, ... — never one shared file, so
/// changing one Perspective's layout never touches another's).
class PerspectiveLayout {
  const PerspectiveLayout({
    this.leftVisible = false,
    this.rightVisible = false,
    this.bottomVisible = false,
    this.leftWidth = 280,
    this.rightWidth = 280,
    this.bottomHeight = 240,
  });

  final bool leftVisible;
  final bool rightVisible;
  final bool bottomVisible;
  final double leftWidth;
  final double rightWidth;
  final double bottomHeight;

  PerspectiveLayout copyWith({
    bool? leftVisible,
    bool? rightVisible,
    bool? bottomVisible,
    double? leftWidth,
    double? rightWidth,
    double? bottomHeight,
  }) {
    return PerspectiveLayout(
      leftVisible: leftVisible ?? this.leftVisible,
      rightVisible: rightVisible ?? this.rightVisible,
      bottomVisible: bottomVisible ?? this.bottomVisible,
      leftWidth: leftWidth ?? this.leftWidth,
      rightWidth: rightWidth ?? this.rightWidth,
      bottomHeight: bottomHeight ?? this.bottomHeight,
    );
  }

  Map<String, Object?> toJson() => {
        'leftVisible': leftVisible,
        'rightVisible': rightVisible,
        'bottomVisible': bottomVisible,
        'leftWidth': leftWidth,
        'rightWidth': rightWidth,
        'bottomHeight': bottomHeight,
      };

  factory PerspectiveLayout.fromJson(Map<String, Object?> json) => PerspectiveLayout(
        leftVisible: json['leftVisible'] as bool? ?? false,
        rightVisible: json['rightVisible'] as bool? ?? false,
        bottomVisible: json['bottomVisible'] as bool? ?? false,
        leftWidth: (json['leftWidth'] as num?)?.toDouble() ?? 280,
        rightWidth: (json['rightWidth'] as num?)?.toDouble() ?? 280,
        bottomHeight: (json['bottomHeight'] as num?)?.toDouble() ?? 240,
      );
}
