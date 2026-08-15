# OEP-SPEC-012

# CLI Command Framework Expansion

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification expands the OEP Command Line Interface from a bootstrap utility into the primary developer interface for Foundation.

The CLI shall expose Foundation capabilities through stable, discoverable commands.

The CLI shall never duplicate Foundation business logic.

---

# 2. Scope

This specification defines:

* Runtime-aware CLI execution
* Repository opening
* Command organization
* Command dispatch
* Command help
* Developer documentation

This specification does not define:

* Interactive shell mode
* Scripting language support
* Remote execution
* Studio user interfaces

---

# 3. Runtime Integration

Every command requiring repository access shall obtain services through FoundationRuntime.

Commands shall never instantiate Repository services directly.

---

# 4. Standard Commands

Sprint 012 shall implement:

```text
oep open <repository>

oep validate

oep packages

oep status
```

Definitions:

**open**

Opens a repository through the Foundation Runtime.

**validate**

Executes Repository Validation and reports repository health.

**packages**

Lists all discovered packages with their current state.

**status**

Displays:

* Runtime state
* Current repository
* Repository ID
* Loaded package count
* Foundation version

---

# 5. Command Output

Command output shall be:

* Human-readable
* Deterministic
* Suitable for future scripting

Future specifications may introduce structured JSON output.

---

# 6. Error Handling

Commands shall display descriptive errors.

CLI commands shall never expose stack traces or internal implementation details.

---

# 7. Help System

The Help command shall automatically enumerate all registered commands.

Each command shall provide:

* Name
* Syntax
* Short description

Future specifications may introduce detailed command help.

---

# 8. Developer Documentation

Implementation shall create:

```text
platform/runtime/CLI_USAGE.md
```

The document shall include:

* Purpose of the CLI
* Build prerequisites
* Build instructions
* Running the CLI
* Every implemented command
* Example command sessions
* Expected output
* Repository layout expected by Foundation
* Current limitations
* Troubleshooting tips

Developer documentation is part of the Definition of Done.

---

# 9. Acceptance Criteria

Sprint 012 is complete when:

* `oep open <repository>` successfully opens a repository through Foundation Runtime.
* `oep validate` executes Repository Validation and displays a validation summary.
* `oep packages` discovers and lists packages with their current state.
* `oep status` displays Foundation Runtime status and repository information.
* The Help system automatically lists all available commands.
* CLI commands use Foundation Runtime rather than directly constructing Repository services.
* `platform/runtime/CLI_USAGE.md` is created and accurately documents the current CLI.
* Unit tests verify command execution, runtime integration, invalid repository handling, help generation, and error reporting.

---

# 10. Future Expansion

Future specifications may introduce additional commands including:

* Search
* Graph traversal
* Audit inspection
* Object management
* Relationship management
* Package installation
* Package updates
* Registry interaction

The command framework shall be extensible without requiring modification of existing commands.

---

# 11. Engineering Principle

The CLI is the canonical developer interface to the Open Engineering Platform.

Every command shall be a thin layer over Foundation Runtime.

Business logic belongs to Foundation.

Presentation belongs to the CLI.

This separation shall remain consistent across all future interfaces including Flutter Studios, SDKs, and APIs.

