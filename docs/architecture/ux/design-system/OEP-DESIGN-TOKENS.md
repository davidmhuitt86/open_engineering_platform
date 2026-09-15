# OEP Design Tokens

**Status:** Proposed implementation baseline
**Scope:** OEP desktop application visual language
**Purpose:** Give implementation agents explicit, measurable visual constants rather than asking them to infer style from screenshots.

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
| `oep.accent` | `#2F81F7` | active Studio, primary actions, focus |
| `oep.accent.hover` | `#4A94FF` | hover/focus refinement |
| `oep.success` | `#39B56B` | success/healthy |
| `oep.warning` | `#D9A441` | warning |
| `oep.error` | `#D95C5C` | error |
| `oep.info` | `#5DA9E9` | informational state |

Do not introduce gradients as a substitute for hierarchy.

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
| `oep.toolbar.height` | 40px |
| `oep.workspace.height` | 36px |

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

Active navigation uses accent blue plus a restrained background/border treatment. Hover must not look identical to active. Disabled elements reduce contrast without becoming invisible.

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
- arbitrary new accent colors
- generic Material/Bootstrap dashboard styling
- excessive whitespace that hides engineering information
- decorative illustrations that compete with engineering content
