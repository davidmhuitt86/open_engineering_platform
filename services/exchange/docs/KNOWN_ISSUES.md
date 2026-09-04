# Engineering Exchange RC1 — Known Issues

## Studio Workspace/Repository integration

1. **"Open in Engineering Workspace" does not launch a specific installed asset.** It navigates to Studio's existing Project Explorer destination after a successful install, rather than opening the specific installed engineering asset directly. No generic "installed-package-asset-type → Studio destination" dispatch mechanism exists anywhere in `oep_studio` today, and `PackageDto`/`InstallationDto` don't carry an asset-type field to dispatch on even if one did — see `docs/guides/STUDIO_INTEGRATION_GUIDE.md` "Workspace Integration — known limitation." Building the real version of this is future work, not a defect introduced by this release.
2. **"Open Installed Package" is also best-effort.** It refreshes and navigates to the Repository destination rather than deep-linking to the specific installed package's own entry within it, for the same reason as (1).
3. **Unified Search's Exchange contribution is client-side and cache-only**, exactly like the existing Engineering Acquisition contribution it mirrors — it only searches packages/publishers Studio has already fetched into memory (via Marketplace Home or a prior Search), not the full server-side index. A user must open the Exchange Studio at least once in a session before Unified Search will surface Exchange results.
4. **Exchange commands in the Command Palette are limited to no-argument/one-argument operations** (`exchange.search`, `exchange.refreshMarketplace`, `exchange.refreshRepository`). "Install Package" is not a Command Palette command because it needs both a package id and a display name, which the current `CommandArgs` contract (a single optional `String`) cannot carry without changing that shared framework — out of scope for this Work Package.

## Environment/testing limitations (this validation pass, not product defects)

5. **No live PostgreSQL/Docker was available in the environment this Work Package was validated in.** `apps/exchange-api`'s repository/integration test suite (124 tests) skips cleanly rather than failing when no database is reachable (an existing, intentional convention — see `db/README.md` "Testing without a live database"), so those tests did not execute during this validation pass. The pure/unit/service test layers (316 tests) did execute and passed.
6. **No live, interactive end-to-end click-through** (a real `exchange-api` process + a running OEP Studio desktop build, driven manually through Publisher Registration → ... → Engineering Workspace) was performed in this environment, for the same reason. Validation instead traced the integration through the passing automated test suites of both repositories plus direct code inspection of the full call chain — see `docs/VALIDATION_REPORT.md`.

## Carried over from the MVP (pre-existing, not introduced by this release)

7. Authentication, Commerce, Licensing, Reviews, Ratings, Organizations, and Publisher administration remain unimplemented — all explicitly out of scope (WP-EXC-010 §2, and every prior task's own scope section).
8. No real OEP Repository exists yet; `exchange-api` talks to a `StubRepositoryClient` by default (a deterministic stand-in that reports success), per `docs/guides/INSTALLATION_GUIDE.md`. This is unchanged by RC1 and is not a Studio-integration defect — the same stub backs both the web app's and Studio's Install actions identically.
