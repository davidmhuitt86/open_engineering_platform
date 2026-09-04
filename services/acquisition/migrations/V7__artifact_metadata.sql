-- V7__artifact_metadata.sql
--
-- WORK_PACKAGE-008 (Engineering Metadata Extraction Engine): "Store: UUID,
-- Verification ID, File Name, MIME Type, File Size, SHA-256, Timestamps,
-- Status, Error Message. Metadata history shall be preserved."
--
-- `id`/`uuid` follow the same internal-surrogate-key /
-- externally-visible-identifier split as every prior domain table.
--
-- `verification_id` is a real foreign key to `integrity_verifications(uuid)`
-- -- both tables live in this same repository/database, and "Verification
-- shall exist" (Validation Rules) is exactly what a `REFERENCES` constraint
-- enforces, matching V6's `download_session_id` precedent.
--
-- "Metadata history shall be preserved" / "Re-extract Metadata" is
-- satisfied by never updating an existing row's `verification_id` binding
-- in place across separate extraction attempts -- `POST /metadata` always
-- INSERTs a new row (see MetadataExtractionService), so multiple metadata
-- records can exist for the same `verification_id`, each independently
-- queryable and never overwritten (Engineering Principle 8: Engineering
-- Evidence Is Immutable).
--
-- `file_extension`, `pdf_version`, and `pdf_page_count` are additive to the
-- Database section's minimum listed columns, needed to store the "Basic
-- Document Inspection" scope item and the Metadata Model's own
-- "File Extension" field -- see README.md "Implementation Decisions".
--
-- No `deleted_at` column: WORK_PACKAGE-008's REST API has no DELETE route.

CREATE TABLE artifact_metadata (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    verification_id UUID NOT NULL REFERENCES integrity_verifications (uuid),
    file_name TEXT NOT NULL DEFAULT '',
    file_extension TEXT NOT NULL DEFAULT '',
    mime_type TEXT NOT NULL DEFAULT '',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    sha256_hash TEXT NOT NULL DEFAULT '',
    file_created_at TIMESTAMPTZ,
    file_modified_at TIMESTAMPTZ,
    pdf_version TEXT,
    pdf_page_count INTEGER,
    status TEXT NOT NULL
        CHECK (status IN ('pending', 'extracted', 'failed')),
    extracted_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT artifact_metadata_uuid_key UNIQUE (uuid)
);

CREATE UNIQUE INDEX idx_artifact_metadata_uuid ON artifact_metadata (uuid);
CREATE INDEX idx_artifact_metadata_status ON artifact_metadata (status);
CREATE INDEX idx_artifact_metadata_verification_id ON artifact_metadata (verification_id);
