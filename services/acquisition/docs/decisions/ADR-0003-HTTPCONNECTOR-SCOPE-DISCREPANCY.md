# ADR-0003 — HttpConnector Exceeds Ratified Milestone-1 Scope (Discovered, Not Introduced, by WP-017)

**Status:** Proposed — requires a decision from whoever owns Milestone-1 scope authority; not self-ratified by this audit.
**Date:** 2026-09-12
**Discovered during:** WP-017 (EAM / Reference Vault Implementation Audit), Section 4 (Connector Audit)
**Author:** Claude (Sonnet 5), during WP-017's implementation audit — this ADR documents a finding, it does not implement or remove anything.

## Context

WP-005 (Engineering Source Connector Framework) states explicitly: *"No implementation shall perform actual network communication."* WP-006 (Engineering Downloader) lists "HTTP client" under its own "Do NOT implement" list. The service's own `README.md` states, in multiple places, that *"`StubConnector` remains the only connector type"* and that this "performs no real network communication."

WP-017's Connector Audit (its own Section 4) found this claim to be **false as of the current codebase**. A second, fully implemented `IConnector`:

- `include/oep/acquisition/connectors/http_connector.hpp` / `src/connectors/http_connector.cpp` — `HttpConnector`, using `cpp-httplib`'s client mode to issue real `GET` requests, stream a real response body to disk, follow redirects, honor cancellation via `std::stop_token`, and report real HTTP status/MIME type/ETag.
- Registered at startup in `src/app/main.cpp` under connector id `http-source`, type `"http"`, alongside `example-stub` — **live in the running server today**, reachable via the existing `POST /downloads` route with `"connector_id": "http-source"` and any `http://`/`https://` `source_uri`.
- Has its own dedicated test suite (`tests/test_http_connector.cpp`), including tests that perform a real HTTP fetch, follow a real redirect, and handle a real 404 — i.e. this is not a dead/unreachable stub left mid-implementation; it is functional.

This was present before WP-017 began (confirmed via `git log` on `http_connector.cpp`: introduced by the single squashed commit that imported the `oep_acquisition` service into this monorepo, `af5c6ec`, 2026-09-04 — WP-017 did not write it, and the pre-import history that would show exactly when/why it was added relative to WP-005/006's ratification is not available in this monorepo).

## Why this needs a decision, not a silent fix

Per this audit's own governing rule ("Do not assume the documentation and implementation agree. Where they differ, document the difference explicitly. Do not silently rewrite architecture to match implementation."), WP-017 is explicitly not authorized to unilaterally decide this either way:

- **Removing `HttpConnector`** would be an architectural redesign in the opposite direction — deleting a working, tested capability — which WP-017's own scope ("Do NOT redesign EAM... unless the audit proves that an existing governing specification already requires the capability at this phase") does not clearly authorize either, since nothing says this capability must *not* exist forever, only that WP-005/006 didn't ask for it *yet*.
- **Leaving it silently undocumented** is worse: the README's claims about M1 scope are then simply wrong, and a future reader (or a future work package's own scope reasoning, which leans heavily on "what does the current implementation actually do") would be misled.

## The actual gap, concretely

1. **Scope**: `HttpConnector` performs the exact capability ("HTTP client", "actual network communication") that WP-005 and WP-006 both explicitly excluded from Milestone 1.
2. **Trust boundary (WP-017 Section 17 finding)**: `HttpConnector::fetch` validates only that `source_uri` has an `http://`/`https://` scheme (see `parse_url` in `http_connector.cpp`) — it does **not** cross-check the requested host against the Official Source Registry's `base_url` for the Job's actual `source_id`, and `set_follow_location(true)` means it will follow a redirect anywhere, including a private/internal address. There is no destination allowlist. This is a genuine SSRF-shaped gap: a `POST /downloads` request naming `connector_id: "http-source"` can direct this live service to fetch an arbitrary URL, including internal network addresses, constrained only by whatever network access the process itself has.
3. **README accuracy**: every "StubConnector is the only connector" claim in `README.md` is factually incorrect right now.

## Options for the actual decision-maker

**Option A — Ratify `HttpConnector` as an approved, in-scope Milestone-1 (or Milestone-1.5) extension.** Requires: closing the SSRF gap (validate `source_uri`'s host against the resolved Job's Official Source `base_url` before fetching, at minimum), and correcting `README.md` to describe it accurately instead of claiming it doesn't exist.

**Option B — Treat it as out-of-scope scope creep and gate it off** (e.g. do not register the `"http"` factory / `http-source` connector in `main.cpp` until a future work package formally reintroduces it under its own spec and security review), keeping the source files in tree but dormant, matching WP-005/006's actual ratified scope.

**Option C — Leave it exactly as-is and only correct the documentation** to honestly describe it as an already-implemented, not-yet-security-reviewed capability, deferring the SSRF fix to a dedicated future work package.

This ADR takes no position between A/B/C — that decision belongs to whoever holds Milestone-1/M2 scope authority for this service, not to an audit task. WP-017's own final recommendation (`EAM_REFERENCE_VAULT_M2_READINESS.md`) treats this as an open condition rather than assuming any of the three.

## Consequences of not deciding

Milestone-2 planning that assumes "no real connector exists yet, HTTP connectors are greenfield M2 work" is building on a false premise — real HTTP acquisition already exists, unreviewed, in the running M1 service. This should be resolved before M2 connector work begins, to avoid two independent HTTP-fetch implementations.
