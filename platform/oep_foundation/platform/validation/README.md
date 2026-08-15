# Validation

Status: Foundation (Repository Integrity Validation)

Purpose: Read-only integrity validation over a repository's metadata, Engineering Objects, and Relationships, per OEP-SPEC-009-REPOSITORY_VALIDATION.

## Architecture

- `include/oep/validation/validation_result.hpp` — `Severity`, `ValidationFinding`, `RepositoryStatus`, `ValidationReport`, and `generate_validation_report`
- `include/oep/validation/repository_validator.hpp` — public `RepositoryValidator` (`validate_metadata` / `validate_objects` / `validate_relationships` / `validate_repository`)
- `src/validation_result.cpp`, `src/repository_validator.cpp` — report aggregation and the ten integrity checks

`RepositoryValidator` never modifies repository contents, never creates temporary files, and continues past individual failures so a single report reflects every integrity problem found. It operates over an `oep::repository::ObjectStore`, `RelationshipStore`, and `AuditStore`, plus the path to `repository.json`.
