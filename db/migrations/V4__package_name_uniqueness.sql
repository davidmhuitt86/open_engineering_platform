-- V4__package_name_uniqueness.sql
--
-- TASK-EXC-0004 (docs/tasks/WP-EXC-004.md §6): "Duplicate package names
-- within a publisher" must be rejected. `packages.title` (PKG-002's
-- "title" field, exposed by the Package Catalog REST API as
-- `displayName` — see docs/architecture/REPOSITORY_STRUCTURE.md §14.1)
-- had no uniqueness constraint before this task; it only needs to be
-- unique per-Publisher, not globally, since two different Publishers
-- may legitimately title a package the same thing (e.g. two publishers
-- each with a "Wiring Diagram" package). `packages.package_id` (the
-- PKG-001/PKG-002 reverse-domain identifier) already enforces global
-- uniqueness independently (V1) and is unaffected by this migration.

CREATE UNIQUE INDEX idx_packages_publisher_title_active
    ON packages (publisher_id, title)
    WHERE deleted_at IS NULL;
