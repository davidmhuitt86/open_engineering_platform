# OEP Foundation

# WORK PACKAGE 014

Status: Approved

Version: 1.0

---

# Objective

Extend the Public C API to support engineering object and relationship mutation.

This work package completes the first write-capable Public API for Foundation.

Studio shall continue communicating exclusively through the Public C API.

No direct Runtime access.

No hidden APIs.

No Studio changes.

---

# Foundation Architecture

This work package shall preserve all existing Foundation architectural principles.

No existing API behavior shall change.

All additions shall be additive.

---

# TASK-000027

## Public Object Mutation API

### Purpose

Expose Engineering Object creation through the Public C API.

---

# Requirements

Implement:

- oep_object_create()
- oep_object_update()
- oep_object_delete()

Support:

- Object Type
- Name
- Description
- Author
- Tags

Return:

- Result
- Error information
- Created Object ID

Implementation shall use Foundation Runtime internally.

No duplicated business logic.

---

# TASK-000028

## Public Relationship Mutation API

### Purpose

Expose Engineering Relationship creation through the Public C API.

---

# Requirements

Implement:

- oep_relationship_create()
- oep_relationship_update()
- oep_relationship_delete()

Support:

- Source Object
- Target Object
- Relationship Type
- Description

Implementation shall reuse existing Runtime functionality.

---

# TASK-000029

## Public Transaction API

### Purpose

Provide deterministic repository mutation.

---

# Requirements

Implement:

- oep_transaction_begin()
- oep_transaction_commit()
- oep_transaction_rollback()

Transactions shall:

- Group object mutations
- Group relationship mutations

Failures shall:

- Abort transaction
- Roll back changes

---

# TASK-000030

## Public Batch Mutation

### Purpose

Allow multiple object creations within a single transaction.

---

# Requirements

Support:

- Batch Object Create
- Batch Relationship Create

Execution order shall be deterministic.

Failures shall roll back the complete batch.

---

# Runtime Requirements

All mutation operations shall pass exclusively through Foundation Runtime.

The Public API shall never manipulate stores directly.

Runtime remains the single orchestration layer.

---

# Error Handling

Support:

- Duplicate IDs
- Invalid relationships
- Missing objects
- Repository unavailable
- Transaction failure
- Validation errors

No exceptions shall cross the C ABI.

---

# Thread Safety

Preserve existing thread-safety guarantees.

Document any new guarantees.

---

# Versioning

This work package introduces additive API functionality.

Increment:

OEP_API_VERSION

ABI version shall remain unchanged unless structurally required.

---

# Verification

Perform:

- Full clean rebuild
- Complete regression suite
- Manual verification through a standalone C API test program

Verify:

- Object creation
- Object update
- Object deletion
- Relationship creation
- Relationship update
- Relationship deletion
- Transaction rollback
- Batch mutation

Re-run existing CLI commands to confirm no regression.

---

# Documentation

Update:

- platform/api/README.md
- platform/runtime/README.md

Create:

platform/api/MUTATION_API.md

Document:

- Object mutation
- Relationship mutation
- Transactions
- Batch mutation
- Error handling
- Thread safety

Update:

PROJECT_STATUS.md

CURRENT_SPRINT.md

TASK.md

---

# Definition of Done

This work package is complete when:

- Object mutation API functions.
- Relationship mutation API functions.
- Transaction API functions.
- Batch mutation functions.
- Documentation is complete.
- Clean rebuild succeeds.
- Complete regression suite passes.
- Manual verification succeeds.

Stop after completion and await formal review.