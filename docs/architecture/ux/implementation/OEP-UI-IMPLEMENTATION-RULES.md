# OEP UI Implementation Rules

**Status:** Proposed implementation-agent contract  
**Audience:** Claude Code and other implementation agents

## 1. Required reading order

Before changing UI code, read:

1. `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`
2. `docs/architecture/ux/design-system/OEP-DESIGN-TOKENS.md`
3. `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md`
4. `docs/architecture/ux/design-system/OEP-UI-RULES.md`
5. `docs/architecture/ux/implementation/OEP-UI-SECTIONAL-IMPLEMENTATION.md`
6. the Studio-specific screen specification
7. existing Studio integration/behavior documents

## 2. Inspect before editing

The first implementation pass must identify:

- current shell components;
- current Studio route/registry;
- current workspace composition;
- existing reusable controls;
- existing theme/token definitions;
- embedded web/native boundaries;
- Engine-facing APIs that must remain unchanged.

Produce a short design-to-code map before substantial refactoring.

## 3. Design-to-code map

Use this structure:

| Reference element | Target component/file | Existing or new | Behavior owner | Change type |
|---|---|---|---|---|
| Global Studio Bar | ... | ... | Studio host | visual/layout |
| Workspace Bar | ... | ... | Studio host | visual/layout |
| Context Nav | ... | ... | Studio | navigation |
| Main Surface | ... | ... | Engine/Studio | preserve |
| Inspector | ... | ... | Studio | visual/layout |

If an element has no obvious implementation owner, stop and report the ambiguity rather than guessing.

## 4. Sectional implementation

Do not attempt to reproduce an entire 1920×1080 screen in one uncontrolled visual pass.

Break the screen into independently implemented visual sections using `OEP-UI-SECTIONAL-IMPLEMENTATION.md`.

The default sequence is:

```text
00  Frame / Geometry Contract
01  Application / Top Panel
02  Global Studio Tab Bar
03  Workspace Tab Bar / Context Bar
04  Context Navigation / Left Panel
05  Primary Work Surface
06  Inspector / Right Panel
07  Toolbar / Action Strip
08  Status / Bottom Row
```

The exact physical arrangement may differ by Studio, but each meaningful region should be handled as a discrete implementation pass.

### Rules for each section

1. Select one section.
2. Inspect its existing implementation.
3. Produce the section's design-to-code mapping.
4. Implement only that section and its necessary integration points.
5. Hot reload the running Windows application.
6. Inspect the live application.
7. Compare the section against the approved reference.
8. Correct visual differences.
9. Verify that previously completed sections remain intact.
10. Freeze the section before moving to the next section.

Do not make broad simultaneous visual changes across multiple sections unless the change is explicitly a shared geometry/token change.

## 5. Section freeze rule

Once a section meets its acceptance criteria, treat its geometry, spacing, and visual treatment as frozen for the remainder of the WP.

If a later section exposes a genuine dependency requiring a change to a frozen section:

- document the dependency;
- make the minimum necessary change;
- revalidate the affected section;
- continue only after the affected section is again acceptable.

## 6. Implementation sequence

### Phase A — Inventory
Inspect current code and identify reuse.

### Phase B — Frame
Establish the 1920×1080 frame and major region boundaries before detailed styling.

### Phase C — Sectional implementation
Implement and freeze each visual region independently.

### Phase D — Visual QA
Run the actual application at 1920×1080, capture a screenshot, compare to the reference, enumerate differences, fix them, and capture again.

### Phase E — Regression
Run the existing Studio tests/build and verify existing engineering interactions still work.

## 7. Live application requirement

During UI work, the Windows Flutter application must remain open with hot reload active whenever the local development environment permits it.

Claude must use the live application as continuous visual feedback while implementing each section.

The workflow is:

```text
EDIT
 ↓
HOT RELOAD
 ↓
OBSERVE LIVE WINDOW
 ↓
COMPARE
 ↓
CORRECT
 ↓
HOT RELOAD
```

Do not judge UI solely from source code or build output.

## 8. Visual QA acceptance

Do not claim visual completion because the app builds. Completion requires a rendered screen check.

Compare, at minimum:

- overall silhouette;
- header/studio/workspace heights;
- left/center/right region widths;
- alignment and spacing;
- typography scale;
- background/surface/border values;
- active/hover/disabled states;
- icon scale and placement;
- visible information density;
- clipping/overflow;
- interaction controls visible in the reference.

Fix P0/P1 differences before declaring completion. P2 differences must be documented.

Section-level checks do not replace final full-screen validation.

## 9. Scope discipline

A visual WP may refactor presentation code when necessary. It must not silently alter domain semantics, persistence, Engine contracts, command behavior, or data models.

If the desired visual architecture conflicts with an existing boundary, stop and report the conflict as an architectural finding.

## 10. Required completion report

Every UI WP report must state:

- baseline commit;
- final commit;
- files changed;
- design-to-code map summary;
- section acceptance record;
- build/test commands and results;
- application run result;
- screenshot path(s);
- visual QA differences found and fixed;
- known remaining differences;
- explicit statement that no unauthorized Engine/domain changes were made.
