# ADR-0003 Resolution Audit — HttpConnector Security, Scope, and SSRF — 2026-09-13

Point-in-time audit/implementation report. Companion to [`services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`](../../../services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md), which is now the authoritative, Resolved decision record. This document is the audit trail behind that resolution: what was inspected, what was found, what was changed, and what was tested.

**No Foundation, Exchange, OEP Engine, Diagram Studio, or Studio source was touched. Only `services/acquisition` (HttpConnector + its tests + its README) was modified. Nothing was pushed.**

---

## 1. Files Inspected

- `services/acquisition/include/oep/acquisition/connectors/{connector,http_connector,stub_connector,connector_factory,connector_registry,connector_errors,connector_json}.hpp`
- `services/acquisition/src/connectors/{connector,http_connector,stub_connector,connector_factory,connector_registry,connector_json}.cpp`
- `services/acquisition/src/app/main.cpp` (connector registration, lines ~139-170)
- `services/acquisition/src/downloads/{download_service.cpp,validation.cpp}` and their headers (traced `source_uri`'s full origin)
- `services/acquisition/include/oep/acquisition/registry/official_source.hpp` (the `base_url`/`trust_level`/`status` trust anchor that exists but is unused by the download path)
- `services/acquisition/include/oep/acquisition/acquisition/acquisition_job.hpp` (confirmed `source_id` foreign-keys to `OfficialSource`)
- `services/acquisition/src/api/server.cpp` (confirmed zero authentication/middleware on any route)
- `services/acquisition/tests/test_http_connector.cpp` (full read, then extended)
- `services/acquisition/docs/decisions/ADR-0002-PROPOSED-CONNECTOR-CONTENT-RETRIEVAL.md`, `ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md` (the pre-existing "Proposed" finding — the actual starting point for this work)
- `services/acquisition/README.md` (every "StubConnector is the only connector type" claim, all now corrected)
- `services/acquisition/build/_deps/httplib-src/httplib.h` (vendored `cpp-httplib` 0.18.5) — read directly for: `set_hostname_addr_map`/`create_client_socket`/`create_socket` (DNS-pinning mechanism), `ResponseHandler` invocation semantics around `follow_location_`, TLS certificate-verification default, redirect-count default, and confirmed absence of any automatic proxy-environment-variable reading
- `docs/project/audits/2026-09-13-OEP-RELEASE-BOUNDARY-AUDIT.md` (for naming convention and prior ADR-0003 cross-reference)

## 2. Call-Site Findings

- `HttpConnector` is constructed exactly once, in `main.cpp`'s startup sequence, registered unconditionally under `connector_id: "http-source"`, `type: "http"` (line ~163-169).
- Reached at runtime exclusively via `DownloadService::start_download` (`download_service.cpp:66 connector_registry_.resolve(request.connector_id)`), itself reachable only via `POST /downloads` (`server.cpp:515`).
- `tests/test_http_connector.cpp` is its only test consumer; no other file references `HttpConnector` directly.

## 3. Actual Data Flow (confirmed against the real code, not assumed)

```
Caller (no authentication anywhere on this API) 
    -> POST /downloads {job_id, connector_id: "http-source", source_uri: <any string>}
    -> validation.cpp: non-empty check only
    -> download_service.cpp: looks up Job by job_id (checks executable), looks up
       Connector by connector_id -- NEVER reads Job.source_id -> OfficialSource.base_url
    -> HttpConnector::fetch(source_uri)   [Category E: arbitrary, caller-controlled]
```

Destination authority: **Category E**, confirmed by tracing `source_uri` from the JSON request body (`validation.cpp:37`) straight through to `AcquisitionRequest::source_uri` (`download_service.cpp:98`) with zero intermediate validation against any registered source. The Official Source Registry's `base_url`/`trust_level`/`status` (Category C's real trust anchor) exists in the schema and domain model but is architecturally disconnected from this path — a genuine finding, documented in the ADR (Section 2) and explicitly not "fixed" by this work (see Section 6 below, "why not").

## 4. Security Findings (before this ADR's implementation)

