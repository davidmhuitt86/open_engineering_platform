import 'package:flutter/material.dart';

import 'studio_colors.dart';

/// AP-OEP-STUDIO-DESIGN-UNIFY-001 — the named type scale Studio never
/// had (every page previously declared its own inline `TextStyle`
/// literals). Modeled on Diagram Studio's Property Inspector (the
/// legacy `eke-wiring-sim` JS app's sidebar panel): uppercase
/// micro-labels with letter-spacing for anything that names a field or
/// section, bold plain-case values. Sizes are scaled up from that
/// app's literal 7.5–10px CSS pixels — legible at normal desktop
/// reading distance in a native app was the goal, not a pixel-for-pixel
/// copy.
abstract final class StudioTypography {
  /// A page's own top-level title (`StudioPanelHeader` at the page
  /// level). Replaces the handful of ad hoc page-title sizes different
  /// pages had converged on independently (15px, 24px, ...).
  static const pageTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: StudioColors.textPrimary,
  );

  /// A section divider label inside a page or panel — the
  /// `.mip-section-hd`/`.cat-hd` idiom: small, muted, uppercase, wide
  /// letter-spacing, no background fill (paired with a top border by
  /// the widget that uses it, not by this style itself).
  static const sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: StudioColors.textSecondary,
  );

  /// A single field's label in a `StudioDetailRow` — the `.fpk` idiom.
  static const fieldLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: StudioColors.textSecondary,
  );

  /// A single field's value in a `StudioDetailRow` — the `.fpv` idiom.
  static const fieldValue = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: StudioColors.textPrimary,
  );
}
