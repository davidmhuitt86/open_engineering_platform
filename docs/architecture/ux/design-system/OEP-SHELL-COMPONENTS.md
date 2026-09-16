# OEP Shell Components

**Status:** Proposed implementation baseline
**Purpose:** Define the reusable desktop shell that Studios must consume instead of independently inventing navigation chrome.
**Reconciled by:** AP-UX-002 — §1's anatomy below was corrected to resolve AP-UX-001's C2 finding (the original anatomy nested the Toolbar inside the middle column; the design-owner-designated pixel wireframe places it as a full-width row instead). See `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md` §7 for the evidence.

## 1. Shell anatomy

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ 01 Application Header                                            58px        │
├──────────────────────────────────────────────────────────────────────────────┤
│ 02 Global Studio Bar                                              56px        │
├──────────────────────────────────────────────────────────────────────────────┤
│ 03 Workspace / Context Bar                                        42px        │
├───────────────┬───────────────────────────────────────────────┬──────────────┤
│ 04 Context    │ 05 Primary Engineering Surface                │ 06 Inspector │
│    Nav        │                                                │              │
│    240px      │                    ~1040px                    │    640px     │
│  (variable)   │                    (variable)                  │  (variable)  │
├───────────────┴───────────────────────────────────────────────┴──────────────┤
│ 07 Toolbar / Action Strip                                          60px       │
├──────────────────────────────────────────────────────────────────────────────┤
│ 08 Status / Context Bar                                            36px       │
└──────────────────────────────────────────────────────────────────────────────┘
```

Region numbering (01–08) matches `.claude/skills/oep-ui/SKILL.md`'s standard section sequence and `SECTION-8-STATUS-BAR-SPEC.md`'s own numbering — implement and freeze one region at a time in this order. Pixel values are the 1920×1080 baseline (§6 of `OEP-DESIGN-TOKENS.md`); side-region widths are variable/resizable, everything else is fixed.

**The Toolbar is a full-width row below the Context-Nav/Surface/Inspector split, not nested inside the middle column.** This is a deliberate correction (AP-UX-002 C2) to the anatomy this document originally showed — the physical position of a Studio-specific toolbar may still vary per `.claude/skills/oep-ui/SKILL.md`, but the *default*/reference position is this full-width row.

The exact presence of each region is Studio-specific. The hierarchy is not.

## 2. Application Header

Purpose: identify OEP and provide application-level controls.

Rules:
- visually quiet;
- never consume the majority of vertical space;
- no Studio-specific navigation embedded here;
- no browser address-bar metaphor.

## 3. Global Studio Bar

Purpose: switch between meaningful OEP destinations.

Studios are first-class destinations. The bar may include Home, Diagram Studio, EAM, Knowledge Studio, Engineering Exchange, Engineering Intelligence, Instruments, Settings, and other ratified Studios.

Rules:
- native application tabs, not browser tabs;
- active Studio is obvious, using that Studio's identity color (`OEP-DESIGN-TOKENS.md` §2A, AP-UX-002 C1);
- inactive Studios remain available;
- no backend capability names such as Objects or Relationships as global tabs;
- no duplicate Studio-specific navigation in the global bar.

## 4. Workspace Bar

Purpose: identify open work inside the active Studio.

Examples include an open wiring artifact, acquisition workspace, project, or reference document.

Rules:
- workspace tabs represent OEP work contexts;
- workspace tabs inherit their parent Studio's identity color (`OEP-DESIGN-TOKENS.md` §2A, AP-UX-002 C1);
- closing a workspace must not imply closing the Studio;
- workspace labels should identify the engineering subject, not an internal class name;
- `+` creates/opens another workspace when the Studio supports it.

## 5. Context Navigation

Purpose: expose views and workflow stages that make sense for the current workspace.

Examples:
- Overview
- Document
- Objects
- Relationships
- Graph
- Validation
- Evidence
- History

A contextual item must derive its meaning from the current workspace. Do not promote it to global navigation merely because it has a route or backend service.

## 6. Toolbar

Purpose: expose actions applicable to the current selection/workspace.

Rules:
- action density is preferred over decorative spacing;
- destructive actions require clear separation/confirmation semantics;
- selection-dependent actions should disable rather than disappear when discoverability matters;
- toolbar must not become a second navigation bar;
- toolbar controls use the single global `oep.accent` (`OEP-DESIGN-TOKENS.md` §2A), never a per-Studio identity color — confirmed by the approved "Grouped Sections" toolbar option (AP-UX-002 C1).

## 7. Main Engineering Surface

The main surface belongs to the owning Studio. It may be a diagram canvas, document viewer, acquisition workflow, editor, table, or other engineering surface.

The shell must not dictate the internal rendering implementation.

## 8. Inspector

Purpose: inspect the selected engineering entity or current context.

Rules:
- contextual;
- compact;
- structured fields rather than card-heavy presentation;
- should not duplicate the entire object browser;
- selection changes should update the inspector without changing global navigation.

## 9. Status / Context Bar

Use for concise state such as save status, connection state, validation state, cursor coordinates, or active mode. Do not turn it into a dashboard.

## 10. Component ownership

The OEP Studio host owns shell composition. The owning Studio owns the contents of its workspace and contextual tools. Engine remains authoritative for engineering model, graph/layout/commands/validation/search/editing/navigation/rendering where established by the architecture.
