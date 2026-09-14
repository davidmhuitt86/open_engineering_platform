-- WP-SRV-012: repository tombstone/delete semantics (ADR-0006 SS10).
--
-- Additive only -- no table is dropped or restructured, no history row is
-- ever removed. `is_tombstoned` on the "head" tables distinguishes LIVE
-- from TOMBSTONED current state (O(1), lockable via the existing
-- SELECT ... FOR UPDATE pattern); the same column on the append-only
-- history tables records whether a *specific past revision* was itself
-- the tombstone revision, so historical retrieval of that revision can
-- report it accurately. `commit_mutations.is_delete` lets a commit's
-- recorded outcome distinguish a delete mutation from a create/update
-- one without re-deriving it from the objects/relationships tables.

ALTER TABLE object_heads ADD COLUMN is_tombstoned BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE objects ADD COLUMN is_tombstoned BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE relationship_heads ADD COLUMN is_tombstoned BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE relationships ADD COLUMN is_tombstoned BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE commit_mutations ADD COLUMN is_delete BOOLEAN NOT NULL DEFAULT FALSE;
