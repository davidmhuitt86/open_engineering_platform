# OEP-SPEC-014

# Engineering Relationship CLI Commands

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification extends the OEP Command Line Interface to support the creation and management of Engineering Relationships.

Engineering Relationships connect Engineering Objects into a navigable engineering knowledge graph.

The CLI shall become the first client capable of constructing complete engineering graphs.

Business logic shall remain within Foundation.

---

# 2. Scope

This specification defines:

* Relationship creation
* Relationship listing
* Relationship inspection
* Relationship deletion
* CLI integration

This specification does not define:

* Relationship editing
* Batch relationship creation
* Graph visualization
* Automatic relationship discovery

Future specifications shall define those capabilities.

---

# 3. Standard Commands

Sprint 014 shall implement:

```text
oep relationship create

oep relationship list

oep relationship show <relationship-id>

oep relationship delete <relationship-id>
```

---

# 4. Relationship Creation

The create command shall require:

* Source Object ID
* Target Object ID
* Relationship Type

Optional fields:

* Author
* Description

Relationship IDs shall always be generated automatically.

Relationship creation shall utilize Foundation Runtime and RelationshipStore.

---

# 5. Relationship Listing

The list command shall display:

* Relationship ID
* Relationship Type
* Source Object ID
* Target Object ID

Output shall be deterministic.

Future specifications may introduce filtering.

---

# 6. Relationship Inspection

The show command shall display:

* Relationship ID
* Relationship Type
* Source Object ID
* Target Object ID
* Author
* Description
* Creation Timestamp

---

# 7. Relationship Deletion

Deletion shall utilize RelationshipStore.

Deletion shall automatically generate the required Audit Event.

No additional audit logic shall exist within the CLI.

---

# 8. Runtime Integration

All relationship commands shall obtain services exclusively through Foundation Runtime.

Commands shall never instantiate Repository services directly.

---

# 9. Help Integration

The Help command shall automatically include every new relationship command.

Syntax and descriptions shall remain consistent with existing object commands.

---

# 10. Developer Documentation

Implementation shall update:

```text
platform/runtime/CLI_USAGE.md
```

Documentation shall include:

* Relationship command syntax
* Supported relationship types
* Example relationship workflows
* Expected output
* Current limitations

Documentation updates are part of the Definition of Done.

---

# 11. Acceptance Criteria

Sprint 014 is complete when:

* Relationships can be created from the CLI.
* Relationships can be listed.
* Relationships can be displayed.
* Relationships can be deleted.
* Relationship validation is enforced.
* Audit Events are generated automatically.
* Help documentation includes all relationship commands.
* CLI_USAGE.md is updated.
* Unit tests validate creation, listing, inspection, deletion, invalid object references, invalid relationship types, duplicate operations, and runtime integration.

---

# 12. Engineering Principle

Engineering knowledge is expressed through both Engineering Objects and Engineering Relationships.

The CLI shall provide a complete authoring interface for both, while Foundation remains the sole owner of engineering business logic.
