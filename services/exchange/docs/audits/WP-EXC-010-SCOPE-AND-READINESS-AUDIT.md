# WP-EXC-010 — Exchange RC1 + OEP Studio Integration
## Scope & Architecture Readiness Audit

**This is an audit, not an implementation.** No production code was modified to produce this document. It exists to establish the exact, evidence-based scope for WP-EXC-010 now that WP-EXC-011 (Exchange Workspace Reconstruction) and WP-EXC-012 (Exchange Client API Foundation) are both complete. Companion documents: `docs/tasks/WP-EXC-010-SCOPE.md` (the proposed final work package definition this audit produces) and the historical `docs/tasks/WP-EXC-010.md` (unmodified, retained as-is — see this document's own findings on why it is stale).

---

## 1. Audit scope

Exchange's actual current-state implementation (`apps/*`, `packages/*`), the actual backend API contract, the actual Exchange client contract, the actual OEP Studio Exchange integration (which turned out to already exist, extensively — the single largest finding of this audit), the actual Foundation Repository install/trust capability, and the actual gap between all of the above and a genuine, demonstrable end-to-end vertical slice.

## 2. Executive summary — the central finding

**OEP Studio already has a substantial, working Exchange integration** — a full workspace (`ExchangeStudioPage`), five in-workspace sections (Marketplace Home, Search, My Library, Downloads, Publishing), package/publisher detail drill-downs, a real HTTP-backed `ExchangeApiClient` (Dart), persistent local library/download storage, a settings page for the API base URL, and full registration in `StudioRegistry`/`SurfaceRegistry`/the command palette/global search — all of it already labeled `WP-EXC-010` in its own doc comments. This is dramatically further along than the original `docs/tasks/WP-EXC-010.md` ("Status: Planned") describes, and the original spec's framing of Studio integration as the main remaining task is **stale**.

**The one genuine, well-evidenced architectural gap this audit found**: Studio's Exchange "Install" action currently calls only Exchange's own backend REST API (`POST /packages/{id}/install`), which — confirmed by reading `apps/exchange-api/src/app.ts` — defaults to a `StubRepositoryClient` that fabricates a fake `repositoryPackageId` and never touches a real OEP Repository. Meanwhile, Foundation's Public C API already has a **real, working, already-Dart-FFI-bound** package-install capability (`oep_package_install`, wrapped as `FoundationBridge.installPackage(archivePath)`), already used today by a separate, unrelated Studio page (`package_manager_page.dart`, a manual "browse for a local `.oep` file and install it" feature) — and this real install path **already performs genuine Ed25519 trust/signature verification** (`FoundationRuntime::install_package` calls `oep::installer::verify_package_trust(...)` before any repository transaction, per WP-REP-004/PKG-005). Studio's Exchange integration and Foundation's real installer are two fully-built, fully-working systems that have simply never been connected to each other. Closing that one connection — not building new architecture, not inventing a trust system, not redesigning Studio — is the crux of what remains for a genuine RC1 vertical slice.

**The second most significant gap**: no publisher-facing upload UI exists anywhere (neither `publisher-portal` nor Studio), despite a real, tested backend upload pipeline (`POST /packages/upload`, WP-EXC-005) already existing. `publisher-portal`, despite its name, is a **consumer-facing marketplace app only** — browse/search/detail/download/install — with zero package-creation/publish screens. Studio's own `ExchangePublishingPanel` is a deliberately honest "not yet available" placeholder, whose own doc comment independently confirms (written before this audit, by a different task) that no publish/build/sign capability exists in either the Foundation Bridge or the Exchange client.

## 3. Original WP-EXC-010 scope vs. current recommended scope

**ORIGINAL WP-EXC-010 SCOPE** (`docs/tasks/WP-EXC-010.md`, unmodified, Status: Planned): frames the work as pure "integration, validation, bug fixes, documentation completion, Studio wiring" over an assumed-complete Exchange, validating an 11-stage workflow (Publisher Registration → Package Registration → Package Upload → Search → Package Detail → Download → Install → Repository → Engineering Workspace) that it assumes already works end to end, needing only Studio wiring and a validation pass.

**Why it is stale**: it assumes (a) Studio integration has not started (false — extensive, already-built, already-registered), (b) the Repository/Engineering-Workspace end of the chain already works (false — Exchange's own install path is fully stubbed, and nothing today calls Foundation's real installer from the Exchange flow), (c) publisher registration/upload has a working UI (false — no UI exists anywhere; only a backend API), and (d) "no architectural redesign shall occur" together with treating Repository integration as a validation-only step (in tension — bridging Exchange to the real installer is new wiring, not merely validation, though it requires no redesign of either side).

**CURRENT RECOMMENDED WP-EXC-010 SCOPE**: build and verify the smallest genuinely complete Exchange → OEP vertical slice by (1) wiring Studio's existing Exchange "Install" action to actually invoke Foundation's existing, trust-verifying `FoundationBridge.installPackage` after downloading real package bytes, (2) deciding and documenting (not necessarily building) how/whether a minimal publisher upload path enters RC1, (3) closing the specific, named test/verification gaps this audit found, and (4) leaving everything else the original spec listed as excluded (auth, commerce, licensing, reviews, ratings, publisher administration, new features) — those exclusions remain correct and are not challenged by this audit's findings. See `docs/tasks/WP-EXC-010-SCOPE.md` for the full proposed definition.

## 4. Component-by-component classification

| Component | Classification | Evidence |
|---|---|---|
| `apps/exchange-api` | **PARTIAL** | Real Fastify app; publishers/packages/search/upload/installation/download routes all real and tested; `RepositoryClient` defaults to `StubRepositoryClient` (`app.ts`) — installation never reaches a real Repository |
| `apps/exchange-admin` | **FOUNDATION ONLY** | `App.tsx`/`main.tsx` only, explicit "scaffolded, not yet implemented" doc comment; RC1 does not require it (unchanged exclusion from the original spec) |
| `apps/publisher-portal` | **PARTIAL** | Consumer-facing marketplace flows (search/browse/detail/download/install) real and tested (WP-EXC-012 unblocked it fully); zero publisher-facing upload/publish screens exist |
| `packages/core` | **COMPLETE** (for what it defines) | `Result`, `DomainError` family, `newId`, `Clock` — genuinely used throughout, restored/verified in WP-EXC-011 |
| `packages/api-contracts` | **COMPLETE** (for currently-implemented routes) | Every DTO used by every real route, restored/verified |
| `packages/manifest` | **PARTIAL** | Real parse/extract logic; reads (does not verify) a `signatures` block — signature verification explicitly out of this package's own scope |
| `packages/signing` | **NOT STARTED** | Pure `PACKAGE_NAME` scaffold, unchanged since `TASK-EXC-0001`; its own doc comment says real implementation "arrives in TASK-EXC-0005," but WP-EXC-005's actual delivered scope explicitly excluded it (`process-upload.ts`'s own comment) |
| `packages/search` | **COMPLETE** (for the current query surface) | Real query normalization/pagination, backs the real `/search` route |
| `packages/package_manager` | **PARTIAL** | Real archive-extraction/manifest-parsing/metadata-extraction orchestration (`processUpload`); no signature verification (by design, deferred) |
| `packages/exchange_client` | **COMPLETE** (as of WP-EXC-012) | Real `ExchangeApiClient`/`ExchangeApiError`, every method mapped to a real route, 24/24 tests passing |
| `packages/installer` | **PARTIAL** | Real `RepositoryClient` interface + two real implementations (`StubRepositoryClient`, `HttpRepositoryClient`); `HttpRepositoryClient` targets an HTTP endpoint (`{baseUrl}/api/v1/packages/install`) that does not exist anywhere in this monorepo — Foundation has no HTTP server at all (confirmed: zero `httplib`/HTTP-server evidence in `platform/oep_foundation`) |
| `packages/dependency_resolver` | **NOT STARTED** | Pure scaffold, explicitly deferred past MVP per its own README; not required by any current route (a Package's `dependencies` are stored/returned as data, never resolved/enforced) |
| `packages/update_service` | **NOT STARTED** | Pure scaffold; no update/versioning workflow exists beyond storing multiple `PackageVersion` rows |
| `packages/licensing` | **OUT OF SCOPE** | Explicitly excluded from WP-EXC-001's own scope; pure scaffold, unchanged |
| `packages/payments` | **OUT OF SCOPE** | Same as licensing |
| `packages/reviews` | **OUT OF SCOPE** | Same as licensing |
| `packages/interfaces` | **COMPLETE** (for its one defined contract) | `RepositoryClient` type contract, real, used by `installer` |

## 5. Current Exchange workflow — arrow-by-arrow

| Step | State | Evidence |
|---|---|---|
| Publisher → Package creation | **MISSING (UI)** / EXISTS (data model + API) | `POST /publishers`, `POST /packages` routes exist and are tested; no UI creates either anywhere |
| Package creation → Manifest | **EXISTS** | `POST /packages/upload` parses a real manifest from the archive (`packages/manifest`) |
| Manifest → Signing | **MISSING** | `signing` package is a pure scaffold; manifest's `signatures` block is read, never verified, at upload time |
| Signing → Upload | **PARTIAL** | Upload itself works and is tested; nothing about signing gates it |
| Upload → Exchange repository (catalog) | **EXISTS** | Real DB persistence (`PackageRepository`/`PackageVersionRepository`/`PackageFileRepository`), tested |
| → Search | **EXISTS** | Real `/search` route + `publisher-portal` consumer, tested end to end (WP-EXC-012) |
| → Package detail | **EXISTS** | Real `/packages/{id}` route + `publisher-portal`/Studio consumers, tested |
| → Download | **EXISTS** | Real `/packages/{id}/download` route (binary, streamed) + both `publisher-portal` (href) and Studio (`downloadPackage`, bytes-to-file) consumers |
| → Install | **PARTIAL / SIMULATED** | Real `/packages/{id}/install` route exists and is tested — but resolves against `StubRepositoryClient` by default; the response is a real, well-formed `InstallationDto`, but `repositoryPackageId` is fabricated (`stub-{packageId}@{version}`), not a real Repository record |
| Install → Local OEP repository | **MISSING (the real connection)** | Foundation's real, working `oep_package_install`/`FoundationBridge.installPackage` is never called anywhere in the Exchange flow — it exists and works, but only for the unrelated manual "Package Manager" page |
| Repository → Engineering Workspace | **UNTESTED / LIKELY EXISTS** | Once a package is genuinely installed via `FoundationBridge.installPackage`, its Engineering Objects exist in the open Repository exactly as `package_manager_page.dart`'s own already-working flow proves; whether/how a Studio surface then opens/uses that specific asset was not traced further in this audit (out of this audit's most load-bearing path) |
| → Engineering Object / usable asset | **EXISTS, independent of Exchange** | Object creation is the Repository's own established behavior (WP-012/WP-014 in the Public C API), unrelated to and unaffected by anything Exchange-specific |

