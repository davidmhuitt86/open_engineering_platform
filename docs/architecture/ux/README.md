# OEP UX Architecture

This directory is the current design/specification home for the OEP application shell and contextual workspace UX.

**Reconciliation status (AP-UX-002):** two generations of this design work previously coexisted with unresolved contradictions on accent color and shell geometry. Those are now resolved — see `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md` for the full evidence and design-owner decisions. This index reflects the reconciled state.

## Authority

For new UX work, read in this order:

```text
docs/architecture/ux/
├── AP-UX-001-UX-DESIGN-RECOVERY.md              -- audit record: what existed, what conflicted (historical input to AP-UX-002)
├── AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md    -- CANONICAL: resolved contradictions, current design-owner decisions
├── OEP-UX-ARCHITECTURE.md                        -- CANONICAL: navigation hierarchy, interaction grammar, destination/capability rule
├── README.md                                     -- this file
├── design-system/
│   ├── OEP-DESIGN-TOKENS.md                      -- CANONICAL: color (incl. per-Studio accent, §2A), geometry, typography
│   ├── OEP-SHELL-COMPONENTS.md                   -- CANONICAL: shell anatomy, region ownership
│   └── OEP-UI-RULES.md                           -- CANONICAL: 10 implementation rules + prohibited patterns
├── implementation/
│   ├── OEP-UI-IMPLEMENTATION-RULES.md            -- implementation-agent contract
│   ├── OEP-UI-SECTIONAL-IMPLEMENTATION.md        -- required section-by-section implementation method
│   ├── OEP-VISUAL-QA-PROTOCOL.md                 -- P0/P1/P2 visual-diff protocol
│   ├── OEP-SCREEN-IMPLEMENTATION-TEMPLATE.md     -- blank per-screen template
│   ├── DS-GOLDEN-WORKSPACE-SPEC.md               -- CANONICAL: Diagram Studio golden-screen target (DS-WORKSPACE-A)
│   └── WP-UI-DS-001-PROMPT.md                    -- ready-to-execute Diagram Studio integration WP; re-verify its "Read first"
│                                                     list against this reconciled index before executing (it predates AP-UX-002)
├── eam/
│   ├── EAM-ACQUISITION-WORKSPACE-SPEC.md         -- CANONICAL EAM acquisition-workspace spec
│   ├── EAM-INTERACTION-STATE-SPEC.md             -- CANONICAL EAM interaction/state spec
│   ├── EAM_ACQUISITION_WORKFLOW_SPEC.md          -- supplementary, additive workflow detail
│   ├── EAM_INFORMATION_ARCHITECTURE.md           -- supplementary, additive information-architecture detail
│   ├── EAM_POST_ACQUISITION_UX_FLOW.md           -- supplementary, additive post-acquisition detail
│   ├── EAM_WORKSPACE_SCREEN_SPEC.md              -- supplementary, additive screen-level detail
│   ├── 02_EAM_ACQUISITION_WORKSPACE_SPEC.md      -- RETAINED FOR HISTORICAL/MIGRATION REFERENCE (see its own notice)
│   └── EAM_INTERACTION_STATE_SPEC.md             -- RETAINED FOR HISTORICAL/MIGRATION REFERENCE (see its own notice)
├── OEP_UX_RENDER_REFERENCE_INDEX.md              -- CANONICAL render index (which renders are current/historical/experimental)
└── renders/                                       -- see the render index above for per-file status
```

Also present, and consistent with (not competing against) the documents above: `01_OEP_SHELL_UX_DESIGN_SPEC.md`, `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`, `OEP_CONTEXTUAL_CAPABILITY_SPEC.md`, `OEP_HOME_UX_SPEC.md`, `OEP_STUDIO_TAB_WORKSPACE_SPEC.md`, `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`, `SECTION-8-STATUS-BAR-SPEC.md` — these add concrete, worked detail beneath `OEP-UX-ARCHITECTURE.md`'s more abstract rules and are not superseded by it (see `AP-UX-001-UX-DESIGN-RECOVERY.md` §4/§16 for why they were found consistent rather than merged).

The architecture defines navigation hierarchy and interaction intent. Design renders are visual references and must not silently define behavior.

## Navigation Model

```text
OEP
  ↓
Studio
  ↓
Open Workspace
  ↓
Contextual Views / Capabilities
  ↓
Engineering Objects / Operations
```

Global navigation should contain meaningful destinations. Objects, Relationships, Graph, Validation, Evidence, Provenance, History, and Packages should normally be exposed contextually when the current work makes their meaning clear.

## UI Implementation Kit

The `design-system/` and `implementation/` documents translate the visual direction into an implementation contract. They are intended to solve the recurring problem of a render being interpreted as a loose design suggestion rather than a measurable target.

Implementation agents should:

1. read the UX architecture and UI kit;
2. inspect the existing implementation;
3. produce a design-to-code map;
4. implement the smallest coherent visual slice;
5. run the real Windows application at 1920×1080;
6. capture and compare the rendered screen;
7. fix P0/P1 differences before declaring completion.

The repository also contains the reusable Claude Code skill at `.claude/skills/oep-ui/SKILL.md` — confirmed sufficient as written by `AP-UX-001-UX-DESIGN-RECOVERY.md` §19; no competing skill exists or is needed.

## Existing Documentation Reconciliation

Older Studio documents are not being mass-deleted. They contain useful implementation history and, in several cases, valid behavioral architecture.

Current reconciliation policy:

| Existing document | Treatment |
|---|---|
| `platform/oep_studio/docs/OEP_INTERACTION_MODEL.md` | Retain. Behavioral interaction findings remain useful. Navigation assumptions must be reconciled against the new OEP UX architecture before new UX work. |
| `platform/oep_studio/docs/OEP_SURFACE_ARCHITECTURE.md` | Retain as historical/derived architecture. Its existing Surface/Tab findings remain useful; new global navigation should follow this UX architecture. |
| `platform/oep_studio/docs/DASHBOARD.md` | Superseded for the global OEP landing model (confirmed still applied). The old Dashboard-as-landing-page concept is replaced by Home; Studio-specific dashboards may still exist when justified by workflow. |
| `platform/oep_studio/docs/DESIGN_LANGUAGE.md` | Retain pending design-system reconciliation. It should not be treated as a complete replacement for the new visual baseline. |
| Diagram Studio-specific audits/specs | Retain. These document domain behavior and implementation constraints; they are not automatically superseded by the OEP shell redesign. |

## Important Rule

Do not delete or rewrite historical design documents merely because a newer UX direction exists. First determine whether a document contains behavioral/architectural facts that remain valid. Mark only the conflicting portion or document as superseded, and link it to this directory where practical.

## Current Design Work

EAM now has one canonical acquisition-workspace specification and one canonical interaction/state specification (AP-UX-002 C4), plus four supplementary detail documents. Diagram Studio has a golden-workspace specification for validating the OEP shell against a real engineering surface, but still lacks a dedicated shell-integration render (AP-UX-001 §9, AP-UX-002 §14 — a defined but not-yet-produced requirement).

`WP-UI-DS-001-PROMPT.md` is a complete, ready-to-execute Diagram Studio implementation prompt, but it predates AP-UX-002's reconciliation and should have its "Read first" list re-verified against this index before it is executed.
