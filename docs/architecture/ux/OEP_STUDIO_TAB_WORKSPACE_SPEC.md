# OEP Studio Tab and Workspace Specification

**Status:** Proposed
**Storage:** `docs/architecture/ux/OEP-STUDIO-TAB-WORKSPACE-SPEC.md`

## 1. Purpose

Define the two-level tab model established by the OEP visual baseline.

OEP uses tabs for meaningful application/work context, not as a browser imitation.

## 2. Two Tab Levels

### Studio Bar

The Studio Bar represents major OEP applications:

```text
Home | Diagram Studio | EAM | Knowledge Studio | Exchange | Engineering | Instruments
```

### Workspace Bar

The Workspace Bar represents open work inside the active Studio:

```text
[ TRX300 Manual × ] [ GL1200 Wiring × ] [ + ]
```

These levels have different semantics and must remain visually distinguishable.

## 3. Studio Bar Behavior

Selecting a Studio:
- changes the active application context
- updates contextual navigation
- preserves open work
- does not close other Studio work
- does not behave like browser history

The active Studio must have a clear selected state.

## 4. Workspace Bar Behavior

Selecting a workspace:
- focuses that work object
- restores its last useful view when appropriate
- preserves Studio identity
- updates contextual navigation

Closing a workspace:
- closes presentation context
- does not delete persisted work
- prompts when unsaved changes require confirmation

## 5. Studio Switching

Example:

```text
EAM
  [ TRX300 Manual ]

        ↓ select Diagram Studio

Diagram Studio
  [ TRX300 Wiring ]
```

The EAM acquisition remains available. Switching Studios is not equivalent to closing work.

## 6. Cross-Studio Work

An engineering object may be viewed from multiple Studios.

A contextual transition should preserve identity.

Example:

```text
EAM
TRX300 Manual
  ↓
Detected Object: Ignition Coil
  ↓
Open in Diagram Studio
  ↓
TRX300 Wiring
  ↓
Ignition Coil selected
```

The system should make the relationship between the originating context and destination context understandable.

## 7. Tab Overflow

If many Studios or workspaces are open:
- prioritize active context
- retain predictable ordering
- provide overflow controls
- never hide the identity of the active workspace

## 8. Persistence

Where supported, workspace tabs should survive application restart as recoverable presentation state.

Persisted presentation state must remain separate from authoritative engineering data.

## 9. Visual Requirements

Studio tabs:
- larger visual authority
- application identity
- active Studio emphasis

Workspace tabs:
- compact
- artifact/work-object identity
- close control
- subordinate to Studio navigation

Neither should imitate Chrome, Edge, Firefox, or another browser.

## 10. Acceptance Test

A user should understand immediately:
- which Studio is active
- which work object is active
- how to switch Studios
- how to switch open work
- how to close work without deleting it
