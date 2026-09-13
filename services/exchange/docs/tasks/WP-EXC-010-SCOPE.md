# WP-EXC-010-SCOPE
## Exchange RC1 + OEP Studio Integration — Proposed Current Scope

**Status: PROPOSED / NOT IMPLEMENTED.** This document supersedes the *scope framing* (not the historical record) of `docs/tasks/WP-EXC-010.md`, which is retained unmodified. See `docs/audits/WP-EXC-010-SCOPE-AND-READINESS-AUDIT.md` for the full evidence behind every claim below.

---

## TITLE

WP-EXC-010 — Exchange RC1 + OEP Studio Integration (revised scope)

## OBJECTIVE

Prove a genuine, verified, end-to-end Exchange → OEP vertical slice — a publisher's package can be found, downloaded, and **really** installed into an open OEP Repository, becoming real Engineering Objects — by connecting two already-built, already-working systems (Studio's Exchange workspace and Foundation's package installer/trust verifier) that have simply never been wired to each other. This is not a build-Exchange-from-scratch task and not a build-Studio-integration-from-scratch task: both already exist.

## PRECONDITIONS

- WP-EXC-011 (Exchange Workspace Reconstruction) — COMPLETE WITH CONDITIONS, LOCAL / NOT PUSHED.
- WP-EXC-012 (Exchange Client API Foundation) — COMPLETE, LOCAL / NOT PUSHED.
- This scope audit (WP-EXC-010 scope/readiness) — COMPLETE, LOCAL / NOT PUSHED.
- The full Exchange workspace (all 14 packages + `exchange-api` + `exchange-admin` + `publisher-portal`) builds, typechecks, lints, and tests with zero failures (verified by WP-EXC-012's own report).

## IN SCOPE

1. **Exchange → Repository install bridge**: `ExchangeRuntimeNotifier.installPackage` (Studio, Dart) downloads the real package archive and calls `FoundationBridge.installPackage(localPath)` — the same, already-working, already-trust-verifying call `package_manager_page.dart` already makes for a manually-selected file — instead of relying on Exchange's own stubbed `RepositoryClient` for the Repository-side effect.
2. A small, narrowly-scoped temporary-file utility for the above (write downloaded bytes to a temp path before installing) — no equivalent exists yet; this is the one genuinely new piece of code this scope calls for beyond wiring.
3. Client-side SHA-256 checksum verification of the downloaded archive before installing (the download response already carries `X-Checksum-Sha256`; nothing currently re-checks it).
4. Specific, distinguishable error handling for the new failure modes this bridge introduces: corrupt/unreadable archive, invalid/tampered signature, already-installed package, unreachable/closed repository — surfaced through the existing `ExchangeServiceState.lastError`/`OperationEvent` conventions, not a new error-handling architecture.
5. One hand-built, Stored-ZIP (uncompressed) `.oep` test fixture, seeded into the Exchange catalog through the existing, real `POST /publishers`/`POST /packages`/`POST /packages/upload` APIs — proving the vertical slice does not require a publisher-facing UI to exist.
6. One genuine end-to-end test/demonstration exercising the full chain: seed → search → detail → download → real install → confirm via `oep_package_list_installed`.
7. Closing the specific Studio-side test-depth gaps this audit identified for `ExchangeRuntimeNotifier`'s install path (success, trust-rejection, already-installed, corrupt-archive).
8. Documentation reconciliation: correct `docs/tasks/WP-EXC-010.md`'s own successor status (a pointer to this document, not a rewrite of its history) and Studio's `ExchangePublishingPanel` comment if publisher upload remains out of scope (§ Out of Scope below) so it continues to describe reality accurately.

## OUT OF SCOPE

- A publisher-facing upload/publish UI (in either `publisher-portal` or Studio) — the real upload API already exists and is sufficient to seed the vertical slice's test data; building a UI for it is a separate, explicitly deferred decision (see Follow-On Work), not a precondition for proving the architecture.
- `exchange-admin` — remains a scaffold, unchanged, per the original WP-EXC-010's own exclusion.
- Authentication, commerce, licensing, reviews, ratings, organizations — unchanged exclusions from the original WP-EXC-010.
- Dependency resolution, package updates, uninstall-via-Exchange — genuinely unimplemented, not required to prove the architecture, and each large enough to be its own future work package if ever needed.
- Any change to `ADR-0003`, EAM's `HttpConnector`, or any unrelated OEP subsystem.
- Any new Foundation/Engine/Studio architectural decision — the trust-verification system, the Public C API's package-install surface, and Studio's `StudioRegistry`/`SurfaceRegistry` pattern are all reused exactly as they already exist.
- A new HTTP server anywhere in Foundation (`HttpRepositoryClient`'s target endpoint does not exist and this scope does not build it — the in-process FFI path via `FoundationBridge` is the correct, existing integration point, not a Repository-side HTTP API).
- Transport security (TLS), server-identity verification, and any change to the default (permissive, unsigned-allowed) trust policy — all existing, disclosed platform defaults, not new decisions this WP makes.

## ARCHITECTURE

```
Studio (ExchangeStudioPage / ExchangeRuntimeNotifier)
    |
    | (existing) search / detail / download bytes
    v
Exchange REST API (apps/exchange-api) -- unchanged
    |
    | (existing) POST /packages/{id}/install  [still called, for Exchange's own
    |             Installation record/tracking -- its RepositoryClient
    |             remains the stub for THAT bookkeeping purpose]
    v
[NEW] Studio writes downloaded bytes to a temp file, then calls
FoundationBridge.installPackage(tempPath)
    |
    v
Foundation Public C API: oep_package_install
    |
    +--> oep::installer::verify_package_trust (existing, real, Ed25519)
    +--> ObjectStore / RelationshipStore (existing, real, unchanged)
    +--> Package Registry record (existing, real, unchanged)
```

No component in this diagram is redesigned. The only new element is the connecting arrow between Studio's existing download result and Foundation's existing install call.

## DEPENDENCIES

WP-EXC-011, WP-EXC-012 (both complete, both LOCAL / NOT PUSHED). Foundation's existing, unmodified Public C API (`oep_package_install`, `oep_package_list_installed`, trust/signing surface) and its existing Dart FFI binding (`FoundationBridge`). Studio's existing `ExchangeRuntimeNotifier`/`ExchangeStudioPage`/`StudioRegistry` registration.

## IMPLEMENTATION PHASES

1. **Bridge**: implement the temp-file + `FoundationBridge.installPackage` call inside `ExchangeRuntimeNotifier.installPackage`, plus checksum verification and the new error paths.
2. **Fixture**: hand-build one Stored-ZIP `.oep` test package; seed it via the existing real upload API.
3. **Verification**: write the end-to-end test/demonstration and the Studio-side unit tests for the new code paths.
4. **Documentation**: reconcile `docs/tasks/WP-EXC-010.md`'s successor pointer and any Studio comment that becomes stale once the bridge exists (e.g. `ExchangePublishingPanel`'s comment, only if its own claims change — they do not, since publisher upload UI remains out of scope).

## TEST STRATEGY

See `docs/audits/WP-EXC-010-SCOPE-AND-READINESS-AUDIT.md` §18 for the full existing-vs-needed matrix. Minimum release gate: the new `ExchangeRuntimeNotifier` install-path unit tests (success, trust-rejection, already-installed, corrupt-archive) plus the one end-to-end test proving the full chain against a real Foundation repository.

## SECURITY REQUIREMENTS

None new. Reuse Foundation's existing, already-tested Ed25519 trust verification exactly as-is (default policy: unsigned packages allowed, matching the platform's existing, disclosed default). Add client-side checksum verification (integrity, not trust) before installing. Do not touch ADR-0003, `HttpConnector`, transport security, or the trust policy default — all explicitly out of scope.

