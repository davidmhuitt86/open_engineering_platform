# AP-DIAGRAM-V2-UI-001 — OEP Visual Theme Adaptation

> Visual-only package. Builds on the functional bridge established by
> AP-DIAGRAM-V2-BRIDGE-002 through 009
> (`DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`) — no bridge behavior,
> Engine, Foundation, or native renderer changes were made or needed.

## 1. OEP Visual Sources Inspected

- `platform/oep_studio/lib/core/theme/studio_colors.dart` — the single
  source-of-truth color token set (`StudioColors`): `background`,
  `surface`, `surfaceRaised`, `surfaceSunken`, `border`, `borderSubtle`,
  `textPrimary`, `textSecondary`, `textDisabled`, `selection`, plus
  status colors (`success`/`warning`/`error`/`info`/`inactive`) —
  explicitly documented in that file as communicating *state*, not
  decoration.
- `platform/oep_studio/lib/core/theme/studio_theme.dart` — the ratified
  `ThemeData` (SDD-002 Design Language): font family `'Segoe UI'`
  (general) / `'Consolas'` (monospace/technical, via `monoTextStyle`),
  `visualDensity: compact`, 4px/6px corner radii, zero elevation, border-
  based (not shadow-based) surface separation, `NoSplash` interaction
  feedback.

These two files are the entire OEP visual language relevant to this
task — no other theme system exists in `oep_studio`.

## 2. V2 CSS Sources Inspected

- `reference/legacy_wiring_sim_v2/eke-wiring-sim/css/main.css` (675
  lines — the only substantive V2 stylesheet; `editor.css`/
  `inspector.css`/`meter.css`/`modules.css`/`wires.css` are near-empty
  stubs). **Confirmed V2 already routes essentially all UI chrome color
  through CSS custom properties** declared on `:root`/`[data-theme="dark"]`/
  `[data-theme="light"]`: `--surf-0..3`(+`-hover`), `--border-0..2`,
  `--text-hi/md/lo/faint`, `--btn-text`/`--btn-text-hover`, `--ink`,
  `--bg`, `--amber`, plus shadow tokens. This is the exact "reusable V2
  CSS variable" mechanism this task's Phase 12 asked to prefer.
- Confirmed (by direct read) that the **same variable set drives header,
  sidebar, modals, and floating panels alike** — `#topbar*`, `#left-sidebar`,
  `.sidebar-tab`, `.modal-box`/`.modal-hd`/`.modal-body`/`.modal-ft`
  (shared by every V2 modal: wire-properties, add-module, module-
  properties), and `#fp`/`#fp-*` (floating panel chrome) all consume
  `--surf-*`/`--border-*`/`--text-*` — meaning one variable override
  covers all of them without per-selector patching.
- **Deliberately identified as engineering-semantic, not UI chrome**
  (left unmodified): `--purple`/`--green`/`--cyan`/`--cyan-dim`/`--red`/
  `--red-dim` (category/mode-badge/continuity-display colors),
  `--lcd-bg`/`--lcd-fg` (the multimeter LCD readout), `--canvas-*`/
  `--card-*` (the actual module-card/wiring-diagram rendering on the
  canvas), and `js/utils/colors.js`'s wire-color table (used by wire
  bridge editing, AP-DIAGRAM-V2-BRIDGE-005/006).
