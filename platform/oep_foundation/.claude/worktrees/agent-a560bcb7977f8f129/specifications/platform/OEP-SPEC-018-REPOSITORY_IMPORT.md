# OEP-SPEC-018

# Repository Import

**Version:** 1.0
**Status:** Draft

---

# 1. Purpose

This specification extends the OEP Command Line Interface to support importing Engineering Knowledge into an OEP Repository.

Repository Import reconstructs a repository from a previously exported archive.

All import operations shall execute through Foundation Runtime.

Business logic shall remain within Foundation.

---

# 2. Scope

This specification defines:

* Repository import
* Archive validation
* Repository reconstruction
* CLI integration

This specification does not define:

* Merge operations
* Conflict resolution
* Incremental import
* Cloud synchronization

---

# 3. Standard Command

Sprint 018 shall implement:

```text
oep import <archive-file>
```

Optional parameters:

```text
--destination <path>

--overwrite
```

---

# 4. Import Behavior

Import shall:

* Validate the export manifest.
* Validate repository metadata.
* Restore engineering objects.
* Restore relationships.
* Restore audit events.
* Restore optional packages.

---

# 5. Validation

Import shall reject:

* Invalid archives.
* Unsupported export versions.
* Corrupted manifests.
* Existing repositories unless `--overwrite` is specified.

---

# 6. Runtime Integration

Import shall execute entirely through Foundation Runtime.

The CLI shall never directly reconstruct repository contents.

---

# 7. Error Handling

Import shall gracefully report:

* Archive not found.
* Invalid archive.
* Existing destination.
* Validation failures.
* Write failures.

---

# 8. Developer Documentation

Implementation shall update:

```text
platform/runtime/CLI_USAGE.md
```

with import examples, overwrite behavior, and expected output.

---

# 9. Acceptance Criteria

Sprint 018 is complete when:

* Repository import succeeds.
* Invalid archives are rejected.
* Existing repositories are protected.
* Optional overwrite functions correctly.
* Runtime integration is preserved.
* Documentation is updated.
* Unit tests verify successful import, overwrite behavior, invalid archives, corrupted manifests, version mismatch, and package restoration.

---

# 10. Engineering Principle

Engineering knowledge shall be recoverable.

Repository import shall faithfully reconstruct exported engineering knowledge while preserving repository integrity.
