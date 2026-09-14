# WP-SRV-004 — EAM API TLS Boundary Audit — 2026-09-14

Companion to [`ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md`](../../architecture/decisions/ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md) (the design decision, with full verification detail already recorded there) and [`ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md`](../../architecture/decisions/ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md) (unchanged by this WP).

## Scope

Add a TLS transport boundary in front of the EAM API without touching its existing authentication (ADR-0002). Out of scope, and not attempted: authorization/RBAC, Exchange authentication, rate limiting, user identity.

## Baseline

`0421ca2` (WP-SRV-003, confirmed via `git rev-parse HEAD` before any change).

## Two disclosed deviations from `OEP_REFERENCE_SERVER_REQUIREMENTS.md`'s stated preferences

Neither rises to the "actual contradiction -- STOP" bar this WP's own instructions define (a hard architectural conflict), but both are worth surfacing explicitly rather than silently diverging:

1. **Reverse proxy choice**: `OEP_REFERENCE_SERVER_REQUIREMENTS.md` Section 11.1 lists Caddy as "Recommended Software" (not "required"/"SHALL"). This WP's own instructions left the choice open ("select a mature TLS reverse-proxy implementation appropriate for the existing OEP deployment environment"). **nginx** was chosen instead: it is equally mature, equally native-install-compatible (`apt install nginx`, already in Ubuntu's repositories, no Docker needed), was already one of the three reverse-proxy candidates the original SERVER-BRINGUP-001 audit considered, and meets every actual requirement in this WP's text (TLS 1.2+/1.3, cipher control, header preservation, clean failure behavior). If the user has a firm reason to standardize on Caddy specifically, that is a straightforward substitution against the same architecture this ADR describes -- flagged here rather than assumed.
2. **Plaintext port-80 behavior**: the requirements doc's Section 13 firewall table lists port 80's purpose as "HTTP → HTTPS" (implying a redirect), while this WP's own instructions explicitly state a preference for API endpoints: *"prefer rejecting plaintext external access rather than silently allowing it"* and require that any redirect implementation be evaluated for Authorization-header leakage. This WP's more specific, more recent instruction was followed: port 80 returns `444` (connection closed, no redirect) rather than a `301`/`302` to HTTPS, which sidesteps the redirect-leakage question entirely rather than requiring a separate audit of it. This is a pure API service (no browser-facing content expected at all), so a redirect's usual purpose (helping a browser silently upgrade) does not clearly apply here either.

Both are recorded as decisions, not omissions; `OEP_REFERENCE_SERVER_REQUIREMENTS.md` itself was **not modified**.

## Architecture

nginx terminates TLS and reverse-proxies to `oep_acquisition`, which now binds `127.0.0.1:8080` by default (previously `0.0.0.0:8080`) and is otherwise completely unchanged -- zero lines of EAM application logic were touched. Full diagram and rationale: ADR-0003 Sections 1-3.

## TLS Termination