- **Identified as a UI accent, not an engineering color, despite the
  name**: `--amber`. Reading its actual usage (`.key-btn.active`,
  `.tb-btn`-adjacent mode badges, `#fp-kb.active`,
  `.mod-card.wire-selected`'s selection outline, `.sidebar-tab.active`)
  shows it functions as V2's own general accent/selection color — not a
  category or status indicator. This is exactly the "selection/
  interaction colors may be adapted to OEP's accent language" case
  Phase 3 explicitly permits.

## 3. Visual Mapping Implemented (OEP → V2)

| V2 variable | New value | OEP source |
|---|---|---|
| `--ink`, `--text-hi` | `#E6E9EE` | `StudioColors.textPrimary` |
| `--bg`, `--surf-0` | `#0D1117` | `StudioColors.background` |
| `--surf-1` | `#11161D` | `StudioColors.surface` |
| `--surf-2` | `#161C25` | `StudioColors.surfaceRaised` |
| `--surf-3` | `#232B36` | `StudioColors.border` (doubles as an interactive-surface tone) |
| `--border-0` | `#1B222C` | `StudioColors.borderSubtle` |
| `--border-1` | `#232B36` | `StudioColors.border` |
| `--text-md`, `--text-lo`, `--btn-text` | `#9AA5B1` | `StudioColors.textSecondary` (V2's 4-tier text hierarchy collapses onto OEP's 3-tier one here — see §12 limitations) |
| `--text-faint` | `#5B6572` | `StudioColors.textDisabled` |
| `--btn-text-hover` | `#E6E9EE` | `StudioColors.textPrimary` |
| `--amber` | `#3B82F6` | `StudioColors.selection` |
| `--surf-3-hover`, `--border-2` | `#2C3542` | **Derived**, not a direct token — no OEP "hover/bright-border" token exists; a small manually-chosen shade between `border` and `surfaceRaised`, disclosed here rather than presented as a real token |
| `--shadow-soft`/`-panel`/`-modal` | unchanged values | Already close to OEP's own zero-elevation/border-based convention; left as V2's own (subtle) shadow, not remapped to a token since OEP has no shadow token system to map from |

**Explicitly not remapped** (§2's protection list): `--purple`, `--green`,
`--cyan`, `--cyan-dim`, `--red`, `--red-dim`, `--lcd-bg`, `--lcd-fg`,
`--canvas-bg`, `--canvas-border`, `--canvas-grid`, `--card-bg`,
`--card-ink`, `--card-border`, `--card-sub`, `--card-tlbl`, and every
hardcoded (non-variable) hex value in `main.css` (e.g. `#0891b2` for the
wire-mode badge) — none of these have a corresponding OEP token, and
several are genuinely engineering-semantic.

**Typography**: `html, body`'s blanket `font-family: 'Courier New',
monospace` is overridden to `'Segoe UI', 'Courier New', monospace` —
OEP's own general-UI font, matching `studio_theme.dart`'s `_fontFamily`.
The multimeter LCD specifically (`#lcd-mode`, `#lcd-val`, `#lcd-unit`,
`#lcd-range`, `#lcd-note`) is instead set to `'Consolas', 'Courier New',
monospace` — OEP's own `_monoFontFamily`/`monoTextStyle` convention for
technical/instrument-style readouts — rather than losing the "instrument
panel" character the LCD is meant to have.

## 4. Implementation Mechanism

A single `<style id="oep-v2-theme-overlay">` element, injected via
`document.createElement`/`(document.head ||
document.documentElement).appendChild(...)` at the very top of the
existing bridge script's IIFE
(`LegacyV2BridgeTransport`'s `_kBridgeScript`, run via
`addScriptToExecuteOnDocumentCreated` — the same mechanism every prior
bridge injection already uses, no new injection point created).

- **Every declaration uses `!important`.** This script runs before V2's
  own `<link rel="stylesheet">` tags are even parsed (document-created
  time), so relying on cascade source order alone would let V2's own
  later-loaded rule win instead of this override. `!important` makes the
  override correct regardless of load order, with no timing dependency
  and no need for a second "apply after load" call.
- **No V2 CSS rule was duplicated.** The override redefines the *same*
  custom properties V2's own rules already reference — every consumer
  (header, sidebar, panels, modals, buttons, tabs, inputs) picks up the
  new values automatically, with zero per-selector patches.
- **Wrapped in `try/catch`.** A theme-injection failure is visual-only
  and must never block the functional bridge (module/wire sync,
  measurement, persistence) — matches this codebase's existing
  convention of isolating cosmetic failures from functional ones.

## 5. Files Changed

- `platform/oep_studio/lib/diagram_studio/webview/legacy_v2_bridge_transport.dart`
  — the only file modified. Added the theme-injection block described
  above, at the top of `_kBridgeScript`'s IIFE. No existing script logic
  (polling, message dispatch, authoritative-sync-back functions) was
  touched.

No other file was created, modified, or deleted for the mechanism
itself (this document and its migration-doc pointer are the only other
additions).

## 6. Reference-Source Integrity

`reference/legacy_wiring_sim_v2/eke-wiring-sim/` is **completely
unmodified** — confirmed via `git status`/`git diff --stat` showing zero
changes under that path. The injected `<style>` overlay exists purely at
runtime inside the WebView's live DOM; V2's own `css/main.css` file on
disk is never read-modified-written, never patched, never touched by
any tool this task used. This satisfies Phase 13's own preference (an
injected/overlay CSS approach) without needing to invoke its STOP
condition — no modification of the frozen reference implementation was
ever necessary.

