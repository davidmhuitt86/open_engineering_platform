-- V6__installations.sql
--
-- TASK-EXC-0008 (docs/tasks/WP-EXC-008.md): the Repository Installation
-- Integration's own record of each attempt to install a Package version
-- into an OEP Repository (§4 "GET /api/v1/installations/{installationId}",
-- §8 "Installation status reporting"). Distinct from `downloads` (an
-- append-only log of artifact retrievals, TASK-EXC-0002/0007):
-- `installations` is created once per install attempt (`status =
-- 'pending'`) and updated exactly once more, to its terminal state
-- (`completed` or `failed`) once the Repository responds — so, unlike
-- `downloads`/`audit_log`, it carries `row_version`/`updated_at` despite
-- being a historical record, the same way `package_versions` does for
-- its own pending -> published lifecycle.
--
-- `repository_package_id`/`error_message` are mutually exclusive in
-- practice (populated on success or failure respectively) but neither
-- is constrained NOT NULL, since a `pending` row has neither yet.

CREATE TABLE installations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES packages (id) ON DELETE CASCADE,
    package_version_id UUID NOT NULL REFERENCES package_versions (id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'completed', 'failed')),
    repository_package_id TEXT,
    error_message TEXT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_installations_package ON installations (package_id);
CREATE INDEX idx_installations_package_version ON installations (package_version_id);
CREATE INDEX idx_installations_status ON installations (status);