## STUDIO INTEGRATION REQUIREMENTS

Reuse `ExchangeRuntimeNotifier`, `ExchangeStudioPage`, `StudioRegistry`/`SurfaceRegistry` registration, and the existing `OperationEvent`/`lastError` conventions exactly as they exist today. The only new Studio-side code is inside `ExchangeRuntimeNotifier.installPackage` itself (plus its new small temp-file helper) — no new workspace, no new navigation entry, no change to `WorkspaceTabsController`/Diagram Studio/the application shell.

## END-TO-END ACCEPTANCE

A single demonstrable flow: a package registered and uploaded through the existing real API is found via Search in the Exchange Studio workspace, its detail page shown, downloaded, and installed — with the install genuinely reaching Foundation's Repository (verifiable via `oep_package_list_installed` showing the new package, and via the Repository's own Engineering Object count increasing) — not merely receiving a fabricated `stub-...` acknowledgment from Exchange's own API.

## EXIT CRITERIA

- [ ] `ExchangeRuntimeNotifier.installPackage` calls `FoundationBridge.installPackage` with a real, downloaded archive.
- [ ] A downloaded archive's SHA-256 is verified against the server-supplied checksum before install is attempted.
- [ ] Corrupt-archive, invalid-signature, and already-installed failures are each surfaced distinctly, not as one generic error.
- [ ] One hand-built, Stored-ZIP `.oep` fixture exists and is used by the end-to-end test.
- [ ] The end-to-end test passes, demonstrating: seed → search → detail → download → real install → confirmed via `oep_package_list_installed`.
- [ ] The new Studio-side unit tests (§ Test Strategy) pass.
- [ ] No regression in any of the currently-passing Exchange or Studio test suites.
- [ ] No `.cpp`/`.hpp` change to Foundation's installer, trust store, or Public C API (this WP only calls existing functions).
- [ ] No new Foundation HTTP server was built; `HttpRepositoryClient` remains unused/undeleted, documented as intentionally dormant.
- [ ] `docs/tasks/WP-EXC-010.md` carries a pointer to this document; no historical content is rewritten.
- [ ] `exchange-admin`, authentication, commerce, licensing, reviews, ratings, dependency resolution, update service, and publisher-facing upload UI all remain unimplemented, as scoped.

## RELEASE IMPACT

None claimed. No OEP/Foundation/Engine/Studio/Exchange version is bumped by this scope document or by the eventual WP-EXC-010 implementation on its own — that remains a separate release-engineering decision per `docs/project/OEP_MILESTONE_ROADMAP.md`.

## FOLLOW-ON WORK

- A publisher-facing upload/publish UI, once a founder decision is made that RC1 (or a subsequent release) needs one — not required to prove the architecture.
- Dependency resolution, package update/uninstall-via-Exchange, licensing/payments/reviews, `exchange-admin`'s real administration screens — each a legitimate, separately-scoped future work package, not created here to avoid unnecessary scope.
- Deciding `HttpRepositoryClient`'s long-term disposition (keep dormant vs. remove) once/if a real, separate OEP Repository HTTP service is ever architected — explicitly not this WP's decision to make.
