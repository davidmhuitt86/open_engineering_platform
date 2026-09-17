/// OEP target design-system tokens (AP-UX-002/AP-UX-004/AP-UX-005 reconciled
/// values, `docs/architecture/ux/design-system/OEP-DESIGN-TOKENS.md`).
///
/// AP-UX-006 §14 / WP-UI-DS-001 Section 01 — this is an ADDITIVE token layer.
/// [StudioColors] (`studio_colors.dart`) is not modified, renamed, or removed
/// by introducing this file: its values are close-but-not-identical to the
/// values below, and every existing call site continues to work unchanged.
/// New shell code (Sections 02–10) should read from [OepColors]/
/// [OepGeometry]/[OepTypography]; older, already-shipped widgets keep using
/// [StudioColors] until a separate, deliberate follow-up migrates them.
///
/// Accent rule (OEP-DESIGN-TOKENS.md §2A, AP-UX-002 C1 — enforced here by
/// having two clearly separate token groups, not by convention alone):
/// - [OepColors.studioHome]..[OepColors.studioSettings] are used ONLY on
///   Global Studio Bar and Workspace Bar tabs.
/// - Every other control (Toolbar, Inspector, Status Bar, Context
///   Navigation, focus/active states) uses [OepColors.accent] only.
/// Do not introduce a new per-Studio color usage outside those two regions
/// without a further explicit design-owner decision.
library;

import 'package:flutter/material.dart';

/// Color tokens. Mirrors `OEP-DESIGN-TOKENS.md` §2 (general) and §2A
/// (per-Studio identity, closed set — do not add an eighth entry).
abstract final class OepColors {
  // --- §2 general tokens ---
  static const bg = Color(0xFF0B0F14);
  static const surface1 = Color(0xFF111720);
  static const surface2 = Color(0xFF151D27);
  static const surface3 = Color(0xFF1B2531);
  static const border = Color(0xFF2A3542);
  static const borderStrong = Color(0xFF394858);
  static const textPrimary = Color(0xFFE7EDF4);
  static const textSecondary = Color(0xFF9AA8B7);
  static const textMuted = Color(0xFF667585);

  /// The single global interaction accent. NOT the Studio Bar/Workspace Bar
  /// identity color — see the per-Studio tokens below.
  static const accent = Color(0xFF2F81F7);
  static const accentHover = Color(0xFF4A94FF);

  static const success = Color(0xFF39B56B);
  static const warning = Color(0xFFD9A441);
  static const error = Color(0xFFD95C5C);
  static const info = Color(0xFF5DA9E9);

  // --- §2A Studio identity tokens (closed set of 7 — Engineering
  // Intelligence is deliberately absent; it is not a Studio) ---
  static const studioHome = textSecondary; // #9AA8B7, neutral — no identity of its own
  static const studioDiagram = accent; // #2F81F7, same as the global accent
  static const studioEam = Color(0xFF2FB584);
  static const studioKnowledge = Color(0xFFD9A441);
  static const studioExchange = Color(0xFF8A5CF6);
  static const studioInstruments = Color(0xFFD95C5C);
  static const studioSettings = textMuted; // #667585
}

/// Geometry tokens. Mirrors `OEP-DESIGN-TOKENS.md` §3. These are the values
/// AP-UX-002 corrected against the design-owner-designated pixel wireframe
/// ("Start With this Exact Wireframe and its Pixel Measurments.png"):
/// Workspace Bar 36->42px and Toolbar 40->60px were both corrected there.
abstract final class OepGeometry {
  static const radiusNone = 0.0;
  static const radiusSm = 3.0;
  static const radiusMd = 5.0;
  static const radiusLg = 7.0;

  static const spacing1 = 4.0;
  static const spacing2 = 8.0;
  static const spacing3 = 12.0;
  static const spacing4 = 16.0;
  static const spacing5 = 20.0;
  static const spacing6 = 24.0;
  static const spacing8 = 32.0;

  static const controlHeight = 32.0;
  static const controlHeightCompact = 28.0;

  // --- Target shell region heights (1920x1080 baseline) ---
  static const headerHeight = 58.0;
  static const studioBarHeight = 56.0;
  static const workspaceBarHeight = 42.0;
  static const toolbarHeight = 60.0;
  static const statusBarHeight = 36.0;

  // --- Context Navigation / Inspector reference widths (variable;
  // AP-UX-005 held these values for its canonical renders) ---
  static const contextNavWidth = 280.0;
  static const inspectorWidth = 640.0;
}

/// Typography tokens. Mirrors `OEP-DESIGN-TOKENS.md` §4's baseline hierarchy.
/// The source document gives each role a range (e.g. "18-20px"); the values
/// below are single concrete picks within that range for implementation use.
abstract final class OepTypography {
  static const fontFamily = 'Segoe UI';

  static const applicationTitle = 19.0; // 18-20px, semibold
  static const studioTitle = 15.0; // 14-16px, semibold
  static const workspaceLabel = 12.5; // 12-13px, medium
  static const body = 12.5; // 12-13px
  static const metadata = 10.5; // 10-11px
  static const monospace = 11.5; // 11-12px
}
