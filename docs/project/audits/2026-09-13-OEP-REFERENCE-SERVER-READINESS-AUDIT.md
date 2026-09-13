# OEP Reference Server — Implementation Readiness Audit — 2026-09-13

Point-in-time audit/readiness report for WP-SRV-001. Companion to [`ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md`](../../architecture/decisions/ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md), which establishes the architectural decision this report inspects readiness against.

**No production code was modified. No endpoint was added. No database or storage layout changed. `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` was not touched.**

---

## 1. Files/Areas Inspected

- `services/acquisition/src/api/server.cpp` — full route registration (all 31 routes across Sources/Jobs/Connectors/Downloads/Verifications/Metadata/Vault/Acquisition-Records/Health), confirmed zero authentication middleware.
- `services/acquisition/include/oep/acquisition/vault/{vault_entry.hpp,vault_entry_json.hpp,vault_path.hpp}` and `src/vault/{vault_entry_json.cpp,reference_vault_service.cpp,postgres_vault_repository.cpp}` — confirmed `vault_path` is a real, server-local filesystem path, computed from `storage_config_.root_path`, and is directly serialized into every `GET/POST /vault*` JSON response.
- `services/acquisition/include/oep/acquisition/downloads/download.hpp` — confirmed `Download.local_storage_path` is the same category of leak for the download-session record.
- `services/acquisition/include/oep/acquisition/registry/official_source.hpp`, `acquisition/acquisition_job.hpp` — Official Source Registry / Job model (unchanged from ADR-0003 investigation).
- `platform/oep_studio/lib/acquisition/inspector/acquisition_properties.dart`, `models/vault_entry_record.dart`, `wizard/acquisition_wizard_controller.dart` — confirmed Studio's existing Vault-artifact UI already reads `vaultPath` directly and already documents, in its own doc comment, that this cannot be resolved remotely — file actions are permanently disabled today because `vaultRoot` is never supplied anywhere in the codebase.
- `platform/oep_studio/lib/core/foundation/oep_api_bindings.dart` — confirmed Foundation is loaded via `DynamicLibrary.open`, i.e. genuinely in-process, with no server/socket boundary anywhere in the codebase.
- `services/exchange/apps/exchange-api/src/routes/download.ts`, and this session's own prior work (WP-EXC-013/014) — confirmed the Exchange download route's real, working, already-tested `X-Checksum-Sha256` artifact-transfer contract, reused as the model in ADR-0001 §6.
- `specifications/AP-EK-019_Knowledge_Package_Distribution_Exchange_Integration.md` — full 100-section read; confirmed it already fully specifies the Reference Library / Compiler / Exchange / Knowledge Runtime boundary and package-distribution lifecycle in detail. ADR-0001 defers to this specification rather than re-deriving it.
- `services/acquisition/src/app/main.cpp` (bind host `0.0.0.0:8080` default) and `services/exchange/apps/exchange-api/src/server.ts` (bind host `0.0.0.0` default) — both already network-bindable services, neither with authentication.
- `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` — read for context/awareness only (per its own user-owned, out-of-scope status); not incorporated into or referenced by ADR-0001's own content, and not modified.

## 2. APIs That Already Support the Reference Server Model

- **EAM's REST API generally**: real HTTP client/server separation already exists and is already exercised remotely-shaped (Studio's `AcquisitionApiClient` never touches EAM's database directly). This is most of the "boundary model" (ADR-0001 §3) already working today.
- **Exchange's package download route**: `GET /packages/{id}/download` — the exact artifact-transfer shape (metadata route + sibling bytes route, `X-Checksum-Sha256` header, client-side verification) ADR-0001 §6 reuses for the new Vault artifact contract. Already proven end-to-end (WP-EXC-013/014's own real, non-mocked test coverage).
- **EAM's Acquisition Record / provenance API** (`GET /acquisition-records/{id}`, `GET /acquisition-records/{id}/provenance`): already a pure metadata contract with no filesystem leakage — a working example of the pattern ADR-0001 §5 wants for Vault metadata too.
- **Knowledge Runtime's package validation pipeline** (per AP-EK-019, and Foundation's own Ed25519 trust verification, WP-REP-004): already transport-independent by design (AP-EK-019 §16 "Runtime Does Not Trust Transport") — no change needed to support a future remote package source, since the runtime already validates a package the same way regardless of where it came from.

## 3. APIs That Require Future Implementation

