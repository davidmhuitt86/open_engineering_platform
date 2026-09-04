-- V5__download_sessions.sql
--
-- WORK_PACKAGE-006 (Engineering Downloader): "Store: identifiers, status,
-- timestamps, connector reference, source reference, storage location,
-- progress. Do not store metadata extracted from downloaded files."
--
-- `id`/`uuid` follow the same internal-surrogate-key /
-- externally-visible-identifier split as every prior domain table.
--
-- `job_id` is a real foreign key to `acquisition_jobs(uuid)` -- both
-- tables live in this same repository/database, and "Job shall exist"
-- (Validation Rules) is exactly what a `REFERENCES` constraint enforces,
-- matching V3's `source_id` precedent.
--
-- `connector_id` is deliberately NOT a foreign key: the Connector
-- Registry (WORK_PACKAGE-005) is in-memory only, with no backing table
-- to reference (see that work package's "no persistence" decision) --
-- "Connector shall exist"/"Connector shall be healthy" are validated by
-- `DownloadService` against the live registry at request time instead.
--
-- No `deleted_at` column: WORK_PACKAGE-006's REST API has no DELETE
-- route (only Cancel, a status transition, not a deletion), so there is
-- nothing to soft-delete.

CREATE TABLE download_sessions (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES acquisition_jobs (uuid),
    connector_id TEXT NOT NULL,
    source_uri TEXT NOT NULL,
    local_storage_path TEXT NOT NULL DEFAULT '',
    file_name TEXT NOT NULL DEFAULT '',
    mime_type TEXT NOT NULL DEFAULT '',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    status TEXT NOT NULL
        CHECK (status IN ('pending', 'downloading', 'completed', 'failed', 'cancelled')),
    progress_percentage SMALLINT NOT NULL DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT download_sessions_uuid_key UNIQUE (uuid)
);

CREATE UNIQUE INDEX idx_download_sessions_uuid ON download_sessions (uuid);
CREATE INDEX idx_download_sessions_status ON download_sessions (status);
CREATE INDEX idx_download_sessions_job_id ON download_sessions (job_id);
CREATE INDEX idx_download_sessions_connector_id ON download_sessions (connector_id);
