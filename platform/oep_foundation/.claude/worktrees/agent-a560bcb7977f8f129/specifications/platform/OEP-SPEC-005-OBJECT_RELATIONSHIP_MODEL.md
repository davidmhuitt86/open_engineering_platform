-# OEP-SPEC-005

# Engineering Object Relationship Model

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification defines the relationship model used by the Open Engineering Platform.

Relationships connect Engineering Objects into a navigable engineering knowledge graph.

Engineering knowledge is defined not only by objects, but by how those objects relate to one another.

---

# 2. Scope

This specification defines:

* Relationship identity
* Relationship types
* Relationship storage
* Relationship validation
* Relationship lifecycle

This specification does not define:

* Graph search
* AI reasoning
* Visualization
* Registry synchronization

---

# 3. Relationship

Every relationship shall contain:

* relationshipId
* sourceObjectId
* targetObjectId
* relationshipType
* createdUtc
* author
* description

Relationship IDs shall be UUIDv4.

---

# 4. Relationship Types

Sprint 005 shall support:

* References
* Contains
* DependsOn
* ConnectedTo
* Documents
* Implements

Future specifications may extend this list.

---

# 5. Direction

Relationships are directional.

Example:

Document

→ Documents

Component

is different from

Component

→ DocumentedBy

Document

Future specifications may define reverse traversal.

---

# 6. Validation

Foundation shall validate:

* Both objects exist.
* Relationship type is valid.
* Source and target IDs differ.
* UUID format is valid.

Invalid relationships shall not be created.

---

# 7. Relationship Store

Foundation shall expose a Relationship Store responsible for:

* Create
* Read
* Update
* Delete
* Enumerate by object

The Relationship Store shall remain independent of Studios.

---

# 8. Serialization

Relationships shall support JSON serialization.

Future storage formats may be introduced without changing the API.

---

# 9. Acceptance Criteria

Sprint 005 is complete when:

* Relationship model exists.
* Relationship Store exists.
* CRUD operations succeed.
* Validation succeeds.
* Serialization succeeds.
* Unit tests verify relationship creation, persistence, loading, validation, and deletion.

---

# 10. Engineering Principle

Engineering knowledge forms a graph.

Engineering Objects are the nodes.

Relationships are the edges.

Foundation shall preserve both with equal importance.
