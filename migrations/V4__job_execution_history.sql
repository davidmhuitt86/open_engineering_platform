-- V4__job_execution_history.sql
--
-- WORK_PACKAGE-004 (Engineering Acquisition Execution Engine): "Execution
-- history shall be recorded." WORK_PACKAGE-004 explicitly reuses
-- acquisition_jobs unchanged ("No schema redesign") and only permits a
-- migration "if additional execution metadata is required" -- this table
-- is additive, new metadata alongside acquisition_jobs, not a redesign of
-- it.
--
-- Append-only: rows are never updated or deleted, mirroring Engineering
-- Principle 8 (Engineering Evidence Is Immutable). No soft-delete column
-- is needed as a result.

CREATE TABLE acquisition_job_execution_history (
    id BIGSERIAL PRIMARY KEY,
    job_id UUID NOT NULL REFERENCES acquisition_jobs (uuid),
    from_status TEXT NOT NULL
        CHECK (from_status IN ('created', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    to_status TEXT NOT NULL
        CHECK (to_status IN ('created', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    message TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_acquisition_job_execution_history_job_id ON acquisition_job_execution_history (job_id);
