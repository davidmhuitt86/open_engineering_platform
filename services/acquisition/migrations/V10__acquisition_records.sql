-- V10__acquisition_records.sql
--
-- WP-018 (Acquisition Record & Provenance Foundation): establishes the
-- Acquisition Record entity WP-017's audit found missing -- SDD-R015's
-- canonical, durable identity for one acquisition event. Added as V10 --
-- Flyway migrations are immutable once committed; V1-V9 are untouched.
--
-- `id`/`uuid` follow the same internal-surrogate-key /
-- externally-visible-identifier split as every prior domain table. `uuid`
-- is SDD-R015 Section 6's "Acquisition Identifier": globally unique, never
-- reused, stable for the record's lifetime.
--
-- `download_session_id` is a real foreign key to `download_sessions(uuid)`,
-- and is additionally UNIQUE: WP-018 Section 6 (Domain Model) establishes
-- exactly one Acquisition Record per Download Session -- one download
-- attempt is one acquisition event (SDD-R015 Section 8's per-acquisition
-- metadata list -- Source URL, Referrer, Redirect Chain, ETag -- describes
-- facts specific to a single fetch, not to the Acquisition Job as a whole).
-- A retried acquisition creates a new Download Session (WP-006's existing
-- behavior, unchanged by this migration) and therefore a new Acquisition
-- Record, satisfying SDD-R015 Section 15 ("Duplicate Acquisitions shall not
-- invalidate Acquisition Records... each acquisition event remains
-- historically significant") without inventing a second retry/versioning
-- mechanism.
--
-- No column here duplicates a relationship already reachable by traversing
-- existing foreign keys starting from `download_session_id` (Official
-- Source, Acquisition Job, Execution history, Integrity Verification,
-- Metadata Extraction) -- see
-- docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md's Provenance Model
-- section for the full traversal. `reference_vault` is likewise left
-- completely unmodified by this migration: a Vault Entry's owning
-- Acquisition Record is found by looking up
-- `acquisition_records.download_session_id = reference_vault.download_session_id`
-- (a column `reference_vault` already has, from V8), not by adding a new
-- column to either table.
--
-- `status` is SDD-R015 Section 5's lifecycle (Pending -> Acquired ->
-- Verified -> Published -> Archived), with `Failed` added alongside it --
-- see `AcquisitionRecordStatus`'s header comment (acquisition_record.hpp)
-- for why. This is the one field this row's `UPDATE`s ever touch (via
-- `IAcquisitionRecordRepository::update_status`) -- `download_session_id`
-- and `created_at` are set once at INSERT and never written again by any
-- code path in this module.
--
-- No `deleted_at` column: this WP's REST API has no DELETE route, and an
-- Acquisition Record's whole purpose is permanent historical identity.
--
-- Unlike V5-V8's own precedent of adding a redundant explicit
-- `CREATE UNIQUE INDEX` alongside a `UNIQUE` constraint that already
-- creates that exact index, this migration relies on the constraint's
-- automatically-created index alone for `uuid` and `download_session_id`
-- -- WP-018 Section 7 explicitly instructs "no redundant indexes," so this
-- migration follows that instruction over blindly repeating V5-V8's own
-- minor redundancy.

CREATE TABLE acquisition_records (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    download_session_id UUID NOT NULL REFERENCES download_sessions (uuid),
    status TEXT NOT NULL
        CHECK (status IN ('pending', 'acquired', 'verified', 'published', 'failed', 'archived')),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT acquisition_records_uuid_key UNIQUE (uuid),
    CONSTRAINT acquisition_records_download_session_id_key UNIQUE (download_session_id)
);

CREATE INDEX idx_acquisition_records_status ON acquisition_records (status);
