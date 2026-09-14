# WP-SRV-003 — EAM API Authentication Audit — 2026-09-13

Companion to [`ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md`](../../architecture/decisions/ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md) (the design decision) and [`2026-09-13-SERVER-BRINGUP-002-OEP-REFERENCE-SERVER-INFRASTRUCTURE-AUDIT.md`](2026-09-13-SERVER-BRINGUP-002-OEP-REFERENCE-SERVER-INFRASTRUCTURE-AUDIT.md) (the VM this was additionally validated against).

## 1. Scope

Add the first authentication boundary to the EAM/acquisition HTTP API: a single, server-wide bearer-token gate in front of every route except `GET /health`. Explicitly not in scope (and not attempted): OAuth/OIDC, user accounts, authorization/roles, session management, Exchange authentication, Studio login, TLS, a reverse proxy, or any change to PostgreSQL/Docker exposure.

## 2. Baseline

Repository HEAD at start: `e6018d15549e514ce62cfc43877e2ef01af7ebc2` (WP-SRV-002) -- confirmed via `git rev-parse HEAD` before any change in this WP.

## 3. Architecture (Phase 0 findings)

- **HTTP server**: `oep::acquisition::api::ApiServer` (`services/acquisition/src/api/server.cpp`), embedding `cpp-httplib` in-process. One `httplib::Server` instance per `ApiServer`.
- **Route registration**: a set of `register_*_routes` free functions, each called from `register_routes` only when its corresponding service pointer is non-null (the established "nullable dependency" pattern from every prior WORK_PACKAGE).
- **Configuration loading**: `common::Config::load_from_file` parses `config/config.toml` (TOML); every field has a struct default so a missing file is non-fatal. `config.toml` is a tracked file already containing a local-development PostgreSQL password (`[database].password = "oep123"`) -- pre-existing, not introduced or touched by this WP, but directly informed the decision (Section 5 of the ADR) to keep the new API token *out* of this file entirely.
- **Environment-variable handling**: no existing convention in the *application's own* configuration path (TOML-only); the only existing environment-variable convention in the repository is `OEP_TEST_DB_{HOST,PORT,NAME,USER,PASSWORD}`, read exclusively by test-support code (`registry_test_support.cpp`), not by `main.cpp`. `OEP_API_TOKEN` (Phase 1) follows that same environment-variable shape rather than inventing a new one.
- **Existing middleware/interceptor mechanisms**: none pre-existed. `httplib::Server::set_pre_routing_handler` (available in the vendored cpp-httplib) was identified as the correct, already-available mechanism -- no second HTTP server abstraction was created, and none was needed.
- **Error response conventions**: `respond_error(response, status, code, message)` already produces `{"error": ..., "message": ...}` for every existing failure path -- reused verbatim for 401s (`respond_unauthorized`), not replaced with a new shape.
- **Test server construction**: every API test file constructs an `ApiServer` directly (no shared test-server abstraction) and an `httplib::Client` against its bound (often OS-assigned ephemeral) port.
- **Existing API client implementations**: none inside this repository call the EAM API as an HTTP client in production code today (Studio talks to EAM via its own `AcquisitionApiClient`, which was not touched -- see Section 12).
- **Existing authentication-related code**: a full-repository search for `Authorization`, `Bearer`, `token`, `API key`, `authentication`, `auth`, `secret`, `credential` found only `registry::AuthenticationType` (`services/acquisition/include/oep/acquisition/registry/official_source.hpp`) -- an enum describing how an *external, outbound* Official Source might itself require authentication (`None`/`UsernamePassword`/`ApiKey`/`OAuth2`/`ClientCertificate`), explicitly documented in its own header as "no authentication is actually implemented against these sources." This is unrelated to, and was not touched by, the *inbound* API-boundary authentication this WP adds. No pre-existing inbound authentication mechanism of any kind was found, confirming the WP's own premise.

## 4. Authentication Mechanism

