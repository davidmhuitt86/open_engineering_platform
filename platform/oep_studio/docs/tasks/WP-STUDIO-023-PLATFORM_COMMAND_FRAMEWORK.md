# WP-STUDIO-023
## Platform Command Framework

**Repository**

projects/platform/oep_studio

**Documentation**

Save As:

projects/platform/oep_studio/docs/tasks/WP-STUDIO-023 Platform Command Framework.md

---

# Objective

Create a centralized Platform Command Framework that provides a consistent mechanism for defining, discovering, validating, and executing commands across all Studios.

The Command Framework is Platform infrastructure.

It is **not** a user interface.

It shall become the execution layer used by future Platform services including:

- Command Palette
- Keyboard Shortcuts
- Toolbar Actions
- Context Menus
- Workflow Engine
- AI Orchestration
- Automation
- Future scripting interfaces

---

# Background

WP-STUDIO-021 established the Studio Registry as the authoritative source for Studio discovery.

WP-STUDIO-022 extended the Studio Registry with Capability Metadata.

The Platform now knows:

• Which Studios exist.

• What engineering capabilities each Studio provides.

The next architectural layer is command execution.

Capabilities describe functionality.

Commands perform actions.

---

# Architectural Principles

The Platform owns command discovery and dispatch.

Studios own command implementation.

The Platform shall never contain Studio-specific business logic.

Studios remain autonomous.

The Command Framework acts as the orchestration layer between Platform services and Studio implementations.

---

# Scope

This work package SHALL:

- Define immutable CommandDescriptor objects.
- Create a centralized Command Registry.
- Associate commands with registered Studios and Capabilities.
- Provide command discovery APIs.
- Define a common execution contract.
- Validate command registrations.

This work package SHALL NOT:

- Implement a Command Palette.
- Implement keyboard shortcuts.
- Implement menus.
- Implement toolbar buttons.
- Implement AI execution.
- Implement workflow automation.
- Redesign existing Studios.

---

# Architecture

Current

Studio Registry

↓

StudioDescriptor

↓

Capability Metadata

Future

Studio Registry

↓

StudioDescriptor

↓

Capability Metadata

↓

Command Metadata

↓

Platform Command Framework

↓

Studio Execution

The Platform dispatches commands.

Studios execute commands.

---

# Deliverables

## Phase 1 – CommandDescriptor

Design an immutable CommandDescriptor.

Minimum fields:

- Command ID
- Display Name
- Description
- Owning Studio
- Owning Capability
- Category
- Enabled
- Visible

Execution shall be represented by a typed handler reference.

No UI dependencies.

---

## Phase 2 – Command Registry

Implement a centralized Command Registry.

Provide APIs for:

- Register Command
- Lookup by ID
- Lookup by Studio
- Lookup by Capability
- Enumerate Commands
- Validate Registry

The registry shall maintain deterministic ordering.

Duplicate registrations shall be rejected.

---

## Phase 3 – Command Registration

Register only commands that already exist in the codebase.

Knowledge Studio

- Create Knowledge Object
- Edit Knowledge Object
- Delete Knowledge Object
- Search Knowledge

Diagram Studio

- Create Diagram
- Open Diagram
- Save Diagram
- Validate Diagram

Engineering Acquisition Studio

- Import Sources
- Create Acquisition Job
- Run OCR
- Verify Artifact
- Open Vault

Do not invent new commands.

Every registered command must correspond to an existing implementation.

---

## Phase 4 – Execution Contract

Create a common execution interface.

The Platform invokes commands through the Command Framework.

The Framework resolves the owning Studio.

The Studio performs the requested operation.

The Platform remains unaware of Studio implementation details.

No command shall directly depend upon another Studio.

---

## Phase 5 – Validation

Validate:

- Unique command identifiers.
- Every command belongs to a registered Studio.
- Every command references a valid Capability.
- No orphan commands.
- Deterministic registry ordering.
- Duplicate IDs rejected.

---

# Data Model

Studio Registry

↓

StudioDescriptor

├── Identity

├── Route

├── Icon

├── Search Provider

├── Settings Provider

├── Capabilities

└── Commands

CommandDescriptor

├── ID

├── Name

├── Description

├── Studio

├── Capability

├── Category

├── Enabled

├── Visible

└── Execution Handler

---

# Out of Scope

Do NOT implement:

- Command Palette
- Keyboard shortcuts
- Context menus
- Toolbar integration
- Event Bus
- Notifications
- Workflow Engine
- AI orchestration
- Automation
- Plugin loading

These systems will consume the Command Framework in future work packages.

---

# Definition of Done

The Platform shall be capable of answering:

"What commands are available?"

"Which Studio owns this command?"

"Which commands belong to Diagram Studio?"

"Which commands implement Acquisition capabilities?"

and executing registered commands through a common dispatch mechanism.

No hard-coded switch statements shall exist for command routing.

---

# Future Consumers

WP-STUDIO-024

Platform Command Palette

Consumes:

- Studio Registry
- Capability Metadata
- Command Framework

WP-STUDIO-025

Platform Event Bus

Consumes:

- Command Framework

WP-STUDIO-026

Workflow Engine

Consumes:

- Command Framework

WP-STUDIO-027

AI Orchestration

Consumes:

- Command Framework

Future Platform services shall invoke commands through the Platform Command Framework rather than calling Studio implementations directly.

---

# Success Criteria

✓ Immutable CommandDescriptor model.

✓ Centralized Command Registry.

✓ Common execution contract.

✓ Existing commands registered.

✓ Deterministic discovery.

✓ Duplicate validation.

✓ Backwards compatibility maintained.

✓ No Studio redesign.

✓ No Platform regressions.

✓ Ready for Platform Command Palette.

---

# Claude Implementation Prompt

WP-STUDIO-023

Platform Command Framework

Repository

projects/platform/oep_studio

Documentation

Save as:

projects/platform/oep_studio/docs/tasks/WP-STUDIO-023 Platform Command Framework.md

=====================================================

OBJECTIVE

Create a centralized Platform Command Framework.

The Framework provides a common mechanism for defining, discovering, validating, and executing commands.

The Platform owns command dispatch.

Studios own command implementation.

=====================================================

IMPLEMENTATION

Review WP-STUDIO-021 and WP-STUDIO-022.

Design immutable CommandDescriptor objects.

Implement a centralized Command Registry.

Associate commands with existing Studios and Capabilities.

Register only commands that already exist.

Create a typed execution contract.

Implement registry validation.

=====================================================

IMPORTANT

Do NOT implement a Command Palette.

Do NOT implement keyboard shortcuts.

Do NOT implement menus.

Do NOT redesign existing Studios.

Do NOT invent commands.

Maintain complete backwards compatibility.

Only expose commands that already exist within the codebase.

=====================================================

DELIVERABLES

1. Command Framework architecture

2. CommandDescriptor model

3. Command Registry

4. Command registrations

5. Execution contract

6. Validation tests

7. Documentation

8. Recommendations for WP-STUDIO-024

Maintain complete backwards compatibility.

No functional regressions.

Stop after completion and do not begin the next work package without authorization.