# OEP UI Implementation Skill

Use this skill for all OEP desktop UI work driven by a design render or UX specification.

## Mandatory context

Read the applicable documents under `docs/architecture/ux/` before editing UI code. The OEP UX architecture defines navigation hierarchy; design tokens define the visual baseline; shell components define reusable chrome; the screen specification defines screen-specific behavior and geometry; `OEP-UI-SECTIONAL-IMPLEMENTATION.md` defines the required section-by-section implementation method.

## Agent behavior

1. Inspect the current implementation before changing it.
2. Identify reusable OEP shell components before creating new ones.
3. Produce a design-to-code map for the requested screen.
4. Decompose the screen into meaningful visual sections.
5. Establish the 1920×1080 frame and major geometry before detailed styling.
6. Implement one section at a time.
7. Keep the Windows Flutter application open with hot reload active during UI iteration.
8. After each section change, hot reload and inspect the live application.
9. Freeze each accepted section before moving to the next.
10. Preserve Engine/domain behavior unless explicitly authorized otherwise.
11. Build and run the actual Windows application.
12. Capture the actual screen at 1920×1080.
13. Compare against the approved reference.
14. Fix P0/P1 visual differences.
15. Report remaining P2 differences.

## Standard section sequence

Unless the screen specification defines a different structure, use:

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

The physical position of a toolbar or other Studio-specific region may vary. The principle is that each meaningful visual region is implemented and tuned as a discrete pass.

## Section iteration loop

```text
SELECT ONE SECTION
      ↓
INSPECT CODE
      ↓
MAP TO COMPONENTS
      ↓
IMPLEMENT
      ↓
HOT RELOAD
      ↓
OBSERVE LIVE OEP WINDOW
      ↓
COMPARE TO REFERENCE
      ↓
CORRECT
      ↓
FREEZE SECTION
      ↓
NEXT SECTION
```

Do not make broad simultaneous visual changes across multiple sections unless the change is explicitly a shared geometry or design-token change.

## Hard constraints

- Windows desktop.
- 1920×1080, 16:9 for primary visual validation.
- Full application window in screenshots.
- Studios are global destinations.
- Objects, Relationships, Graph, Validation, Evidence, Provenance, History, and Packages are normally contextual capabilities.
- Do not introduce browser-style navigation or generic SaaS dashboard patterns.
- Do not replace a real engineering surface with a static mockup.
- Do not silently change Engine contracts or domain semantics.
- Do not casually modify a section that has already been frozen and accepted.

## Escalation rule

If a render appears to require behavior that is not present in the specification, if a section has no clear implementation owner, or if reproducing it requires crossing an Engine/Studio architectural boundary, stop and report the conflict. Do not solve the ambiguity by inventing architecture.

## Completion evidence

A UI task is incomplete without:

- build/test result;
- actual application run;
- section acceptance record;
- final 1920×1080 screenshot;
- full-screen visual difference report;
- list of files changed;
- explicit scope/boundary statement.