Bearer token (`Authorization: Bearer <token>`), checked once per request via `httplib::Server::set_pre_routing_handler`, installed in `ApiServer`'s constructor -- not duplicated inside any route handler. Comparison uses a constant-time helper (`constant_time_equals`, `services/acquisition/include/oep/acquisition/api/auth.hpp`) to avoid a byte-at-a-time timing side channel. Full design rationale: ADR-0002 Sections 3-4.

## 5. Configuration

`OEP_API_TOKEN` environment variable, read once by `main.cpp` at startup, before logging or any other subsystem initializes. Missing or empty -> the process prints a clear, token-free error to stderr and exits with status 1 (verified manually, Section 10). No default token of any kind exists; `admin`/`password`/`changeme`/`development`/`test` are not accepted as implicit values -- there is no implicit-value code path at all. `ApiServer`'s own constructor additionally throws `std::invalid_argument` for an empty token string, independent of `main.cpp`'s check, so no caller (test or production) can end up with a silently-disabled gate.

## 6. Protected Routes

Every route in `register_routes` except `GET /health` -- full enumeration in ADR-0002 Section 6, matching Phase 5's required list exactly, plus one additional route discovered during the Phase 0 audit and classified explicitly rather than left silently unprotected: `GET /connectors/{id}/health`, classified **authenticated** (it reports Connector Framework data, not process-level infrastructure health).

## 7. Public Routes

`GET /health` only -- unconditionally, for both an authenticated and unauthenticated caller, unchanged in its response shape from before this WP. No second health endpoint was created.

## 8. Security Behavior

- Missing, malformed, and wrong-token requests all produce an identical `401` with body `{"error": "unauthorized", "message": "Authentication required."}` and header `WWW-Authenticate: Bearer` -- verified directly (Section 10: "wrong token" vs. "no token at all" produce byte-identical status and body).
- No response ever contains the configured token, the caller's supplied header, a filesystem path, a PostgreSQL connection string, or a stack trace -- confirmed by inspection of every code path that can produce a response in `server.cpp`; `respond_error`'s two arguments (`code`, `message`) are always static, request-independent strings for this specific failure mode.
- Log inspection (Phase 9): no request-logging mechanism of any kind exists in this service today (confirmed by searching for any `set_logger`/per-request logging call in `services/acquisition/src`) -- there was nothing logging `Authorization` headers to correct, and this audit confirms none was introduced. `main.cpp` logs only the configured token's *length*, never its value.

## 9. Tests

Added/updated across 11 test files (`services/acquisition/tests/`): every existing `ApiServer` construction site now passes a shared, obviously-fake test token (`test_support::kTestApiToken`, `registry_test_support.hpp`) and every corresponding `httplib::Client` calls `set_bearer_token_auth` once, so every pre-existing test continues exercising the same successful behavior it always did, now over an authenticated connection.

New coverage, matching Phase 8's required matrix:
- Unit-level (`test_auth.cpp`, new): `constant_time_equals` and `parse_bearer_token` edge cases (equal/unequal/different-length strings; well-formed, missing, wrong-scheme, empty-token, and whitespace-containing headers).
- `test_server.cpp`: health without a token (200), health with a valid token (200), an unregistered route with a valid token still 404s (not swallowed by auth), and `ApiServer` construction with an empty token throws `std::invalid_argument`.
- `test_vault_api.cpp`: `/vault` with no header (401), with a malformed header (401), with the wrong token vs. no token at all (byte-identical response, proving no information leak between failure reasons), `/vault/{id}/artifact` with no token (401) and with a valid token (existing 200/bytes/checksum behavior, from WP-SRV-002, unchanged), and an explicit re-assertion that `vault_path` never appears in either the single-entry or list response body.
- `test_download_api.cpp`: `/downloads` with no header (401), and an explicit re-assertion that `local_storage_path` never appears in the response body.

This is deliberately integration-level (a real `ApiServer` + `httplib::Client` over a real socket), not only the two helper functions tested in isolation, per Phase 8's explicit instruction.

## 10. Build Results