nginx 1.28.3 (Ubuntu package). Site config: `/etc/nginx/sites-available/oep-acquisition-tls.conf` (VM-local infrastructure configuration, not committed to this repository, consistent with WP-SRV-001A's established precedent). `ssl_protocols TLSv1.2 TLSv1.3` only; a modern ECDHE/GCM/ChaCha20-Poly1305 cipher list; `ssl_prefer_server_ciphers on`.

## EAM Binding

`ServerConfig::host` default and `config/config.toml`'s `[server].host` both changed `0.0.0.0` → `127.0.0.1` (`services/acquisition/include/oep/acquisition/common/config.hpp`, `services/acquisition/config/config.toml`) -- the only code/config change this WP makes to the application itself. Verified live on the VM: `ss -tlnp` showed `127.0.0.1:8080` only, no `0.0.0.0` binding.

## Certificate Configuration

Self-signed development certificate/key at `/etc/nginx/ssl/oep-reference-server-dev.{crt,key}`, generated on the VM, never committed to this repository. Key: `600 root:root`. Certificate subject includes `O=OEP-Dev-Only-Not-For-Production` so it is unambiguous on inspection that this is not a production credential. Full detail, including the production-certificate requirements this WP does not itself satisfy: ADR-0003 Section 4/15.

## Authentication

**Unchanged.** ADR-0002's mechanism, `Authorization: Bearer <OEP_API_TOKEN>` contract, 401 response shape, and `WWW-Authenticate: Bearer` header all verified working identically through the new TLS/proxy boundary (Section "Tests" below) -- no EAM route classification changed, no route became newly public or newly protected beyond what ADR-0002 already established.

## HTTP Policy

Plaintext HTTP on port 80 returns `444` (connection closed, no body, no redirect) -- verified directly. No HTTP-to-HTTPS redirect exists, avoiding any Authorization-header-in-redirect question entirely (see "Two disclosed deviations" above).

## Tests

All performed directly against the live VM instance, not asserted from configuration alone (full detail: ADR-0003 Section 11):

- **TLS**: TLS 1.2 succeeds, TLS 1.3 succeeds, TLS 1.1 and TLS 1.0 both fail (`no protocols available`), certificate/key mismatch causes `nginx -t` to fail closed (tested directly with a deliberately mismatched pair, then restored and re-verified).
- **Authentication over HTTPS**: no token → 401; malformed `Authorization` → 401; wrong token → 401; correct token → passes auth and reaches the EAM application layer (observed as 404, since this VM's PostgreSQL has no `oep_acquisition` role provisioned and `/vault` is therefore unregistered -- the same "route not registered" behavior already established by WP-SRV-002/003, not a new gap); `/health` → 200 both with and without a token.
- **Transport**: external-shaped HTTP request → rejected (connection closed); HTTPS → accepted; HTTPS → nginx → plain-HTTP EAM upstream chain → accepted end-to-end.
- **Leak checks**: nginx access log, nginx error log, and the EAM application's own log all searched for the literal test token used during verification -- zero matches in all three. Both a `401` and a `200` response body inspected directly -- clean JSON, no path, no stack trace, no credential.
- **Regression**: the full pre-existing `oep_acquisition_tests` suite was rebuilt and re-run on two separate toolchains:
  - **Linux/GCC, on the VM**: 231 test cases passed, 0 failed, 25 skipped (pre-existing, environment-only DB-credential skip pattern, unrelated to this WP).
  - **Windows/MSVC, on the development machine, with real PostgreSQL credentials supplied**: **256/256 test cases, 1188/1188 assertions, 0 failed, 0 skipped** -- every WP-SRV-003 authentication assertion, including the vault/download leak checks, ran and passed with this WP's one code change (`ServerConfig::host` default) in place, confirming no regression.

## Build

`oep_acquisition_api`, `oep_acquisition` (the executable), and `oep_acquisition_tests` all rebuilt cleanly on both toolchains used (MSVC/Windows, GCC/Linux) -- zero new warnings introduced by this WP (the two changed lines are a single string-literal default in a header and the matching line in `config.toml`).

## Security

No response, log, or error message observed during this WP's verification contained the bearer token, an `Authorization` header value, the TLS private key, a filesystem path, an internal IP/upstream detail, or a stack trace. The private key's permissions were never loosened -- they were `600 root:root` from creation. `nginx`'s access-log format was left at its default (no `$http_authorization` or any header value added to it).

## Documentation

- `docs/architecture/decisions/ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md` -- new. ADR-0002 was read and is **not modified**; it remains accurate as written, and this ADR references it rather than duplicating or contradicting it.
- `docs/project/audits/2026-09-14-WP-SRV-004-EAM-API-TLS-BOUNDARY-AUDIT.md` -- this document.
- `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` -- read for the disclosed-deviations check above; **not modified**.

## Known Limitations / Remaining Security Gaps

- Development/test certificate is self-signed; a real deployment needs a CA-issued certificate matching its actual hostname (ADR-0003 Section 15) -- not provided by this WP.
- No automated certificate renewal/monitoring (ADR-0003 Section 8's procedure is manual).
- `/vault` (and every other DB-backed route) remains unregistered on this VM because no `oep_acquisition` PostgreSQL role/database has been provisioned there yet -- unrelated to TLS, a pre-existing condition from WP-SRV-001A's own explicit "do not create the OEP database yet" instruction, not something this WP was asked to resolve.
- No authorization/roles layer (unchanged, deferred exactly as ADR-0002 already stated).
- No rate limiting (explicitly out of scope for this WP).
- Exchange remains a separate, unauthenticated, un-TLS'd service (separate future scope).

## Recommendation

**COMPLETE.** Every acceptance criterion in WP-SRV-004's own text was verified directly against a live instance: TLS termination implemented, TLS 1.2+ supported, TLS 1.0/1.1 disabled, no production key/certificate in the repository, certificate configuration externalized, EAM operates correctly behind the boundary, ADR-0002's authentication remains authoritative and byte-for-byte unchanged in its response shape, `/health` behavior unchanged, all protected routes remain protected, plaintext external access rejected, authenticated HTTPS requests succeed, unauthorized HTTPS requests remain 401, no credential/key/path leak found in logs or responses, the existing test suite passes on two toolchains with zero regressions, and the build introduces zero new warnings.