- **Confirmed SSRF, closed and proven**: the *unpatched* vulnerability was established by direct code inspection (Section 3 above: zero destination validation anywhere in the pre-existing code, `source_uri` flowing unchecked from the request body straight into a real outbound HTTP client). The fix was implemented before any live server was started in this session, so rather than separately reproducing the exploit against an unpatched build, the *patched* binary was demonstrated live: the identical request (`source_uri: "http://127.0.0.1:8080/health"`) was issued against the real running, patched service and correctly rejected (Section 8 below) — the stronger and more directly useful evidence that the gap Section 3 identifies is actually closed, not merely that it once existed.
- Zero destination-validation code existed anywhere in the codebase prior to this change (exhaustive grep for `loopback`/IP-range literals/`SSRF`/`allowlist` returned nothing).
- No authentication exists on the EAM REST API at all — the SSRF vector is reachable by anything that can route to the configured port (`0.0.0.0:8080` by default).
- Redirects were followed automatically and unconditionally (`set_follow_location(true)`, cpp-httplib default cap 20 hops) with no per-hop destination check.
- TLS certificate verification, request timeouts, proxy behavior, and header/credential handling were **already safe by default** and required no change (cpp-httplib's own secure defaults; confirmed by direct inspection of `httplib.h`, not assumed).

## 5. Documentation Drift (found and corrected)

| Location | Claim | Classification | Resolution |
|---|---|---|---|
| `services/acquisition/README.md` (4 locations: lines ~54, ~235, ~794-814, ~1322) | "`StubConnector` is the only connector type" / "performs no real network communication" | **STALE** | Corrected in place — each site now states both registered connector types accurately and points to ADR-0003 |
| `services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md` | Status: Proposed | **STALE (superseded by this work)** | Status changed to Resolved; full decision record added; original text preserved as history |
| `services/acquisition/include/oep/acquisition/connectors/http_connector.hpp` | Doc comment described mechanics accurately | **MISSING** (silent on SSRF) | Extended with the full security contract description |
| WORK_PACKAGE_005.md / WORK_PACKAGE_006.md (historical scope specs) | "No implementation shall perform actual network communication" | **CURRENT/CORRECT as historical scope statements** | Not modified — accurate as of their own ratification date; this ADR does not retroactively edit historical specifications, per its own governing rule |
| `README.md`'s "Connectors are not yet associated with Official Sources or Acquisition Jobs" note | Still accurate | **CURRENT/CORRECT** | Not modified — correctly anticipates the deferred base_url-cross-check question this ADR explicitly leaves open |

## 6. Decision Rationale (summary — full reasoning in the ADR itself)

**Option A (ratify, with the SSRF gap closed structurally)** was chosen. Option B (gate it off) would regress a real, relied-upon capability for a fully-closeable risk. Option C (document only) was rejected outright — a live, reproducible SSRF hole is not something this audit's own governing rules permit leaving open and merely writing down. Option D (move ownership elsewhere) was rejected — `HttpConnector` sits exactly where `IConnector`'s own design intends real transports to live.

**Explicitly not implemented, and why**: cross-checking `source_uri` against the Job's `OfficialSource.base_url`. Nothing in the ratified WORK_PACKAGE-002/005/006 specifications, nor `README.md`'s own documented examples, ever constrained `source_uri` to match a Source's `base_url` — imposing that now would be a real product-behavior change (a Source's actual content is plausibly hosted on a different domain than its own listed `base_url`), not a security fix, and this ADR's own governing rule against "fixing behavior before its intended architectural purpose is established" counsels leaving this to a future work package with explicit product authority. This is documented as an open question in the ADR (Section 10), not silently decided either way.

**Explicitly not implemented**: a port allowlist/denylist. Once destination *address* classes are restricted to non-internal ranges, restricting *ports* on an already-public host adds no meaningful security boundary this service needs to own, and would be exactly the kind of checklist-driven control this audit's own rules warn against adding without a concrete rationale.

## 7. Implementation Changes

