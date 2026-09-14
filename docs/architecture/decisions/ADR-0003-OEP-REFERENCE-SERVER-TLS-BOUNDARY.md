# ADR-0003 — OEP Reference Server TLS Boundary

Companion to [`ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md`](ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md), which established the bearer-token authentication boundary and explicitly stated (Section 11) that bearer authentication is not transport security and that TLS is a separate, not-yet-implemented requirement. This ADR (WP-SRV-004) implements that TLS layer. **ADR-0002 is not modified or superseded by this ADR** -- its authentication mechanism, contract, and behavior are unchanged; this ADR only adds a transport boundary in front of it.

## 1. Why TLS Is Required

**Bearer authentication is not transport security.** The token travels in a plain HTTP header; without an encrypted transport, anyone able to observe the connection can read it exactly as easily as any other plaintext header. ADR-0002 already stated this; this ADR is the follow-through: a real TLS boundary, so the token (and every other header and body) is actually encrypted in transit whenever this API is reachable across a network boundary that is not fully trusted.

## 2. Where TLS Terminates

TLS terminates **outside the EAM application**, in nginx, not inside `httplib::Server`. The EAM process (`oep_acquisition`) itself gained **zero application code changes** for this ADR -- it remains exactly the transport-agnostic plain-HTTP server ADR-0002 already described, listening only on a private interface (Section 3):

```
Remote Client
     │
     │ HTTPS
     ▼
┌─────────────────────────────┐
│ nginx (TLS termination)     │
│ /etc/nginx/sites-available/ │
│   oep-acquisition-tls.conf  │
└──────────────┬──────────────┘
               │ HTTP, loopback only
               ▼
┌─────────────────────────────┐
│ EAM API (oep_acquisition)   │
│ 127.0.0.1:8080               │
│ existing pre-routing auth   │
│ (ADR-0002, unchanged)       │
└─────────────────────────────┘
```

**Why nginx, and why not TLS directly in `httplib::Server`**: nginx is already the mature, native-install-compatible reverse proxy this repository's own `OEP_REFERENCE_SERVER_REQUIREMENTS.md` and ADR-0001 anticipate as the eventual reverse-proxy layer, is already packaged for Ubuntu (`apt install nginx`, no Docker/Kubernetes/service-mesh needed -- consistent with WP-SRV-001A's native-install architecture), and keeps certificate/cipher/protocol management entirely out of the C++ application, where it would otherwise need its own configuration surface, its own certificate-reload logic, and its own exposure to certificate-handling bugs. cpp-httplib does support TLS builds, but adopting it would have meant the EAM binary itself managing certificate files, private-key permissions, and protocol/cipher policy -- exactly the kind of "application-level TLS for its own sake" this WP's own instructions caution against introducing without a compelling reason, and no such reason exists here.

## 3. EAM Binding

`services/acquisition/include/oep/acquisition/common/config.hpp`'s `ServerConfig::host` default changed from `"0.0.0.0"` to `"127.0.0.1"` (and `services/acquisition/config/config.toml`'s `[server].host` likewise), so the EAM listener is loopback-only **by default**, not merely "capable of it" -- a deployer must deliberately opt back into `0.0.0.0` for the unusual case of running EAM directly reachable with no TLS boundary in front (e.g., a fully isolated local-only development loop). This is the one and only code/config change this ADR makes to the EAM application itself.

**External** (untrusted network) traffic: `HTTPS` only, to nginx.
**Internal** (nginx -> EAM) traffic: plain `HTTP`, over `127.0.0.1:8080` -- never reachable from outside the host, both because EAM binds only to loopback and because the host firewall (`ufw`, see the SERVER-BRINGUP-002 audit) permits nothing on port 8080 at all.

Direct external HTTP access to the EAM listener is explicitly **not** part of the supported production topology.

## 4. Certificate Configuration

Externalized entirely outside the application and outside this repository:

