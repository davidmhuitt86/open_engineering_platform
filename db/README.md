# Exchange Database

PostgreSQL, migrated with Flyway (per WP-EXC-001 §7).

**Status:** Directory structure only (TASK-EXC-0001). `migrations/` is intentionally empty — the Flyway configuration and the first migration (`publishers`, `publisher_profiles`, `packages`, `package_versions`, `package_categories`, `package_files`, `downloads`, `search_index`, per WP-EXC-001 §7) are TASK-EXC-0002's own deliverable, not this one, so that schema design and migration authoring happen together rather than the schema being guessed at ahead of the task that actually owns it.

## Layout

- `migrations/` — versioned Flyway SQL migrations (`V{n}__description.sql`), applied in order, never edited once committed.

## Conventions (for TASK-EXC-0002 onward)

Following `oep_acquisition`'s own established Flyway convention (the only other OEP repository using PostgreSQL + Flyway today) for consistency across the platform:

- One migration file per schema change, named `V{n}__{snake_case_description}.sql`.
- Migrations are forward-only; a mistake is corrected by a new migration, never by editing a committed one.
- No manual database changes — every schema change goes through a migration (WP-EXC-001 §4: "No manual database changes are required").
