# WP-STUDIO-029
## Workspace Lifecycle & Session Management

Repository

projects/platform/oep_studio

Documentation

docs/tasks/WP-STUDIO-029 Workspace Lifecycle & Session Management.md

---

# Objective

Implement the first complete Workspace Lifecycle subsystem for OEP Studio.

This milestone establishes how the application manages workspaces, sessions, recovery, dirty-state coordination, recent workspaces, application startup/shutdown, and persistence boundaries.

The goal is to make oep_studio behave like a mature desktop engineering application rather than a collection of individual Studios.

This work package should reuse the existing Platform infrastructure wherever practical:

- Studio Registry
- Command Framework
- Platform Input Framework
- Platform Event Bus
- Notification Service

Do not duplicate existing services.

---

# Tasks

## Phase 1 — Architecture Review

Review the current implementation and document:

- Workspace ownership
- Session ownership
- Startup sequence
- Shutdown sequence
- Dirty-state handling
- Current persistence boundaries
- Existing recovery behavior
- Existing "recent" functionality
- Existing autosave behavior
- Existing lifecycle events

Identify missing concepts and unnecessary duplication.

---

## Phase 2 — Workspace Manager

Design and implement a centralized WorkspaceManager.

Responsibilities may include:

- current workspace
- active project
- workspace metadata
- workspace state
- workspace initialization
- workspace closing
- workspace switching

Reuse existing services whenever possible.

Avoid introducing duplicate state.

---

## Phase 3 — Session Manager

Implement SessionManager responsible for:

- application session
- workspace session
- session identifiers
- session timestamps
- session lifecycle
- clean shutdown tracking

Publish lifecycle events through the Platform Event Bus where appropriate.

---

## Phase 4 — Dirty-State Coordination

Review every location tracking unsaved changes.

Centralize dirty-state management where practical.

WorkspaceManager should become capable of answering:

- Is anything dirty?
- Which documents are dirty?
- Which Studio owns them?

Do not rewrite Studio logic unnecessarily.

---

## Phase 5 — Workspace Persistence

Review persistence responsibilities.

Implement or improve:

- workspace metadata
- last opened workspace
- last active Studio
- recent workspaces
- recent projects
- restoration metadata

Do not implement full project serialization if it already exists elsewhere.

Focus on lifecycle.

---

## Phase 6 — Recovery Infrastructure

Implement recovery architecture.

Capabilities should include:

- interrupted session detection
- abnormal shutdown detection
- recovery metadata
- recovery preparation hooks
- future autosave integration points

No full autosave implementation is required.

The architecture should simply be ready.

---

## Phase 7 — Startup / Shutdown Lifecycle

Review the entire application startup.

Where appropriate:

- publish lifecycle events
- initialize WorkspaceManager
- initialize SessionManager
- restore previous state
- clean shutdown handling

Avoid changing user-visible behavior unnecessarily.

---

## Phase 8 — Recent Workspaces

Implement or improve:

- recent workspace list
- recent project list
- persistence
- validation of stale entries
- helper APIs

UI changes only where necessary.

---

## Phase 9 — Integration Cleanup

Review Platform services.

Reduce coupling where practical.

Ensure new managers integrate naturally with:

- Event Bus
- Notification Service
- Studio Registry
- Command Framework

Do not introduce unnecessary abstractions.

---

## Phase 10 — Validation

Verify:

- startup
- shutdown
- workspace switching
- dirty tracking
- recovery preparation
- session lifecycle
- recent workspace handling

Run:

- flutter analyze
- full test suite
- application build

Document all results.

---

# Deliverables

1. Architecture review

2. WorkspaceManager

3. SessionManager

4. Dirty-state coordination

5. Workspace persistence improvements

6. Recovery infrastructure

7. Startup/shutdown lifecycle

8. Recent workspaces

9. Platform integration cleanup

10. Validation results

11. Documentation

12. Recommendations for WP-STUDIO-030

---

# Requirements

- Review existing architecture before implementation.
- Reuse existing Platform services.
- Prefer extending current code instead of replacing it.
- Do not redesign Studios.
- Do not redesign the Command Framework.
- Do not redesign the Event Bus.
- Do not redesign Platform Input.
- Maintain backward compatibility.
- Remove duplicated lifecycle logic where practical.
- Keep the implementation lightweight.
- Document architectural decisions.
- Do not commit.
- Stop when complete and await authorization.
