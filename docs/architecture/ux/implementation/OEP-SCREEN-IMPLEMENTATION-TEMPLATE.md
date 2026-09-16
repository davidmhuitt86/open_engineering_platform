# OEP Screen Implementation Template

Copy this template for each screen that will be implemented from a design render.

## Screen identity

- Studio:
- Screen ID:
- Reference render:
- Target platform: Windows desktop
- Target capture: 1920×1080, 16:9

## Purpose

Describe what engineering task this screen supports.

## Navigation hierarchy

```text
OEP → Studio → Workspace → Contextual View
```

## Region map

| Region | Purpose | Target geometry | Owner | Notes |
|---|---|---|---|---|
| Application Header | | | Studio host | |
| Global Studio Bar | | | Studio host | |
| Workspace Bar | | | Studio host | |
| Context Navigation | | | Studio | |
| Toolbar | | | Studio | |
| Main Surface | | | Studio/Engine | |
| Inspector | | | Studio | |
| Status Bar | | | Studio | |

## Component map

| Reference element | Existing component | New component needed | Implementation file | Behavior owner |
|---|---|---|---|---|
| | | | | |

## Visual tokens

List only deviations from `OEP-DESIGN-TOKENS.md`. If there are no deviations, state `None`.

## States

Define visible states required by the screen:

- active Studio:
- active workspace:
- selected entity:
- unsaved:
- validation:
- error:
- loading/empty:

## Interaction contract

List the interactions visible in the render and identify their existing implementation owner. Do not infer new domain behavior from visual appearance alone.

## Scope boundary

Explicitly state what this screen change does not modify.

## Visual QA

- [ ] application runs at 1920×1080
- [ ] full-window screenshot captured
- [ ] structural P0 comparison complete
- [ ] visual-system P1 comparison complete
- [ ] polish P2 comparison complete
- [ ] final screenshot saved
- [ ] remaining deviations documented
