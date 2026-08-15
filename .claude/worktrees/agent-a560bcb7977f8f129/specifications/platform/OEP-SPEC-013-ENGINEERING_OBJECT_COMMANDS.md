# OEP-SPEC-013

# Engineering Object CLI Commands

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification extends the OEP Command Line Interface to support the creation and management of Engineering Objects.

The CLI shall become the primary interface for creating engineering knowledge within an OEP repository.

Commands shall utilize Foundation Runtime and Repository services exclusively.

Business logic shall remain within Foundation.

---

# 2. Scope

This specification defines:

* Object creation
* Object listing
* Object inspection
* Object deletion
* CLI integration

This specification does not define:

* Object editing
* Binary asset import
* Relationship management
* Diagram editing

These capabilities are defined by future specifications.

---

# 3. Standard Commands

Sprint 013 shall implement:

```text
oep object create

oep object list

oep object show <object-id>

oep object delete <object-id>
```

---

# 4. Object Creation

The create command shall support:

* Object Type
* Name
* Description
* Author
* Tags

Object IDs shall be generated automatically.

Creation shall utilize Foundation Runtime and ObjectStore.

---

# 5. Object Listing

The list command shall display:

* Object ID
* Object Type
* Name
* Version

Output shall be deterministic.

Future specifications may introduce filtering and sorting.

---

# 6. Object Inspection

The show command shall display all metadata associated with an Engineering Object.

Display shall include:

* Object ID
* Object Type
* Name
* Description
* Author
* Tags
* Version
* Creation Timestamp
* Last Modified Timestamp

---

# 7. Object Deletion

Deletion shall remove the Engineering Object through ObjectStore.

Deletion shall automatically generate the required Audit Event.

Future specifications may introduce soft deletion.

---

# 8. Runtime Integration

All commands shall operate through Foundation Runtime.

Commands shall never instantiate Repository services directly.

---

# 9. Help Integration

The Help command shall automatically include every new object command.

Syntax and descriptions shall be generated consistently with existing commands.

---

# 10. Developer Documentation

Implementation shall update:

```text
platform/runtime/CLI_USAGE.md
```

Documentation shall include:

* Object command syntax
* Example workflows
* Expected output
* Current limitations

Documentation updates are part of the Definition of Done.

---

# 11. Acceptance Criteria

Sprint 013 is complete when:

* Engineering Objects can be created from the CLI.
* Engineering Objects can be listed.
* Engineering Objects can be displayed.
* Engineering Objects can be deleted.
* Audit Events are generated automatically.
* Help documentation includes all new commands.
* CLI_USAGE.md is updated.
* Unit tests validate creation, listing, inspection, deletion, invalid IDs, and runtime integration.

---

# 12. Engineering Principle

Engineering knowledge should be creatable through stable Foundation interfaces.

The CLI is the first engineering authoring client for OEP.

Future Studios shall build upon these same Foundation services without duplicating business logic.