- `services/acquisition/src/connectors/http_connector.cpp`: `parse_url` extended (userinfo rejection; separate host extraction matching cpp-httplib's own internal authority-parsing grammar exactly, confirmed by reading `Client::Client(scheme_host_port)`'s regex in `httplib.h`); new `resolve_redirect`, `is_disallowed_ipv4`, `is_disallowed_ipv6`, `resolve_and_validate_host` helpers; `fetch` rewritten as a manual, per-hop-revalidated redirect loop (`set_follow_location(false)`, `httplib::ResponseHandler` used to gate opening the destination file until a genuine 2xx is confirmed, `set_hostname_addr_map` used to pin the validated address against DNS rebinding); response-size cap added inside the streaming content receiver; two new settings (`max_redirects` default 5, `max_response_bytes` default 2 GiB) plus one test-only setting (`allow_private_destinations`, never set by the real `main.cpp` registration — enforced by a dedicated test that reads `main.cpp`'s own source text).
- `services/acquisition/include/oep/acquisition/connectors/http_connector.hpp`: doc comment extended with the full security contract.
- `services/acquisition/tests/test_http_connector.cpp`: `make_local_test_config()` helper added (test-only escape hatch for the pre-existing mechanics tests, which need a real local server on loopback); 13 new tests covering every REJECT scenario in Section 8 below, plus new `TestHttpServer` routes (`/redirect-to-unsupported-scheme`, `/redirect-loop`, `/redirect-to-unresolvable`).
- `services/acquisition/README.md`: 4 stale claims corrected (Section 5 above).
- `services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`: resolved in place (Status: Resolved), full ADR content added, original text preserved as history.

**No Foundation, Exchange, OEP Engine, Diagram Studio, or Studio source file was touched.** No new HTTP library was introduced (`cpp-httplib` was already the dependency in use). No unrelated refactoring was performed — `StubConnector`, `ConnectorFactory`, `ConnectorRegistry`, `DownloadService`, the REST API layer, and the Official Source Registry are byte-for-byte unchanged.

## 8. Test Results

**Build**: `cmake --build . --config Debug` (full project, including tests) — **PASS**, zero errors (only pre-existing, unrelated `LNK4099`/`LNK4098` linker warnings about missing zlib PDB symbols and a CRT-library conflict, present before this change and unrelated to it).

**`tests/test_http_connector.cpp`** (23 test cases, 85 assertions) — **PASS**, all green:
- 10 pre-existing tests (mechanics: connect/disconnect, capabilities, config validation, real fetch, real redirect, real 404, non-http(s) rejection, overwrite=false, cancellation before/during transfer, `fetch_outcome=failure`) — all still pass, using the new `make_local_test_config()` where a real local test server is needed
- 13 new ADR-0003 tests (destination-policy REJECT cases) — all pass, all deterministic, none depend on internet access:
  - IPv4 loopback, `0.0.0.0`, IPv6 loopback, RFC1918 (×3), link-local/cloud-metadata address, IPv4-mapped IPv6 loopback, userinfo-in-URL, redirect to unsupported scheme, redirect loop exceeding `max_redirects`, oversized response, redirect to an unresolvable host (proves per-hop re-validation), and a direct assertion against `main.cpp`'s own source text that the live registration never opts out of validation

**Full suite, all filters** (`oep_acquisition_tests.exe`, no filter): **247 test cases, 568 assertions, 0 failed, 25 skipped** — **PASS** (with 25 **ENVIRONMENT BLOCKED**, all pre-existing PostgreSQL-authentication gaps in `test_vault_api.cpp`/`test_acquisition_record_repository.cpp`/`test_acquisition_record_migration.cpp`/`test_acquisition_record_api.cpp`, none of which touch connectors — confirmed unrelated to this change, not a regression).

**Live exploitation-and-fix verification** (manual, against the real running binary, not part of the automated suite — this is the one check that genuinely needs real internet, exactly the kind this audit's own rules say the *normal* suite must not depend on):
1. Started the real server with real PostgreSQL 18.
2. Created a real Official Source + Job, transitioned the Job to `queued`.
3. `POST /downloads` with `source_uri: "https://example.com/"` → **PASS**: real 200, 559 bytes, `status: "completed"`.
4. `POST /downloads` with `source_uri: "http://127.0.0.1:8080/health"` → **PASS (correctly rejected)**: `status: "failed"`, `error_message: "Destination host \"127.0.0.1\" resolves to a disallowed private/loopback/link-local address."` — and the destination directory was confirmed **empty** (no partial file), contrasted against the successful request's real, non-empty `download.bin`.
5. Server stopped cleanly; both jobs' empty/populated workspace directories removed as test cleanup (not committed — `services/acquisition/data/` is a runtime directory, unaffected by this audit's git changes).

**Threats not reliably testable in this environment, honestly documented rather than falsely claimed as covered**: a redirect specifically *into* a disallowed IP-class address (as opposed to an unresolvable hostname) could not be exercised as an isolated automated test without either real DNS control or reusing the same loopback bypass needed to reach the test server itself (which would mask the very check under test). The per-hop re-validation *mechanism* is proven (the unresolvable-redirect test demonstrates the loop re-runs full resolution on every hop); the IP-class check itself is proven independently (13 tests); the specific combination rests on code-path identity, confirmed by direct code reading, not a dedicated integration test. **GAP**, documented in both the ADR and here.

## 9. Remaining Bounded Gaps

1. `source_uri` is still not cross-checked against the Job's `OfficialSource.base_url` — a deliberate, documented deferral (Section 6), not an oversight. Any future work package proposing this should treat it as a product/architecture decision, not merely a security patch.
2. Redirect-into-a-private-address is not independently, automatically tested (Section 8's last item) — documented, not silently skipped.
3. `allow_private_destinations` is a permanent test-support fixture; its non-use in production is enforced by a test reading `main.cpp`'s literal source, not by the type system — a future contributor adding a second real HTTP-fetching connector elsewhere should be pointed at this same pattern rather than reinventing it, but nothing currently prevents that from being forgotten if this file's own conventions aren't followed.
4. Port-based restrictions were deliberately not added (Section 6) — if a future requirement emerges (e.g., restricting fetches to ports 80/443 only), that is a new, separate decision, not something this ADR silently ruled out forever.

## 10. Release-Boundary Impact

This work resolves a Proposed architectural gate the release-boundary audit (`2026-09-13-OEP-RELEASE-BOUNDARY-AUDIT.md`) and ADR-0003's own original text flagged as needing a decision before Milestone-2 connector planning proceeds. `OEP_PROJECT_STATUS.md`'s own EAM section should be updated to record ADR-0003 as Resolved (LOCAL / NOT PUSHED) rather than Proposed/open — see the accompanying `OEP_PROJECT_STATUS.md`/`docs/project/OEP_RELEASE_HISTORY.md` updates in this same commit. This does **not** change EAM Milestone-1/M2 scope claims beyond this one connector's own status, and does not touch any of the other open items the release-boundary audit identified (Exchange package history, credential-exposure documentation drift, etc.).

## 11. Commit

One dedicated commit, not pushed: `ADR-0003: resolve HttpConnector security and scope`.
