# OEP-SPEC-016

# Repository Graph CLI Commands

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification extends the OEP Command Line Interface to expose the Repository Graph Engine.

The Graph CLI enables engineers to navigate Engineering Objects through their Engineering Relationships.

All graph operations shall execute through Foundation Runtime and the Repository Graph Engine.

Business logic shall remain within Foundation.

---

# 2. Scope

This specification defines:

* Neighbor discovery
* Graph traversal
* Path detection
* CLI integration

This specification does not define:

* Graph visualization
* Shortest-path algorithms
* Weighted traversal
* Interactive graph exploration
* Graph editing

These capabilities are reserved for future specifications.

---

# 3. Standard Commands

Sprint 016 shall implement:

```text
oep graph neighbors <object-id>

oep graph traverse <object-id>

oep graph path <source-object-id> <target-object-id>
```

Optional parameters:

```text
--repository <path>

--algorithm bfs

--algorithm dfs
```

If no traversal algorithm is specified, Breadth-First Search (BFS) shall be the default.

---

# 4. Neighbor Discovery

The neighbors command shall return:

* Neighbor Object ID
* Neighbor Object Type
* Neighbor Object Name
* Relationship Type

Output shall preserve deterministic ordering.

---

# 5. Graph Traversal

The traverse command shall execute using the Repository Graph Engine.

Supported traversal algorithms:

* Breadth-First Search (default)
* Depth-First Search

Traversal output shall display:

* Traversal Order
* Object ID
* Object Type
* Object Name

The CLI shall not implement traversal logic.

---

# 6. Path Detection

The path command shall determine whether a path exists between two Engineering Objects.

Sprint 016 shall report only:

* Path Found
* No Path Found

Future specifications may introduce:

* Shortest path
* Path visualization
* Relationship sequence
* Path cost

---

# 7. Runtime Integration

Every graph command shall:

* Initialize Foundation Runtime
* Open the Repository
* Execute Graph Engine operations
* Display Results
* Shutdown Runtime

Graph commands shall never instantiate Repository or Graph Engine objects directly.

---

# 8. Error Handling

Graph commands shall gracefully report:

* Repository not found
* Invalid object IDs
* Missing objects
* Empty repositories
* No neighbors
* No path found

Errors shall be descriptive.

The CLI shall never expose implementation details or stack traces.

---

# 9. Help Integration

The Help system shall automatically include every graph command.

Syntax and descriptions shall remain consistent with all existing CLI commands.

---

# 10. Developer Documentation

Implementation shall update:

```text
platform/runtime/CLI_USAGE.md
```

Documentation shall include:

* Graph command syntax
* BFS and DFS usage
* Neighbor discovery examples
* Path detection examples
* Expected output
* Current limitations

Documentation updates are part of the Definition of Done.

---

# 11. Acceptance Criteria

Sprint 016 is complete when:

* Neighbor discovery executes successfully.
* Graph traversal executes successfully.
* BFS traversal executes successfully.
* DFS traversal executes successfully.
* Path detection executes successfully.
* Runtime integration is preserved.
* Help documentation includes all graph commands.
* CLI_USAGE.md is updated.
* Unit tests validate neighbor discovery, BFS traversal, DFS traversal, disconnected graphs, invalid object IDs, path detection, empty repositories, and runtime integration.

---

# 12. Engineering Principle

Engineering knowledge is most valuable when its relationships can be explored.

The CLI shall expose the Repository Graph Engine as a thin presentation layer over Foundation.

All graph algorithms shall remain owned by the Repository subsystem.