**Smallest complete chain that can be made RC1**: Search → Package Detail → Download → **real** Install (the one link that needs building) → Repository. Publisher/Manifest/Signing/Upload already function via the API (even without a UI) well enough to seed real test data for this chain; they do not need a UI to prove the vertical slice, only a decision about whether RC1 needs one (§6, §16).

## 6. Publisher workflow

**Current screens**: none, in either `publisher-portal` or Studio. `publisher-portal`'s seven pages (Marketplace Home, Categories, Search Results, Package Detail, Publisher Profile, My Library, 404) are all consumer-facing. Studio's `ExchangePublishingPanel` is a placeholder explicitly stating no capability exists.

**Current API calls available (backend, unconsumed by any UI)**: `POST /publishers` (register), `POST /packages` (register), `POST /packages/upload` (upload + parse + catalog).

**Missing**: any UI to call the above three routes; any UI-level manifest-building/packaging step (there is no ".oep archive builder" anywhere in this repository — a publisher today would need to hand-construct a `.oep` ZIP archive themselves, outside any tool this repository provides); any signing UI (moot until the `signing` package itself is real).

**Upload behavior**: real, validated (`validatePublisherId`/`validateCategoryId`/`validateFilePresent`), namespace-checked against the publisher, duplicate-version-checked, content-hashed (SHA-256) and stored, audited. Genuinely solid for what it does — it simply has no caller today besides a raw HTTP request.

