-- V1__initial_exchange_schema.sql
--
-- TASK-EXC-0002 (docs/tasks/WP-EXC-002.md): the Exchange's initial
-- persistent schema — Publisher Registry (EXC-002) and Package Catalog
-- (PKG-002), per the 8-table list in WP-EXC-002.md §4: publishers,
-- publisher_profiles, packages, package_versions, package_categories,
-- package_files, downloads, audit_log. Search indexing (`search_index`)
-- is explicitly out of this task's scope (WP-EXC-002.md §2) and is
-- deferred to the Search task (TASK-EXC-0006).
--
-- Database standards (WP-EXC-002.md §8), superseding this repository's
-- earlier draft of the oep_acquisition BIGSERIAL+UUID convention for
-- this schema specifically:
--   - UUID is the true primary key of every table (`id UUID PRIMARY KEY
--     DEFAULT gen_random_uuid()`), not a surrogate BIGSERIAL with a
--     separate external UUID column. `gen_random_uuid()` is used
--     directly (no `CREATE EXTENSION pgcrypto`) — built into PostgreSQL
--     itself since v13, and this platform targets PostgreSQL 18.
--   - Every mutable table carries `row_version INTEGER NOT NULL DEFAULT
--     1`, an optimistic-concurrency field incremented on every UPDATE
--     (named `row_version` rather than `version` to avoid colliding
--     with `package_versions.version`, which holds the package's own
--     semver string). Append-only event logs (`downloads`, `audit_log`)
--     have no `row_version` — an event, once recorded, is never
--     updated.
--   - Enums remain `TEXT NOT NULL CHECK (...)` rather than native
--     PostgreSQL ENUM types, so a future allowed value is a plain
--     migration rather than one subject to native-enum transactional
--     restrictions (this part of the oep_acquisition convention is
--     unaffected by the primary-key change above).
--   - Soft delete via nullable `deleted_at`; partial indexes scoped to
--     `WHERE deleted_at IS NULL`.
--
-- Scope note: this schema is the Exchange's own *pre-installation*
-- catalog of published, downloadable packages (EXC-001 §2 "Package
-- Catalog") — distinct from PKG-008's "Package Registry", which is
-- Foundation/Repository-side bookkeeping of already-*installed*
-- packages and explicitly out of this repository's scope
-- (WP-EXC-001 §2 "Package Runtime").

-- ---------------------------------------------------------------------
-- publishers
--
-- EXC-002 §4 Publisher Identity. `id` is the immutable Publisher ID
-- referenced everywhere else (EXC-002 §4: "Publisher IDs are
-- immutable. Display names may change."). `namespace` is the reverse-
-- domain namespace a Publisher owns (EXC-002 §5) — unique so that
-- Package IDs minted under it (PKG-002 §7) can never collide across
-- Publishers. `publisher_type` is EXC-002 §6's classification list.
-- `verification_status` is EXC-002 §8's list ("Verification determines
-- trust indicators only. Verification does not alter package
-- behavior."). `trust_status` is a minimal, extensible value EXC-002 §4
-- names but does not enumerate — modeled narrowly here since no future
-- behavior depends on its exact values yet. `status` distinguishes
-- Suspension (EXC-002 §16 — "shall not silently remove installed
-- packages") from ordinary activity; deletion (EXC-002 §17 — "does not
-- remove repository history... IDs shall never be reused") is the
-- existing `deleted_at` soft-delete convention, which already guarantees
-- an id is never reused for a different Publisher.
-- Publisher Certificates (EXC-002 §9) are PKG-005's lifecycle, out of
-- this task's scope and not part of the table list in WP-EXC-002.md §4.
CREATE TABLE publishers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    namespace TEXT NOT NULL,
    publisher_type TEXT NOT NULL
        CHECK (publisher_type IN (
            'individual', 'company', 'oem', 'educational_institution',
            'government', 'standards_organization', 'enterprise',
            'community_organization'
        )),
    verification_status TEXT NOT NULL DEFAULT 'unverified'
        CHECK (verification_status IN (
            'unverified', 'identity_verified', 'organization_verified',
            'oem_verified', 'academic_verified', 'government_verified',
            'open_engineering_verified'
        )),
    trust_status TEXT NOT NULL DEFAULT 'standard'
        CHECK (trust_status IN ('standard', 'trusted', 'flagged')),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended')),
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_publishers_namespace_active ON publishers (namespace) WHERE deleted_at IS NULL;
CREATE INDEX idx_publishers_name_active ON publishers (name) WHERE deleted_at IS NULL;
CREATE INDEX idx_publishers_status ON publishers (status) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- publisher_profiles
--
-- EXC-002 §7 Publisher Profile — deliberately a separate table from
-- `publishers`: Publisher Identity (immutable, ownership-bearing) and
-- Publisher Profile (public-facing, freely editable organization
-- information) are two distinct concepts per EXC-002. One active
-- profile per Publisher for this MVP.
CREATE TABLE publisher_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers (id) ON DELETE RESTRICT,
    organization_name TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    website TEXT NOT NULL DEFAULT '',
    support_contact TEXT NOT NULL DEFAULT '',
    documentation_url TEXT NOT NULL DEFAULT '',
    logo_url TEXT NOT NULL DEFAULT '',
    banner_url TEXT NOT NULL DEFAULT '',
    engineering_disciplines JSONB NOT NULL DEFAULT '[]',
    country TEXT NOT NULL DEFAULT '',
    languages JSONB NOT NULL DEFAULT '[]',
    social_links JSONB NOT NULL DEFAULT '{}',
    verified_badges JSONB NOT NULL DEFAULT '[]',
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_publisher_profiles_publisher_active ON publisher_profiles (publisher_id) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- package_categories
--
-- PKG-002 §11 Engineering Classification / EXC-004 §7 Engineering
-- Taxonomies. Self-referential `parent_id` supports the hierarchical
-- taxonomy EXC-004 §7 illustrates (Automotive -> Honda -> ... ->
-- Charging System) without requiring a schema change to add depth.
CREATE TABLE package_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    parent_id UUID REFERENCES package_categories (id) ON DELETE RESTRICT,
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_package_categories_slug_active ON package_categories (slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_package_categories_parent_active ON package_categories (parent_id) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- packages
--
-- PKG-002 §5/§7 the version-independent Package identity record:
-- `package_id` is PKG-001 §10 / PKG-002 §7's globally unique, immutable,
-- reverse-domain Package ID ("Names may change. Identifiers shall
-- not."), always owned by exactly one Publisher (EXC-002 §1). `status`
-- is the Exchange catalog's own publication lifecycle for this Package
-- (draft/published/deprecated/suspended) — distinct from PKG-008's
-- installed-package Registry lifecycle, which this repository does not
-- implement. `latest_version_id` is a forward reference to
-- `package_versions`, added via ALTER TABLE below once that table
-- exists, so package listings can look up the current version without
-- a correlated subquery.
CREATE TABLE packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id TEXT NOT NULL,
    publisher_id UUID NOT NULL REFERENCES publishers (id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    summary TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    category_id UUID REFERENCES package_categories (id) ON DELETE RESTRICT,
    engineering_domains JSONB NOT NULL DEFAULT '[]',
    keywords JSONB NOT NULL DEFAULT '[]',
    capabilities JSONB NOT NULL DEFAULT '[]',
    license JSONB NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'deprecated', 'suspended')),
    latest_version_id UUID,
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_packages_package_id_active ON packages (package_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_packages_publisher_active ON packages (publisher_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_packages_category_active ON packages (category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_packages_status ON packages (status) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- package_versions
--
-- PKG-002 §5-§18 the per-version manifest record. `manifest` stores the
-- full manifest JSON verbatim (PKG-002 §22: "The manifest is always read
-- before installation... Use the manifest as the authoritative package
-- metadata source"); the specific JSONB columns alongside it
-- (`repository_stats`, `statistics`, `signatures`, `build_metadata`,
-- `dependencies`) mirror PKG-002 §12-§18's named nested structures so
-- they can be queried/indexed directly without unpacking the raw
-- manifest blob each time. `release_channel` is EXC-004 §6's filter.
-- `status` is this version's own publication lifecycle, independent of
-- the parent Package's `status`. `version` is the package's own semver
-- string (PKG-002 §8) — distinct from `row_version`, the optimistic-
-- concurrency field.
CREATE TABLE package_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES packages (id) ON DELETE CASCADE,
    version TEXT NOT NULL,
    schema_version TEXT NOT NULL DEFAULT '1.0',
    manifest JSONB NOT NULL,
    dependencies JSONB NOT NULL DEFAULT '[]',
    repository_stats JSONB NOT NULL DEFAULT '{}',
    statistics JSONB NOT NULL DEFAULT '{}',
    signatures JSONB NOT NULL DEFAULT '{}',
    build_metadata JSONB NOT NULL DEFAULT '{}',
    release_channel TEXT NOT NULL DEFAULT 'stable'
        CHECK (release_channel IN ('stable', 'beta', 'alpha')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'published', 'deprecated', 'yanked')),
    published_at TIMESTAMPTZ,
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_package_versions_package_version_active ON package_versions (package_id, version) WHERE deleted_at IS NULL;
CREATE INDEX idx_package_versions_status ON package_versions (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_package_versions_release_channel ON package_versions (release_channel) WHERE deleted_at IS NULL;

ALTER TABLE packages
    ADD CONSTRAINT packages_latest_version_id_fkey
    FOREIGN KEY (latest_version_id) REFERENCES package_versions (id) ON DELETE SET NULL;

CREATE INDEX idx_packages_latest_version_active ON packages (latest_version_id) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- package_files
--
-- PKG-001 §5/§12/§13 the physical `.oep` package artifact for a given
-- version: required integrity hashes (§12 — SHA-256 required, BLAKE3
-- recommended) and signing metadata (§13 — Ed25519). `storage_path` is
-- deliberately opaque to this schema (filesystem path, object storage
-- key, etc.) — the persistence layer's Download API resolves it, not
-- this table.
CREATE TABLE package_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_version_id UUID NOT NULL REFERENCES package_versions (id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    mime_type TEXT NOT NULL DEFAULT 'application/vnd.oep.package',
    size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
    storage_path TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    blake3 TEXT,
    signature_algorithm TEXT,
    row_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_package_files_version_active ON package_files (package_version_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_package_files_sha256 ON package_files (sha256) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------
-- downloads
--
-- EXC-002 §14 Publisher Analytics ("Downloads") / EXC-004 §8 package
-- listing "Download Count". An append-only event log, not a mutable
-- entity — no `row_version`/`updated_at`/`deleted_at`: a download
-- event, once recorded, is never edited or soft-deleted, only ever
-- aggregated (e.g. `COUNT(*) GROUP BY package_version_id`).
CREATE TABLE downloads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_version_id UUID NOT NULL REFERENCES package_versions (id) ON DELETE CASCADE,
    downloaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    client_ip INET,
    user_agent TEXT
);

CREATE INDEX idx_downloads_version ON downloads (package_version_id);
CREATE INDEX idx_downloads_downloaded_at ON downloads (downloaded_at);

-- ---------------------------------------------------------------------
-- audit_log
--
-- WP-EXC-002.md §4/§6 — Exchange audit events (`AuditRepository`). An
-- append-only event log, like `downloads`: no `row_version`/
-- `updated_at`/`deleted_at`. `entity_type`/`entity_id` identify the
-- affected row polymorphically (across `publishers`, `packages`,
-- `package_versions`, etc.) — deliberately not a foreign key, since no
-- single column can reference multiple tables; `entity_type` values
-- correspond to this schema's own table names. `action` is
-- intentionally unconstrained TEXT rather than a CHECK enum: audit
-- actions span every entity type in this schema (EXC-002 §18 alone
-- lists seven Publisher-specific event names), and a single shared enum
-- would need a migration every time any entity gains a new action.
-- `actor` identifies who/what performed the action as free text
-- (a Publisher id, an administrator identifier, or `'system'`) — full
-- identity/authentication is out of WP-EXC-001's scope, so this column
-- is deliberately not a foreign key to any identity table.
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    action TEXT NOT NULL,
    actor TEXT,
    metadata JSONB NOT NULL DEFAULT '{}',
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_entity ON audit_log (entity_type, entity_id);
CREATE INDEX idx_audit_log_occurred_at ON audit_log (occurred_at);
