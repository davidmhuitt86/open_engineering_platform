# OEP UI Implementation Rules

**Status:** Proposed implementation-agent contract
**Audience:** Claude Code and other implementation agents

## 1. Required reading order

Before changing UI code, read:

1. `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`
2. `docs/architecture/ux/design-system/OEP-DESIGN-TOKENS.md`
3. `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md`
4. `docs/architecture/ux/design-system/OEP-UI-RULES.md`
5. the Studio-specific screen specification
6. existing Studio integration/behavior documents

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

## 4. Implementation sequence

### Phase A — Inventory
Inspect current code and identify reuse.

### Phase B — Shell integration
Connect the Studio to the approved OEP shell without changing domain behavior.

### Phase C — Surface layout
Match the specified geometry, panel proportions, typography, borders, spacing, and states.

### Phase D — Visual QA
Run the actual application at 1920×1080, capture a screenshot, compare to the reference, enumerate differences, fix them, and capture again.

### Phase E — Regression
Run the existing Studio tests/build and verify existing engineering interactions still work.

## 5. Visual QA acceptance

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

## 6. Scope discipline

A visual WP may refactor presentation code when necessary. It must not silently alter domain semantics, persistence, Engine contracts, command behavior, or data models.

If the desired visual architecture conflicts with an existing boundary, stop and report the conflict as an architectural finding.

## 7. Required completion report

Every UI WP report must state:

- baseline commit;
- final commit;
- files changed;
- design-to-code map summary;
- build/test commands and results;
- application run result;
- screenshot path(s);
- visual QA differences found and fixed;
- known remaining differences;
- explicit statement that no unauthorized Engine/domain changes were made.
