# OEP UI Implementation Skill

Use this skill for all OEP desktop UI work driven by a design render or UX specification.

## Mandatory context

Read the applicable documents under `docs/architecture/ux/` before editing UI code. The OEP UX architecture defines navigation hierarchy; design tokens define the visual baseline; shell components define reusable chrome; the screen specification defines screen-specific behavior and geometry.

## Agent behavior

1. Inspect the current implementation before changing it.
2. Identify reusable OEP shell components before creating new ones.
3. Produce a design-to-code map for the requested screen.
4. Separate shell changes, Studio changes, and engineering-surface changes.
5. Preserve Engine/domain behavior unless explicitly authorized otherwise.
6. Implement the smallest coherent visual slice.
7. Build and run the actual Windows application.
8. Capture the actual screen at 1920×1080.
9. Compare against the approved reference.
10. Fix P0/P1 visual differences.
11. Report remaining P2 differences.

## Hard constraints

- Windows desktop.
- 1920×1080, 16:9 for primary visual validation.
- Full application window in screenshots.
- Studios are global destinations.
- Objects, Relationships, Graph, Validation, Evidence, Provenance, History, and Packages are normally contextual capabilities.
- Do not introduce browser-style navigation or generic SaaS dashboard patterns.
- Do not replace a real engineering surface with a static mockup.
- Do not silently change Engine contracts or domain semantics.

## Escalation rule

If a render appears to require behavior that is not present in the specification, or if reproducing it requires crossing an Engine/Studio architectural boundary, stop and report the conflict. Do not solve the ambiguity by inventing architecture.

## Completion evidence

A UI task is incomplete without:

- build/test result;
- actual application run;
- final 1920×1080 screenshot;
- visual difference report;
- list of files changed;
- explicit scope/boundary statement.
