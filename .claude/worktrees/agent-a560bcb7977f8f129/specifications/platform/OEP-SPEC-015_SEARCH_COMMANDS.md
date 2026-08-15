# OEP-SPEC-015

# Repository Search CLI Commands

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification extends the OEP Command Line Interface to expose the Repository Search Engine.

The Search CLI provides engineers with the ability to locate Engineering Objects and Engineering Relationships without requiring prior knowledge of object identifiers.

All search operations shall execute through Foundation Runtime and the Search Engine.

Business logic shall remain within Foundation.

---

# 2. Scope

This specification defines:

* Repository search
* Object search
* Relationship search
* Search filtering
* CLI integration

This specification does not define:

* Semantic search
* AI-assisted search
* Regular expression search
* Saved searches
* Advanced query languages

These capabilities are reserved for future specifications.

---

# 3. Standard Commands

Sprint 015 shall implement:

```text
oep search <query>

oep search objects <query>

oep search relationships <query>
```

Optional filters:

```text
--repository <path>

--type <object-type>

--author <author>

--tag <tag>
```

---

# 4. Search Behavior

Search shall execute through Foundation Runtime.

The CLI shall never access Repository data directly.

Search results shall utilize the existing Search Engine without modification.

---

# 5. Object Search Output

Object search results shall display:

* Object ID
* Object Type
* Name
* Match Score
* Match Location

Results shall be sorted exactly as returned by the Search Engine.

The CLI shall not implement independent ranking.

---

# 6. Relationship Search Output

Relationship search results shall display:

* Relationship ID
* Relationship Type
* Source Object ID
* Target Object ID
* Match Score
* Match Location

Results shall preserve Search Engine ordering.

---

# 7. Search Filters

Sprint 015 shall support:

* Object Type
* Author
* Tag

Filtering shall occur after Search Engine execution.

Future specifications may move filtering into Foundation without changing CLI behavior.

---

# 8. Error Handling

Search shall gracefully report:

* Repository not found
* Empty repositories
* No matching results
* Invalid command syntax

Errors shall be descriptive.

The CLI shall never expose internal implementation details.

---

# 9. Runtime Integration

Every search command shall:

* Initialize Foundation Runtime
* Open the Repository
* Execute Search
* Display Results
* Shutdown Runtime

Search commands shall not instantiate SearchEngine directly.

---

# 10. Help Integration

The Help system shall automatically include every search command.

Syntax and descriptions shall remain consistent with all existing CLI commands.

---

# 11. Developer Documentation

Implementation shall update:

```text
platform/runtime/CLI_USAGE.md
```

Documentation shall include:

* Search command syntax
* Available filters
* Example searches
* Expected output
* Current limitations

Documentation updates are part of the Definition of Done.

---

# 12. Acceptance Criteria

Sprint 015 is complete when:

* Object search executes successfully.
* Relationship search executes successfully.
* Search filters operate correctly.
* Runtime integration is preserved.
* Search results remain deterministic.
* Help documentation includes all search commands.
* CLI_USAGE.md is updated.
* Unit tests validate object search, relationship search, filtering, empty repositories, invalid repositories, no-match results, and runtime integration.

---

# 13. Engineering Principle

Engineering knowledge is valuable only when it can be efficiently discovered.

The CLI shall expose the Repository Search Engine as a thin presentation layer over Foundation.

All search logic shall remain owned by the Search subsystem.
