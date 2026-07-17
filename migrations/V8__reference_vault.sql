-- V8__reference_vault.sql
--
-- WORK_PACKAGE-009 (Engineering Reference Vault): "Store: UUID, Metadata
-- ID, Verification ID, Download Session ID, Source ID, Vault Path,
-- SHA-256, MIME Type, File Size, Publication Timestamp, Status. No
-- engineering interpretation shall be stored."
--
-- `id`/`uuid` follow the same internal-surrogate-key /
-- externally-visible-identifier split as every prior domain table.
--
-- `metadata_id`, `verification_id`, `download_session_id`, and
-- `source_id` are all real foreign keys -- every referenced table lives
-- in this same repository/database, and each corresponding "... shall
-- exist"/"... shall be successful" Validation Rule is exactly what a
-- `REFERENCES` constraint enforces, matching V6's/V7's precedent.
--
-- `metadata_id` is additionally UNIQUE: WORK_PACKAGE-009 lists "Publish
-- Verified Artifact" as its only creation-side Functional Requirement,
-- with no "Re-publish" counterpart to WORK_PACKAGE-007's "Verify Existing
-- Hashes" or WORK_PACKAGE-008's "Re-extract Metadata" -- a given Metadata
-- record may be published at most once. See README.md "Implementation
-- Decisions".
--
-- No `updated_at`-refreshing UPDATE ever runs against this table --
-- `IVaultRepository` has no `update` method at all (see its header) --
-- so `updated_at` will always equal `created_at` by construction; it is
-- kept only for schema-shape consistency with every other domain table.
--
-- No `deleted_at` column: WORK_PACKAGE-009's REST API has no DELETE
-- route, and "Vault entries shall be immutable after publication" rules
-- out even a soft-delete.

CREATE TABLE reference_vault (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    metadata_id UUID NOT NULL REFERENCES artifact_metadata (uuid),
    verification_id UUID NOT NULL REFERENCES integrity_verifications (uuid),
    download_session_id UUID NOT NULL REFERENCES download_sessions (uuid),
    source_id UUID NOT NULL REFERENCES official_sources (uuid),
    vault_path TEXT NOT NULL,
    sha256_hash TEXT NOT NULL,
    mime_type TEXT NOT NULL DEFAULT '',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    status TEXT NOT NULL
        CHECK (status IN ('published')),
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT reference_vault_uuid_key UNIQUE (uuid),
    CONSTRAINT reference_vault_metadata_id_key UNIQUE (metadata_id)
);

CREATE UNIQUE INDEX idx_reference_vault_uuid ON reference_vault (uuid);
CREATE INDEX idx_reference_vault_status ON reference_vault (status);
CREATE INDEX idx_reference_vault_sha256_hash ON reference_vault (sha256_hash);
