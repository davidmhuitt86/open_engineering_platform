-- V5__search_index.sql
--
-- TASK-EXC-0006 (docs/tasks/WP-EXC-006.md): the Package Search table
-- deferred from TASK-EXC-0002 (see `docs/architecture/REPOSITORY_STRUCTURE.md`
-- §11.1) — TASK-EXC-0002 registered `audit_log` instead of `search_index`
-- as its eighth table, explicitly noting that search indexing was out
-- of scope and belonged to this task. This is that table.
--
-- One search document per Package (EXC-004 §4 "Search Sources" /
-- WP-EXC-006.md §5's searchable fields: Package name (`package_id`),
-- Display name (`title`), Description, Publisher (name/display name),
-- Category, Current version, plus PKG-002's own `keywords` field, which
-- exists specifically to aid discovery). `search_vector` is a
-- generated, stored column — Postgres maintains it automatically from
-- `search_text`, the same pattern this repository's own earlier design
-- work (recorded in this migration's history) already established.
--
-- Kept in sync by a trigger on `packages` rather than application code:
-- every task that already writes to `packages` (`PackageService`,
-- TASK-EXC-0004; `UploadService`, TASK-EXC-0005) needs zero changes to
-- keep the search index current — see this file's trigger function.
-- Publisher/Category name changes are not separately triggered (no
-- update path exists for either today); a soft-deleted Package's search
-- document is left in place but naturally unreachable, since every read
-- query joins back through `packages` and filters `deleted_at IS NULL`,
-- consistent with the soft-delete convention this schema already uses
-- everywhere else.

CREATE TABLE search_index (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES packages (id) ON DELETE CASCADE,
    search_text TEXT NOT NULL,
    search_vector TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', search_text)) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT search_index_package_id_key UNIQUE (package_id)
);

CREATE INDEX idx_search_index_vector ON search_index USING GIN (search_vector);

-- ---------------------------------------------------------------------
-- refresh_package_search_index()
--
-- Recomputes and upserts the search document for the Package the
-- triggering row represents, joining in the fields WP-EXC-006.md §5
-- names that don't live on `packages` itself (publisher name/display
-- name, category name, current version's semver string).
CREATE OR REPLACE FUNCTION refresh_package_search_index() RETURNS TRIGGER AS $$
DECLARE
    v_search_text TEXT;
BEGIN
    SELECT
        NEW.package_id || ' ' ||
        NEW.title || ' ' ||
        COALESCE(NEW.summary, '') || ' ' ||
        COALESCE(NEW.description, '') || ' ' ||
        pub.name || ' ' ||
        pub.display_name || ' ' ||
        COALESCE(cat.name, '') || ' ' ||
        COALESCE(kw.keywords_text, '') || ' ' ||
        COALESCE(ver.version, '')
    INTO v_search_text
    FROM publishers pub
    LEFT JOIN package_categories cat ON cat.id = NEW.category_id
    LEFT JOIN package_versions ver ON ver.id = NEW.latest_version_id
    LEFT JOIN LATERAL (
        SELECT string_agg(elem, ' ') AS keywords_text
        FROM jsonb_array_elements_text(NEW.keywords) AS elem
    ) kw ON true
    WHERE pub.id = NEW.publisher_id;

    INSERT INTO search_index (package_id, search_text)
    VALUES (NEW.id, v_search_text)
    ON CONFLICT (package_id) DO UPDATE SET
        search_text = EXCLUDED.search_text,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_packages_refresh_search_index
    AFTER INSERT OR UPDATE ON packages
    FOR EACH ROW
    EXECUTE FUNCTION refresh_package_search_index();
