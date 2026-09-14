# WP-SRV-005 — OEP Server Data Infrastructure Audit — 2026-09-14

Companion to [`ADR-0001`](../../architecture/decisions/ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md), [`ADR-0002`](../../architecture/decisions/ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md), [`ADR-0003`](../../architecture/decisions/ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md), and `services/acquisition/README.md`'s new "Database Provisioning & Migrations" section (this WP's primary documentation update).

## 0. Scope Determination — Read Before The Rest Of This Report

WP-SRV-005 as originally specified assumed a PostgreSQL-backed "OEP
Repository" persistence layer for Engineering Objects, Relationships,
and State (tables named `object_types`, `knowledge_domains`,
`object_states`, `universal_objects`). **This does not exist anywhere in
the repository**, and more importantly, building it would contradict
[`ADR-0001`](../../architecture/decisions/ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md) Section 4.6, which explicitly, currently, states that Foundation
(`platform/oep_foundation` -- the actual owner of "Engineering
Object/Relationship creation") **has no server-side existence at all**,
and that giving it one is an *explicit, separate, not-yet-made*
architectural decision (Gap G8), not something ADR-0001 or any other
ratified document has decided.

Per WP-SRV-005's own Section 38 ("inspect existing ADRs... do not
introduce an implementation that contradicts an existing ratified
architectural decision without stopping and reporting") and Section 43's
explicit stop conditions ("Repository architecture contradicts the
current implementation," "an existing ADR conflicts with the proposed
implementation," "persistence requires redesigning the Engineering
Object Model / Relationship Model"), this was reported to the user
directly (not silently narrowed) before any implementation began. The
user selected the recommended path: proceed with the parts of
WP-SRV-005 that are real and uncontested -- **EAM's own PostgreSQL
persistence and its already-implemented Reference Vault** -- and leave
the "OEP Repository" (Engineering Objects/Relationships/State) entirely
untouched, pending its own separate architectural decision.

**Every section below covers only that narrowed, user-approved scope.**
Acceptance-criteria items under WP-SRV-005's original "Repository"
heading (Engineering Objects/Relationships persisting in a
`universal_objects`-shaped schema) are explicitly **not attempted** and
are not claimed complete.

## 1. Baseline

`ce2fbf9` (WP-SRV-004), confirmed via `git rev-parse HEAD` and `git
status --short` (clean) before any change.

## 2. Database Inventory

- `oep_acquisition` -- EAM's real database. **Did not exist before this
  WP**; created here.
- `oep_acquisition_test` -- a second, identically-migrated database
  created for the automated test suite, so `TRUNCATE`-based test
  fixtures never touch the "live" database used for manual/demo
  verification.
- `oep_exchange` -- Exchange's own database (confirmed via
  `services/exchange/apps/exchange-api/src/persistence/config.ts`).
  Exchange is explicitly out of scope for this WP (Section 40 of its own
  text) and was not touched, queried, or provisioned.
- `eke`, `oep_foundation` -- do not exist, and per Section 0 above,
  correctly do not exist: EKE has no persistent database component in
  this repository, and Foundation has no server-side existence at all.

## 3. Application Role

`oep_acquisition` PostgreSQL role: `LOGIN`, a generated random password
(never committed, never printed after creation), `NOSUPERUSER
NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 20`. Owns both of
its own databases (`oep_acquisition`, `oep_acquisition_test`) -- full
DML/DDL rights within them, zero access to anything else on the
instance. This satisfies every explicit requirement in WP-SRV-005
Section 5 (least-privilege, not a superuser, not the `postgres` admin
account).

## 4. Credential Handling

The existing, already-established mechanism (confirmed by inspection --
`common::Config::load_from_file`, TOML) is file-based, not
environment-variable-based, unlike `OEP_API_TOKEN` (WP-SRV-003). Rather
than introduce a second, competing configuration mechanism (which
WP-SRV-005 Section 6 explicitly says not to do "unless required"), the
real password was supplied via a config file kept **entirely outside
the git repository** (`/opt/oep/config/acquisition.toml` on the VM, mode
`600`), passed to the binary via its existing, already-supported
`argv[1]` config-path override (`main.cpp`, present since
WORK_PACKAGE_001). This is the existing mechanism, used the way it
already supports being used -- not a new one. The repository's own
tracked `config/config.toml` still carries only its long-standing local
development default (`oep123`, pre-existing, not introduced by this WP)
and was not given the real credential.

## 5. Migration State

`migrations/flyway.toml` was rewritten to Flyway's current
`[environments.*]` schema -- its previous flat `[flyway]
url/user/password` form is from Flyway's pre-10.x configuration format
and is rejected outright by a real Flyway 10.20.1 CLI
("Failed to configure parameters: Parameter: flyway.password..."),
which is almost certainly the real reason README.md's own "not yet
invoked by any automated process" note had remained true through
WP-SRV-004. All 10 migrations (`V1` through `V10`) applied cleanly, in
order, to both `oep_acquisition` and `oep_acquisition_test`, verified via
`flyway info`/`flyway migrate` output showing every version installed
with no errors.

## 6. Schema Audit

Queried directly against `information_schema.table_constraints` /
`pg_indexes`: **zero** foreign-key columns anywhere in the schema lack a
covering index. WP-SRV-005's own text specifically asked whether the
previously-known "missing FK indexes in V7-V12" issue remained --
re-verified directly rather than assumed: it does not.
`V9__reference_vault_fk_indexes.sql` already closed that gap for `V8`
(WP-017, prior session); `V7`/`V10` never had it. 9 real tables plus
Flyway's own `flyway_schema_history`; every table carries a primary key,
appropriate foreign keys, `NOT NULL` constraints, `CHECK` constraints
(status/priority/trust-level enums), and `UNIQUE` constraints (`uuid`
columns, single-vault-entry-per-metadata-id) -- confirmed via a full
`pg_constraint` dump, not merely `\dt`.

## 7. Reference Data

Not applicable to this narrowed scope -- WP-SRV-005's "reference data"
requirement (`object_types`/`knowledge_domains`/`object_states`) belongs
entirely to the out-of-scope "OEP Repository" (Section 0). EAM's own
schema has no seed/reference-data tables of its own.

## 8. Repository / Relationships / Object State / Provenance (as WP-SRV-005 originally specified)

**Not attempted** -- Section 0.

## 9. Reference Vault

EAM's already-implemented Reference Vault (`services/acquisition/src/vault`,
built in WP-017/WP-SRV-002) is the real, existing artifact store this
WP's Sections 17-20/23 map onto. Verified directly, end-to-end, against
the real, freshly-provisioned database (not a fake/unit-test double):

