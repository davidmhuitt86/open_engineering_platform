-- V9__reference_vault_fk_indexes.sql
--
-- WP-017 (EAM / Reference Vault Implementation Audit), Section 11
-- (Database Audit): every foreign key added in V2 through V7 got its own
-- dedicated index (idx_<table>_<fk_column>) alongside the constraint --
-- reference_vault (V8) added three foreign keys (verification_id,
-- download_session_id, source_id) but only indexed metadata_id (via its
-- own UNIQUE constraint) and sha256_hash/status. The three unindexed
-- foreign keys are exactly the columns GET /vault's existing
-- `metadata_id`-only filter today ignores but a future filter, a join
-- back to Verification/Download/Source for provenance reconstruction
-- (WP-017 Section 9), or an ON DELETE/UPDATE check against a large table
-- would need -- a missing FK index is a genuine, demonstrated gap this
-- audit's own Section 11 explicitly asks to look for, not a
-- hypothetical one.
--
-- Additive only: V1 through V8 remain untouched, per every prior
-- migration's own "Flyway migrations are immutable once committed" note.
-- No column, constraint, or existing index is changed or dropped.

CREATE INDEX idx_reference_vault_verification_id ON reference_vault (verification_id);
CREATE INDEX idx_reference_vault_download_session_id ON reference_vault (download_session_id);
CREATE INDEX idx_reference_vault_source_id ON reference_vault (source_id);
