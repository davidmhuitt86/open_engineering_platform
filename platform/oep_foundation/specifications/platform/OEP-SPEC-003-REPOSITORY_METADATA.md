# OEP-SPEC-003

# Repository Metadata System

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification defines the metadata system used by every OEP repository.

Metadata uniquely identifies a repository and provides the information required for Foundation, Studios, SDKs, and the OEP Registry to understand and interact with it.

Metadata is considered part of the repository.

---

# 2. Scope

This specification defines:

* Repository identity
* Repository metadata schema
* Metadata validation
* Metadata loading
* Metadata updates
* Repository version information

It does not define:

* Registry synchronization
* Authentication
* Cloud services

---

# 3. Metadata Files

Every repository shall contain:

```text
repository.json
workspace.json
```

Sprint 003 focuses exclusively on **repository.json**.

---

# 4. Repository Metadata Object

The repository metadata shall contain:

```json
{
  "repositoryId": "",
  "repositoryName": "",
  "repositoryVersion": "1.0.0",
  "foundationVersion": "",
  "templateVersion": "1.0",
  "createdUtc": "",
  "lastModifiedUtc": "",
  "description": "",
  "author": "",
  "organization": "",
  "tags": []
}
```

---

# 5. Repository Identity

repositoryId

* UUID Version 4
* Immutable
* Never reused
* Never regenerated

This value permanently identifies the repository.

---

# 6. Repository Name

The repository name shall:

* Match the initialized repository.
* Be editable.
* Never affect the repository ID.

---

# 7. Version Information

Repository Version

Tracks engineering content.

Foundation Version

Tracks the Foundation release used to create the repository.

Template Version

Tracks the repository template.

---

# 8. Metadata Loader

Foundation shall expose a metadata loader responsible for:

* Loading repository.json
* Validating required fields
* Returning a strongly typed metadata object

Malformed metadata shall produce descriptive errors.

---

# 9. Metadata Writer

Foundation shall expose a metadata writer responsible for:

* Saving repository metadata
* Preserving formatting
* Updating timestamps
* Preventing corruption

---

# 10. Validation

Validation shall verify:

* Required fields exist
* UUID format
* Version format
* Valid JSON
* UTF-8 encoding

Validation failures shall not modify repository contents.

---

# 11. CLI Integration

The generator shall populate repository.json.

Future CLI commands shall consume metadata rather than duplicate configuration.

---

# 12. Acceptance Criteria

Sprint 003 is complete when:

* Repository metadata loads successfully.
* Invalid metadata is detected.
* Metadata can be written safely.
* UUID integrity is preserved.
* Strongly typed metadata objects are available to Foundation.
* Unit tests validate the loader and writer.
