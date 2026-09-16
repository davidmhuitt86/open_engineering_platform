# OEP Visual QA Protocol

**Status:** Proposed implementation-agent contract

## Objective

Visual QA verifies that the real application reproduces the approved design intent. It is not a substitute for functional testing.

## Required capture

- Windows desktop application
- full application window
- 1920×1080
- 16:9
- actual implemented Studio, not a static HTML mockup
- representative populated engineering content when the reference shows content

## Compare in this order

### P0 — Structural
- wrong application/studio shell
- wrong navigation hierarchy
- missing primary workspace
- major region dimensions wrong
- content clipped or unusable

### P1 — Visual system
- wrong background/surface hierarchy
- wrong active state
- wrong typography scale
- wrong panel spacing
- wrong border treatment
- incorrect toolbar/workspace proportions
- major icon/control placement differences

### P2 — Polish
- minor alignment
- small spacing deviations
- icon glyph differences
- subtle radius or divider differences

## Iteration loop

```text
REFERENCE
   ↓
IMPLEMENT
   ↓
BUILD / RUN
   ↓
CAPTURE 1920×1080
   ↓
COMPARE
   ↓
LIST P0/P1/P2 DIFFERENCES
   ↓
FIX P0/P1
   ↓
CAPTURE AGAIN
   ↓
ACCEPT / DOCUMENT P2
```

Never stop at the first successful build.

## Comparison discipline

Use the reference render as a spatial target. Do not redesign elements because a different arrangement is personally preferred. If an element is technically impossible or conflicts with an existing architectural constraint, document the conflict instead of silently substituting a different UI.

## Screenshot naming

Use:

`<STUDIO>-<SCREEN>-<ITERATION>-1920x1080.png`

Example:

`DS-WORKSPACE-A-02-1920x1080.png`

## Acceptance statement

A UI WP is visually accepted only when the final report includes the final 1920×1080 capture and a concise list of remaining deviations, if any.