**Classification: FOUNDATION ONLY** for the publisher workflow specifically (real backend, zero UI). This is a genuine RC1 scope decision (§16), not an ambiguity: RC1 can reasonably ship without a publisher UI if its own test/demo data is seeded directly through the existing, real, tested upload API (exactly as WP-EXC-011/012's own test fixtures already do) — matching "prove the architecture," not "build the whole Exchange."

## 7. Exchange Admin

**Current role**: none — an empty Vite/React scaffold proving the toolchain works, nothing else. **RC1 does not require it** — this matches the original spec's own exclusion of "Administration," and this audit found no reason to revisit that exclusion.

## 8. Exchange API — route inventory

| Method | Endpoint | Existing | Consumer | RC1 Required | Tested |
|---|---|---|---|---|---|
| GET | `/health` | Yes | Studio (`checkHealth`) | Yes | Yes |
| GET | `/search` | Yes | publisher-portal, Studio | Yes | Yes |
| GET | `/packages` | Yes | Studio (`listPackages`) | Yes | Yes |
| GET | `/packages/{id}` | Yes | publisher-portal, Studio | Yes | Yes |
| POST | `/packages` | Yes | none (no UI) | Not required for the vertical slice (data can be seeded directly) | Yes |
| PUT | `/packages/{id}` | Yes | none | No | Yes |
| DELETE | `/packages/{id}` | Yes | none | No | Yes |
| POST | `/packages/upload` | Yes | none (no UI) | Not required for the vertical slice UI-wise; required as the seeding mechanism for the slice's test data | Yes |
| GET | `/publishers` | Yes | publisher-portal, Studio | Yes | Yes |
| GET | `/publishers/{id}` | Yes | publisher-portal, Studio | Yes | Yes |
| POST | `/publishers` | Yes | none | Not required for the slice UI | Yes |
| PUT | `/publishers/{id}` | Yes | none | No | Yes |
| DELETE | `/publishers/{id}` | Yes | none | No | Yes |
| POST | `/packages/{id}/install` | Yes | publisher-portal, Studio | Yes — but its Repository-side effect must change (§9, §12) | Yes (against the stub) |
| GET | `/installations/{installationId}` | Yes | publisher-portal, Studio | Yes | Yes |
| GET | `/packages/{id}/download` | Yes | publisher-portal, Studio | Yes | Yes |
| GET | `/packages/{id}/versions/{version}/download` | Yes | none | No (no current consumer needs a specific version) | Yes |

**No missing endpoint was identified as required for the RC1 vertical slice.** The one required change is not a new endpoint — it is what happens *after* `POST /packages/{id}/install` responds (§9, §12): the caller (Studio) must also perform a real local install, since the endpoint's own `RepositoryClient` abstraction has no real implementation to point at without inventing an HTTP Repository server that does not fit this monorepo's actual architecture (§12).

## 9. Exchange client — sufficiency audit

WP-EXC-012's `ExchangeApiClient` (TS) and Studio's own pre-existing `ExchangeApiClient` (Dart) both already cover every method the current consumer surface needs: `search.run`, `packages.get`, `publishers.get`, `publishers.list`, `installations.install`, `installations.get`, `downloads.url`/`downloadBytes`. **No missing client method was identified for the RC1 vertical slice.** The gap is not in the client — it is in what Studio does with the *result* of `installations.install`/`downloadBytes` (§12). The versioned-download method is the one theoretically-missing extension (§8 of WP-EXC-012's own audit already flagged this) but no current consumer requires it, so it remains correctly unimplemented.

## 10. Package management — actual capabilities

Directly answering the task's own checklist, against source:

- **Downloaded?** Yes, real (`/packages/{id}/download`, streamed, checksummed via response headers).
- **Verified?** Partially — the download response carries `X-Checksum-Sha256`; nothing on the client side currently re-verifies it against the byte stream before installing (a small, concrete gap — see §16).
- **Installed?** Simulated only, today (`StubRepositoryClient`). Genuinely possible via `FoundationBridge.installPackage`, which is not yet called from this flow.
- **Registered?** Yes, in the Exchange catalog (upload path) — but "registered in the OEP Repository's own Package Registry" only happens via the real installer, which this flow doesn't yet reach.
- **Version-selected?** Yes at the data level (`PackageVersion` rows, `currentVersion`); the install route accepts an optional `version`.
- **Dependency-resolved?** No — `dependency_resolver` is an unimplemented scaffold; a package's declared `dependencies` are stored and returned as data, never resolved or enforced anywhere.
- **Updated?** No update workflow exists (`update_service` is a scaffold); a new version simply becomes the package's new "current version" on the next upload.
- **Removed?** Packages/publishers have soft-delete routes (`DELETE`); no "uninstall from a Repository" flow exists through Exchange (Foundation itself has `oep_package_uninstall` per `foundation_bridge.dart`'s `uninstallPackage`, unrelated to Exchange).

**Minimum RC1 package-management behavior**: download, verify (checksum), install (real), list (already exists via `oep_package_list_installed`/Studio's Package Manager page). Dependency resolution, update, and uninstall-via-Exchange are correctly out of RC1's smallest-slice scope.

## 11. Signing / trust

- **What is signed?** Nothing today, in practice — no tool in this repository produces a signed `.oep` archive. The manifest format has a `signatures` block (PKG-002 §17) that Exchange's own `manifest` package reads structurally but never verifies.
- **What is verified?** On the **Foundation side**, genuinely real and already working: `FoundationRuntime::install_package` calls `oep::installer::verify_package_trust(archive_path, trust_store)` before any Repository Transaction begins (WP-REP-004, PKG-005), resolving to one of `Trusted`/`Unsigned`/`UnknownPublisher`/`ExpiredCertificate`/`RevokedCertificate`/`InvalidSignature`/`Tampered`, with Tampered/InvalidSignature/UnknownPublisher/ExpiredCertificate/RevokedCertificate rejecting the install outright and Unsigned proceeding unless the repository's own trust policy (`oep_trust_get_policy`/`set_policy`) requires signatures. **This exists and works today — it is simply never reached by the Exchange flow, because Exchange's own stubbed install path never calls it.**
- **What key/trust model exists?** Ed25519, local Trust Store (`settings/trust/` inside the repository), certificates added/revoked by explicit local action only — deliberately no online/Exchange-dependent trust authority (PKG-005 §3: "Verification shall never require access to the Engineering Exchange"), confirmed by direct reading of `trust_store.hpp`/`package_verifier.hpp`.
- **Is trust currently real or placeholder?** Real, on the Foundation/install side. Placeholder, on the Exchange/signing-package side (irrelevant to whether trust is enforced, since enforcement is correctly Foundation's job per the architecture, not Exchange's).
- **Is signing mandatory?** No, by default (`Unsigned` is accepted unless the repository's own trust policy is changed) — this is an existing, already-shipped default, not a new decision this audit is making.
- **Can a package be installed without a valid signature?** Yes, today, both through the manual Package Manager page (by design) and through Exchange once the real installer is wired in (also by design, unless RC1 chooses to flip the local policy — a configuration choice, not new engineering).
- **What should RC1 require?** Wire the existing, already-verified trust gate into the Exchange install path (free, since it is the same `oep_package_install` call) and **document**, not invent, the existing default-permissive policy. No new trust architecture is needed or should be built.

**Classification: IMPLEMENTED (Foundation-side, real) / MISSING (Exchange-side wiring to it)** — not an RC1 blocker requiring new security engineering, but a required wiring task (§16).

## 12. OEP Studio integration

**Existing, must-not-redesign**: `WorkspaceTabsController`, `SurfaceRegistry`, `StudioRegistry`, existing workspace routing, Diagram Studio, the application shell — none of these were touched or need to be for Exchange; Exchange already integrates through the same `StudioRegistry`/`SurfaceRegistry` pattern every other Studio destination uses (confirmed: `StudioDestination.exchange`, its own `pageBuilder`, `settingsProvider`, and three command-palette entries already registered in `studio_registry.dart`).

**Already built and reused correctly**: the entire `ExchangeStudioPage` workspace (five sections + two drill-downs), `ExchangeRuntimeNotifier` (the Connection-Manager-style single owner of Exchange state, explicitly modeled on `AcquisitionRuntimeNotifier`), `ExchangeApiClient` (Dart), persistent library/download storage, a Settings page for the API base URL, and integration into Studio's own global/unified search.

**The one integration point that needs new work, not redesign**: `ExchangeRuntimeNotifier.installPackage` must, after a successful Exchange-side install response (or in place of relying on it for the Repository-side effect), obtain the actual package bytes (already possible via the existing `_api.downloadBytes`/`downloadPackage` path) and call `ref.read(foundationRuntimeServiceProvider.notifier).bridge.installPackage(localTempPath)` — the exact call `package_manager_page.dart` already makes today for a manually-selected local file. This requires: writing the downloaded bytes to a temporary file (a small, new, narrowly-scoped utility — no equivalent exists yet in either Acquisition's or Exchange's own Studio code, confirmed by search) rather than the download path (which is the user's own chosen save location); everything else about the call is identical to the existing pattern.

**Error states**: `ExchangeRuntimeNotifier` already has a working error-surfacing convention (`lastError`, `ExchangeApiException`) and an `OperationEvent` publish for install progress/failure — this convention should be extended to cover a `FoundationBridgeException` from the new real-install call, not replaced.

**Offline behavior**: the existing `_ConnectionBanner` already handles "Exchange service unreachable" (network/service error states). A *local* Foundation/Repository failure during the new real-install step is a distinct failure mode not yet handled anywhere in this flow (§14).

## 13. Repository integration

Foundation's actual Repository install/query surface, already real, already tested at the Foundation layer (per its own doc comments) and already Dart-bound:

- `oep_package_install(runtime, archive_path, &result)` — real, offline, trust-verifying (§11), only valid from `RepositoryOpen` state, requires an uncompressed ("Stored" method) ZIP — a DEFLATE-compressed `.oep` archive fails with `OEP_ERROR_OPERATION_FAILED` (a real, concrete constraint on whatever `.oep` fixture is used to prove the vertical slice — no package-building tool exists anywhere in this repository, so a test fixture must be hand-built to this constraint).
- `oep_package_list_installed(runtime, &out_list)` — real, already used by `package_manager_page.dart`.
- `oep_package_verify(runtime, package_id, &out_result)` — a real, separate integrity-check call (distinct from the install-time trust check).
- `oep_package_uninstall` — real, bound as `FoundationBridge.uninstallPackage`, unrelated to Exchange today.

**RC1 requires**: repository registration and Engineering Object creation are already handled automatically, inside `oep_package_install` itself (it "creates [Engineering Objects/Relationships] through the same ObjectStore/RelationshipStore paths... records the install in the Package Registry, and rebuilds the Search/Graph indexes" per its own doc comment) — RC1 does not need to build or invent any of this; it needs only to **call** the existing function with a real, downloaded archive. Repository import, workspace opening, and package "activation" beyond installation were not traced further in this audit — the existing Package Manager page's own post-install behavior (a simple list refresh) is the nearest existing precedent, and RC1's exit criteria (§ WP-EXC-010-SCOPE.md) should require confirming what a Studio user can actually *do* with a freshly-Exchange-installed package's resulting Engineering Objects, since this audit did not independently verify that any Studio surface currently opens/uses them differently based on install origin (Exchange vs. manual).

## 14. Engineering Object boundary

Exchange's role is **(A): distribute/install packages**, never (B) create Engineering Objects itself, and Engineering Object creation is not a separate (C) import/activation step Exchange or Studio needs to build — it is already an intrinsic, automatic part of Foundation's own `oep_package_install` (confirmed by its doc comment: object/relationship creation happens as part of the install call itself, through the same paths ordinary object mutation uses). This means the boundary already exists correctly and by construction: **Exchange (and Exchange-side Studio code) must never parse, interpret, or construct Engineering Objects/Relationships itself** — it only ever hands a validated archive path to `oep_package_install` and lets Foundation's own, already-established object-creation machinery do that work, exactly as the manual Package Manager page already does. Nothing found in this audit suggests any temptation or existing code that violates this — the risk is purely forward-looking (a future engineer might be tempted to have Exchange "unpack" a package's Engineering Objects itself for a richer preview; this audit recommends against that explicitly, see §16/exit criteria).

## 15. Offline / network behavior

| Condition | Current behavior | RC1 requirement |
|---|---|---|
| No network (Exchange unreachable) | Handled — `_ConnectionBanner`, `ExchangeConnectionStatus.networkError` | Keep as-is |
| Server unavailable | Handled — same banner/status | Keep as-is |
| Package download failure | Handled — `ExchangeApiException` surfaces via `lastError` | Keep as-is |
| Partial download | **Not explicitly handled** — `downloadBytes` either completes or throws; no resumption/partial-file detection exists | Document as a known limitation; no retry/resume logic should be invented for RC1 (matches the task's own "do not invent retry behavior unless architecture already defines it") |
| Corrupt package | **Partially handled** — Foundation's installer will fail to parse a corrupt archive (`OEP_ERROR_OPERATION_FAILED`); nothing today re-verifies the SHA-256 checksum client-side before attempting install | Add a client-side checksum check before calling `installPackage` (small, concrete, in scope) |
| Invalid signature | **Handled, once wired** — Foundation's trust verification already rejects `InvalidSignature`/`Tampered` outright (§11) | Ensure the resulting `FoundationBridgeException` surfaces a clear, specific message, not a generic failure |
| Package already installed | **Handled** — `oep_package_install` fails with `OEP_ERROR_OPERATION_FAILED` if the `packageId` is already installed (per its own doc comment) | Surface this specific, already-distinguishable case with a clear message, not a generic error |
| Version mismatch | Not applicable at the install layer today (Foundation's installer has no explicit version-conflict concept beyond "already installed") | No new behavior needed |
| Dependency failure | Not applicable — dependency resolution does not exist (§10) | Out of RC1 scope, matches existing non-implementation |

## 16. Security

| Area | Classification | Note |
|---|---|---|
| Package authenticity | **PARTIAL** | Real Ed25519 verification exists (Foundation), unsigned packages accepted by default (an existing, disclosed platform default, not a new RC1 decision) |
| Integrity | **PARTIAL** | SHA-256 computed and served (download headers); not yet re-checked client-side before install (§15) |
| Transport security | **DEFERRED** | Exchange's API is plain HTTP in this environment (same-origin dev proxy); no TLS decision was made or is being made by this audit — out of scope, matches "do not solve unrelated ADR-0003" |
| Trust | **IMPLEMENTED** (Foundation) / **MISSING (wiring)** | See §11 |
| Local installation security | **IMPLEMENTED** | Foundation's installer already gates on repository state, archive readability, and trust — this audit found no path that bypasses it once wired in |
| Path traversal | **NOT INDEPENDENTLY VERIFIED** | `zip_reader.cpp`/`package_installer.cpp` were not audited path-by-path for traversal safety in this pass — flagged as a verification item for whoever implements the wiring, not assumed safe or unsafe |
| Malicious package considerations | **PARTIAL** | Trust verification covers tampering/signature forgery; no sandboxing/static-analysis of package contents exists or is expected for RC1 |
| Credential handling | **NOT APPLICABLE** | No authentication exists anywhere in Exchange (unchanged, correct exclusion) |
| Server trust | **DEFERRED** | `baseUrl` is user/operator-configured (Studio's own Settings page); no certificate pinning or server-identity verification exists — out of scope for RC1, matches the existing, already-shipped model |

**No RC1 blocker requiring a new security decision was found.** The trust-verification capability already exists, is already correct by this repository's own architecture (offline, local, Exchange-independent per PKG-005 §3), and needs only to be *invoked*, not designed.

## 17. End-to-end vertical slice

The smallest genuinely complete, demonstrable RC1 slice, evaluated against the task's own 12-step list:

1. **Publisher creates package** — via the existing, real `POST /publishers`/`POST /packages` APIs (no UI needed for RC1 — justified: proving the architecture does not require a publisher-facing product surface, only a real publisher/package to exist).
2. **Package has a valid manifest** — real, via `packages/manifest`; the test fixture must be a hand-built `.oep` archive using **Stored (uncompressed)** ZIP entries, per Foundation's installer's own documented constraint.
3. **Package is signed if required** — not required by RC1 (default policy is permissive); justified by §11/§16 — this is an existing platform default, not a gap RC1 must close.
4. **Package is uploaded** — via the existing, real, tested `POST /packages/upload`.
5. **Exchange stores package** — already real and tested.
6. **User searches Exchange** — already real and tested (both `publisher-portal` and Studio).
7. **User views package details** — already real and tested.
8. **User downloads package** — already real and tested.
9. **Package is verified** — needs a client-side checksum check added before install (§15), and already gets Foundation's own trust verification for free once wired in (§11).
10. **Package is installed** — **the one link that must be built**: Studio calling `FoundationBridge.installPackage` with the real downloaded archive.
11. **Package becomes available to OEP** — automatic, once #10 happens, per Foundation's own `oep_package_install` behavior.
12. **Studio can discover/use the installed package** — partially provable via the existing `oep_package_list_installed`/Package Manager page pattern; whether a *freshly Exchange-installed* package's resulting Engineering Objects are actually usable in a downstream Studio workflow (e.g. Diagram Studio) was not traced end-to-end in this audit and should be an explicit RC1 exit-criterion check, not an assumption.

**Explicitly NOT required for RC1** (with justification): a publisher-facing upload UI (§6 — the real API already exists and can seed the slice's own test data); `exchange-admin` (§7 — always excluded); dependency resolution, package updates, uninstall-via-Exchange (§10 — genuinely unimplemented and not needed to prove the architecture); authentication/commerce/licensing/reviews/ratings (§ original scope, unchanged, still correctly excluded).

## 18. Test strategy — what exists vs. what must be added

| Layer | Exists | Must be added |
|---|---|---|
| Package unit tests | Yes — `core`, `api-contracts`, `manifest`, `search`, `package_manager`, `exchange_client` all have real, passing test suites | None identified beyond ordinary maintenance |
| API tests | Yes — every route tested (`apps/exchange-api/src/routes/*.test.ts`) | A test proving `POST /packages/{id}/install` behavior is unaffected by whichever `RepositoryClient` is swapped in (already somewhat covered via `StubRepositoryClient({simulateFailure})`, per `installation.test.ts`) |
| Client tests | Yes — TS `exchange_client` (24/24, WP-EXC-012), Dart `exchange_api_client_test.dart` | None identified |
| Admin tests | N/A | None — `exchange-admin` out of RC1 scope |
| Publisher portal tests | Yes — full suite green (WP-EXC-012) | None for RC1's own vertical slice (no new publisher-portal UI is being added) |
| Studio integration tests | **Thin** — only 3 test files (`exchange_api_client_test.dart`, `exchange_models_test.dart`, `exchange_settings_test.dart`) for a substantial amount of implemented UI/service code (panels, `ExchangeRuntimeNotifier`, `ExchangeStudioPage` itself) | Tests for `ExchangeRuntimeNotifier.installPackage`'s new real-install path (success, trust-rejection, already-installed, corrupt-archive cases), and at least one widget-level test for the install action's error surfacing |
| Repository install tests | Real, at the Foundation/C++ layer (per its own test suites, not re-audited line-by-line here) | An integration test proving a *downloaded-from-Exchange* archive installs successfully through the new Studio-side wiring — the one test that actually proves the vertical slice |
| End-to-end test | **Does not exist today** | One test/demonstration script exercising the full chain: seed publisher/package via the real API → search → detail → download → real install → confirm via `oep_package_list_installed` |
| Security tests | Real, at the Foundation layer for trust verification (not re-audited line-by-line) | A test proving an Exchange-downloaded, intentionally-tampered or unsigned-when-required archive is correctly rejected once the real install path is wired in |
| Failure-path tests | Partial (§15 table) | Corrupt-archive, already-installed, and invalid-signature cases specifically through the new Studio-side call |

**Minimum release gate**: the end-to-end test (one real publisher → package → upload → search → download → real Foundation install → confirmed-installed check) plus the new `ExchangeRuntimeNotifier` unit tests above. Everything else in this table already exists and passes.

## 19. Work package breakdown (proposed, not implemented)

1. **WP-EXC-013 — Exchange → Repository Install Bridge**: wire `ExchangeRuntimeNotifier.installPackage` to download the real archive and call `FoundationBridge.installPackage`, replacing reliance on the Exchange-side stub for the Repository-side effect. Includes the small new temp-file utility, client-side checksum verification, and error-surfacing for the new failure modes (§15). This is the single highest-value, best-evidenced work package this audit identified.
2. **WP-EXC-014 — RC1 End-to-End Verification**: build the one missing end-to-end test/demonstration (§18), using a hand-built, Stored-ZIP `.oep` test fixture, seeded through the existing real upload API. Depends on WP-EXC-013.
3. **WP-EXC-015 — RC1 Studio Test Depth**: close the specific Studio-side test gaps §18 identifies (install success/failure/already-installed/corrupt cases). Can run in parallel with WP-EXC-014 once WP-EXC-013 lands.
4. **(Decision, not necessarily a WP) Publisher Upload UI** — only if RC1's own exit criteria are judged to require a product-facing publish flow rather than API-seeded test data; this audit's own recommendation is that RC1 does not need it (§6, §17), making this a founder decision point, not an automatically-required work package.

No unnecessary work package was created — dependency resolution, update service, licensing/payments/reviews, and `exchange-admin` are each already correctly excluded and do not need their own WP for RC1.

## 20. 0.2.x / versioning impact

None. No version was bumped by this audit. Exchange's foundation (workspace + client, WP-EXC-011/012) remains LOCAL / NOT PUSHED; this audit adds no new commit beyond its own documentation, also LOCAL / NOT PUSHED.
