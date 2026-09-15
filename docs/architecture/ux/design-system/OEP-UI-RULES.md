# OEP UI Rules

**Status:** Proposed implementation baseline

## Rule 1 — Implement the system, not the screenshot

Screenshots communicate visual intent. This document and screen specifications define behavior and hierarchy. An implementation must satisfy both.

## Rule 2 — Studios are destinations

Global navigation exposes Studios and Home. Backend capabilities are not automatically destinations.

Normally contextual:
`Objects`, `Relationships`, `Graph`, `Validation`, `Evidence`, `Provenance`, `History`, `Packages`.

Repository and Search may remain independent destinations because users can intentionally browse them as persistent resources.

## Rule 3 — No invented navigation

If a render contains a control whose behavior is not defined by the corresponding specification, do not invent behavior. Flag it in the implementation report.

## Rule 4 — Preserve domain behavior

A visual WP must not rewrite Engine behavior, diagram data models, command stacks, persistence, bridge protocols, or domain semantics unless its specification explicitly authorizes that change.

## Rule 5 — Reuse the shell

Do not create a Studio-specific imitation of the OEP shell. Reuse existing shell components where present. If a reusable component is missing, report the gap before introducing a parallel implementation.

## Rule 6 — Explicit geometry beats approximation

At 1920×1080, primary regions must have measurable dimensions. A screen specification should state target heights/widths and relative behavior for resizable regions.

## Rule 7 — Visual density is intentional

OEP is an engineering workstation. Prefer clear compact controls, aligned panels, and useful information over oversized cards and decorative whitespace.

## Rule 8 — Selection drives context

Selected engineering entities should drive contextual inspection and tools. Do not make the user navigate away from the engineering surface simply to inspect an entity.

## Rule 9 — State must be visible

Active Studio, active workspace, selected entity, unsaved state, validation state, and relevant connection state must have clear visual treatment appropriate to their importance.

## Rule 10 — Accessibility remains structural

Do not encode meaning by color alone. Maintain readable contrast, keyboard/focus behavior, semantic labels, and sensible hit targets.

## Prohibited patterns

- generic SaaS dashboard templates
- browser-style tab bars
- arbitrary sidebar menus for every backend service
- purple/AI gradients
- glassmorphism
- excessive pill controls
- giant hero headers
- excessive nested cards
- placeholder icons/text left in production UI
- replacing a working engineering surface with a mockup
