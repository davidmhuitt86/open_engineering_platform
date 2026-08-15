import 'package:flutter/material.dart';

import 'studio_colors.dart';

/// The single ratified Studio theme (SDD-002 Design Language).
///
/// Dark theme is the primary supported appearance; light theme is
/// deferred to a future release. Hierarchy is established through
/// weight and size within one sans-serif family, not multiple families.
abstract final class StudioTheme {
  static const _fontFamily = 'Segoe UI';
  static const _monoFontFamily = 'Consolas';

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: StudioColors.selection,
      secondary: StudioColors.selection,
      surface: StudioColors.surface,
      error: StudioColors.error,
      onSurface: StudioColors.textPrimary,
      onPrimary: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: StudioColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: StudioColors.border,
      dividerTheme: const DividerThemeData(
        color: StudioColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: _fontFamily,
        bodyColor: StudioColors.textPrimary,
        displayColor: StudioColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: StudioColors.surface,
        foregroundColor: StudioColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: StudioColors.surface,
        selectedIconTheme: const IconThemeData(color: StudioColors.selection),
        unselectedIconTheme: const IconThemeData(color: StudioColors.textSecondary),
        selectedLabelTextStyle: const TextStyle(
          color: StudioColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: StudioColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: StudioColors.selection.withValues(alpha: 0.16),
        useIndicator: true,
      ),
      cardTheme: CardThemeData(
        color: StudioColors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: StudioColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      iconTheme: const IconThemeData(color: StudioColors.textSecondary, size: 18),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StudioColors.selection,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StudioColors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: StudioColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: StudioColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: StudioColors.selection),
        ),
        hintStyle: const TextStyle(color: StudioColors.textDisabled),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: StudioColors.surfaceRaised,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: StudioColors.border),
        ),
        textStyle: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Monospace style for IDs, CLI output, JSON, and other technical data.
  static const monoTextStyle = TextStyle(
    fontFamily: _monoFontFamily,
    fontSize: 12,
    color: StudioColors.textSecondary,
  );
}
