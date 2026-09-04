-- V2__official_sources.sql
--
-- WORK-PACKAGE-002 (Official Source Registry): the Trust Layer's first
-- persistent engineering domain table. Added as V2 rather than editing V1
-- -- Flyway migrations are immutable once committed; V1 remains the
-- WORK_PACKAGE_001 bootstrap placeholder.
--
-- `id` is an internal surrogate primary key used only for joins/storage
-- ordering; `uuid` is the externally-visible identifier used throughout
-- the REST API and never changes after creation ("UUID immutable").
-- `trust_level` and `status` are stored as constrained values rather than
-- native PostgreSQL ENUM types so that WORK-PACKAGE-002's "Future fields
-- shall not require schema redesign" note extends to future value
-- additions too: extending a CHECK constraint is a plain migration,
-- while adding a value to a native enum type has additional transactional
-- restrictions.

CREATE TABLE official_sources (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    organization TEXT NOT NULL DEFAULT '',
    base_url TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    country TEXT NOT NULL DEFAULT '',
    language TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT '',
    trust_level SMALLINT NOT NULL CHECK (trust_level BETWEEN 0 AND 5),
    status TEXT NOT NULL
        CHECK (status IN ('proposed', 'approved', 'active', 'suspended', 'deprecated', 'archived')),
    authentication_type TEXT NOT NULL
        CHECK (authentication_type IN ('none', 'username_password', 'api_key', 'oauth2', 'client_certificate')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT official_sources_uuid_key UNIQUE (uuid)
);

-- Partial indexes: every query WORK-PACKAGE-002 needs (find by id, list,
-- filter by status/trust level) only ever targets non-deleted rows.
CREATE UNIQUE INDEX idx_official_sources_uuid_active ON official_sources (uuid) WHERE deleted_at IS NULL;
CREATE INDEX idx_official_sources_status ON official_sources (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_official_sources_trust_level ON official_sources (trust_level) WHERE deleted_at IS NULL;
CREATE INDEX idx_official_sources_category ON official_sources (category) WHERE deleted_at IS NULL;
CREATE INDEX idx_official_sources_country ON official_sources (country) WHERE deleted_at IS NULL;
