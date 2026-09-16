# OEP Design Tokens

**Status:** Proposed implementation baseline
**Scope:** OEP desktop application visual language
**Purpose:** Give implementation agents explicit, measurable visual constants rather than asking them to infer style from screenshots.
**Reconciled by:** AP-UX-002 (`docs/architecture/ux/AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`) — this document's color model (§2/§2A) and geometry (§3) were amended by that reconciliation to resolve AP-UX-001's C1 and C2 findings. See that document for the evidence and design-owner decision behind each change below.

## 1. Core visual intent

OEP is a professional engineering workstation, not a consumer SaaS dashboard. The visual system is dark, compact, technical, restrained, and information-dense.

## 2. Color tokens

Use these as the baseline unless a Studio-specific specification explicitly overrides them.

| Token | Value | Use |
|---|---|---|
| `oep.bg` | `#0B0F14` | application/background foundation |
| `oep.surface.1` | `#111720` | primary panels |
| `oep.surface.2` | `#151D27` | raised panels, inspectors |
| `oep.surface.3` | `#1B2531` | selected/hovered surfaces |
| `oep.border` | `#2A3542` | panel and control borders |
| `oep.border.strong` | `#394858` | active structural separators |
| `oep.text.primary` | `#E7EDF4` | primary text |
| `oep.text.secondary` | `#9AA8B7` | secondary text |
| `oep.text.muted` | `#667585` | tertiary text |
| `oep.accent` | `#2F81F7` | primary actions, focus, controls, borders — the interaction accent (see §2A: NOT the Studio Bar/workspace-tab identity color) |
| `oep.accent.hover` | `#4A94FF` | hover/focus refinement |
| `oep.success` | `#39B56B` | success/healthy |
| `oep.warning` | `#D9A441` | warning |
| `oep.error` | `#D95C5C` | error |
| `oep.info` | `#5DA9E9` | informational state |

Do not introduce gradients as a substitute for hierarchy.

## 2A. Studio identity tokens (per-Studio accent — AP-UX-002 C1)

**Design-owner decision (AP-UX-002):** OEP uses a **hybrid** accent model, not a single global accent and not an unrestricted per-Studio scheme.

- **Studio Bar tabs and Workspace Bar tabs** carry their parent Studio's identity color (below). This is the one region where a Studio's own color is authoritative.
- **Everywhere else** — toolbar/action-strip controls, buttons, borders, focus rings, links, form controls, and any other interaction chrome — uses the single `oep.accent` (§2) regardless of the active Studio. The Toolbar Action Matrix's own selected option (`toolbar 7 use option 3.png`, "Grouped Sections") is monochrome for exactly this reason and must not be reinterpreted as per-Studio-colored.
- **Semantic status colors** (`oep.success/warning/error/info`) never change meaning or hue based on the active Studio. A Studio identity color and a status color must never occupy the same visual role on the same control.

| Token | Value | Studio |
|---|---|---|
| `oep.studio.home` | `#9AA8B7` (neutral — same as `oep.text.secondary`) | Home (no identity color of its own) |
| `oep.studio.diagram` | `#2F81F7` (same as `oep.accent`) | Diagram Studio |
| `oep.studio.eam` | `#2FB584` | EAM |
| `oep.studio.knowledge` | `#D9A441` | Knowledge Studio |
| `oep.studio.exchange` | `#8A5CF6` | Engineering Exchange |
| `oep.studio.instruments` | `#D95C5C` | Instruments (see `OEP-UX-ARCHITECTURE.md` §2/AP-UX-002 C7 — the Studio Bar destination previously drafted as "Tools" in second-generation documents) |
| `oep.studio.settings` | `#667585` (same as `oep.text.muted`) | Settings |

Exact hex values above are this reconciliation's best-effort extraction from the approved `studio tab bar use option 3.png` render, not a re-run of that render's own source — if a pixel-exact value is later needed, sample it directly from that file rather than trusting this table blindly.

**Open, not decided by AP-UX-002:** whether Knowledge/Exchange/Instruments/Settings identity colors extend any further than Studio Bar + Workspace Bar tabs (e.g. to a Studio's own internal accents) is unresolved — no render or specification currently shows that, and this reconciliation does not invent it. Treat Studio-internal accents as `oep.accent` (single, global) until a specific Studio's own UX specification says otherwise.

## 3. Geometry

| Token | Value |
|---|---:|
| `oep.radius.none` | 0px |
| `oep.radius.sm` | 3px |
| `oep.radius.md` | 5px |
| `oep.radius.lg` | 7px |
| `oep.spacing.1` | 4px |
| `oep.spacing.2` | 8px |
| `oep.spacing.3` | 12px |
| `oep.spacing.4` | 16px |
| `oep.spacing.5` | 20px |
| `oep.spacing.6` | 24px |
| `oep.spacing.8` | 32px |
| `oep.control.height` | 32px |
| `oep.control.height.compact` | 28px |
| `oep.header.height` | 58px |
| `oep.studiobar.height` | 56px |
| `oep.workspace.height` | **42px** (AP-UX-002 C2 — was 36px; corrected to match `Start With this Exact Wireframe and its Pixel Measurments.png`, the design-owner-designated geometry authority) |
| `oep.toolbar.height` | **60px** (AP-UX-002 C2 — was 40px; corrected for the same reason) |
| `oep.statusbar.height` | 36px |

Rounded corners are structural, not decorative. Avoid pill-shaped controls except for genuine status chips.

## 4. Typography

Use the existing platform/system sans-serif family unless the implementation already has an approved OEP font. Do not introduce a new font solely for visual effect.

Baseline hierarchy:

- Application title: 18–20px, semibold
- Studio title: 14–16px, semibold
- Workspace/tab label: 12–13px, medium
- Body/UI: 12–13px
- Metadata/status: 10–11px
- Monospace engineering values/identifiers: 11–12px

The interface should feel compact at 1920×1080. Do not use oversized hero typography.

## 5. State rules

Active navigation in the Studio Bar/Workspace Bar uses that Studio's identity color (§2A) plus a restrained background/border treatment; every other active state uses `oep.accent`. Hover must not look identical to active. Disabled elements reduce contrast without becoming invisible.

Status colors communicate state only. Do not use status colors as decorative accents.

## 6. 1920×1080 baseline

All primary desktop renders and visual QA captures use **1920×1080, 16:9, full application window**. Layout specifications should use explicit pixel measurements at this baseline.

## 7. Prohibited visual drift

Do not introduce:

- purple/pink AI-style gradients
- glassmorphism
- oversized rounded cards
- giant empty hero areas
- browser-like chrome
- excessive shadows
- arbitrary new accent colors — the Studio identity set in §2A is closed; do not add a color for a new Studio or a new use without a further design-owner decision
- generic Material/Bootstrap dashboard styling
- excessive whitespace that hides engineering information
- decorative illustrations that compete with engineering content
