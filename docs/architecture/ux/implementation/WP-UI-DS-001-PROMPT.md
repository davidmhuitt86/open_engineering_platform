# WP-UI-DS-001 — Diagram Studio OEP Shell Integration

**Baseline:** current `origin/main`
**Target:** Windows desktop, 1920×1080, 16:9
**Status:** Ready for implementation by Claude Code

## Mission

Bring the existing Diagram Studio presentation into alignment with the OEP application shell and visual system defined in `docs/architecture/ux/`, using the `DS-WORKSPACE-A` specification as the implementation target.

This is a **presentation/integration WP**, not an Engine redesign.

## Read first

1. `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`
2. `docs/architecture/ux/design-system/OEP-DESIGN-TOKENS.md`
3. `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md`
4. `docs/architecture/ux/design-system/OEP-UI-RULES.md`
5. `docs/architecture/ux/implementation/OEP-UI-IMPLEMENTATION-RULES.md`
6. `docs/architecture/ux/implementation/OEP-VISUAL-QA-PROTOCOL.md`
7. `docs/architecture/ux/implementation/DS-GOLDEN-WORKSPACE-SPEC.md`
8. existing Diagram Studio integration and architecture documents under `platform/oep_studio/docs/`

## Step 1 — Inspect; do not edit yet

Determine:

- how the current OEP shell is composed;
- how Diagram Studio is registered/routed;
- how its workspace is composed;
- where the current diagram surface is hosted;
- which existing shell/theme components can be reused;
- which UI regions already exist;
- which parts are Legacy V2/embedded web content;
- which Engine-facing APIs and bridges must remain untouched.

Produce a design-to-code map using:

| Reference element | Existing implementation | Target file/component | Owner | Change |
|---|---|---|---|---|
| Application Header | | | Studio host | |
| Global Studio Bar | | | Studio host | |
| Workspace Bar | | | Studio host | |
| Context Navigation | | | Diagram Studio | |
| Toolbar | | | Diagram Studio | |
| Diagram Surface | | | Engine/Studio/V2 | preserve |
| Inspector | | | Diagram Studio | |
| Status Bar | | | Studio | |

If this inspection reveals an architectural conflict, STOP and report it before modifying code.

## Step 2 — Implement

Implement only the changes necessary to make Diagram Studio conform to the OEP shell and golden workspace specification.

Priority order:

1. correct shell hierarchy;
2. correct Studio/workspace/context navigation;
3. correct region geometry;
4. OEP visual tokens;
5. toolbar/inspector presentation;
6. selected/active/status states;
7. spacing/alignment/polish.

Reuse existing components whenever possible.

## Hard prohibitions

Do NOT:

- redesign or rewrite OEP Engine;
- change the diagram data model;
- change command/undo semantics;
- change persistence;
- change bridge protocols;
- replace the real diagram renderer with a mockup;
- invent new engineering semantics;
- add Objects/Relationships/Graph/Validation as global Studio destinations;
- create browser-like tab chrome;
- introduce generic SaaS dashboard styling;
- introduce purple/AI gradients or glassmorphism;
- modify ADRs or unrelated architecture documents.

## Step 3 — Build and run

Build the actual Windows application using the repository's existing documented build path.

Run the real application. Do not validate against a static mockup.

Capture the complete application window at **1920×1080**.

## Step 4 — Visual QA

Compare the capture against the approved `DS-WORKSPACE-A` reference and the golden workspace specification.

Classify differences:

- P0 = structural/navigation/usability failure
- P1 = major visual mismatch
- P2 = polish/minor mismatch

Fix all P0/P1 issues and recapture.

## Step 5 — Completion report

Report:

- baseline SHA;
- final SHA;
- files changed;
- design-to-code map;
- build command/result;
- test command/result;
- application launch result;
- final screenshot path;
- P0/P1 differences fixed;
- remaining P2 differences;
- confirmation that Engine/domain behavior was not changed.

Commit exactly this WP as one focused commit and push it to `origin/main`.

Do not begin another UI WP after this one.
