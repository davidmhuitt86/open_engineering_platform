# OEP UX Architecture

This directory is the current design/specification home for the OEP application shell and contextual workspace UX.

## Authority

For new UX work, use these documents first:

```text
docs/architecture/ux/
├── OEP-UX-ARCHITECTURE.md
├── README.md
└── EAM/
    └── EAM-ACQUISITION-WORKSPACE-SPEC.md
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

## Next Design Work

Before production UI implementation, the EAM redesign should receive a detailed interaction/state specification covering stage transitions, workspace opening/closing, contextual views, errors, retries, navigation, and completion behavior.