## 7. Functional Regression Results

All of the following were re-verified via the existing automated test
suites (this is a CSS/DOM-styling change with no JS logic touched, so
no new tests were needed — the existing bridge tests already cover
every one of these against the real `LegacyV2BridgeTransport`/
`LegacyV2StateAdapter`/`DiagramStudioController` path):

- `flutter test test/diagram_studio/ test/instruments/ test/simulation/`
  — **192/192 passed**, zero regressions (module select/move/create/
  delete/rename, wire create/select/delete/label/color, measurement
  bridge, persistence round-trip/cross-document isolation/dirty-state,
  undo/resync — all unchanged).
- `flutter analyze` — clean (7 pre-existing, unrelated lints only).
- `flutter build windows --debug` — succeeded.
- Built `oep_studio.exe` launched, process confirmed running/responsive,
  stopped cleanly (no lingering process).

## 8. Known Visual Limitations

- **Text hierarchy compression**: V2's 4-tier text scale (`hi`/`md`/
  `lo`/`faint`) maps onto OEP's 3-tier one (`textPrimary`/
  `textSecondary`/`textDisabled`) by collapsing `md` and `lo` to the
  same `textSecondary` value — a minor loss of V2's original visual
  hierarchy in secondary label text, not a functional issue.
- **`--surf-3-hover`/`--border-2` are derived, not real OEP tokens** — a
  small manually-chosen shade, since OEP's own token set has no
  "hover" or "brighter border" concept. Disclosed here rather than
  presented as sourced from `StudioColors`.
- **Card/canvas rendering intentionally untouched** — module cards
  remain V2's own light "paper diagram" style (`--card-bg`/`--card-ink`/
  `--canvas-bg` all left as V2's originals) to protect wire-color
  legibility and avoid flattening engineering-semantic contrast. This
  means the diagram *canvas* itself does not visually match OEP's dark
  chrome the way the surrounding UI now does — a deliberate choice per
  Phase 3/8's explicit protection of engineering graphics, not an
  oversight.
- **Secondary hardcoded badge colors** (e.g. `#0891b2` for the wire-mode
  badge, `#10b981`/`#0891b2` for terminal lead-dot highlights) were not
  remapped — no corresponding OEP token exists for these one-off
  accents, and they are few enough that leaving them as V2's own
  designed accent colors was judged preferable to fabricating new
  tokens for them.
- **Manual visual inspection not performed** (optional/non-blocking per
  this task's own instruction) — the mapping was verified by confirming
  every touched CSS variable's actual consumer selectors via direct
  source read, and by confirming the override applies via `!important`
  regardless of load order, but no live WebView2 screenshot comparison
  was captured. The developer may hot-reload/relaunch to inspect the
  result visually at any time.

## 9. Recommended Follow-Up

- A live visual spot-check by the developer (optional, non-blocking, as
  this task allows) to confirm the mapping reads well in practice,
  particularly the collapsed text-hierarchy tiers and the card/canvas
  contrast against the now-dark surrounding chrome.
- If the collapsed 4-tier→3-tier text hierarchy proves visually
  insufficient in practice, consider a small, disclosed 4th OEP text
  tone (not a new theme system — one more token in `StudioColors`)
  rather than continuing to reuse `textSecondary` for both `--text-md`
  and `--text-lo`.
- This package does not touch the command-palette-removal or native-
  renderer-deletion questions — those remain exactly where
  AP-DIAGRAM-V2-BRIDGE-009 left them (§18.5/§18.6 of the migration
  plan).
