-- V3__acquisition_jobs.sql
--
-- WORK_PACKAGE-003 (Engineering Acquisition Job Engine): the orchestration
-- layer for future acquisition operations. Added as V3 -- Flyway
-- migrations are immutable once committed; V1 and V2 are untouched.
--
-- `id`/`uuid` follow the same internal-surrogate-key /
-- externally-visible-identifier split as `official_sources`
-- (migrations/V2__official_sources.sql).
--
-- `source_id` is a real foreign key to `official_sources(uuid)` -- Job
-- Model's "Source ID required" (WORK_PACKAGE-003 Validation Rules) is
-- enforced as genuine relational integrity rather than only an
-- application-level presence check, since both tables live in this same
-- repository/database. `official_sources_uuid_key` (V2) is an
-- unconditional UNIQUE constraint, so it is a valid FK target regardless
-- of a source's soft-delete state.
--
-- `status`/`priority` follow V2's precedent: constrained values rather
-- than native PostgreSQL ENUM types, so extending the allowed set later
-- is a plain migration (see V2's comment for the full rationale).
--
-- `started_at`, `completed_at`, and `error_message` are genuinely
-- nullable (no DEFAULT) -- WORK_PACKAGE-003's Job Model explicitly marks
-- them "(nullable)", unlike Source Model's optional text fields (V2),
-- which default to '' instead.

CREATE TABLE acquisition_jobs (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES official_sources (uuid),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL
        CHECK (status IN ('created', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    priority SMALLINT NOT NULL CHECK (priority BETWEEN 0 AND 3),
    requested_by TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT acquisition_jobs_uuid_key UNIQUE (uuid)
);

-- Partial indexes: every query WORK_PACKAGE-003 needs (find by id, list,
-- filter by status/priority/source/requester) only ever targets
-- non-deleted rows.
CREATE UNIQUE INDEX idx_acquisition_jobs_uuid_active ON acquisition_jobs (uuid) WHERE deleted_at IS NULL;
CREATE INDEX idx_acquisition_jobs_status ON acquisition_jobs (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_acquisition_jobs_priority ON acquisition_jobs (priority) WHERE deleted_at IS NULL;
CREATE INDEX idx_acquisition_jobs_source_id ON acquisition_jobs (source_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_acquisition_jobs_requested_by ON acquisition_jobs (requested_by) WHERE deleted_at IS NULL;
