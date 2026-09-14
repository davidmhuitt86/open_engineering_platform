-- WP-SRV-011: Server Repository persistence (ADR-0004/0005/0006).
-- Separate database, separate role, separate migration history from EAM's
-- own (ADR-0006 SS25) -- this file has no dependency on any EAM table.
--
-- Delete/tombstone, branching, merging, synchronization, authorization/
-- tenancy tables are deliberately absent -- explicitly out of scope for
-- this first slice (WP-SRV-011 Scope Exclusions).

CREATE TABLE repositories (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    author TEXT NOT NULL DEFAULT '',
    organization TEXT NOT NULL DEFAULT '',
    tags TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ADR-0006 SS9/SS21: repository-creation operation identities are
-- SERVER-SCOPED, not repository-scoped -- there is no repository_id to
-- scope into at the moment the identity is first received. This table
-- has no repository-partitioning column in its primary key; operation_id
-- alone is the whole-server namespace. `request_fingerprint` is a SHA-256
-- of the canonicalized creation request, used to distinguish "identical
-- retry" (return original result) from "reused identity, different
-- content" (IDEMPOTENCY_CONFLICT).
CREATE TABLE repository_creation_operations (
    operation_id UUID PRIMARY KEY,
    request_fingerprint TEXT NOT NULL,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- "Head" tables hold only the latest revision pointer for each object/
-- relationship, so current-state lookups and the optimistic-concurrency
-- check (ADR-0004 SS10) are O(1) and lockable via SELECT ... FOR UPDATE
-- without scanning history. The historical revisions themselves live in
-- the append-only tables below and are never updated or deleted
-- (ADR-0004 SS7: "revisions MUST NOT be deleted").
CREATE TABLE object_heads (
    object_id UUID PRIMARY KEY,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    current_revision BIGINT NOT NULL
);
CREATE INDEX idx_object_heads_repository ON object_heads(repository_id);

CREATE TABLE objects (
    object_id UUID NOT NULL REFERENCES object_heads(object_id),
    revision BIGINT NOT NULL,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    object_type TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    author TEXT NOT NULL DEFAULT '',
    tags TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    version TEXT NOT NULL DEFAULT '1.0.0',
    commit_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (object_id, revision)
);
CREATE INDEX idx_objects_repository ON objects(repository_id);

CREATE TABLE relationship_heads (
    relationship_id UUID PRIMARY KEY,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    current_revision BIGINT NOT NULL
);
CREATE INDEX idx_relationship_heads_repository ON relationship_heads(repository_id);

CREATE TABLE relationships (
    relationship_id UUID NOT NULL REFERENCES relationship_heads(relationship_id),
    revision BIGINT NOT NULL,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    source_object_id UUID NOT NULL,
    target_object_id UUID NOT NULL,
    relationship_type TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    author TEXT NOT NULL DEFAULT '',
    commit_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (relationship_id, revision)
);
CREATE INDEX idx_relationships_repository ON relationships(repository_id);
CREATE INDEX idx_relationships_source ON relationships(source_object_id);
CREATE INDEX idx_relationships_target ON relationships(target_object_id);

-- ADR-0006 SS9: commit operation identities are REPOSITORY-SCOPED --
-- UNIQUE(repository_id, operation_id), not a global primary key.
CREATE TABLE commits (
    commit_id UUID PRIMARY KEY,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    operation_id UUID NOT NULL,
    request_fingerprint TEXT NOT NULL,
    audit_event_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (repository_id, operation_id)
);
CREATE INDEX idx_commits_repository ON commits(repository_id);

-- Denormalized per-mutation outcome, so a commit's full result (ADR-0006
-- SS19/SS23) can be reconstructed on GET .../commits/{commit_id} without
-- re-deriving it from the objects/relationships tables.
CREATE TABLE commit_mutations (
    commit_id UUID NOT NULL REFERENCES commits(commit_id),
    seq INT NOT NULL,
    is_relationship BOOLEAN NOT NULL,
    entity_id UUID NOT NULL,
    resulting_revision BIGINT NOT NULL,
    PRIMARY KEY (commit_id, seq)
);

-- ADR-0006 SS27: minimal audit association -- not an enterprise audit
-- subsystem, and never itself mutated once written.
CREATE TABLE audit_events (
    event_id UUID PRIMARY KEY,
    repository_id UUID NOT NULL REFERENCES repositories(id),
    event_type TEXT NOT NULL,
    commit_id UUID,
    actor TEXT NOT NULL DEFAULT '',
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    description TEXT NOT NULL DEFAULT ''
);
CREATE INDEX idx_audit_events_repository ON audit_events(repository_id);
