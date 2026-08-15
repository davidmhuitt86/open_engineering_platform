# OEP-SPEC-004

# Engineering Object Model

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification defines the Engineering Object model used throughout the Open Engineering Platform.

Engineering Objects are the fundamental units of engineering knowledge stored within an OEP repository.

Every future subsystem shall operate on Engineering Objects rather than directly manipulating files.

---

# 2. Scope

This specification defines:

* Engineering Object identity
* Object metadata
* Object lifecycle
* Object classification
* Object serialization
* Repository ownership

This specification does not define:

* File formats
* User interface behavior
* Registry synchronization
* Object relationships (future specification)

---

# 3. Engineering Object

Every Engineering Object shall contain:

```text
objectId
objectType
name
description
createdUtc
lastModifiedUtc
version
author
tags
```

Every object shall possess a globally unique Object ID (UUIDv4).

---

# 4. Object Identity

The Object ID is permanent.

It shall never change during the lifetime of the object.

Names may change.

Descriptions may change.

Object IDs never change.

---

# 5. Object Types

Initial supported types:

* Document
* Diagram
* Component
* Procedure
* Project
* Image

Future specifications may introduce additional object types.

---

# 6. Object Storage

Engineering Objects shall be stored independently of user interface concerns.

Foundation shall operate on objects.

Studios shall present views of those objects.

---

# 7. Object Metadata

Each object shall expose:

* Display name
* Description
* Version
* Author
* Tags
* Creation timestamp
* Modification timestamp

---

# 8. Object Serialization

Engineering Objects shall support serialization.

Serialization shall preserve all metadata.

Future specifications shall define storage formats.

---

# 9. Object Lifecycle

Foundation shall support:

Create

Read

Update

Delete

Delete operations shall be soft-delete capable in future revisions.

---

# 10. Validation

Foundation shall validate:

* Object ID
* Required fields
* Metadata integrity
* Object type validity

Validation failures shall not modify repository contents.

---

# 11. Repository Ownership

Every Engineering Object belongs to exactly one repository.

Objects may be exported.

Objects may be imported.

Ownership remains explicit.

---

# 12. Acceptance Criteria

Sprint 004 is complete when:

* EngineeringObject class exists.
* Object metadata is strongly typed.
* UUID identity is enforced.
* Object validation succeeds.
* Serialization and deserialization succeed.
* Unit tests validate object creation, loading, saving, and validation.

---

# 13. Engineering Principle

Engineering knowledge is represented by Engineering Objects.

Files are merely one possible representation of those objects.

The object—not the file—is the source of truth.
