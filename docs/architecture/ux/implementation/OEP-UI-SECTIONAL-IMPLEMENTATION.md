# OEP UI Sectional Implementation Workflow

**Status:** Proposed implementation-agent contract
**Purpose:** Prevent Claude from attempting to reproduce an entire 1920×1080 UI screen in one uncontrolled pass.

## 1. Principle

A full OEP screen is a composition of independently controllable visual regions.

UI implementation should therefore proceed **section-by-section**, while the complete 1920×1080 application remains running in the hot-reload window.

The reference render remains the source of overall composition. Individual sections are implemented and visually tuned independently, then verified together.

## 2. Standard Screen Decomposition

For an OEP desktop Studio screen, use this default decomposition unless the approved screen specification defines a different structure:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  SECTION 01 — APPLICATION / TOP PANEL                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│  SECTION 02 — GLOBAL STUDIO TAB BAR                                          │
├──────────────────────────────────────────────────────────────────────────────┤
│  SECTION 03 — WORKSPACE TAB BAR / CONTEXT BAR                                │
├───────────────┬──────────────────────────────────────────────┬───────────────┤
│               │                                              │               │
│ SECTION 04    │                                              │ SECTION 06    │
│ CONTEXT NAV   │ SECTION 05 — PRIMARY WORK SURFACE            │ INSPECTOR     │
│ / LEFT PANEL  │                                              │ / RIGHT PANEL │
│               │                                              │               │
├───────────────┴──────────────────────────────────────────────┴───────────────┤
│  SECTION 07 — TOOLBAR / ACTION STRIP (position may vary by Studio)           │
├──────────────────────────────────────────────────────────────────────────────┤
│  SECTION 08 — STATUS / BOTTOM ROW                                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

The exact arrangement is screen-specific. The important rule is that each visually meaningful region receives its own implementation pass and acceptance criteria.

## 3. Recommended Implementation Order

Use the following order for a new or substantially redesigned screen:

### Section 00 — Frame / Geometry Contract

Before styling any section, establish the immutable 1920×1080 reference frame and major region boundaries.

Record:

- application window size;
- top-level section heights;
- left/center/right widths;
- major margins;
- separators;
- bottom-row height;
- canvas/work-surface bounds.

Do not begin detailed icon, typography, or control work until the major geometry is stable.

### Section 01 — Application / Top Panel

Implement and visually tune the highest-level application chrome first.

Acceptance includes:

- height;
- OEP identity/branding;
- title placement;
- window-level controls if applicable;
- background/surface treatment;
- separators;
- alignment.

### Section 02 — Global Studio Tab Bar

Implement the Studio-level navigation independently.

Acceptance includes:

- tab height;
- tab spacing;
- active Studio state;
- inactive state;
- icon scale;
- labels;
- separators;
- overflow behavior.

Do not introduce browser-style tab behavior.

### Section 03 — Workspace Tab Bar / Context Bar

Implement open-workspace context independently from global Studio navigation.

Acceptance includes:

- workspace tab geometry;
- active workspace;
- close affordance where specified;
- contextual identity;
- state indicators;
- spacing.

### Section 04 — Context Navigation / Left Panel

Implement the Studio's contextual navigation or resource tree.

Acceptance includes:

- width;
- hierarchy indentation;
- selection state;
- section headers;
- icons;
- scrolling;
- separators.

### Section 05 — Primary Work Surface

Implement the central engineering surface presentation without replacing or redesigning the underlying engineering engine.

For Diagram Studio, this means preserving the real diagram renderer and engineering interactions while changing only the presentation/integration necessary to meet the approved design.

Acceptance includes:

- exact available bounds;
- toolbar relationship;
- canvas/background treatment;
- zoom/navigation controls where specified;
- clipping;
- overlays;
- engineering content density.

### Section 06 — Inspector / Right Panel

Implement contextual properties and engineering information presentation.

Acceptance includes:

- width;
- hierarchy;
- field spacing;
- headers;
- selection state;
- scrolling;
- divider treatment.

### Section 07 — Toolbar / Action Strip

Implement Studio-specific tools independently of the global shell.

The toolbar may be physically above, below, or inside the primary work surface depending on the approved screen specification.

Acceptance includes:

- control grouping;
- button size;
- icon scale;
- separators;
- active/disabled states;
- tooltip behavior where applicable.

### Section 08 — Status / Bottom Row

Implement the persistent bottom/status region independently.

Acceptance includes:

- height;
- status indicators;
- engineering state information;
- connection/runtime indicators where specified;
- alignment;
- separators.

## 4. One Section at a Time

Claude should not make large simultaneous visual changes across all sections unless the task specifically concerns global geometry.

For each section:

```text
SELECT ONE SECTION
      ↓
INSPECT EXISTING CODE
      ↓
MAP SECTION TO COMPONENTS
      ↓
IMPLEMENT SECTION
      ↓
HOT RELOAD
      ↓
OBSERVE LIVE WINDOW
      ↓
COMPARE SECTION TO REFERENCE
      ↓
CORRECT
      ↓
FREEZE SECTION
      ↓
MOVE TO NEXT SECTION
```

## 5. Freeze Completed Sections

Once a section meets its acceptance criteria, treat its geometry and visual tokens as frozen for the remainder of the WP unless a later section exposes a documented dependency.

A later section must not casually change a previously completed section.

If a geometry change is necessary, record the dependency and revalidate the affected sections.

## 6. Full-Screen Validation Still Required

Sectional implementation does **not** mean sectional-only validation.

After each section is tuned, inspect the entire 1920×1080 application window to ensure that the new section integrates correctly with the existing sections.

At the end of the WP, capture the complete application window and perform a final full-screen comparison.

## 7. Reference Materials

Each UI WP should provide, when available:

1. one complete 1920×1080 reference render;
2. the screen specification;
3. exact section measurements;
4. section-specific reference crops or annotated measurements when useful;
5. design tokens;
6. component mapping.

The full-screen render establishes composition. Measurements and section references establish implementation precision.

## 8. Section Acceptance Record

Claude should maintain a small record during implementation:

| Section | Geometry | Visual | Interaction | Integrated | Status |
|---|---|---|---|---|---|
| 00 Frame | ✓/✗ | ✓/✗ | N/A | ✓/✗ | |
| 01 Top Panel | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 02 Studio Tabs | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 03 Workspace Tabs | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 04 Context Nav | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 05 Work Surface | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 06 Inspector | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 07 Toolbar | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |
| 08 Bottom Row | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | |

## 9. Scope Rule

Sectional implementation is a delivery technique, not permission to change architecture.

The same OEP boundaries remain in force:

- Engine owns engineering behavior and engineering data.
- Studio owns workspace composition and presentation.
- Shared shell owns global application chrome.
- Legacy V2 is reference/embedded content where applicable.

If a section cannot be implemented without crossing these boundaries, stop and report the architectural conflict.
