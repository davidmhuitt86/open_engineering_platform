# ADR-0002 — OEP Reference Server API Authentication

Companion to [`ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md`](ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md), which established that the Reference Server's diagram places authentication at the API boundary, in front of EAM, Knowledge services, and Exchange, rather than inside each one separately. This ADR defines what that boundary mechanism actually is, for the current development/test Reference Server (WP-SRV-003).

## 1. Purpose

Before this ADR, the EAM/acquisition API had no authentication at all -- every route, including `/vault/{id}/artifact` and the full `/sources` -> `/jobs` -> `/downloads` -> `/verifications` -> `/metadata` -> `/vault` -> `/acquisition-records` pipeline, was reachable by anyone who could reach the port. This ADR adds the first authentication gate, so that reachability no longer implies access.

## 2. Scope

This ADR covers only the EAM/acquisition service's own HTTP API (`services/acquisition`). It does **not** cover:

- User accounts, OAuth, OpenID Connect, or any enterprise identity system.
- Authorization/roles (who is allowed to do *what* -- this ADR only establishes *whether a caller is a recognized holder of the token at all*).
- Exchange's own authentication (a separate Node/TypeScript service, out of scope for this WP).
- Studio user login.
- TLS/transport security itself (Section 11).

This is deliberately a narrow, first boundary mechanism -- see Section 13.

## 3. Authentication Mechanism

A single, server-configured **bearer API token**, checked against every incoming request at one place: `ApiServer`'s constructor installs an `httplib::Server::set_pre_routing_handler` (`services/acquisition/src/api/server.cpp`, `authenticate_request`) that runs before any route is dispatched. This is deliberately the *only* place the check exists -- no individual route handler (`/sources`, `/jobs`, `/vault`, etc.) contains its own authentication logic, and none should ever be added, per `server.hpp`'s class-level comment. Any future route registered on the same `ApiServer` -- including a future Knowledge or Exchange route, if either is ever folded into this same process -- is protected automatically by virtue of being registered on this server, with no separate implementation to write or forget.

If Knowledge or Exchange instead remain separate processes (Exchange already is, being Node/TypeScript), they do not share this C++ implementation directly, but should replicate the same *contract* (Section 4) rather than invent a different one -- see Section 13.

Token comparison uses `constant_time_equals` (`services/acquisition/include/oep/acquisition/api/auth.hpp`), which does not short-circuit on the first mismatched byte, to avoid a timing side-channel that could help an attacker narrow down a correct token one byte at a time.

## 4. Authorization Header Contract

```
Authorization: Bearer <token>
```

`parse_bearer_token` accepts exactly this shape. All of the following are treated identically -- as "no valid token supplied," never distinguished in the response:

- No `Authorization` header at all.
- An `Authorization` header with a different scheme (`Basic ...`, etc.).
- `Bearer` with no token, or with internal whitespace in the token.
- `Bearer <token>` where `<token>` does not match the configured token.

## 5. Token Configuration

The token is supplied via the `OEP_API_TOKEN` environment variable, read once at process startup (`main.cpp`) -- **not** via `config/config.toml`. This is a deliberate departure from every other setting in `common::Config` (all of which come from the TOML file): `config.toml` is a tracked file in this repository (and, per the existing, pre-dating-this-WP `[database].password` entry in that same file, evidently already sometimes holds a local-development secret) -- a real deployment's API token must never be written to a file that could be committed, so it is kept out of that mechanism entirely rather than added to it. `OEP_TEST_DB_*`'s existing environment-variable convention (`registry_test_support.cpp`) was the closest precedent found in this repository for "secret-shaped configuration supplied outside the tracked config file," and `OEP_API_TOKEN` follows the same pattern.

