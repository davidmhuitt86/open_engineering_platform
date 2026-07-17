-- V6__integrity_verifications.sql
--
-- WORK_PACKAGE-007 (Engineering Integrity Verification Engine): "Store:
-- UUID, Download Session ID, Status, SHA-256, File Size, Timestamp, Error
-- Message. No metadata shall be stored."
--
-- `id`/`uuid` follow the same internal-surrogate-key /
-- externally-visible-identifier split as every prior domain table.
--
-- `download_session_id` is a real foreign key to `download_sessions(uuid)`
-- -- both tables live in this same repository/database, and "Download
-- session shall exist" (Validation Rules) is exactly what a `REFERENCES`
-- constraint enforces, matching V5's `job_id` precedent.
--
-- No `deleted_at` column: WORK_PACKAGE-007's REST API has no DELETE route.

CREATE TABLE integrity_verifications (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    download_session_id UUID NOT NULL REFERENCES download_sessions (uuid),
    status TEXT NOT NULL
        CHECK (status IN ('pending', 'verified', 'failed')),
    sha256_hash TEXT NOT NULL DEFAULT '',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    verified_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT integrity_verifications_uuid_key UNIQUE (uuid)
);

CREATE UNIQUE INDEX idx_integrity_verifications_uuid ON integrity_verifications (uuid);
CREATE INDEX idx_integrity_verifications_status ON integrity_verifications (status);
CREATE INDEX idx_integrity_verifications_download_session_id ON integrity_verifications (download_session_id);