- Certificate: `/etc/nginx/ssl/oep-reference-server-dev.crt` (VM-local, `644`, `root:root`).
- Private key: `/etc/nginx/ssl/oep-reference-server-dev.key` (VM-local, `600`, `root:root` -- readable only by root, which is the account nginx's master process runs as before it forks/drops privilege for its workers).
- Neither file exists anywhere in this Git repository, in Git history, in a Docker image, in source, or in a config default. Certificate configuration is a path referenced from `nginx`'s own site config (`/etc/nginx/sites-available/oep-acquisition-tls.conf`), which is itself VM-local infrastructure configuration, per WP-SRV-001A's established precedent of keeping VM infrastructure configuration outside the application repository where practical.

**Development/test certificate**: a self-signed certificate, generated once via `openssl req -x509 ... -subj '/CN=oep-reference-server-dev/O=OEP-Dev-Only-Not-For-Production' ...` -- the `O=OEP-Dev-Only-Not-For-Production` subject field is deliberate, so anyone inspecting the certificate (e.g., `openssl x509 -text`) sees immediately that it is not a production credential. Its Subject Alternative Names cover `oepstudioserver`, `localhost`, `127.0.0.1`, and the VM's current NAT address (`10.0.2.15`) -- development-topology addresses only.

**Production certificate**: not generated or provided by this ADR. A real deployment needs a certificate from a trusted CA (or an internally-trusted CA for a private network), matching the actual hostname(s) the API will be reached by. See Section 15 (Certificate Validation) below for what a production deployment must additionally establish.

## 5. Private-Key Protection

The private key is `600`, owned `root:root` -- unreadable by any account other than root, including the `www-data` account nginx's worker processes run as (the master process, which reads the key file, runs as root until it forks workers and they drop privilege). This ADR did not weaken any existing filesystem permission to accommodate TLS termination -- the key's permissions were set this way from creation, matching the requirement, not loosened afterward. The key is never logged (nothing in this ADR's implementation logs certificate or key contents), and its filesystem path is never returned by any EAM API response or nginx response body -- it appears only in `nginx`'s own site configuration file, which is not served.

## 6. Production Deployment Topology

```
Internet / LAN (untrusted)
        │
        │ HTTPS only (port 443)
        ▼
┌──────────────────────────────┐
│ nginx (this VM)               │
│ - TLS 1.2/1.3 only            │
│ - real CA-issued certificate  │
│ - rejects plaintext :80       │
└──────────────┬────────────────┘
               │ HTTP, 127.0.0.1 only
               ▼
┌──────────────────────────────┐
│ EAM API (oep_acquisition)     │
│ 127.0.0.1:8080                 │
│ Bearer auth (ADR-0002)        │
└────────────────────────────────┘
```

Firewall (`ufw`): `443/tcp` allowed in; `8080/tcp` never opened externally (was never opened by any prior WP either -- WP-SRV-001A's original firewall baseline was SSH-only, and this ADR adds exactly one more allowed port, 443, nothing else).

## 7. Development/Test Topology

Identical shape to Section 6, but using the self-signed development certificate (Section 4) and reachable only via the VM's existing NAT port-forward from its single trusted developer machine (unchanged from the SERVER-BRINGUP-002 audit's network-topology finding) -- there is no separate "dev-mode-skips-TLS" code path; the same nginx configuration is used, just with a non-production certificate.

## 8. Certificate Renewal

Not automated by this ADR (out of scope -- WP-SRV-004 is transport security, not operations tooling). Documented procedure for a future operator:

1. Obtain a new certificate/key pair (from a CA for production, or regenerate the self-signed pair via the same `openssl req` invocation for development).
2. Place the new files at the same paths (`/etc/nginx/ssl/...`), preserving the private key's `600 root:root` permissions.
3. Validate before applying: `sudo nginx -t` (this fails closed on a mismatched or unreadable pair -- verified directly as part of this WP, Section 10).
4. Only after `nginx -t` succeeds, apply with `sudo systemctl reload nginx` (a reload, not a restart, avoids dropping in-flight connections).

## 9. Failure Behavior

Verified directly (not merely asserted) as part of this WP:

- **Certificate/key mismatch**: `nginx -t` fails immediately (`SSL_CTX_use_PrivateKey(...) failed: key values mismatch`), exit code 1 -- confirmed by deliberately testing a mismatched pair against the real site configuration, then restoring the correct pair and re-validating successfully. Nginx never serves TLS with a bad pair; there is no fallback to plaintext.
- **Obsolete protocol versions**: `openssl s_client -tls1` and `-tls1_1` both fail the handshake outright (`no protocols available`) -- confirmed directly. Only `TLSv1.2` and `TLSv1.3` are listed in `ssl_protocols`, so nothing else is negotiable.
- **Plaintext HTTP**: the port-80 server block returns `444` (nginx-specific: closes the connection with no response at all) rather than proxying or redirecting -- confirmed directly (`curl` against port 80 receives no response). No HTTP-to-HTTPS redirect exists, specifically because a redirect response can under some client/proxy configurations still have carried a client's `Authorization` header toward the redirect target; rejecting outright removes that question entirely rather than requiring a redirect-safety audit.
- **Upstream (EAM) unavailable**: nginx's `proxy_intercept_errors` returns a generic `{"error":"upstream_unavailable", ...}` JSON body rather than passing through whatever raw error the failed upstream connection would otherwise produce -- no internal connection detail is exposed to the client in that case.

## 10. HTTP Exposure Restrictions

Summarized from Sections 3, 6, 9: the plaintext EAM listener (`127.0.0.1:8080`) is not reachable externally by construction (loopback bind) and not reachable externally by firewall policy (port 8080 was never opened, in this or any prior WP). Plaintext HTTP on the externally-reachable address (port 80) is explicitly rejected by nginx itself, not merely left unconfigured. There is no supported path for an external client to reach EAM except through TLS.

## 11. Verification Performed

All of the following were checked directly against a live instance (nginx 1.28.3, on the same VM as every prior Reference Server WP), not merely asserted from the configuration:

- `GET /health` via HTTPS, without a token: `200` (unchanged public behavior).
- `GET /health` via HTTPS, with a valid token: `200`.
- `GET /vault` via HTTPS, with no `Authorization` header: `401`.
- `GET /vault` via HTTPS, with a malformed `Authorization` header: `401`.
- `GET /vault` via HTTPS, with the wrong token: `401`.
- `GET /vault` via HTTPS, with the correct token: `404` (this VM's PostgreSQL has no `oep_acquisition` role/database provisioned yet, so `/vault` is not registered at all -- the `404` here is exactly the same "route not registered" behavior ADR-0002/WP-SRV-002 already established, and its appearance here is the proof that the request passed authentication and actually reached the EAM application layer through the TLS/proxy boundary, not evidence of any new gap).
- `WWW-Authenticate: Bearer` header present on the `401` response, forwarded correctly through the proxy.
- TLS 1.2 and TLS 1.3 handshakes succeed; TLS 1.1 and TLS 1.0 handshakes fail with `no protocols available`.
- Certificate/private-key mismatch causes `nginx -t` to fail (Section 9).
- Plaintext HTTP on port 80 receives no response (connection closed).
- `nginx`'s access log, error log, and the EAM application's own log were all grepped for the literal test token used during this verification: zero matches in any of the three.
- Response bodies for both a `401` and a `200` were inspected directly: `{"error":"unauthorized","message":"Authentication required."}` and `{"status":"ok"}` respectively -- no filesystem path, no stack trace, no upstream connection detail, no credential.
- The full existing WP-SRV-003 automated test suite (`oep_acquisition_tests`) was rebuilt and re-run on this same VM (native Linux/GCC build, distinct from the Windows/MSVC build these tests were already proven against in WP-SRV-003): **231 test cases passed, 0 failed, 25 skipped** (the same pre-existing, environment-only skip pattern -- this VM's PostgreSQL has no test role/database configured, unrelated to this WP). On the Windows/MSVC build, with matching `OEP_TEST_DB_*` credentials supplied, the full suite (including every database-backed WP-SRV-003 assertion) ran completely: **256/256 test cases, 1188/1188 assertions, 0 failed, 0 skipped** -- confirming this WP's one code change (the `ServerConfig::host` default) introduced no regression anywhere in the existing suite.

## 12. Explicitly Not Done By This ADR

- No authorization, roles, scopes, or per-caller identity (unchanged from ADR-0002 -- still deferred).
- No change to Exchange's authentication (a separate service, out of scope).
- No API-layer rate limiting.
- No automated certificate renewal/ACME integration -- Section 8's procedure is manual.
- No production certificate was obtained or committed -- only a clearly-marked, non-production development certificate exists, and only outside this repository.
- No Docker, Kubernetes, or service mesh was introduced to implement this ADR.
