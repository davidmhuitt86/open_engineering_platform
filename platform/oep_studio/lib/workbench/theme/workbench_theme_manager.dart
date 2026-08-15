import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// WP-DS-006 Engineering Workbench — Theme Manager.
///
/// The governing spec lists a Theme Manager among the 8 Workbench-owned
/// managers, but this codebase already has exactly one, app-wide theme:
/// `StudioColors`/`StudioTheme` (`lib/core/theme/`), used by `StudioShell`,
/// every existing Studio, and every Workbench widget already built
/// (`PerspectiveSelector`, `WorkbenchStatusBar`, `DockRegion`). Building a
/// second, competing color palette would violate "match existing visual
/// conventions" and give the Workbench two sources of truth for the same
/// colors — so this is deliberately a thin accessor, not a new theming
/// system.
///
/// [WorkbenchThemeManager] exposes the same named colors [StudioColors]
/// already defines, one property per color, so Workbench widgets can
/// depend on "the Workbench's theme manager" (injectable, mockable in a
/// test) instead of a hardcoded `StudioColors` import. Every getter below
/// simply forwards to the matching [StudioColors] constant today — there
/// is no second palette.
///
/// [colorsFor] is the documented seam for a future per-Perspective theme
/// override (e.g. a Simulation Perspective wanting a distinct accent color
/// while a live session is running): it returns `this` for every
/// perspective id today, i.e. no override exists yet. Building the actual
/// override mechanism is out of scope for Phase 1 ("shell only").
class WorkbenchThemeManager {
  const WorkbenchThemeManager();

  Color get background => StudioColors.background;
  Color get surface => StudioColors.surface;
  Color get surfaceRaised => StudioColors.surfaceRaised;
  Color get surfaceSunken => StudioColors.surfaceSunken;
  Color get border => StudioColors.border;
  Color get borderSubtle => StudioColors.borderSubtle;
  Color get textPrimary => StudioColors.textPrimary;
  Color get textSecondary => StudioColors.textSecondary;
  Color get textDisabled => StudioColors.textDisabled;
  Color get selection => StudioColors.selection;
  Color get success => StudioColors.success;
  Color get warning => StudioColors.warning;
  Color get error => StudioColors.error;
  Color get info => StudioColors.info;
  Color get inactive => StudioColors.inactive;

  /// The [WorkbenchThemeManager] a given Perspective should render with.
  /// Always `this` today (no per-Perspective override exists yet); this
  /// method is the documented seam for adding one later without changing
  /// every call site that currently reads a fixed instance.
  WorkbenchThemeManager colorsFor(String perspectiveId) => this;

  static const WorkbenchThemeManager instance = WorkbenchThemeManager();
}