- `oep_acquisition_api` (library containing `auth.cpp`/`server.cpp`): builds cleanly, zero warnings introduced by this WP.
- `oep_acquisition` (the `main.cpp` executable): builds cleanly.
- `oep_acquisition_tests`: builds cleanly.
- Manual startup check: `OEP_API_TOKEN` unset -> prints the documented stderr message, exits **1**. `OEP_API_TOKEN` set -> starts normally, logs "API authentication token configured (length N)" -- never the value.
- **Full test run, against a real local PostgreSQL instance** (this Windows machine already had one reachable using `config.toml`'s own credentials -- setting the matching `OEP_TEST_DB_*` environment variables unlocked every previously-skipped DB-backed test, so the VM's PostgreSQL was not additionally needed for this run): **PASS — 256/256 test cases, 1188/1188 assertions, 0 failed, 0 skipped.** This includes every new authentication assertion listed in Section 9 actually executing (confirmed individually via targeted tag/section filtering), not merely compiling.
- No test was SKIPPED and none was ENVIRONMENT-BLOCKED in this run; the graceful-skip mechanism for a database-unavailable environment remains in place and untouched (verified unchanged in the earlier, pre-token-export run of the same suite, which showed the same pre-existing 25 DB-dependent test cases skipping with the established "PostgreSQL test database unavailable" message).

## 11. Client Compatibility

No production internal caller depends on unauthenticated EAM access: Studio's `AcquisitionApiClient` (`platform/oep_studio/lib/acquisition/...`) was inspected and is out of this WP's scope to modify (it is a Dart client for a different, already-separately-scoped integration surface, and per WP-SRV-003's own Phase 10 instruction, "do not redesign unrelated clients" -- it was not touched). No infrastructure health check was broken: `GET /health` remains callable with no token, exactly as before. No Exchange or Studio-login code was modified.

## 12. TLS Considerations

Documented in full in ADR-0002 Section 11: bearer-token authentication is not transport security by itself. The current VM remains plain HTTP, reachable only from its own hypervisor host through a NAT port-forward (a trusted path, per the SERVER-BRINGUP-002 audit) -- an acceptable environment for this mechanism as-is. Any future exposure across a less-trusted network boundary requires TLS in front of this token, which this WP does not implement (no certificate embedded, no reverse proxy installed, no HTTPS listener added), per its own explicit constraints.

## 13. Known Limitations

- One shared token for every caller -- no per-caller identity, no revocation short of rotating the single token and restarting the process.
- No authorization/roles layer -- any holder of the token can do anything any protected route allows (as intended: Phase 25 of `OEP_REFERENCE_SERVER_REQUIREMENTS.md` explicitly defers authorization until the service boundary is established, which is exactly what this WP is).
- `fail2ban` (noted in the prior infrastructure audit) still has zero jails configured -- unrelated to this WP, not addressed here.
- The token must currently be supplied identically to every request; there is no session, cookie, or refresh mechanism (deliberately -- Phase 12 of this WP explicitly excludes session management and refresh tokens).

## 14. Remaining Security Gaps

- No TLS -- Section 12.
- No rate limiting specific to authentication failures beyond whatever OpenSSH-level `PerSourcePenalties`/`fail2ban` already provide at the VM's SSH layer (unrelated to this HTTP API, and not extended to it by this WP).
- No authorization layer, by design (Section 13/ADR-0002 Section 2).
- Exchange remains completely unauthenticated (out of scope -- a separate service, a separate future WP).

## 15. Recommendation

**GREEN — COMPLETE WITH BOUNDED GAPS.**

The stated objective -- add the first explicit authentication boundary to the EAM API, designed once at the server boundary rather than per-handler, without redesigning EAM or introducing OAuth/JWT/RBAC/sessions -- is fully met, verified by a complete, passing test run (not merely a compiling one) against a real database, and documented in ADR-0002 without overstating what it provides. The bounded gaps (Section 14) are exactly the ones WP-SRV-003 itself lists as explicitly out of scope, not accidental omissions.