- **`GET /vault/{id}/artifact`** (ADR-0001 §6) — does not exist. This is the single concrete gap this readiness report is required to record, per the task's own "Known Current Gap." Not implemented by this WP.
- **A corrected `GET /vault/{id}` / `POST /vault` response body** that omits `vault_path` from the public JSON (ADR-0001 §5) — the route exists; the response-shaping correction does not.
- **A corrected `Download` response body** omitting `local_storage_path`, if downloads are ever exposed to a remote client the same way Vault entries are (not currently exposed outside EAM's own API, but the same leak pattern exists).
- **A Knowledge-package remote distribution surface** — AP-EK-019 §68-70 already conceptually defines `ExchangeClient`/`PackageManager`/`KnowledgePackageStore`, but no implementation of "download a `.oerp` package from a remote source and install it through Knowledge Runtime" exists in this repository today (distinct from Exchange's own Foundation-package install bridge, WP-EXC-013, which installs `.oep` *Foundation* packages, not `.oerp` *Knowledge* packages — these are two different package families with two different runtimes).
- **EAM API authentication** — no implementation exists; a prerequisite for safely exposing any of the above outside a trusted local network.
- **A server-side Foundation existence** — does not exist in any form; Foundation is purely an in-process library today (Section 4.6 of the ADR). Whether this is ever needed is an open question, not a scheduled work item.

## 4. Filesystem Assumptions That Break Remote Operation

Identified precisely, with citations:

1. `services/acquisition/src/vault/vault_entry_json.cpp:12` — `VaultEntry.vault_path` (a real server-local path) is serialized into every Vault API response.
2. `services/acquisition/include/oep/acquisition/downloads/download.hpp:35` — `Download.local_storage_path`, same category of leak.
3. `platform/oep_studio/lib/acquisition/inspector/acquisition_properties.dart:87-92` — Studio's own Vault-artifact file actions already assume co-located filesystem access, and already fail closed (never silently wrong, but currently permanently disabled) because that assumption doesn't hold for a remote EAM instance.
4. `platform/oep_studio/lib/core/foundation/oep_api_bindings.dart:19` — Foundation's entire existence is an in-process native library load; there is no filesystem assumption to break here so much as a *complete absence* of any remote path at all. This is the largest single gap if "Foundation over the network" is ever required — bigger than a response-field correction, and explicitly out of this ADR's scope to resolve (ADR-0001 §4.6, §13).

## 5. Security Boundaries

- **EAM**: no authentication on any route today (confirmed, `server.cpp`). Binds `0.0.0.0:8080` by default — reachable beyond localhost if network/firewall configuration permits, which is itself a live exposure already noted in `OEP_PROJECT_STATUS.md` Section 16 and unrelated to this WP.
- **Exchange**: no authentication either (prior-session finding, WP-EXC-010 audit), same `0.0.0.0` default bind pattern.
- **Foundation**: not network-reachable at all today (in-process only) — trivially "secure" only because it has no remote attack surface, not because of any access control.
- **Knowledge Runtime trust**: Ed25519 verification exists and is genuinely wired into Foundation's own installer (WP-REP-004, confirmed in prior session work); AP-EK-019's own broader trust-store concept (§64-65, publisher key rotation) remains **not yet fully implemented in production** per `OEP_PROJECT_STATUS.md` Section 16's own standing note — this readiness report does not claim otherwise, and ADR-0001 explicitly forbids the Reference Server bypassing Knowledge Runtime trust regardless of that gap's current state.

## 6. Unresolved Questions (recorded, not answered)

1. Should `.oerp` Knowledge packages and `.oep` Foundation packages ever share one distribution/install surface, or remain permanently distinct? Not decided here.
2. If Foundation ever needs remote-repository capability, does that mean a new server-side service, or a remote-mountable repository protocol Foundation itself understands? Not decided here.
3. Should the future `GET /vault/{id}/artifact` route live under EAM's existing service, or under a new "Knowledge services" logical grouping (ADR-0001's own diagram) even while physically still served by the EAM process? Not decided here — a future work package's call, informed by whatever the "Knowledge services" logical box in ADR-0001 §2 turns out to require physically.
4. What is the actual EAM→Reference Library handoff mechanism (a Vault artifact becoming canonical knowledge)? No implementation or even a proposed mechanism exists today; recorded as an open question, matching ADR-0001 §4.2's own explicit statement that this handoff is unimplemented.

## 7. Recommended Next Implementation Work Packages (not started by this report)

1. **WP-SRV-002 (proposed)**: implement `GET /vault/{id}/artifact` and correct the `GET/POST /vault` response body to omit `vault_path`, per ADR-0001 §6 exactly. Smallest, most concrete next step; closes the one gap this ADR was specifically asked to formalize.
2. **WP-SRV-003 (proposed)**: EAM API authentication — a prerequisite for any of the above being safe to expose beyond a trusted local network.
3. A future, separately-scoped work package for Knowledge-package remote distribution, once product priority determines it is actually needed (AP-EK-019's own Implementation Sequence, §97, already lists this in detail — this readiness report does not re-derive that sequence, only points to it).

## 8. Validation Performed

- `git status` before and after all edits — confirmed only the two new documentation files were added; the two pre-existing untracked/modified artifacts (`platform/oep_instruments/.../*.cache.dill.track.dill`, the LibreOffice lock file) and the user-owned `docs/server/` directory were untouched.
- `git diff --check` — clean.
- Manual review of both new documents for internal consistency: every ownership claim in ADR-0001 §4 is either (a) reaffirming an already-ratified boundary (AP-EK-019, WP-EXC-013) or (b) citing a specific, checked code location in this repository — no speculative claim about what a subsystem "will" do.
- No endpoint, schema, or config file was added or changed — confirmed via `git diff --stat` (documentation files only).

## 9. Remaining Bounded Gaps (explicitly not solved by this WP)

Exactly as ADR-0001 §11 states as non-goals, restated here as the standing gap list: `GET /vault/{id}/artifact` does not exist; EAM/Exchange authentication does not exist; Foundation has no server-side existence; remote Knowledge-package distribution does not exist; the EAM→Reference Library handoff does not exist. All five are explicitly recorded, not silently solved, per this WP's own governing instruction.
