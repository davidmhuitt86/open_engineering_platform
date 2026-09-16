# OEP UX Architecture

This directory is the current design/specification home for the OEP application shell and contextual workspace UX.

## Authority

For new UX work, use these documents first:

```text
docs/architecture/ux/
├── OEP-UX-ARCHITECTURE.md
├── README.md
├── design-system/
│   ├── OEP-DESIGN-TOKENS.md
│   ├── OEP-SHELL-COMPONENTS.md
│   └── OEP-UI-RULES.md
├── implementation/
│   ├── OEP-UI-IMPLEMENTATION-RULES.md
│   ├── OEP-VISUAL-QA-PROTOCOL.md
│   ├── OEP-SCREEN-IMPLEMENTATION-TEMPLATE.md
│   └── DS-GOLDEN-WORKSPACE-SPEC.md
└── EAM/
    ├── EAM-ACQUISITION-WORKSPACE-SPEC.md
    └── EAM-INTERACTION-STATE-SPEC.md
```

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

The repository also contains the reusable Claude Code skill at `.claude/skills/oep-ui/SKILL.md`.

## Existing Documentation Reconciliation

Older Studio documents are not being mass-deleted. They contain useful implementation history and, in several cases, valid behavioral architecture.

Current reconciliation policy:

| Existing document | Treatment |
|---|---|
| `platform/oep_studio/docs/OEP_INTERACTION_MODEL.md` | Retain. Behavioral interaction findings remain useful. Navigation assumptions must be reconciled against the new OEP UX architecture before new UX work. |
| `platform/oep_studio/docs/OEP_SURFACE_ARCHITECTURE.md` | Retain as historical/derived architecture. Its existing Surface/Tab findings remain useful; new global navigation should follow this UX architecture. |
| `platform/oep_studio/docs/DASHBOARD.md` | Superseded for the global OEP landing model. The old Dashboard-as-landing-page concept is replaced by Home; Studio-specific dashboards may still exist when justified by workflow. |
| `platform/oep_studio/docs/DESIGN_LANGUAGE.md` | Retain pending design-system reconciliation. It should not be treated as a complete replacement for the new visual baseline. |
| Diagram Studio-specific audits/specs | Retain. These document domain behavior and implementation constraints; they are not automatically superseded by the OEP shell redesign. |

## Important Rule

Do not delete or rewrite historical design documents merely because a newer UX direction exists. First determine whether a document contains behavioral/architectural facts that remain valid. Mark only the conflicting portion or document as superseded, and link it to this directory where practical.

## Current Design Work

EAM now has both an acquisition workspace specification and an interaction/state specification. Diagram Studio has a golden-workspace specification for validating the OEP shell against a real engineering surface. The next implementation step is a focused Diagram Studio visual WP using the UI implementation kit and the approved 1920×1080 reference render.