The token is never:
- Written to `config.toml` or any other tracked file.
- Logged verbatim (`main.cpp` logs only the configured token's *length*, never its value).
- Returned by any API response.
- Given a default value of any kind, including any of `admin`, `password`, `changeme`, `development`, or `test`.

## 6. Protected Routes

Every route registered by `register_routes` (`server.cpp`) except `GET /health` (Section 7):

- `/sources`, `/sources/{id}`
- `/jobs`, `/jobs/{id}`, `/jobs/{id}/status`, `/jobs/{id}/execute`, `/jobs/{id}/cancel`
- `/connectors`, `/connectors/{id}`, and `/connectors/{id}/health` -- this last one was discovered during this WP's own Phase 0 audit and is deliberately classified **authenticated**, not public, despite its name: it reports a specific connector's operational health/capabilities, which is Connector Framework data, not process-level infrastructure health. Only the top-level `GET /health` (Section 7) is the intentionally public exception.
- `/downloads`, `/downloads/{id}`, `/downloads/{id}/status`
- `/verifications`, `/verifications/{id}`
- `/metadata`, `/metadata/{id}`
- `/vault`, `/vault/{id}`, `/vault/{id}/artifact`
- `/acquisition-records`, `/acquisition-records/{id}`, `/acquisition-records/{id}/provenance`

Because the check runs in `set_pre_routing_handler` -- before routing, not inside a matched route -- an unauthenticated request to a path that does not exist at all is also rejected with 401 rather than 404. This is intentional: it means an unauthenticated caller cannot use response codes to enumerate which routes exist.

## 7. Public Health Route

`GET /health` remains unauthenticated, unconditionally, exactly as it already was before this ADR -- `authenticate_request` checks `request.path == "/health"` first and returns `Unhandled` (proceeds to normal routing, bypassing the token check entirely) before any header is inspected. This supports process supervision, container/VM health checks, and infrastructure monitoring without requiring those systems to hold the API secret, while every EAM data/control route above still requires it. No second health endpoint was created; the existing one's behavior (a 200 with `{"status": "ok"}`) is unchanged for both an authenticated and an unauthenticated caller.

## 8. 401 Behavior

Every authentication failure -- missing header, malformed header, wrong token -- produces the same response:

```
HTTP/1.1 401
WWW-Authenticate: Bearer
Content-Type: application/json

{"error": "unauthorized", "message": "Authentication required."}
```

This reuses the project's existing `{"error": ..., "message": ...}` error-response shape (`respond_error`, already used by every other error path in `server.cpp`) rather than inventing a new one. The body never contains the configured token, the caller's supplied header value, a stack trace, a filesystem path, or any PostgreSQL connection detail.

## 9. WWW-Authenticate Behavior

Every 401 response carries a standard `WWW-Authenticate: Bearer` challenge header (no realm or other parameter -- the simplest valid form), which is compatible with cpp-httplib's plain `set_header` and requires no library change. It never contains the actual token.

## 10. Secret Handling

Summarized from Section 5: environment-variable only, never in `config.toml`, never logged, never returned by any endpoint, no default, no common placeholder value accepted implicitly. `ApiServer`'s constructor additionally throws `std::invalid_argument` if constructed with an empty token string, so a caller (production or test) cannot accidentally end up with "authentication silently disabled" -- an empty configured token would otherwise mean no client-supplied token (never empty, per `parse_bearer_token`) could ever match it, permanently locking out every non-health route rather than actually disabling the check. This is a fail-loud safety net in addition to, not instead of, `main.cpp`'s own startup check (Section 5, Section 12).

## 11. TLS Requirement

**Bearer-token authentication is not, by itself, transport security.** The token travels in a plain HTTP header; anyone able to observe the connection (a network intermediary, a shared Wi-Fi network, a misconfigured proxy) can read it in plaintext exactly as easily as they could read a request body, unless the connection itself is encrypted. This ADR does not claim otherwise, and does not attempt to solve TLS -- no certificate is embedded, no reverse proxy is installed, no HTTPS listener is added by this WP (per WP-SRV-003's own explicit constraints).

**Local development HTTP** (the current VM, `http://10.0.2.15:8080` or similar, reachable only via the VM's own NAT port-forward from its single trusted developer's machine -- see `2026-09-13-SERVER-BRINGUP-002-OEP-REFERENCE-SERVER-INFRASTRUCTURE-AUDIT.md`) is an acceptable environment for this token mechanism as-is, precisely because that network path is not untrusted.

**Remotely exposed authenticated HTTPS** -- any deployment where this API becomes reachable across a network boundary that is not fully trusted (a real LAN, let alone the public internet) -- **requires TLS in front of the bearer token**, not instead of it. This ADR does not implement that TLS layer; it only records the requirement so a future WP does not skip it under the assumption that the bearer token alone is sufficient.

## 12. Development HTTP Limitation

Because of Section 11, this authentication mechanism's real-world security guarantee today is bounded by the network it runs on. On the current VM (HTTP, NAT-only, single trusted developer), the practical benefit is: a process that could previously be driven by *any* local process or accidental misconfiguration now requires deliberately supplying the correct token -- a meaningful improvement over no gate at all, but not equivalent to a production-grade credential system fronted by TLS.

## 13. Future Migration Path

This is explicitly **not** the platform's long-term identity system. It is the smallest mechanism that satisfies "the Reference Server API boundary requires *something*" today. Recorded, not decided, as candidates a future WP may consider:

- Per-caller tokens (today there is exactly one shared token, not one per client) if distinguishing callers becomes necessary.
- Authorization/roles layered on top of this same authentication boundary (this ADR deliberately does not conflate the two).
- A real identity system (OAuth/OIDC, enterprise SSO) if/when Studio user login or multi-tenant access becomes a real requirement -- none of which exists today.
- TLS termination (a reverse proxy, or a certificate directly on this service) before any non-trusted-network exposure, per Section 11.
- If Knowledge or Exchange ever need this same boundary and are not already in-process with EAM, replicating this ADR's *contract* (Sections 4, 6, 8, 9) in whatever language/framework they use, rather than inventing an incompatible scheme -- this ADR does not mandate a shared binary/library across languages, only a shared header/response contract.

None of the above is implemented by this ADR or by WP-SRV-003. This section exists so a future reader does not mistake the current bearer-token mechanism for a finished identity system.