- **Store**: a full pipeline run (Section 10 below) published a real
  artifact.
- **Content identity**: SHA-256, deterministic, content-addressable
  sharded path (`compute_vault_path`, pre-existing, unchanged) --
  confirmed the same hash was produced and reused correctly.
- **Retrieve**: `GET /vault/{id}/artifact` returned the exact original
  bytes (`stub-connector-fetch-placeholder`), with correct
  `Content-Type`/`Content-Length`/`X-Checksum-Sha256` headers
  (WP-SRV-002's contract, unchanged and reverified here against real
  data).
- **Integrity**: the SHA-256 recorded at publish time and the bytes
  retrieved afterward match exactly.
- **Survives restart**: confirmed directly (Section 11).
- **Immutability / cannot be silently overwritten**: unchanged,
  pre-existing behavior (`ReferenceVaultService::publish`'s
  content-addressable dedup logic) -- not modified by this WP.
- **Physical storage paths not exposed**: re-confirmed, and in the
  course of this verification, **a real leak was found and fixed** --
  see Section 13.

## 10. EAM → Reference Vault (Full Pipeline)

A complete, real, end-to-end pipeline was run through the live HTTPS +
Bearer-auth boundary (ADR-0002/ADR-0003, unchanged), against the newly
real database:

```
POST /sources        -> registered a real Official Source
POST /jobs            -> created against that source
POST /jobs/{id}/execute -> executed via the "example-stub" connector
POST /downloads        -> completed, real DownloadSession row
POST /verifications    -> SHA-256 computed and verified
POST /metadata          -> extracted
POST /vault              -> published, real VaultEntry row + real file on disk
GET /vault/{id}/artifact -> retrieved, byte-identical to the original
GET /acquisition-records/{id}/provenance -> full chain: source -> job ->
    execution_history -> download -> verifications -> metadata ->
    vault_entry, every field correctly linked
```

