# ADR-0003 — HttpConnector Security, Scope, and SSRF Resolution

**Status:** **Resolved** (2026-09-13). Originally raised as "Proposed" by WP-017's implementation audit (2026-09-12); resolved by the dedicated ADR-0003 work package below. Supersedes this document's own original "Proposed" text, which is preserved in Section 1 (Context) for the historical record.

**Date resolved:** 2026-09-13
**Resolved by:** Claude (Sonnet 5), dedicated ADR-0003 work package
**Original finding by:** Claude (Sonnet 5), WP-017 (EAM / Reference Vault Implementation Audit), Section 4 (Connector Audit)

---

## 1. Context (original WP-017 finding, preserved verbatim as history)

WP-005 (Engineering Source Connector Framework) states explicitly: *"No implementation shall perform actual network communication."* WP-006 (Engineering Downloader) lists "HTTP client" under its own "Do NOT implement" list. The service's own `README.md` states, in multiple places, that *"`StubConnector` remains the only connector type"* and that this "performs no real network communication."

WP-017's Connector Audit (its own Section 4) found this claim to be **false as of the current codebase**. A second, fully implemented `IConnector`:

- `include/oep/acquisition/connectors/http_connector.hpp` / `src/connectors/http_connector.cpp` — `HttpConnector`, using `cpp-httplib`'s client mode to issue real `GET` requests, stream a real response body to disk, follow redirects, honor cancellation via `std::stop_token`, and report real HTTP status/MIME type/ETag.
- Registered at startup in `src/app/main.cpp` under connector id `http-source`, type `"http"`, alongside `example-stub` — **live in the running server today**, reachable via the existing `POST /downloads` route with `"connector_id": "http-source"` and any `http://`/`https://` `source_uri`.
- Has its own dedicated test suite (`tests/test_http_connector.cpp`), including tests that perform a real HTTP fetch, follow a real redirect, and handle a real 404 — i.e. this is not a dead/unreachable stub left mid-implementation; it is functional.

