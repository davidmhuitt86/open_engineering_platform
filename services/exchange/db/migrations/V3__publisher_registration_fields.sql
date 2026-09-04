-- V3__publisher_registration_fields.sql
--
-- TASK-EXC-0003 (docs/tasks/WP-EXC-003.md §5): the Publisher Registry's
-- API-facing model names two fields `publishers` didn't yet have:
-- "Contact Email" (new column) and "Legal Name" — the latter is not a
-- new column; it is the already-existing `name` column (EXC-002 §4's
-- "Publisher Name"), which this task's REST API surfaces as
-- `legalName` alongside `displayName` (`display_name`). See
-- `docs/architecture/REPOSITORY_STRUCTURE.md` for the full reasoning.
--
-- WP-EXC-003.md §6 additionally requires rejecting duplicate publisher
-- names and duplicate contact emails, so both gain a partial unique
-- index (active rows only, consistent with every other uniqueness rule
-- in this schema). `idx_publishers_name_active` (a plain, non-unique
-- index from V1) is dropped and replaced by a unique one — migrations
-- are forward-only, so the correction is a new statement here, not an
-- edit of V1.

ALTER TABLE publishers ADD COLUMN contact_email TEXT NOT NULL DEFAULT '';

DROP INDEX idx_publishers_name_active;
CREATE UNIQUE INDEX idx_publishers_name_active ON publishers (name) WHERE deleted_at IS NULL;

-- Empty contact_email is allowed (WP-EXC-003.md §5 doesn't mark it
-- mandatory at the column level the way `name`/`display_name` are) and
-- deliberately excluded from uniqueness so any number of publishers can
-- share a blank value; comparison is case-insensitive (`lower(...)`)
-- since email addresses are conventionally treated as such.
CREATE UNIQUE INDEX idx_publishers_contact_email_active
    ON publishers (lower(contact_email))
    WHERE deleted_at IS NULL AND contact_email <> '';
