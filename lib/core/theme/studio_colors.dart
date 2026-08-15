import 'package:flutter/material.dart';

/// Status and surface colors for OEP Studio, per SDD-002 Design Language.
///
/// Colors communicate state, not decoration:
/// blue = selection, green = success, yellow = warning, red = error,
/// gray = inactive.
abstract final class StudioColors {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF11161D);
  static const surfaceRaised = Color(0xFF161C25);
  static const surfaceSunken = Color(0xFF0A0E13);
  static const border = Color(0xFF232B36);
  static const borderSubtle = Color(0xFF1B222C);

  static const textPrimary = Color(0xFFE6E9EE);
  static const textSecondary = Color(0xFF9AA5B1);
  static const textDisabled = Color(0xFF5B6572);

  static const selection = Color(0xFF3B82F6);

  /// The consistent selected-row background across list/tree rows app-
  /// wide (Phase 4 shared-primitives work: consumers previously used
  /// alpha 0.12 in some panels and 0.15 in others for the same visual
  /// intent -- one value now, not a new color).
  static final selectedRowBackground = selection.withValues(alpha: 0.12);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFEAB308);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF9AA5B1);
  static const inactive = Color(0xFF5B6572);
}