This was present before WP-017 began (confirmed via `git log` on `http_connector.cpp`: introduced by the single squashed commit that imported the `oep_acquisition` service into this monorepo, `af5c6ec`, 2026-09-04 — WP-017 did not write it, and the pre-import history that would show exactly when/why it was added relative to WP-005/006's ratification is not available in this monorepo).

**Original "why this needs a decision" reasoning (also preserved):** Per WP-017's own governing rule ("Do not assume the documentation and implementation agree. Where they differ, document the difference explicitly. Do not silently rewrite architecture to match implementation."), WP-017 was explicitly not authorized to unilaterally decide this either way — removing `HttpConnector` would delete a working, tested capability nothing says must *not* exist; leaving it silently undocumented would mean the README's M1-scope claims stay simply wrong.

**Original three options (A/B/C), for the record:** (A) ratify as an approved extension, closing the SSRF gap and correcting `README.md`; (B) gate it off (stop registering it in `main.cpp`) until a future work package formally reintroduces it under security review; (C) leave it as-is and only correct documentation, deferring the SSRF fix. This ADR resolves that choice — see Section 6.

---

## 2. Actual Current Behavior (re-verified, 2026-09-13, before any change)

Direct inspection of the current repository (not assumed from the above finding, though it confirms it):

- **HTTP library**: `cpp-httplib` (vendored at `build/_deps/httplib-src`, version `0.18.5`), in client mode (`httplib::Client`) — the exact same library the service's own `ApiServer` uses server-side.
- **`source_uri` origin**: fully caller-supplied, per-request. Traced end to end: `POST /downloads`'s JSON body → `validation.cpp:37 request.source_uri = get_string(body, "source_uri")` → `download_service.cpp:98 fetch_request.source_uri = request.source_uri` → `HttpConnector::fetch`. **No cross-check exists anywhere against the Job's registered `OfficialSource.base_url`** (`AcquisitionJob.source_id` foreign-keys to `OfficialSource`, which has exactly this field plus `trust_level`/`status`, per `include/oep/acquisition/registry/official_source.hpp` — this trust anchor exists in the schema/domain model but was never wired into the download path). This makes `source_uri`, as implemented, **Category E: an arbitrary, untrusted URL** — not Category C (source metadata), despite a Category-C-shaped anchor sitting unused right next to it.
- **No authentication anywhere on the EAM REST API** (`src/api/server.cpp` — confirmed by direct inspection: no `set_pre_routing_handler`, no `Authorization`/API-key check on any route). Any process able to reach the configured port (`0.0.0.0:8080` by default, per `config/config.toml`) can call `POST /downloads` with `connector_id: "http-source"` and any `source_uri`.
- **No existing destination validation of any kind** prior to this ADR's implementation — confirmed by an exhaustive repository-wide search for `loopback`, `127.0.0.1`, `169.254`, `192.168`, `172.16`, `SSRF`, `allowlist`, `denylist`, `private_ip`, `is_private` across `src/`/`include/`: zero matches anywhere.
- **Redirects**: `set_follow_location(true)` (before this ADR) followed *any* redirect target, with cpp-httplib's own default cap of 20 hops, no per-hop validation.
- **TLS certificate verification**: cpp-httplib's own default, `server_certificate_verification_ = true` (confirmed directly in `httplib.h`) — `HttpConnector` never disabled it. Already safe, unchanged by this ADR.
- **Proxy**: cpp-httplib never reads `HTTP_PROXY`/`HTTPS_PROXY` environment variables automatically (confirmed: zero `getenv` calls anywhere in `httplib.h`); proxying is opt-in only via `set_proxy()`, which `HttpConnector` never calls. Not applicable.
- **Headers/credentials**: the only header ever sent is `User-Agent`. `AcquisitionRequest` has no header field at all — there is no mechanism for a caller to inject arbitrary headers or forward `Authorization`/cookies through this connector, confirmed by its absence from the request model, not merely by convention.
- **Response size / timeouts (before this ADR)**: `connect_timeout_seconds`/`read_timeout_seconds` (configurable, default 10/30) already existed. No response-size cap existed.
- **Real, working, tested capability**: WP-017's characterization holds — this is not a half-built stub. A live smoke test performed as part of this ADR's resolution (Section 8) confirms a real external HTTPS fetch (`https://example.com/`) completes successfully end to end through the running server's own `POST /downloads` route.

## 3. Security Boundary (actual data flow)

```
Caller (any process reaching the EAM port -- no auth)
    ↓  POST /downloads {job_id, connector_id: "http-source", source_uri: <any string>}
Acquisition API (validation.cpp -- checks non-empty only)
    ↓
DownloadService::start_download (download_service.cpp -- looks up job.source_id
    only to check the job is executable; never reads OfficialSource.base_url)
    ↓
HttpConnector::fetch(source_uri)  [Category E: arbitrary, untrusted URL]
    ↓
getaddrinfo(host) -- NEW as of this ADR: every returned address validated
    ↓
TCP/TLS -- NEW as of this ADR: connects only to the pre-validated, pinned address
    ↓
Remote resource (or, before this ADR: any internal/loopback/link-local resource)
```

**Destination authority classification: Category E (arbitrary untrusted URL).** Not B (the caller doesn't "select" from a curated list — they type any string), not C (the Official Source registry exists but is not consulted), not D (no admin-only config gate).

**Concrete attack surface confirmed by direct exploitation** (Section 8): before this ADR, `POST /downloads` with `source_uri: "http://127.0.0.1:8080/health"` caused the live service to make a real, successful loopback request to itself. The same technique, unpatched, would reach any address the host process's own network stack can reach — other services on `localhost`, RFC1918 LAN addresses if the host is multi-homed, and (had the deployment been cloud-hosted) the `169.254.169.254` instance-metadata endpoint, since it is architecturally indistinguishable from any other link-local address to this code. This is not a theoretical SSRF label — it is a reproduced, working exploit against the actual running binary, closed by the change in Section 7.

## 4. Threat Model

| # | Threat | Classification | Rationale |
|---|---|---|---|
| 1 | SSRF (arbitrary internal destination) | **Requires mitigation → Mitigated** | Confirmed exploitable (Section 3); closed by destination-class validation (Section 7). |
| 2 | DNS rebinding (validate-time vs. connect-time resolution differ) | **Requires mitigation → Mitigated** | Closed structurally: the validated address is pinned via `httplib::Client::set_hostname_addr_map`, confirmed (by reading `httplib.h`'s `create_client_socket`/`create_socket`) to make cpp-httplib connect to that exact literal (`AI_NUMERICHOST`) rather than re-resolving. |
| 3 | Redirect-based SSRF | **Requires mitigation → Mitigated** | `set_follow_location(false)`; redirects followed manually, each hop re-validated through the identical `resolve_and_validate_host` path as the initial URL, up to `max_redirects`. |
| 4 | IPv4 private-address bypass (RFC1918, loopback, link-local, shared/CGNAT, multicast, broadcast, "this network") | **Requires mitigation → Mitigated** | Explicit byte-range checks for all of the above; verified with a real, unpatched-to-patched SSRF reproduction (Section 8) and 6 dedicated unit tests. |
| 5 | IPv6 private/link-local bypass (`::1`, `fe80::/10`, `fc00::/7`, `::`) | **Requires mitigation → Mitigated** | Explicit checks via `IN6_IS_ADDR_*` macros plus a manual `fc00::/7` check (no standard macro exists for RFC 4193 ULA). |
| 6 | Localhost aliases (`localhost`, `127.0.0.1`, `[::1]`) | **Requires mitigation → Mitigated** | All resolve, via `getaddrinfo`, to addresses caught by threats 4/5 above — no special-casing needed or added. |
| 7 | Alternate IP representations (decimal/octal/hex-encoded IPv4, IPv4-mapped IPv6) | **Requires mitigation → Mitigated** | `getaddrinfo` itself normalizes these into real address bytes before validation ever runs; IPv4-mapped IPv6 (`::ffff:127.0.0.1`) is explicitly unwrapped and re-checked against the IPv4 rules. Verified with a dedicated test. |
| 8 | Non-HTTP schemes | **Already mitigated** | `parse_url` already rejected anything but `http`/`https` before this ADR; unchanged. |
| 9 | Arbitrary ports | **Not applicable (by design, see Section 6)** | Once the destination *address* is restricted to non-internal ranges, the port a public host chooses to expose is that host's own concern, not this service's security boundary — no port allowlist was added; see Section 6 for why this was deliberately not implemented. |
| 10 | Credential/header forwarding | **Not applicable** | No header besides `User-Agent` is ever sent; `AcquisitionRequest` has no field through which a caller could inject one. Nothing to mitigate because nothing is forwarded. |
| 11 | Oversized responses / resource exhaustion | **Requires mitigation → Mitigated** | New `max_response_bytes` cap (default 2 GiB, configurable), enforced inside the streaming content receiver — verified with a dedicated test using a 10-byte cap. |
| 12 | Connection timeout abuse | **Already mitigated** | `connect_timeout_seconds`/`read_timeout_seconds` already existed before this ADR; unchanged. |
| 13 | Redirect loops | **Requires mitigation → Mitigated** | `max_redirects` (default 5); verified with a dedicated self-redirecting-loop test. |
| 14 | TLS certificate validation | **Already mitigated** | cpp-httplib's own default (`server_certificate_verification_ = true`); `HttpConnector` never disabled it, before or after this ADR. |
| 15 | Proxy/environment-variable behavior | **Not applicable** | cpp-httplib never reads proxy environment variables automatically (confirmed: no `getenv` in `httplib.h`); `set_proxy` is never called. |
| 16 | Request smuggling | **Not applicable** | `HttpConnector` is an HTTP *client*; smuggling is a server-side request-framing ambiguity between a frontend and backend — not relevant to a single outbound client request. |
| 17 | Logging of sensitive request information | **Not applicable** | `HttpConnector`/`DownloadService` do not log request contents at all (only `main.cpp`'s own startup/connector-count logging exists in this area); nothing sensitive is ever captured, since nothing sensitive is ever sent (threat 10). |

## 5. Architectural Decision

**Option A, refined: ratify `HttpConnector` as an approved capability, with the SSRF gap closed structurally (not merely documented).**

Rejected alternatives:
- **Option B (gate it off)** would regress a real, working, already-relied-upon capability (confirmed live and exercised via `POST /downloads` in production-shaped testing, e.g. the WP-EAM-LOCAL-SERVICE-001 work package's own real end-to-end use of this exact backend) for a risk that is fully closeable without removing the feature. Rejected as an overcorrection.
- **Option C (leave the SSRF gap open, document only)** was rejected outright — Section 3 demonstrates a live, reproduced exploit against the running binary; documenting a known, open SSRF hole rather than closing it does not meet this ADR's own governing rule ("prefer structural enforcement over documentation").
- **Option D (move HTTP-fetch ownership to another subsystem)** was not seriously considered: `HttpConnector` is exactly the extension point `IConnector`'s own doc comment describes ("future work packages can add real transports (HTTP, FTP, browser automation, ...) without the Registry, Factory, or REST layer changing") — it is architecturally in the *right* place, not the wrong one. Moving it would be redesign for theoretical cleanliness, explicitly disallowed by this ADR's own governing rules.
- **A stricter Option (Source-registry allowlisting: require `source_uri` to match the Job's `OfficialSource.base_url`)** was considered and explicitly **not** implemented now. Nothing in WORK_PACKAGE-002/005/006 or `README.md` ever documented `source_uri` as constrained to `base_url` — every existing example (and the field's own free-form nature) shows it as an independent, per-request value. Imposing that constraint now would be a real product-behavior change (a Source's actual content is very plausibly hosted on a different domain/CDN than its own `base_url`, e.g. an "IEEE" source's `base_url` of `https://ieee.org` while real documents live on `ieeexplore.ieee.org`), not merely a security fix, and this ADR's own governing rule #3 ("do not 'fix' behavior until its intended architectural purpose is established") counsels against silently imposing it. **This is flagged as a natural, recommended follow-on hardening for a future work package with explicit product authority to decide it** (Section 10) — not a decision this ADR makes.

**Correspondingly, "arbitrary ports" (threat 9) is deliberately left unrestricted**: once the destination address itself cannot be an internal/private one, restricting which port a legitimate public host serves on adds no meaningful security value here and would be exactly the kind of "control added because checklists mention it" this ADR's own governing rules warn against.

## 6. Security Requirements (implemented — see Section 7 for the code)

1. URL parsing rejects userinfo (`user:pass@host`) unconditionally.
2. Destination resolution (`getaddrinfo`) validates **every** returned address (IPv4 and IPv6, including IPv4-mapped IPv6) against: loopback, RFC1918, link-local (169.254.0.0/16, which is what makes the cloud-metadata address a non-special-case), shared/CGNAT (100.64.0.0/10), multicast, broadcast, and unspecified/"this network" (0.0.0.0/8) ranges for IPv4; loopback, unspecified, link-local, multicast, and unique-local (fc00::/7) for IPv6.
3. The validated address is pinned for the actual connection (DNS-rebinding closure).
4. Redirects are followed manually, with the identical validation re-run on every hop, bounded by `max_redirects` (default 5).
5. Response bodies are capped at `max_response_bytes` (default 2 GiB), enforced during streaming (not after the fact).
6. TLS certificate verification remains at cpp-httplib's own secure default; never disabled.
7. No caller header (including `Authorization`) is ever accepted or forwarded.
8. **Test-only escape hatch, never live in production**: `allow_private_destinations` (a `ConnectorConfig::settings` key) disables check #2 above for a specific connector *instance* — used only by `tests/test_http_connector.cpp` to reach its own real local test server (itself on loopback, per this repository's own established "real local server, not a mock" testing convention). The live `"http-source"` connector `main.cpp` registers never sets it; a dedicated test (`main.cpp's real 'http-source' connector registration does not opt out of destination validation`) reads `main.cpp`'s own source text and asserts this directly, so a future edit that quietly added the flag there would fail CI, not merely violate a convention.

## 7. Implementation

Changed files:
- `services/acquisition/include/oep/acquisition/connectors/http_connector.hpp` — doc comment rewritten to describe the security contract; two new settings keys documented (`max_redirects`, `max_response_bytes`, `allow_private_destinations`).
- `services/acquisition/src/connectors/http_connector.cpp` — `parse_url` extended (userinfo rejection, host extraction); new `resolve_redirect`, `is_disallowed_ipv4`, `is_disallowed_ipv6`, `resolve_and_validate_host` helpers; `fetch` rewritten as a manual, per-hop-validated redirect loop using `httplib::ResponseHandler` (to decide whether to open the destination file and stream a body *before* any bytes are written, rather than after) and `set_hostname_addr_map` (DNS-rebinding pinning); response-size cap added to the content receiver.
- `services/acquisition/tests/test_http_connector.cpp` — `make_local_test_config()` added (the test-only escape hatch, used only by the pre-existing mechanics tests that need a real local server); 13 new tests (Section 8's TESTS list).
- `README.md` — see Section 9.

No other file was modified. `main.cpp`'s connector registration is unchanged (still registers `"http-source"` with no new settings — verified by the new test that reads it directly). `DownloadService`, the REST API routes, and the Official Source Registry are unchanged; the (deliberately deferred) base_url cross-check would touch these, and does not, because it was not implemented.

## 8. Testing Requirements / Results

**Unit tests** (`tests/test_http_connector.cpp`, real local server per hop, no internet dependency — `getaddrinfo` resolves numeric literals like `10.1.2.3` without any network access):

VALID:
- normal HTTPS external URL — proven live (see below), not merely unit-tested (no outbound internet access is exercised by the automated suite itself, per this ADR's own "must not depend on the public Internet" rule)
- redirect to a permitted destination — existing `HttpConnector.fetch follows a real HTTP redirect` test, unchanged in intent
- expected download response — existing fetch/mime-type/bytes-transferred assertions, unchanged in intent

REJECT (13 new tests, all passing, all deterministic/offline):
- IPv4 loopback (`127.0.0.1`)
- `0.0.0.0`
- IPv6 loopback (`[::1]`)
- RFC1918 (`10.x`, `172.16.x`, `192.168.x`)
- link-local IPv4 (`169.254.169.254` — the cloud-metadata address specifically, proving it needs no special case)
- IPv4-mapped IPv6 loopback (`[::ffff:127.0.0.1]`)
- URL with userinfo
- redirect to an unsupported scheme (`ftp://`)
- redirect loop exceeding `max_redirects`
- response exceeding `max_response_bytes`
- redirect to an unresolvable hostname (proves each hop is genuinely re-resolved, not skipped)
- `main.cpp`'s live registration does not opt into the test-only bypass

**Full existing suite**: `oep_acquisition_tests.exe`, all filters: **247 test cases, 568 assertions, 0 failed, 25 skipped**. All 25 skips are pre-existing, unrelated PostgreSQL-authentication environment gaps (`vault_api`, `acquisition_record_repository`, `acquisition_record_migration`, `acquisition_record_api` test files — none touch connectors) — **ENVIRONMENT BLOCKED**, not a regression from this change.

**Live exploitation-and-fix verification** (manual, one-off, against the real running `oep_acquisition.exe` — not part of the automated suite, exactly matching this ADR's own "do not make the *normal* test suite depend on the internet" scope, since this check specifically *needs* real internet to prove the legitimate path still works):
1. Started the real server (`services/acquisition/build/src/app/Debug/oep_acquisition.exe config/config.toml`), real PostgreSQL 18 backing it.
2. Created a real Official Source, a real Job, transitioned it to `queued`.
3. `POST /downloads` with `source_uri: "https://example.com/"` → **PASS**: real 200, 559 bytes downloaded, `status: "completed"`.
4. `POST /downloads` with `source_uri: "http://127.0.0.1:8080/health"` (the service attacking itself) → **PASS (rejected)**: `status: "failed"`, `error_message: "Destination host \"127.0.0.1\" resolves to a disallowed private/loopback/link-local address."`, and the destination directory was confirmed empty (no partial file ever written) — contrasted directly against the successful request's own non-empty `download.bin`.

**Threats that could not be reliably tested in this environment, documented rather than falsely claimed as covered**: a redirect specifically *into* a disallowed IP-class address (as opposed to an unresolvable one) was not exercised as an isolated automated test — doing so would require either real DNS control or reusing the same loopback bypass needed to reach the test server in the first place, which would mask the very check under test. The per-hop re-validation *mechanism* itself is proven (the unresolvable-redirect-target test demonstrates the loop re-runs full resolution/validation on every hop, not just hop 0), and the IP-class check itself is proven independently (13 tests above) — but the specific combination ("real redirect hop 2+ into a private IP") rests on code-path identity (the same `resolve_and_validate_host(current.host, allow_private_destinations)` call executes for every loop iteration, visible directly in `http_connector.cpp`), not a dedicated integration test. **ENVIRONMENT BLOCKED / GAP**, documented honestly rather than glossed over.

## 9. Documentation Changes

- **This file** (`ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`): Status changed from "Proposed" to "Resolved"; full decision, threat model, security requirements, and consequences added (this document).
- **`services/acquisition/README.md`**: every *"`StubConnector` is the only connector type"* / *"performs no real network communication"* claim was **STALE** (contradicted by the always-registered `http-source` connector) — corrected in place to describe both registered connector types accurately. See the diff for exact wording changed.
- **`services/acquisition/include/oep/acquisition/connectors/http_connector.hpp`**: doc comment was **CURRENT/CORRECT** for the mechanics it described, but **MISSING** any security-boundary description entirely (silent on SSRF) — extended, not rewritten.
- **No other document** (WP-005/006 task specs, other ADRs, deployment docs) was found to make a false claim requiring correction; WP-005/006 themselves are historical scope specifications for Milestone 1 and are not rewritten to pretend they anticipated this connector — their claims were accurate *as of their own ratification date*, and this ADR does not retroactively edit them.

## 10. Consequences

- The Official Source Registry's `trust_level`/`status`/`base_url` fields remain unused by the download path — a real, identified architectural gap, deliberately left to a future work package with explicit product authority (Section 5's rejected-stricter-alternative). Milestone-2 connector planning should treat "should `source_uri` be constrained to the Job's Source `base_url`?" as an open, unresolved product question, not something this ADR settled either way.
- `HttpConnector` is now a supportable, documented, security-reviewed Milestone-1(.5) capability — Milestone-2 planning should build on it rather than treating HTTP acquisition as greenfield work (the original ADR's own closing warning, now fully addressed rather than merely restated).
- The `allow_private_destinations` test-only setting is a permanent fixture of this connector's own test suite, guarded by a test that reads `main.cpp`'s literal source to ensure it is never live in production — any future contributor adding a new real connector registration that copies this pattern should be aware of, and preserve, that guard test's intent.

---

## Appendix: original "Consequences of not deciding" (superseded, preserved for history)

*"Milestone-2 planning that assumes 'no real connector exists yet, HTTP connectors are greenfield M2 work' is building on a false premise — real HTTP acquisition already exists, unreviewed, in the running M1 service. This should be resolved before M2 connector work begins, to avoid two independent HTTP-fetch implementations."* — now resolved, per Section 5 above.
