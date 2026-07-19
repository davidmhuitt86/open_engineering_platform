# Exchange Database

PostgreSQL, migrated with Flyway (per WP-EXC-001 §7).

**Status:** Real schema (TASK-EXC-0002, per its own task specification `docs/tasks/WP-EXC-002.md`). `migrations/` contains the initial 8-table schema (`publishers`, `publisher_profiles`, `package_categories`, `packages`, `package_versions`, `package_files`, `downloads`, `audit_log` — Publisher Registry per EXC-002, Package Catalog per PKG-002, audit trail per WP-EXC-002.md §4/§6) plus a seed migration for the initial engineering categories (WP-EXC-002.md §9). Search indexing (`search_index`) was explicitly out of that task's scope and deferred to the Search task, TASK-EXC-0006, which has since built it — see `docs/architecture/REPOSITORY_STRUCTURE.md` §11.1/§16 for the full reconciliation. `downloads` itself was likewise built ahead of its own task, TASK-EXC-0007 (the Download Service), which needed no new migration at all — see `docs/architecture/REPOSITORY_STRUCTURE.md` §17.

## Layout

- `migrations/` — versioned Flyway SQL migrations (`V{n}__description.sql`), applied in order, never edited once committed.
  - `V1__initial_exchange_schema.sql` — the 8 tables above.
  - `V2__seed_categories.sql` — seeds Automotive, Industrial, Residential, Commercial, Marine, Powersports, Robotics, Education (WP-EXC-002.md §9).
  - `V3__publisher_registration_fields.sql` (TASK-EXC-0003) — adds `publishers.contact_email` and unique partial indexes on `name`/`contact_email` (active rows), per `docs/tasks/WP-EXC-003.md` §5/§6.
  - `V4__package_name_uniqueness.sql` (TASK-EXC-0004) — adds a unique partial index on `packages (publisher_id, title)` (active rows), per `docs/tasks/WP-EXC-004.md` §6 "Duplicate package names within a publisher".
  - `V5__search_index.sql` (TASK-EXC-0006) — adds `search_index` (a generated, GIN-indexed `tsvector` column over each Package's searchable text) and a trigger on `packages` that keeps it current automatically, per `docs/tasks/WP-EXC-006.md` §3/§5 and `docs/architecture/REPOSITORY_STRUCTURE.md` §16.
  - `V6__installations.sql` (TASK-EXC-0008) — adds `installations`, one row per attempt to install a Package version into an OEP Repository, per `docs/tasks/WP-EXC-008.md` §4/§8 and `docs/architecture/REPOSITORY_STRUCTURE.md` §18.
  - `flyway.toml` — Flyway configuration (see "Running migrations" below).

## Conventions

- One migration file per schema change, named `V{n}__{snake_case_description}.sql`.
- Migrations are forward-only; a mistake is corrected by a new migration, never by editing a committed one.
- No manual database changes — every schema change goes through a migration (WP-EXC-001 §4: "No manual database changes are required").
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` is the true primary key of every table (WP-EXC-002.md §8) — not a surrogate `BIGSERIAL` with a separate external UUID column (the convention `oep_acquisition` uses; TASK-EXC-0002 established this as the Exchange's own distinct convention after reconciling its draft against WP-EXC-002.md's explicit requirement).
- Every mutable table carries `row_version INTEGER NOT NULL DEFAULT 1`, an optimistic-concurrency counter incremented on every UPDATE (WP-EXC-002.md §8 "Optimistic version fields"). Append-only event logs (`downloads`, `audit_log`) have none.
- Enums remain `TEXT NOT NULL CHECK (...)`, never native `ENUM` — a future allowed value is a plain migration rather than one subject to native-enum transactional restrictions.
- Soft delete via nullable `deleted_at`; partial indexes scoped `WHERE deleted_at IS NULL`.

## Running migrations

A real PostgreSQL database is required — this is left to a developer/operator, not run automatically by the build or test suite. First, create the role and database `flyway.toml` targets by default:

```sql
CREATE ROLE oep_exchange LOGIN PASSWORD 'your-local-dev-password';
CREATE DATABASE oep_exchange OWNER oep_exchange;
```

Then either edit `migrations/flyway.toml`'s `password` locally (never commit a real credential there — it is deliberately checked in blank), or pass it on the command line. From this `db/` directory, with the [Flyway CLI](https://flywaydb.org/) installed:

```sh
flyway -configFiles=migrations/flyway.toml -password=your-local-dev-password migrate
```

`locations = ["filesystem:./migrations"]` in `flyway.toml` is resolved relative to the current working directory Flyway is invoked from (`db/`), not the config file's own location — hence running the command from `db/`, not from the repository root or from inside `migrations/`.

## Testing without a live database

Following `oep_acquisition`'s own precedent (see its README's "Repository/API/migration categories" testing section): `apps/exchange-api`'s repository and integration tests apply these migration files verbatim from disk against a real database when one is reachable, `TRUNCATE ... CASCADE` the affected tables between test runs, and **skip (never fail)** when no database is reachable, so the suite stays runnable without a live database, just less exercised. Connection settings are overridable via environment variables, which take precedence over `flyway.toml`'s defaults:

```
OEP_EXCHANGE_TEST_DB_HOST, OEP_EXCHANGE_TEST_DB_PORT, OEP_EXCHANGE_TEST_DB_NAME,
OEP_EXCHANGE_TEST_DB_USER, OEP_EXCHANGE_TEST_DB_PASSWORD
```

No Flyway CLI install is required to run the tests (they apply the SQL files directly), though a production deployment should still apply migrations via Flyway as described above.