No step was faked, stubbed at the database layer, or run against an
in-memory fake -- every row above is a real PostgreSQL row, queryable
independently of the API.

## 11. Restart Test

EAM was stopped (`pkill`) and restarted with the identical config. The
previously-created Vault entry, its artifact bytes, and the previously
-created Source were all re-retrieved afterward with **identical IDs and
identical content** -- object identity and content both survive a full
process restart, satisfying WP-SRV-005 Section 12/26's requirement for
the parts of the system this narrowed scope covers.

## 12. Clean Initialization

`oep_acquisition_test` was migrated from a completely empty database
using only `flyway migrate` -- no manual SQL beyond the initial `CREATE
ROLE`/`CREATE DATABASE` (which is provisioning, not schema work).
Confirms the migration set is reproducible from scratch without
undocumented steps.

## 13. Security Finding (Discovered and Fixed During This WP)

While performing the storage-failure test (Section 15), a real
filesystem-path leak was found: `ReferenceVaultService::publish` used
the *throwing* overload of `std::filesystem::exists()` in two places: a
permission-denied error on the Vault's own storage directory produced an
uncaught `std::filesystem::filesystem_error` whose `what()` string
embedded the real server-local path (e.g.
`/opt/oep/artifacts/vault/fb/fb76434c...`), which `guard_vault`'s
generic `catch (const std::exception&)` then passed straight through to
the HTTP response. Separately, `ArtifactNotFoundError` and
`InvalidVaultPathError` (`vault_errors.hpp`) both embedded their own
`path`/`vault_path` constructor argument directly into their exception
message, which would leak the same way on their own respective failure
paths.

**Fixed** (all four changes are minimal, message/error-handling only --
no behavioral change to the publish logic itself):

1. `reference_vault_service.cpp`: both `std::filesystem::exists(...)`
   calls now use the non-throwing, `std::error_code`-out-param overload.
2. `vault_errors.hpp`: `ArtifactNotFoundError` and `InvalidVaultPathError`
   no longer include the path in their message (the parameter is still
   accepted, for call-site clarity, but unused in the resulting text).
3. `server.cpp`'s `guard_vault`: added an explicit
   `catch (const std::filesystem::filesystem_error&)` ahead of the
   generic handler, as defense-in-depth against any other
   not-yet-discovered path in the Vault pipeline that might someday
   throw the same way.

**Verified fixed**: re-ran the exact same storage-permission test after
rebuilding -- the response changed from a raw path-bearing 503
(`"filesystem error: status: Permission denied [/opt/oep/artifacts/vault/fb/...]"`)
to a clean, generic 422 (`{"error":"invalid_vault_path","message":"Vault
path did not validate."}`) with zero path content. The full regression
suite (256/256 test cases, 1188/1188 assertions) was re-run afterward on
both toolchains with no failures.

**Not fixed, recorded as a bounded gap**: this WP only hardened the one
route it was actively stress-testing (`/vault`). The same generic
`catch (const std::exception& ex) { respond_error(..., ex.what()); }`
pattern exists in every other `guard_*` function in `server.cpp`
(`guard_downloads`, `guard_verifications`, `guard_metadata`,
`guard_sources`, etc.) and could theoretically leak similarly if a
different, not-yet-triggered exception type (e.g. a raw `pqxx` exception
whose message happens to include more than the generic "lost
connection" text this WP's own DB-failure test observed) ever escapes
from one of those paths. Auditing and hardening every exception path
across the whole service is a larger, separately-scoped hardening
effort, not something this WP's specific, demonstrated finding required
expanding into.

## 14. EAM Database Integration / DB-Backed Routes

Every route in WP-SRV-005 Section 21's list was exercised for real,
against the real database, through the live pipeline (Section 10) or
directly: `/sources`, `/jobs` (+`/execute`), `/connectors` (in-memory,
unaffected), `/downloads`, `/verifications`, `/metadata`, `/vault`
(+`/{id}/artifact`), `/acquisition-records` (+`/provenance`) -- all
confirmed operating against genuine PostgreSQL state, not merely
responding to a request.

## 15. Failure Behavior

- **Database failure**: PostgreSQL was stopped mid-run. EAM's own direct
  response (bypassing the reverse proxy) was a clean `503
  {"error":"service_unavailable","message":"Lost connection to the
  database server."}` -- no credential, no connection string, no stack
  trace (this exact message originates from libpqxx itself, not
  application code, and happens to already be safe; see the generic-catch
  caveat in Section 13's "not fixed" note for why this isn't a
  guarantee for every possible driver exception). Through nginx, the
  same failure surfaced as nginx's own generic gateway-error JSON
  instead (`proxy_intercept_errors`, from ADR-0003) -- both are safe,
  neither leaks anything; documented as an observed behavioral
  interaction, not a defect.
- **Recovery**: restarting PostgreSQL alone was **not** sufficient --
  EAM held its original (now-dead) `pqxx::connection` objects and kept
  failing every request until EAM itself was restarted. This is a real,
  observed limitation (each repository holds exactly one
  non-reconnecting connection, opened once at startup) -- recorded here,
  not fixed, since implementing reconnection logic is itself a
  connection-management architecture change (see also Section 16's
  concurrency finding, same underlying root cause: one connection,
  no pool, no retry).
- **Storage failure**: see Section 13 -- correctly fails, does not
  falsely report success, and (after the fix) does not leak the path.

## 16. Concurrency

Basic concurrent access was tested directly, not merely reasoned about:
10 simultaneous `GET /vault` requests all returned consistent data.
5 simultaneous `POST /sources` requests, however, only succeeded 2-3
times out of 5 -- the others failed (either EAM's own generic 503 or an
nginx-level upstream-timeout-shaped failure). Root cause identified by
inspection: every `Postgres*Repository` class owns exactly **one**
`pqxx::connection` (`postgres_official_source_repository.cpp` and
siblings) -- not a connection pool, and libpqxx connections are not
safe for concurrent use by multiple threads. Under concurrent write
load, some requests contend for the same single connection. **This is a
genuine, discovered limitation of the pre-existing design**, not
something WP-SRV-005 introduced or was asked to redesign (its own
Section 31: "Do not introduce a new concurrency architecture... Record
any discovered limitations rather than redesigning them"). Documented in
`README.md`'s new "Database Provisioning & Migrations" section as a
concrete, reproducible finding for a future work package.

## 17. Transaction Integrity

Not independently re-tested beyond what already exists: the orphan-file
-race cleanup in `ReferenceVaultService::publish` (WP-017, unchanged by
this WP) already handles the one transactional edge case EAM's own
architecture has (a filesystem copy succeeding but the subsequent
database insert failing) -- covered by existing, still-passing tests
(`test_reference_vault_service.cpp`). No new transactional gap was found
during this WP's live pipeline testing.

## 18. Backup

`pg_dump -Fc` for `oep_acquisition`, plus `tar czf` of the Reference
Vault's `storage.root_path` directory (`/opt/oep/artifacts/vault` on
this VM) -- both are necessary, since artifact bytes live on the
filesystem, not inside PostgreSQL (confirmed by inspection of
`common::StorageConfig`/`ReferenceVaultService` -- there was never any
ambiguity here to resolve, but WP-SRV-005 Section 34 asked it to be
stated explicitly). Backups written to `/opt/oep/backups/` (VM-local,
outside the git repository, per the established infrastructure-config
precedent).

## 19. Restore

Performed directly, not merely described: `pg_restore` into a separate,
throwaway database (`oep_acquisition_restore_test`, dropped immediately
after verification -- the live `oep_acquisition` database was never
touched by this test). Confirmed afterward, by direct query: both known
Vault entries, the known Official Source, and both known Acquisition
Records were present and correct. The Vault artifact tarball was
extracted separately and its content byte-compared against the original
-- identical.

## 20. Security

- PostgreSQL remains bound to `127.0.0.1:5432` only (re-confirmed via
  `ss -tlnp`), with no `ufw` rule for `5432` (re-confirmed) -- unchanged
  from WP-SRV-001A, still holds after this WP's provisioning work.
- No database credential appears in any committed file (checked the
  actual `git diff` before staging -- Section 21 below).
- No credential was logged (EAM's own logging, checked directly) or
  returned by any API response.
- The one real leak found (Section 13) was fixed and reverified.

## 21. Tests

- **Windows/MSVC**: full suite, 256/256 test cases, 1188/1188
  assertions, 0 failed, run twice (once before the Section 13 fix to
  confirm baseline, once after to confirm no regression).
- **Linux/GCC, on the VM, against the real, isolated
  `oep_acquisition_test` database**: full suite, **256/256 test cases,
  1188/1188 assertions, 0 failed, 0 skipped** -- every previously-skipped
  database-backed test (from WP-SRV-002/003/004's runs, which lacked a
  provisioned role) now genuinely executed and passed, not merely
  compiled.
- New, live, non-unit-test verification (the actual point of this WP):
  the full pipeline (Section 10), restart test (Section 11), clean-init
  (Section 12), storage-failure/leak fix (Section 13), DB-failure
  (Section 15), concurrency (Section 16), and backup/restore (Sections
  18-19) were all exercised directly against a running server, not
  simulated.

## 22. Build

`oep_acquisition_api`, `oep_acquisition`, `oep_acquisition_tests` all
rebuilt cleanly on both MSVC (Windows) and GCC (Linux, VM). Zero new
warnings introduced by this WP's changes. The VM rebuild was run
single-threaded (`ninja -j1`) after an earlier `-j4` build briefly
triggered kernel soft-lockup warnings on this 4-vCPU VM (confirmed by
the user to be caused by contention with other work on the physical
host, not a guest-side problem) -- noted here since it shaped how this
WP's VM-side builds were executed, not because it reflects a defect in
this WP's own changes.

## 23. Documentation

- `services/acquisition/README.md` -- updated in place (new "Database
  Provisioning & Migrations" section; the pre-existing "Future
  Considerations" flyway note corrected to reflect that it now works).
  No duplicate document created, per WP-SRV-005's own instruction to
  update the existing authoritative source.
- `migrations/flyway.toml` -- rewritten to a working schema (Section 5).
- This audit document.
- ADR-0001/ADR-0002/ADR-0003: read for the Section 0 architecture check
  and for confirming this WP does not conflict with them; **none
  modified**.

## 24. Remaining Server Gaps

- The "OEP Repository" (Engineering Objects/Relationships/State) does
  not exist and was explicitly not built by this WP -- pending its own
  architectural decision (Section 0).
- No connection pooling / no automatic reconnection after a database
  outage (Sections 15-16) -- a real, demonstrated limitation of the
  pre-existing one-connection-per-repository design.
- No automated certificate/backup/migration scheduling -- everything in
  this WP was run manually and documented as a manual procedure.
- The generic-exception-leaks-`what()` pattern was fixed for `/vault`
  specifically (where it was demonstrated) but not audited across every
  other route (Section 13's "not fixed" note).

## 25. Recommendation

**COMPLETE** for the scope actually in play (EAM's own PostgreSQL
persistence, Reference Vault, DB-backed routes, backup/restore,
restart/clean-init/concurrency/failure behavior) -- verified directly,
end-to-end, against a real database, with a real, previously-unknown
security finding discovered and fixed along the way, not merely
asserted.

**NOT ATTEMPTED** for the "OEP Repository" (Engineering
Objects/Relationships/universal object model) portion of WP-SRV-005's
original text -- correctly deferred as its own, separate architectural
decision per ADR-0001's own explicit, already-ratified statement that
Foundation has no server-side existence today.
