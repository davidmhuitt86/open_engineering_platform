====================================================================
OPEN ENGINEERING PLATFORM
MASTER PROJECT STATUS & RELEASE TRACKING RECORD
====================================================================

Document: OEP-PROJECT-STATUS-MASTER
Record Type: Canonical Project Status / Capability / Release Register
Organization: Divad Technology Group, LLC
Platform: Open Engineering Platform (OEP)

LAST AUDITED:
    2026-09-16 (WP-CTRL-002 reconciliation)

CANONICAL:
    This file is the one authoritative, current, whole-platform status
    document. See docs/project/README.md for the full documentation
    hierarchy (versioning policy, milestone roadmap, release history,
    point-in-time audits). Do not create a second competing root-level
    status document.

====================================================================
0. REPOSITORY BASELINE — GITHUB MAIN vs. LOCAL WORKING TREE
====================================================================

GITHUB main (origin/main), verified via `git log origin/main -1`
(WP-CTRL-002, 2026-09-16 reconciliation pass):
    a36f69e  "Merge remote-tracking branch 'origin/main'"

Previous documented baseline (WP-CTRL-001, 2026-09-13): `4798912`.

The commits below (`889cec2` through `a36f69e`) are now **PUSHED** to
origin/main as of this reconciliation. Listed oldest to newest; see
`docs/project/OEP_RELEASE_HISTORY.md` for the full per-entry writeup
(purpose, verification evidence, deferred items) of each:

    889cec2  feat(server): establish EAM PostgreSQL data infrastructure (WP-SRV-005)
    ce2fbf9  feat(server): add EAM API TLS boundary (WP-SRV-004)
    0421ca2  feat(server): add EAM API authentication boundary (WP-SRV-003)
    e6018d1  WP-SRV-002: implement GET /vault/{id}/artifact and remove filesystem paths from public API
    220d542  docs(server): audit reference server infrastructure bring-up
    a93192d  docs/server: define OEP Reference Server boundary and artifact contract
    77cf395  docs/project: reconcile status with pushed main (WP-CTRL-001 itself)
    0ecded6..a1c8fc3  docs(server): ADR-0001 through ADR-0006 (Server Repository Service
             architecture — service contract, semantics/state model, API/persistence
             boundary, implementation readiness/wire contract, and two wire-contract
             corrections) — see the new Section 11A below
    9bde275  WP-SRV-011: Server Repository first vertical slice (persistence & domain core)
    4618729  WP-SRV-011A: correct PostgreSQL concurrency validation
    48feefe  server bring up docs set
    31cb11b  WP-SRV-011B: add Server Repository API wire version
    fd8d630  WP-SRV-011C: enforce UUIDv4 identity contract
    0d5be8a  WP-SRV-012: implement repository tombstone semantics
    fc0fa5f..7861146  UX-001 / docs(ux): OEP UX architecture, EAM workspace/interaction
             specs, and the sectional UI implementation kit — documentation/specification
             only, no source implementation landed by these commits
    66af1f5  WP-SRV-012A: correct create-shaped tombstone restoration
    a36f69e  Merge remote-tracking branch 'origin/main' (unrelated docs(ux) commits that
             landed on origin/main while WP-SRV-012A was in progress; no conflicts, no
             file overlap with services/repository/)

RULE:
    A status label of "LOCAL / NOT PUSHED" anywhere below this line
    means exactly that: as of this document's own LAST AUDITED date, no
    commit in the list above (or any commit made after it) has reached
    origin/main. Once verified pushed, the label is removed or replaced
    with "PUSHED" — it is never left in place merely as historical
    narration. See docs/project/OEP_RELEASE_HISTORY.md for the full
    chronological record, including each commit's own push status at
    the time it was made.

====================================================================
1. PURPOSE
====================================================================

This document is the master operational record for the current state of
the Open Engineering Platform.

It exists to answer four questions at all times:

1. What actually works?
2. What partially works or has bounded limitations?
3. What has been started but is not yet functional?
4. What has not been started?

It also tracks:

- architectural maturity
- completed work packages
- current work packages
- known defects
- technical debt
- architectural gaps
- release gates
- platform versions
- subsystem versions
- milestone objectives
- blockers
- deferred capabilities
- future capabilities
- verification evidence
- next recommended work

This document must distinguish VERIFIED implementation from planned
or documented intention.

====================================================================
2. STATUS TAXONOMY
====================================================================

GREEN / VERIFIED
    Implemented and actually verified through appropriate tests,
    integration testing, or real-world operation.

GREEN / COMPLETE WITH BOUNDED GAPS
    Core capability works and is verified, but explicitly documented
    limitations remain.

YELLOW / PARTIAL
    Significant implementation exists, but the capability is not yet
    complete or production-ready.

YELLOW / HARDENING
    Core capability works but requires production hardening,
    security work, performance work, or broader validation.

ORANGE / STARTED
    Architecture/code exists, but the capability is not yet a
    complete usable feature.

RED / NOT STARTED
    Planned architecture/specification exists, but implementation has
    not meaningfully begun.

RED / BLOCKED
    Work cannot responsibly proceed because of a dependency,
    unresolved architecture decision, security issue, or other gate.

BLUE / DEFERRED
    Intentionally postponed by architecture/scope decision.

GRAY / FUTURE
    Long-term capability; not currently part of an active milestone.

IMPORTANT:
"Code exists" does NOT automatically mean "works."
"Documentation exists" does NOT automatically mean "implemented."
"Tests exist" does NOT automatically mean "production-ready."

====================================================================
3. OVERALL PLATFORM STATE
====================================================================

CURRENT PLATFORM VERSION:
    0.1.0 legacy development version

RECOMMENDED NEXT PLATFORM VERSION:
    0.2.0

CURRENT PLATFORM MATURITY:
    Integrated architectural alpha / pre-beta

CURRENT MAJOR STATE:
    Core platform architecture substantially established.
    Several major subsystems are operational.
    Diagram Studio has a substantial working vertical slice.
    EKE/Foundation have reached internal v1.0 architecture freezes.
    EAM has completed its M1 MVP.
    Exchange remains substantially incomplete.
    Production hardening, integration depth, and release discipline
    remain unfinished.

CURRENT RELEASE TARGET:
    OEP 0.2.0 — Integrated Engineering Platform Foundation

0.2.0 SHOULD NOT MEAN:
    "everything in OEP is finished."

0.2.0 SHOULD MEAN:
    "OEP has moved beyond its original prototype/foundation 0.1.x
     identity and now contains a coherent, integrated set of working
     platform capabilities."

====================================================================
4. VERSIONING MODEL
====================================================================

OEP PLATFORM VERSION
    Describes the integrated OEP product/platform release.

    Current:
        0.1.0

    Next:
        0.2.0

FOUNDATION VERSION
    Currently independent implementation version:
        0.1.0

    Future policy:
        Align with platform release where appropriate, but do not
        blindly change it until version ownership is formally defined.

ENGINE VERSION
    Currently:
        0.1.0

STUDIO VERSION
    Currently:
        0.1.0

EXCHANGE VERSION
    Currently:
        0.1.0

PUBLIC C API VERSION
    Current:
        21

ABI VERSION
    Current:
        1

These are NOT the same version number as the OEP product version.

EKE INTERNAL ARCHITECTURE VERSION
    Engineering Knowledge Engine:
        v1.0 architecture freeze

This does NOT mean:
    OEP Platform = v1.0

PACKAGE VERSION
    Independent package semantic versions.
    Must remain separate from OEP platform release version.

KNOWLEDGE PACKAGE SCHEMA VERSION
    Independent from OEP platform version.

PROTOCOL VERSIONS
    OIP and other wire/protocol versions remain independently managed.

VERSIONING RULE:
    Never use the OEP platform version as a substitute for:
    - API version
    - ABI version
    - package version
    - database schema version
    - protocol version
    - knowledge schema version

====================================================================
5. RELEASE MILESTONE STRATEGY
====================================================================

OEP 0.1.x
    Original architectural foundation / early development stage.

OEP 0.2.x
    Integrated Engineering Platform Foundation.

    Primary objectives:
    - stabilize core Foundation
    - establish integrated Engine
    - establish working Studio
    - establish working Diagram Studio vertical slice
    - establish EKE runtime
    - establish EAM M1/Vault foundation
    - establish initial Instrument/DMM integration
    - establish Exchange foundation
    - establish coherent release/version identity
    - eliminate major documentation/status ambiguity

OEP 0.3.x
    M2 / integration and production-hardening expansion.

    Expected:
    - Acquisition Record
    - stronger provenance
    - EAM/Vault M2 capabilities
    - Exchange integration
    - broader Studio integration
    - production security/hardening

OEP 0.4.x
    Expanded integrated beta platform.

OEP 0.5.x
    Feature-complete beta target.

OEP 0.6–0.8.x
    Integration, ecosystem, performance, reliability and
    production-readiness expansion.

OEP 0.9.x
    Release Candidate series.

OEP 1.0.0
    First stable platform release.

1.0.0 REQUIREMENT:
    Must represent a coherent supported platform, not simply the
    existence of many implemented features.

====================================================================
6. PLATFORM FOUNDATION
====================================================================

------------------------------------------------------------
6.1 Foundation Repository Runtime
------------------------------------------------------------

STATUS:
    GREEN / COMPLETE

WP-REP-001 through WP-REP-008:
    Implemented and verified according to existing Foundation review.

Capabilities established include:
    - package installation
    - registry
    - transactions
    - trust/signing
    - dependency resolution
    - RuntimeService orchestration
    - uninstall/update
    - merge engine

INTERNAL MATURITY:
    v1.0 architecture/freeze

KNOWN GAPS:
    - authentication stub
    - filesystem stub
    - licensing stub
    - logging stub
    - telemetry stub
    - transactions placeholder directory
    - other documented Foundation cleanup items

These are not evidence that the repository runtime itself is
nonfunctional.

------------------------------------------------------------
6.2 Public C API
------------------------------------------------------------

STATUS:
    GREEN / IMPLEMENTED

CURRENT:
    OEP_API_VERSION = 21
    OEP_ABI_VERSION = 1

The API has progressed substantially beyond the original 0.1.0
platform version.

CURRENT API CAPABILITIES INCLUDE:
    - runtime lifecycle
    - repository access
    - object enumeration
    - relationship enumeration
    - repository search
    - object mutation
    - relationship mutation
    - transactions
    - batch mutation
    - diagram identity/API additions

KNOWN GAPS:
    - inconsistent ownership conventions
    - very large oep_api.cpp
    - some C-boundary functionality remains intentionally narrower
      than C++ internals

IMPORTANT:
    API version and OEP product version remain separate.

------------------------------------------------------------
6.3 Foundation Documentation
------------------------------------------------------------

STATUS:
    YELLOW / RECONCILIATION REQUIRED

Known problems:
    - PROJECT_STATUS.md historically stale
    - CURRENT_SPRINT.md historically contradictory
    - multiple numbering schemes
    - duplicate documentation
    - separate specifications trees without a clear relationship
    - historical work packages not fully indexed

This is a project-management/documentation problem, not evidence that
the Foundation runtime itself is incomplete.

====================================================================
7. ENGINEERING KNOWLEDGE ENGINE
====================================================================

STATUS:
    GREEN / INTERNAL v1.0 COMPLETE WITH BOUNDED GAPS

WP-EKE-001 through WP-EKE-008:
    Implemented.

ENGINE LAYERS INCLUDE:
    - Engineering Knowledge Runtime Core
    - Engineering Knowledge Graph Engine
    - Engineering Query Engine
    - Engineering Rules Engine
    - Engineering Validation Engine
    - Engineering Analysis & Reasoning Engine
    - Engineering Intelligence Platform
    - EKE v1.0 integration/release/freeze

INTERNAL STATUS:
    v1.0 architecture freeze

KNOWN BOUNDED GAPS:
    - GraphML export placeholder
    - shallow Studio-side test depth
    - in-memory/process-local sessions
    - explicit caller-driven graph/cache invalidation
    - fixed rule vocabulary
    - some limited C API exposure
    - no automatic event subscription/invalidation

IMPORTANT:
    EKE v1.0 means the ENGINE subsystem reached its declared v1.0
    architecture milestone.

It does NOT mean:
    OEP Platform 1.0.

--------------------------------------------------------------------
7A. ENGINEERING ENGINE (`platform/oep_engine`, Dart package
    `engineering_engine`) — distinct from the Engineering Knowledge
    Engine (EKE, Section 7, Foundation-side) and from Studio (Section 8,
    the UI shell that consumes this package)
--------------------------------------------------------------------

STATUS:
    GREEN / FUNCTIONAL CORE

Package version: 0.1.0 (pubspec.yaml).

The UI-independent Dart engine underneath Diagram Studio: Engineering
Graph, Symbol Library, Views, validation, navigation, selection,
import/export, and the simulation framework — verified present as
distinct library directories (`graph`, `symbols`, `views`, `simulation`,
`trace`, `analysis`, `editing`, `importers`, `exporters`, `bridge`,
`knowledge`, `models`, `services`, `viewstate`).

WORKING:
    - Engineering Graph model and mutation
    - Symbol Library
    - Views/selection/navigation
    - import/export
    - the simulation/solver framework Diagram Studio's electrical
      runtime (Section 9.1) and Trace (Section 9.3) are built on

KNOWN LIMITATIONS:
    - shares the same bounded-scope limitations documented under
      Diagram Studio's Electrical Runtime (Section 9.1) — this package
      is the engine those capabilities are implemented in, not a
      separately-scoped subsystem with its own independent maturity
      claim

NEXT REQUIRED WORK:
    Tracked jointly with Diagram Studio's own next-required-work items
    (Section 9) — this package has no independent roadmap distinct from
    the vertical slice it powers.

TARGET MILESTONE:
    0.2.x (already substantially delivered as part of the Diagram
    Studio vertical slice)

====================================================================
8. ENGINEERING STUDIO / PLATFORM STUDIO
====================================================================

STATUS:
    YELLOW / PARTIALLY MATURE

WORKING FOUNDATION:
    - Workspace
    - SurfaceRegistry
    - StudioRegistry
    - WorkspaceTabsController
    - persistence
    - Home/Dashboard surface
    - OEP branding
    - multi-surface navigation
    - settings
    - Foundation integration
    - Knowledge integration
    - Exchange runtime integration
    - Instrument bridge integration

HOME/DASHBOARD:
    GREEN / IMPLEMENTED

The Home surface now uses the normal Workspace tab architecture rather
than introducing a second navigation authority.

KNOWN STUDIO GAPS:
    - FFI mutation depth
    - some placeholder pages
    - Knowledge Studio dialog depth
    - Settings placeholders
    - documentation inconsistencies
    - some integration testing remains shallow

====================================================================
9. DIAGRAM STUDIO
====================================================================

STATUS:
    GREEN / FUNCTIONAL VERTICAL SLICE
    YELLOW / PRODUCT HARDENING REQUIRED

Diagram Studio is currently one of OEP's most mature end-user
vertical slices.

WORKING:
    - workspace integration
    - diagram loading
    - Legacy V2 renderer integration
    - editable diagram interaction
    - module manipulation
    - wire interaction
    - route editing
    - persistence
    - toolbar architecture
    - Search
    - Trace
    - DMM
    - Analysis
    - Compare
    - Export infrastructure
    - inspection
    - Home/Workspace integration
    - OEP branding
    - real TRX300 fixture
    - operating-state bridge
    - native electrical solver
    - native measurement architecture

IMPORTANT ARCHITECTURE:
    Engine owns engineering behavior.
    Studio owns presentation/workspace.
    Legacy V2 remains the reference/renderer host where applicable.

DO NOT:
    duplicate V2 solver logic unnecessarily.

------------------------------------------------------------
9.1 Diagram Studio Electrical Runtime
------------------------------------------------------------

STATUS:
    GREEN / FUNCTIONAL

Implemented:
    - ElectricalSolver
    - resistive-network MNA
    - electrical operating context
    - voltage
    - resistance
    - continuity
    - current
    - power
    - diode/behavior infrastructure
    - structured measurement results
    - arbitrary terminal measurement foundation

Real TRX300 validation has been performed.

------------------------------------------------------------
9.2 DMM
------------------------------------------------------------

STATUS:
    GREEN / FUNCTIONAL VERTICAL SLICE
    YELLOW / BROADER HARDWARE/PROTOCOL MATURITY

Implemented:
    - DMM UI
    - MultimeterController
    - measurement bridge
    - native Engine electrical authority
    - operating-context bridge
    - OIP host integration
    - Android DMM integration
    - response correlation
    - reconnect work
    - V2 live measurement path

BOUNDARIES:
    - V2 LiveSim remains relevant for live legacy behavior
    - native ElectricalSolver is authority for native solved state
    - Knowledge Runtime is NOT the live DMM solver

KNOWN GAPS:
    - broader E2E
    - some protocol/UI edge cases
    - broader measurement modes/semantics
    - production hardware validation

------------------------------------------------------------
9.3 TRACE
------------------------------------------------------------

STATUS:
    GREEN / FUNCTIONAL

Implemented:
    - physical trace
    - conducting trace
    - current-flow trace
    - component targets
    - terminal targets
    - relationship targets
    - deterministic paths
    - diagnostics
    - path highlighting
    - path inspection
    - current-flow animation using existing V2 primitive
    - real diagram7 validation

------------------------------------------------------------
9.4 CIRCUIT INTELLIGENCE / SEARCH
------------------------------------------------------------

STATUS:
    GREEN / FUNCTIONAL CORE
    YELLOW / PRODUCT EXPANSION

Implemented:
    - component search
    - terminal search
    - relationship/wire search
    - navigation
    - circuit discovery
    - physical/conducting/current-flow modes
    - trace summary
    - path inspection
    - circuit fit/navigation
    - trace diagnostics

KNOWN GAPS:
    - broader indexing/search architecture
    - larger dataset validation
    - further UX refinement

------------------------------------------------------------
9.5 WEBVIEW LIFECYCLE
------------------------------------------------------------

STATUS:
    GREEN / ARCHITECTURALLY FIXED
    YELLOW / HUMAN VALIDATION

PR-014 established the correct lifetime architecture.

Primary WebView:
    - permanent location in widget tree
    - no recreation merely because side panels change
    - actual document changes may reinitialize document state
    - Compare WebView remains independently managed

Validated:
    - CREATE
    - INIT
    - LOAD
    - SEED
    - REINITIALIZE
    - DISPOSE lifecycle instrumentation

Human UX test still required for final product-level acceptance.

------------------------------------------------------------
9.6 HUMAN UX/UI ACCEPTANCE
------------------------------------------------------------

STATUS:
    YELLOW / READY FOR HUMAN TEST

Testing infrastructure exists.

The human tester is the actual product evaluator.

The automated system must NOT fabricate human UX results.

Human acceptance must evaluate:
    - usability
    - discoverability
    - workflow quality
    - visual consistency
    - responsiveness
    - persistence
    - first-time-user experience
    - installer workflow
    - errors
    - WebView lifetime behavior
    - real-world interaction

CURRENT HUMAN TEST:
    NOT YET COMPLETED

====================================================================
10. KNOWLEDGE RUNTIME / REFERENCE LIBRARY
====================================================================

STATUS:
    GREEN / CORE RUNTIME COMPLETE
    YELLOW / LIFECYCLE MATURITY

Implemented:
    - Knowledge Runtime
    - .oerp package loading
    - deterministic package generation
    - SHA-256 fallback
    - bundled production package
    - electrical core knowledge
    - runtime activation
    - production asset loading
    - Windows verification
    - Android verification
    - reference library compiler/runtime path

KNOWN GAPS:
    - Ed25519 trust store not implemented
    - BLAKE3 not implemented; SHA-256 fallback currently used
    - broader knowledge lifecycle/curation not completely closed
    - knowledge ingestion pipeline still evolving
    - provenance/lifecycle maturity still developing

IMPORTANT:
    Knowledge Runtime is NOT the live V2 DMM solver.

====================================================================
11. ENGINEERING ACQUISITION MANAGER
====================================================================

STATUS:
    GREEN / MILESTONE 1 COMPLETE
    GREEN / M2 FOUNDATION (ACQUISITION RECORD) COMPLETE — PUSHED (commit 0494e25)
    GREEN / API AUTHENTICATION + TLS BOUNDARY COMPLETE — PUSHED (WP-SRV-003
    commit 0421ca2, WP-SRV-004 commit ce2fbf9; see below)
    YELLOW / M2 BROADER SCOPE (RICH PROVENANCE METADATA, CUSTODY EVENTS) REQUIRED
    (Connector destination-security is resolved — ADR-0003. EAM API
    authentication, once the one still-open item ADR-0003 was never
    scoped to close, is now ALSO resolved — WP-SRV-003/004, see below.
    Rich per-acquisition provenance metadata and custody events remain
    open, blocked on upstream connector producers that do not exist yet.)

RESOLVED (2026-09-13/14, WP-SRV-003/WP-SRV-004, PUSHED):
    EAM's REST API previously had no authentication at all (a gap
    ADR-0003 explicitly was not scoped to close). WP-SRV-003 (commit
    `0421ca2`) added a bearer-token boundary (`Authorization: Bearer
    <OEP_API_TOKEN>`, constant-time comparison, installed once via
    `httplib::Server::set_pre_routing_handler`) in front of every route
    except `GET /health`; no default/implicit token exists, and both
    `main.cpp` and `ApiServer`'s own constructor independently refuse to
    start with an empty token. WP-SRV-004 (commit `ce2fbf9`) added a TLS
    termination boundary in front of it (nginx reverse proxy, TLS 1.2+/
    1.3 only, EAM rebound to loopback-only `127.0.0.1:8080`), without
    touching ADR-0002's authentication mechanism. Verified: 256/256 test
    cases, 1188/1188 assertions, 0 failed, 0 skipped, against real
    PostgreSQL, on both Windows/MSVC and Linux/GCC (VM) toolchains. Full
    detail: `docs/architecture/decisions/ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md`,
    `ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md`,
    `docs/project/audits/2026-09-13-WP-SRV-003-EAM-API-AUTHENTICATION-AUDIT.md`,
    `docs/project/audits/2026-09-14-WP-SRV-004-EAM-API-TLS-BOUNDARY-AUDIT.md`.
    This is EAM's own inbound API boundary — a distinct, separate
    architecture/implementation from the new Server Repository Service's
    own reuse of the same ADR-0002 mechanism (Section 11A below).

    Also landed in this window: WP-SRV-002 (commit `e6018d1`) added
    `GET /vault/{id}/artifact` (raw-bytes artifact retrieval, modeled on
    Exchange's package-download contract) and removed server-local
    filesystem paths (`vault_path`, `local_storage_path`) from public
    Vault/Download JSON responses. WP-SRV-005 (commit `889cec2`)
    narrowed its original "OEP Repository" persistence scope after
    finding that scope would contradict ADR-0001 (Foundation has no
    server-side existence yet, a separate undecided architectural
    question) — the user-approved narrowed scope (EAM's own PostgreSQL
    persistence, already substantially in place, plus documentation) was
    completed; the original "OEP Repository" (Engineering Objects/
    Relationships/State server persistence) scope was NOT attempted
    under WP-SRV-005 and was subsequently authorized and implemented as
    its own, separate Server Repository Service (Section 11A).

WP-001 through WP-009:
    M1 implemented.

WP-018 (Acquisition Record & Provenance Foundation):
    Complete — PUSHED (commit 0494e25). See Section 11.2.

PIPELINE:
    Official Source
        ->
    Acquisition Job
        ->
    Execution
        ->
    Connector
        ->
    Download
        ->
    Integrity Verification
        ->
    Metadata Extraction
        ->
    Reference Vault

WP-017:
    READY WITH CONDITIONS

WP-017 ACTUAL TEST:
    221 / 221 test cases
    981 / 981 assertions
    0 skipped
    0 failed
    repeated successfully against real PostgreSQL 18

FIXES MADE IN WP-017:
    - Vault publish orphan-file race
    - Reference Vault FK indexes
    - test fixture collision defects

RESOLVED (2026-09-13, ADR-0003, PUSHED — commit d7df760):
    HttpConnector performs real outbound HTTP -- ratified as an
    approved, in-scope capability (Option A). Its SSRF-shaped behavior
    (no destination/redirect restrictions) was confirmed as a real,
    reproducible exploit against the running service, then closed
    structurally: every destination (initial and every redirect hop) is
    resolved and validated against loopback/RFC1918/link-local/
    multicast/unspecified ranges (IPv4 and IPv6, including IPv4-mapped
    IPv6), with the validated address pinned against DNS rebinding, a
    redirect-hop cap, and a response-size cap. No authentication exists
    on the EAM API itself -- that remains a separate, undecided gap
    (see below), not something ADR-0003 was scoped to add. Full detail:
    services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md,
    docs/project/audits/2026-09-13-OEP-ADR-0003-HTTPCONNECTOR-RESOLUTION-AUDIT.md.

ADR:
    ADR-0003 — RESOLVED 2026-09-13 (see above).

EAM FOUNDATION WORK PACKAGE:
    WP-018 — Acquisition Record & Provenance Foundation
    STATUS: COMPLETE — PUSHED (commit 0494e25)
    See Section 11.2 below and docs/project/OEP_RELEASE_HISTORY.md.

------------------------------------------------------------
11.1 Reference Vault
------------------------------------------------------------

STATUS:
    GREEN / M1 COMPLETE
    YELLOW / LONG-TERM ARCHITECTURE INCOMPLETE

M1 IMPLEMENTED:
    - immutable Vault entry
    - content-addressed filesystem storage
    - SHA-256 identity
    - PostgreSQL metadata
    - publication validation
    - Vault REST
    - history/status
    - deduplication at filesystem level
    - verified-artifact publication

NOT YET IMPLEMENTED:
    - full descriptive Vault metadata architecture
    - version/revision system
    - search/indexing
    - derived artifacts
    - richer relationships
    - licensing integration
    - periodic fixity checking
    - broader raw-artifact retrieval capabilities
    - knowledge ingestion

These are M2/future capabilities, not evidence that WP-009 failed.

------------------------------------------------------------
11.2 Acquisition Record / Provenance Foundation
------------------------------------------------------------

STATUS:
    GREEN / COMPLETE WITH BOUNDED GAPS — PUSHED (commit 0494e25)

WP-017 identified this as the largest architectural gap in EAM (no
persistent entity corresponded to SDD-R015's "Acquisition Record"). WP-018
closed that gap, implemented and tested against a real PostgreSQL 18
instance (235/235 test cases, 1090/1090 assertions, 0 skipped, 0 failed,
confirmed twice consecutively) — but the commit is LOCAL ONLY, not on
GitHub main, and is therefore not yet part of any released or shared
state.

IMPLEMENTED:
    - `acquisition_records` table (additive migration V10), one record
      per Download Session (not per Job — see the WP-018 audit for why)
    - Automatic creation/advancement wired as a best-effort side effect
      of the existing `/downloads`, `/verifications`, `/metadata`,
      `/vault` routes — zero changes to those four services' contracts
    - `GET /acquisition-records`, `/{id}`, `/{id}/provenance` — full
      Vault Entry -> Metadata -> Verification -> Download -> Job ->
      Source chain reconstructed via traversal, no duplicated columns,
      `reference_vault` completely unmodified

NOT IMPLEMENTED (explicitly deferred, per WP-018's own audit's Gap
Classification):
    - Rich per-acquisition metadata (Workstation, DNS, TLS, Referrer/
      Redirect Chain, licensing) — no upstream producer exists yet
    - SHA-512 / BLAKE3 — not computed anywhere in this codebase
    - Full Chain-of-Custody event log — `acquisition_job_execution_history`
      already covers the Job-level portion of this need
    - `Archived` lifecycle state — schema accepts it, no code path sets it

EVIDENCE:
    services/acquisition/docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md
    services/acquisition/docs/audits/WP-018-IMPLEMENTATION-REPORT.md

NEXT DEPENDENCY:
    WP-018 itself is now pushed to GitHub main (commit 0494e25, verified
    2026-09-13 as part of WP-CTRL-001's reconciliation). ADR-0003
    (HttpConnector security/scope) is likewise resolved and pushed
    (commit d7df760, see Section 11 above) and was always independent
    of this work regardless.

====================================================================
11A. SERVER REPOSITORY SERVICE
====================================================================

STATUS:
    GREEN / FIRST VERTICAL SLICE COMPLETE WITH BOUNDED GAPS — PUSHED
    (WP-SRV-011 commit 9bde275 through WP-SRV-012A commit 66af1f5)

A new, distinct logical service (NOT Foundation, NOT EAM/Vault, NOT
Exchange, NOT Knowledge Runtime, NOT `.oep`/`.oerp`) that owns
server-resident Engineering Objects/Relationships/revisions/commits/
repository membership/audit history — the "OEP Repository" persistence
scope WP-SRV-005 explicitly found it could not attempt without a new
architectural decision (Section 11 above). That decision chain
(ADR-0001 through ADR-0006, `docs/architecture/decisions/`) authorized
this first implementation slice; ADR-0001/0002/0003 pre-date this
window (referenced, unmodified) and ADR-0004/0005/0006 (plus two later
wire-contract corrections to ADR-0006, commits `57eafeb`/`a1c8fc3`)
were established in this window, all documentation-only, no source
changed by any of them.

IMPLEMENTED AND VERIFIED (real PostgreSQL, not an in-memory fake, every
time; VM-hosted, database `oep_server_repository` /
`oep_server_repository_test`, least-privilege role, ADR-0006 SS25):

    WP-SRV-011 (commit 9bde275) — repositories, repository-creation
        identity/idempotency (server-scoped), objects/relationships with
        append-only revision history + "head" current-state pointers,
        commits with repository-scoped idempotency, minimal audit
        association. Atomicity for both repository creation and commits
        (mutations + revisions + commit record + idempotency + audit, one
        transaction). Optimistic concurrency via SELECT ... FOR UPDATE.
        8 of the ADR-0006-authorized HTTP routes (list-repositories
        deliberately deferred as a documented, non-required scope
        decision — closed by WP-SRV-011B below). 159/159 assertions,
        8 test cases.
    WP-SRV-011A (commit 4618729) — corrected a real concurrency-testing
        gap: the original single-connection-plus-mutex design serialized
        concurrent commits in the application before PostgreSQL ever saw
        a second transaction, so the concurrency test proved HTTP-level
        behavior only, not real database-level row-lock contention.
        Replaced with a small internal connection pool (16 connections)
        so concurrent HTTP requests run on genuinely independent
        connections/transactions; re-verified with 8 real threads racing
        a real PostgreSQL row lock. 166/166 assertions, 8 test cases.
    WP-SRV-011B (commit 31cb11b) — added the `/api/v1/` wire-version
        prefix ADR-0006 requires (`GET /health` deliberately stays
        unversioned/unauthenticated), and closed a related gap: "list
        objects"/"list relationships" were ADR-0006-required for this
        slice but had never been wired up. 200/200 assertions, 9 test
        cases.
    WP-SRV-011C (commit fd8d630) — UUID validation was structural only
        (length/hyphens/hex), not actually UUIDv4-specific as ADR-0004/
        0006 require; strengthened to check version + variant nibbles,
        applied uniformly to every client-supplied identity field.
        307/307 assertions, 12 test cases.
    WP-SRV-012 (commit 0d5be8a) — tombstone/delete semantics (ADR-0006
        SS10): object/relationship deletion as a new tombstone revision
        (never a hard delete, never a removed history row), object
        deletion blocked while a live relationship still references it
        unless that relationship is deleted atomically in the same
        commit, tombstoned current-state GET reuses the existing
        NOT_FOUND/404 category (no new error category invented).
    WP-SRV-012A (commit 66af1f5) — corrected WP-SRV-012's own
        restoration mechanism: ADR-0006 SS10 specifies restoration as a
        "create-shaped" mutation, but the original implementation
        restored via an ordinary update mutation instead. Corrected so
        `object_create`/`relationship_create` against an existing
        tombstoned identity restores it (new LIVE revision N+1,
        SAVEPOINT-backed `pqxx::subtransaction` around the initial
        INSERT-uniqueness attempt so a collision doesn't abort the whole
        commit transaction); an update mutation against a tombstoned
        identity is now correctly rejected instead of silently
        restoring it. Full suite re-run after this correction:
        **514/514 assertions, 16 test cases, all passing** (includes the
        WP-SRV-011A concurrency and WP-SRV-011C UUIDv4 regressions,
        re-verified, not weakened).

ARCHITECTURE (unmodified by any of the above, referenced only):
    ADR-0001 — OEP Reference Server boundary/artifact contract
    ADR-0002 — API authentication (the same bearer-token boundary EAM
        uses — reused, not a second auth system)
    ADR-0003 — TLS boundary (referenced; this service's own TLS/proxy
        deployment topology was not separately re-verified in this
        window — inherits EAM's established WP-SRV-004 pattern by
        design, not independently re-audited here)
    ADR-0004 — Server Repository semantics/state model
    ADR-0005 — API/persistence boundary
    ADR-0006 — implementation readiness/wire contract (incl. the two
        WP-SRV-010A corrections: operation-identity scope, atomic
        idempotency persistence)

EXPLICITLY NOT IMPLEMENTED (out of this first slice's authorized scope,
ADR-0006 SS29 / each WP's own stated exclusions):
    - synchronization
    - branching/merging
    - hard deletion (tombstone-only, verified: no SQL DELETE statement
      exists anywhere in this service's source)
    - full authorization/tenancy/roles/sharing
    - server-side Foundation
    - Exchange/EAM integration
    - `.oerp` distribution
    - administrative APIs
    - client tooling

NOT INDEPENDENTLY RE-VERIFIED IN THIS RECONCILIATION:
    This section's test-count claims are carried forward from each WP's
    own reported, PostgreSQL-verified results at the time it was
    completed (WP-SRV-012A's own report: 514/514, 16 test cases). This
    WP-CTRL-002 documentation pass did not itself re-run the suite —
    see the CONTROL FINDINGS in this reconciliation's own audit trail.

NEXT DEPENDENCY:
    WP-SRV-013 — NOT STARTED. No commit, source file, test, migration,
    or document anywhere in this repository references WP-SRV-013
    (verified by direct search, WP-CTRL-002). No next Server Repository
    work package is authorized by this reconciliation; selecting one is
    a separate decision.

====================================================================
12. ENGINEERING EXCHANGE
====================================================================

STATUS:
    GREEN — EXCHANGE WORKSPACE + CLIENT FOUNDATION COMPLETE (PUSHED)
    Exchange RC1 itself remains ORANGE / NOT STARTED.

WORKSPACE FOUNDATION — RESTORED BY WP-EXC-011 (2026-09-13, PUSHED — commit d110ddf):
    A prior audit (2026-09-13 Release Boundary Audit) found that Exchange's
    own architecture documentation described a 14-package npm workspace
    under `services/exchange/packages/*` that did not exist anywhere in
    this repository. WP-EXC-011 investigated the upstream `oep_exchange`
    repository directly and found the packages were deleted in that
    repository's own final commit (`c6dbb75`, message "v2", no stated
    rationale) before the monorepo migration ever touched the code — a
    genuine, pre-existing, undocumented deletion, not migration-induced.

    WP-EXC-011 restored all 14 packages byte-for-byte from the last known
    good upstream commit (`18484e3`). Result: `npm install` succeeds;
    the root TypeScript composite build (`tsc -b`, covering all 14
    packages + `apps/exchange-api`) succeeds with zero errors;
    `apps/exchange-admin` builds and typechecks cleanly; `npm run lint`
    passes with zero errors. Test suite: 83 test files now execute
    (up from 19 before restoration), 59 passed / 7 failed / 17 skipped
    (self-skipping Postgres-gated tests, pre-existing and unrelated);
    420 tests, 284 passed / 12 failed / 124 skipped.

    THE ONE GAP WP-EXC-011 LEFT OPEN — CLOSED BY WP-EXC-012 (2026-09-13,
    PUSHED — commit 986bf8d): `apps/publisher-portal` depended on a real
    `@oep-exchange/exchange-client` (`ExchangeApiClient`/`ExchangeApiError`)
    implementation that was never committed anywhere, in either
    repository, at any commit (TASK-EXC-0007's own scope, never
    historically completed) — not something WP-EXC-011 could restore.
    WP-EXC-012 implemented the minimum real client, established entirely
    from `apps/exchange-api`'s existing routes and `apps/publisher-portal`'s
    own existing, unmodified consumer code/tests — new code closing a
    historical gap, not a restoration and not Exchange RC1 feature work.

    Result: the full Exchange workspace now builds, typechecks, lints,
    and tests cleanly end to end. 86 test files (69 passed, 17 skipped —
    the same pre-existing, Postgres-gated `exchange-api` tests, unrelated
    to this work), 443 tests (319 passed, 124 skipped), **0 failed**,
    up from WP-EXC-011's 7 failing files / 12 failing tests. No file
    under `apps/publisher-portal/` was modified — its existing contract
    was satisfied as-is.

    Full detail: services/exchange/docs/tasks/WP-EXC-011.md,
    services/exchange/docs/audits/WP-EXC-011-IMPLEMENTATION-REPORT.md,
    services/exchange/docs/tasks/WP-EXC-012.md,
    services/exchange/docs/audits/WP-EXC-012-IMPLEMENTATION-REPORT.md.

ACTUALLY VERIFIED PRESENT (post-WP-EXC-011):
    - All 14 documented packages (`core`, `api-contracts`, `manifest`,
      `signing`, `search`, `package_manager`, `exchange_client`,
      `installer`, `interfaces`, `dependency_resolver`, `update_service`,
      `licensing`, `payments`, `reviews`) — restored, historically
      authentic, building/typechecking/linting cleanly. Five of these
      (`dependency_resolver`, `update_service`, `licensing`, `payments`,
      `reviews`) remain, as they always were, inert single-export
      scaffolds — not implementations, and not required by the current
      apps' build.
    - `apps/exchange-api` — real Fastify app source, one working route
      (`GET /api/v1/health`), OpenAPI generation wired, builds cleanly
      against its restored package dependencies.
    - `apps/exchange-admin` — React/Vite app, builds and typechecks
      cleanly against its restored package dependencies.
    - `apps/publisher-portal` — React/Vite app, now builds, typechecks,
      and tests cleanly against a real, working `@oep-exchange/exchange-client`
      (WP-EXC-012).
    - `@oep-exchange/exchange-client` — real `ExchangeApiClient`/
      `ExchangeApiError` implementation (WP-EXC-012), covering every
      method `publisher-portal` actually calls (search, packages,
      publishers, installations, downloads), each mapped to an existing
      `apps/exchange-api` route — no speculative endpoint.
    - `db/migrations` — Flyway-style migrations directory exists.
    - WP-EXC-001 through WP-EXC-010 (specifications) and WP-EXC-011/012/013
      (workspace + client foundation + install bridge) task documents
      (services/exchange/docs/tasks/) — WP-EXC-011/012/013 are the only
      ones of these actually implemented; WP-EXC-002 through WP-EXC-010
      remain specifications only.

IMPORTANT CORRECTION (2026-09-13, WP-EXC-010 Scope & Readiness Audit):
    OEP Studio already has a substantial, working Exchange integration —
    confirmed by direct source inspection, not previously reflected in
    this document. `platform/oep_studio/lib/exchange/` contains a full
    `ExchangeStudioPage` workspace (Marketplace Home, Search, My Library,
    Downloads, Publishing sections; package/publisher detail drill-downs),
    a real Dart `ExchangeApiClient`, persistent local library/download
    storage, and a Settings page — all already registered in
    `StudioRegistry`/`SurfaceRegistry`/the command palette/global search,
    exactly like any other Studio destination. This is far more mature
    than "not started."

    The one genuine, well-evidenced gap: Studio's Exchange "Install"
    action calls only Exchange's own REST API, which defaults to a
    `StubRepositoryClient` that fabricates a fake result — it never
    reaches a real OEP Repository. Foundation's Public C API already has
    a real, working, already-Dart-FFI-bound install capability
    (`oep_package_install`/`FoundationBridge.installPackage`, already
    used by an unrelated manual "Package Manager" Studio page), which
    already performs genuine Ed25519 trust verification before install
    (WP-REP-004) — but nothing in the Exchange flow calls it yet. Closing
    this one connection, not building new architecture, is the crux of
    what remains for a genuine RC1 vertical slice. Full detail:
    services/exchange/docs/audits/WP-EXC-010-SCOPE-AND-READINESS-AUDIT.md,
    services/exchange/docs/tasks/WP-EXC-010-SCOPE.md.

RESOLVED BY WP-EXC-013 (2026-09-13, PUSHED — commit e1211c4) — Exchange →
Repository Install Bridge:
    The one gap identified directly above (Studio's Exchange "Install"
    action never reaching a real OEP Repository) is closed. Studio's
    `ExchangeRuntimeNotifier.installPackage` now downloads the real
    package artifact, verifies its SHA-256 checksum (Exchange's download
    route already sent an `X-Checksum-Sha256` header Studio simply never
    read), and installs it through a new `ExchangeInstallBridge` that
    calls Foundation's real, unmodified `oep_package_install` via the
    same `FoundationBridge.installPackage` FFI path the manual Package
    Manager page already used. Verified against the genuine Foundation
    runtime (real `oep_foundation_bridge.dll`, not a fake): a valid
    package installs and its object/relationship counts are read back
    from Foundation itself; a checksum mismatch is rejected before
    Foundation is ever called; a corrupt archive and a duplicate install
    both produce Foundation's own real failure outcomes. Zero Foundation
    source changed; zero new Exchange API endpoints; zero new repository
    implementation. Full detail: services/exchange/docs/tasks/WP-EXC-013.md,
    services/exchange/docs/audits/WP-EXC-013-IMPLEMENTATION-REPORT.md.

    HARDENED BY WP-EXC-013A (2026-09-13, PUSHED — commit 26ab396) — Foundation
    Bridge Artifact Synchronization & Integration Test Gate: WP-EXC-013's
    own real-Foundation integration test could previously only be made to
    pass by manually swapping a fresh `oep_foundation_bridge.dll` over a
    stale, tracked copy at `platform/oep_studio/` root and then reverting
    it — not reproducible from a normal checkout. Root cause: the tracked
    root copy (committed 2026-08-15) was never part of any build
    pipeline (the canonical `flutter build windows` pipeline produces its
    own copy under the git-ignored `build/windows/x64/runner/` tree) and
    had gone stale after the Foundation API moved on
    (`OEP_API_VERSION` 21). Added `tool/sync_foundation_bridge_dll.dart`,
    which copies the canonical build output over the tracked root copy;
    ran the real pipeline (`flutter build windows --debug` then the sync
    script) and confirmed the real integration test now passes with zero
    manual file manipulation. Also hardened the test's own failure
    handling so a stale/incompatible bridge FAILS clearly instead of
    silently skipping, while a genuinely absent DLL (Foundation not built
    in that environment) still legitimately skips — both paths verified
    directly. No Foundation source, no `ExchangeInstallBridge` logic, and
    no CMake file were modified. Full detail:
    services/exchange/docs/tasks/WP-EXC-013A.md,
    services/exchange/docs/audits/WP-EXC-013A-IMPLEMENTATION-REPORT.md.

    VERIFIED END-TO-END BY WP-EXC-014 (2026-09-13, PUSHED — commit 30e4a1f) —
    Exchange RC1 End-to-End Verification: the full RC1 vertical slice
    (search → package detail → download → checksum verification →
    `ExchangeInstallBridge` → `FoundationBridge.installPackage` →
    Foundation's installer → Repository registration → Engineering
    Objects/Relationships → installed-package confirmation) is now
    proven through a genuine end-to-end test
    (`platform/oep_studio/test/exchange_rc1_e2e_test.dart`), driving the
    real, unmodified production Studio orchestration
    (`ExchangeRuntimeNotifier.search`/`.selectPackage`/`.installPackage`)
    against a real socket-bound HTTP server, through the real,
    WP-EXC-013A-synced `oep_foundation_bridge.dll`. Confirms: successful
    install (real object/relationship counts, real installed-package
    query), already-installed detection, corrupt-package rejection, and
    checksum-mismatch rejection — all with no partial/misleading
    repository state on any rejected path. A companion real-Postgres
    backend test (`apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts`)
    independently proves the genuine Exchange server's own real
    search/detail/download/checksum behavior, gated by this repository's
    own pre-existing `describe.skipIf(!databaseAvailable)` convention
    (skips in this sandbox — no live PostgreSQL role configured, the
    same pre-existing condition already affecting 17 other test files,
    not a new gap). Full detail: services/exchange/docs/tasks/WP-EXC-014.md,
    services/exchange/docs/audits/WP-EXC-014-IMPLEMENTATION-REPORT.md.

NOT PRESENT / NOT COMPLETE:
    - a publisher-facing upload/publish UI (neither publisher-portal nor
      Studio has one; a real, tested backend upload API already exists
      and needs no UI to prove the RC1 vertical slice)
    - production catalog / complete discovery at production scale
    - production Exchange RC1
    - authentication (excluded from WP-EXC-001's own scope; the client
      has nothing to attach even if it existed)
    - licensing, payments, reviews (explicitly excluded from WP-EXC-001's
      own scope, per that task's own Scope section — restored only as
      their original inert scaffolds, not implemented)
    - dependency resolution, package updates, uninstall-via-Exchange
      (unimplemented scaffolds, not required to prove the architecture)

CURRENT DOCUMENTED WORK:
    WP-EXC-001 through WP-EXC-010 specifications exist. WP-EXC-011
    (Exchange Workspace Reconstruction), WP-EXC-012 (Exchange Client API
    Foundation), WP-EXC-013 (Exchange → Repository Install Bridge),
    WP-EXC-013A (Foundation Bridge Artifact Synchronization &
    Integration Test Gate), and WP-EXC-014 (Exchange RC1 End-to-End
    Verification) are all implemented and PUSHED. A WP-EXC-010
    scope/readiness audit (2026-09-13) is also complete and PUSHED
    (commit 9b2cb13) — Exchange RC1 itself (production publisher UI, auth,
    licensing, and the other items in "NOT PRESENT / NOT COMPLETE"
    above) has not been implemented; what WP-EXC-014 proves is that the
    vertical slice underneath those remaining features genuinely works
    end to end, not that RC1 itself is complete.

MAJOR REMAINING PROGRAM:
    The install bridge (WP-EXC-013), its reproducible test gate
    (WP-EXC-013A), and its end-to-end proof (WP-EXC-014) are all done.
    What remains for an actual Exchange RC1 release is the still-missing
    surface area listed under "NOT PRESENT / NOT COMPLETE" above
    (publisher-facing upload UI, authentication, etc.) — none of which
    this work touched or was asked to touch.

EXCHANGE RC1 IS NOT CURRENTLY A RELEASE-READY OEP SUBSYSTEM. Its
FOUNDATION (workspace + client + Studio UI + a real, Foundation-verified,
now end-to-end-proven install bridge), as of WP-EXC-014, is
substantially more complete than previously documented — the remaining
gap to an actual RC1 release is product surface area (publisher UI,
auth, etc.), not architectural proof.

====================================================================
13. OEP INSTRUMENTS
====================================================================

STATUS:
    YELLOW / FUNCTIONAL FOUNDATION

Implemented:
    - OIP runtime
    - Android DMM
    - host bridge
    - TCP transport
    - measurement protocol
    - DMM UI
    - reconnect behavior
    - Studio integration

KNOWN GAPS:
    - broader instrument ecosystem
    - protocol hardening
    - discovery
    - heartbeat/connection semantics
    - additional instrument types
    - production hardware validation

====================================================================
14. EXPORT / PUBLISHING
====================================================================

STATUS:
    YELLOW / PARTIAL

Implemented:
    - SVG infrastructure
    - PNG infrastructure
    - PDF infrastructure
    - printing integration

DIAGRAM EXPORT GAP:
    Current native SVG renderer does not yet reproduce the complete
    Legacy V2 Symbol Library artwork.

LEGACY V2:
    Existing SVG export is primarily the wire-layer SVG.

TARGET:
    true static diagram export must eventually represent:
    - modules
    - symbols
    - wires
    - splices
    - connectors
    - annotations
    - engineering geometry

Potential final deliverables:
    - static diagram PNG
    - static diagram PDF
    - true self-contained SVG

====================================================================
15. APPLICATION SHELL
====================================================================

STATUS:
    GREEN / INITIAL IMPLEMENTATION COMPLETE
    YELLOW / MATURATION

Implemented:
    - OEP Home
    - Workspace boot
    - real Home/Dashboard
    - real recent-work persistence
    - real provider-based system status
    - Available Studios
    - normal Workspace tab authority

NOT YET COMPLETE:
    - full enterprise-grade application lifecycle
    - complete connection management
    - complete user/account system
    - production update/distribution infrastructure

====================================================================
16. SECURITY
====================================================================

STATUS:
    YELLOW / MAJOR HARDENING REQUIRED

CREDENTIAL-EXPOSURE CLAIM — VERIFIED AGAINST CURRENT REPOSITORY (2026-09-13):
    Three prior Foundation review documents
    (platform/oep_foundation/docs/review/{FINAL_RECOMMENDATION,
    PLATFORM_SNAPSHOT,TECHNICAL_DEBT}.md) record a plaintext credential
    file at `oep_studio/anthropic_api_key.env` as a critical, live issue
    at the time of that review.

    This audit searched for that file directly (filename search across
    the full local filesystem, `git log --all --diff-filter=A` across
    every commit in this repository's entire history, and a text search
    for the string "anthropic_api_key" across every tracked document)
    and found: the file does NOT currently exist anywhere in the working
    tree or any subdirectory searched, and was NEVER added in any commit
    in this repository's git history (tracked or otherwise). The actual,
    implemented credential architecture
    (platform/oep_studio/docs/ANTHROPIC_PROVIDER.md) stores API keys
    exclusively in Windows Credential Manager via `dart:ffi`, never in a
    file — consistent with the file's current absence.

    CONCLUSION: this is DOCUMENTATION DRIFT, not a corroborated current
    exposure. The prior review's claim could reflect a since-remediated
    local working-tree file (never committed, since deleted) or a
    different clone/environment. It is not marked RESOLVED outright,
    because an AI agent session cannot inspect machines/clones/histories
    outside this one repository checkout — the founder should personally
    confirm no copy of this file exists on any other machine, and rotate
    the Anthropic API key out of caution if there is any doubt it was
    ever exposed (e.g. pasted into a chat log, screen-shared, or synced
    to a cloud drive) even though it was never pushed to GitHub main or
    committed to this repository's history.

RESOLVED (2026-09-13, ADR-0003, PUSHED — commit d7df760):
    - HttpConnector SSRF-shaped behavior -- destination validation
      (loopback/RFC1918/link-local/multicast, IPv4 and IPv6, DNS-rebinding
      pinning, per-hop redirect validation, response-size cap) now
      structurally enforced; see Section 11 and
      services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md.

RESOLVED (2026-09-13/14, WP-SRV-003/WP-SRV-004, PUSHED — commits
0421ca2/ce2fbf9):
    - EAM's REST API previously had no authentication at all -- a
      separate gap ADR-0003 (the HttpConnector-scoped ADR) was never
      scoped to close. WP-SRV-003 added a bearer-token boundary in front
      of every EAM route except `GET /health`; WP-SRV-004 added a TLS
      termination boundary in front of that. Both verified: 256/256 test
      cases, 1188/1188 assertions, 0 failed, 0 skipped, against real
      PostgreSQL. See Section 11 above and
      `docs/architecture/decisions/ADR-0002-OEP-REFERENCE-SERVER-API-AUTHENTICATION.md`/
      `ADR-0003-OEP-REFERENCE-SERVER-TLS-BOUNDARY.md`. The new Server
      Repository Service (Section 11A) reuses this exact same
      authentication mechanism rather than inventing a second one.

STILL OPEN:
    - connector authorization not complete
    - trust-store architecture incomplete (Ed25519 not implemented)
    - production security boundary incomplete (EAM/Server Repository's
      TLS is a development/self-signed-certificate deployment, not a
      production-certificate posture; see ADR-0003 Section 4/15)
    - platform-wide authentication (Studio login/accounts, Exchange
      authentication) remains unimplemented -- only the reference-server
      HTTP boundary (EAM + Server Repository) has a bearer-token gate
    - credential-exposure claim above still requires personal,
      out-of-repository confirmation (unchanged by this reconciliation)

SECURITY IS A RELEASE GATE FOR OEP 1.0. This section must not be marked
GREEN until the credential-exposure claim above is personally confirmed
closed, platform-wide authentication exists, and the remaining items
above are closed. The reference-server API-authentication gate
specifically (EAM + Server Repository's shared bearer-token boundary)
is now resolved and pushed, which is real, verified progress -- it does
not by itself close this whole section's gate. ADR-0003 itself is now resolved,
but does not by itself close this gate.

====================================================================
17. PERFORMANCE
====================================================================

STATUS:
    YELLOW / INSUFFICIENTLY MEASURED

Current:
    correctness tests exist
    timing observations exist

Missing:
    dedicated performance/benchmark suite
    repeatable benchmark methodology
    defined thresholds
    representative large engineering datasets
    sustained-load testing
    startup benchmarks
    memory profiling
    rendering benchmarks
    solver scaling benchmarks
    Exchange/EAM throughput benchmarks

OEP 1.0 requires objective performance baselines.

====================================================================
18. DOCUMENTATION / PROJECT CONTROL
====================================================================

STATUS:
    YELLOW / RECONCILIATION REQUIRED

KNOWN:
    - stale PROJECT_STATUS.md
    - contradictory CURRENT_SPRINT.md
    - multiple task numbering schemes
    - duplicate Studio task documents
    - separate specifications trees
    - historical work-package gaps
    - technical-debt records distributed across subsystems

THIS MASTER RECORD EXISTS TO REDUCE THAT PROBLEM.

REQUIRED FUTURE STRUCTURE:
    One master platform status record
    +
    subsystem status records
    +
    work-package records
    +
    release records
    +
    technical-debt register

====================================================================
19. KNOWN MAJOR DEFECTS / DEBT
====================================================================

P0 / CRITICAL

1. Credential-exposure claim from a prior Foundation review, NOT
   corroborated by this audit's direct repository/filesystem inspection
   (see Section 16 for the full finding).
   ACTION:
       Founder to personally confirm no copy of
       `oep_studio/anthropic_api_key.env` exists on any other machine or
       clone, and rotate the Anthropic API key if there is any doubt it
       was ever exposed outside this repository.

P1 / HIGH

2. HttpConnector SSRF-shaped behavior.
   RESOLVED 2026-09-13 (ADR-0003, PUSHED — commit d7df760) -- destination
   validation now structurally enforced; see Section 11.

2A. EAM REST API had no authentication.
   RESOLVED 2026-09-13/14 (WP-SRV-003/WP-SRV-004, PUSHED — commits
   0421ca2/ce2fbf9) -- bearer-token + TLS boundary now enforced,
   256/256 test cases passing; see Section 11/16. Platform-wide
   authentication (Studio, Exchange) remains open (Section 16).

3. GraphML placeholder exposed through public API.
   ACTION:
       Implement properly or explicitly deprecate/re-scope.

4. Studio FFI mutation gaps.
   ACTION:
       Deliberately close before features depend on full CRUD.

5. Documentation status drift.
   ACTION:
       Master status system replaces ambiguous legacy status documents.

P2 / MEDIUM

6. AnalysisEngine dedicated test coverage.

7. C API ownership convention inconsistency.

8. Duplicate ZIP test fixtures.

9. oep_api.cpp size.

10. CLI naming collisions.

11. Foundation/module naming collision.

12. Work-package numbering fragmentation.

13. Duplicate Studio work-package documents.

14. Missing benchmark suite.

15. Studio placeholder surface.

P3 / LOW

16. Orphaned Claude worktree.

17. .scratch_build artifacts.

18. Empty Foundation stub modules.

19. demo-workshop repository cruft.

20. Two specification trees lacking explicit relationship.

====================================================================
20. CURRENT WORK PACKAGE POSITION
====================================================================

COMPLETED / VERIFIED (see Section 0 for the full commit list — all PUSHED to GitHub main):

    WP-REP-001..008
    WP-EKE-001..008
    EAM WP-001..009
    Diagram Studio PR-002..014
    PR-015 testing system
    PR-016 human-test preparation
    Home/Dashboard integration
    WP-017 (EAM / Reference Vault audit) — READY WITH CONDITIONS, commit 8c6185c, PUSHED
    WP-018 (Acquisition Record & Provenance Foundation) — COMPLETE, commit 0494e25, PUSHED
    WP-SRV-002 (Vault artifact route / filesystem-path removal) — commit e6018d1, PUSHED
    WP-SRV-003 (EAM API authentication) — commit 0421ca2, PUSHED — see Section 11/16
    WP-SRV-004 (EAM API TLS boundary) — commit ce2fbf9, PUSHED — see Section 11/16
    WP-SRV-005 (EAM PostgreSQL data infrastructure, narrowed scope) — commit 889cec2, PUSHED
    ADR-0001..0006 (Server Repository Service architecture) — documentation only, PUSHED
    WP-SRV-011 (Server Repository first vertical slice) — commit 9bde275, PUSHED — Section 11A
    WP-SRV-011A (real PostgreSQL concurrency correction) — commit 4618729, PUSHED
    WP-SRV-011B (API wire version) — commit 31cb11b, PUSHED
    WP-SRV-011C (UUIDv4 identity contract) — commit fd8d630, PUSHED
    WP-SRV-012 (tombstone/delete semantics) — commit 0d5be8a, PUSHED
    WP-SRV-012A (create-shaped tombstone restoration correction) — commit 66af1f5, PUSHED,
        514/514 assertions, 16 test cases

CURRENT / IMMEDIATE:

    This documentation/project-control reconciliation task (WP-CTRL-002,
    2026-09-16 — OEP_PROJECT_STATUS.md, OEP_RELEASE_HISTORY.md, and
    OEP_MILESTONE_ROADMAP.md brought back into agreement with the
    actual, verified origin/main state at commit a36f69e).

NEXT (see Section 25 for the full recommended priority order):

    1. Credential/security exposure verification (Section 16 — claim not
       corroborated by current repository inspection; verify and close out)
    2. Diagram Studio human UX/UI acceptance execution
    3. Select the next authorized Server Repository work package
       (WP-SRV-013 — NOT STARTED, no repository evidence of any kind;
       not selected or begun by this reconciliation)

RESOLVED AND PUSHED:

    ADR-0003 (2026-09-13, commit d7df760)
        HttpConnector security/scope decision — see Section 11.
    EAM API authentication + TLS (2026-09-13/14, commits 0421ca2/ce2fbf9)
        See Section 11/16 — the item previously listed as "NEXT" item 3
        in this section as of the WP-CTRL-001 reconciliation.
    Server Repository Service first vertical slice + tombstone semantics
    (2026-09-13 through 2026-09-16, commits 9bde275 through 66af1f5)
        See Section 11A.

PENDING HUMAN:

    Diagram Studio Human UX/UI Acceptance Test

MAJOR FUTURE PROGRAM:

    Engineering Exchange completion/integration
    Server Repository Service — next work package selection (post-WP-SRV-012A)

====================================================================
21. OEP 0.2.0 RELEASE OBJECTIVE
====================================================================

OEP 0.2.0 should establish:

CORE PLATFORM
    [x] Foundation Runtime
    [x] Repository Runtime
    [x] Public API
    [x] Engine
    [x] EKE v1.0 architecture

STUDIO
    [x] Workspace
    [x] Home
    [x] Diagram Studio
    [x] Diagram persistence
    [x] Search
    [x] Trace
    [x] DMM
    [x] Analysis
    [x] Compare
    [x] Export foundation
    [ ] Complete human UX acceptance
    [ ] Complete production hardening

KNOWLEDGE
    [x] Knowledge Runtime
    [x] Reference package
    [x] Production package loading
    [ ] Full trust-store implementation
    [ ] Full lifecycle closure

EAM
    [x] Source registry
    [x] Jobs
    [x] Execution
    [x] Connector framework
    [x] Download
    [x] Verification
    [x] Metadata
    [x] Reference Vault M1
    [x] Acquisition Record (PUSHED — commit 0494e25)
    [x] Network connector security decision (ADR-0003, PUSHED — commit d7df760)
    [x] API authentication + TLS boundary (WP-SRV-003/004, PUSHED — commits 0421ca2/ce2fbf9)

SERVER REPOSITORY SERVICE (new subsystem, not in this checklist's original scope — see Section 11A)
    [x] Architecture decisions (ADR-0001..0006, PUSHED)
    [x] First vertical slice: repositories, objects, relationships,
        revisions, commits, idempotency, audit (WP-SRV-011, PUSHED)
    [x] Real PostgreSQL concurrency correction (WP-SRV-011A, PUSHED)
    [x] API wire version (WP-SRV-011B, PUSHED)
    [x] UUIDv4 identity contract (WP-SRV-011C, PUSHED)
    [x] Tombstone/delete semantics, incl. create-shaped restoration
        correction (WP-SRV-012/012A, PUSHED)
    [ ] Next work package (WP-SRV-013 — NOT STARTED, not selected)

EXCHANGE
    [x] Foundation (workspace + client, WP-EXC-011/012, PUSHED)
    [x] Install bridge to Foundation's real installer (WP-EXC-013, PUSHED)
    [x] Reproducible Foundation bridge test gate (WP-EXC-013A, PUSHED)
    [x] End-to-end vertical-slice verification (WP-EXC-014, PUSHED)
    [ ] RC1 (vertical slice proven end to end; still missing production
        publisher UI, authentication, and the other items in Section 12's
        "NOT PRESENT / NOT COMPLETE" — those, not architectural proof, are
        what remain before RC1 itself)
    [ ] Complete publisher workflow (backend API only, no UI)
    [x] Consumer workflow (search/browse/detail/download/install — real, tested end to end through Foundation's real installer, now with a genuine end-to-end test as of WP-EXC-014)
    [x] Studio integration (substantially built — full Exchange workspace, registered in StudioRegistry; the real-install bridge is now closed by WP-EXC-013, see Section 12)

INSTRUMENTS
    [x] OIP foundation
    [x] Android DMM
    [x] Studio host bridge
    [ ] broader instrument ecosystem

RELEASE ENGINEERING
    [ ] canonical version authority
    [ ] version propagation rules
    [ ] release manifest
    [ ] changelog discipline
    [ ] performance baseline
    [ ] security gate
    [ ] release checklist

====================================================================
22. OEP 0.3.0 OBJECTIVE
====================================================================

PRIMARY THEME:
    M2 / Integrated Platform Expansion

TARGETS:

EAM:
    - Acquisition Record
    - stronger provenance
    - connector security
    - Vault M2 foundation

EXCHANGE:
    - publisher -> package -> upload -> catalog -> download ->
      install -> repository -> Studio

STUDIO:
    - deeper Engine integration
    - close FFI mutation gaps
    - mature Engineering Intelligence pages

KNOWLEDGE:
    - ingestion lifecycle
    - provenance
    - candidate/review boundary
    - trust/signing maturity

PLATFORM:
    - performance baseline
    - security hardening
    - release engineering

====================================================================
23. OEP 1.0.0 DEFINITION
====================================================================

OEP 1.0.0 IS NOT REACHED SIMPLY BECAUSE:
    - many features exist
    - EKE reached v1.0
    - Diagram Studio works
    - Exchange exists
    - EAM exists

OEP 1.0.0 SHOULD REQUIRE:

ARCHITECTURE
    [ ] stable
    [ ] documented
    [ ] no unresolved major architectural contradictions

CORE
    [ ] Foundation production-ready
    [ ] Engine production-ready
    [ ] public API stable
    [ ] ABI compatibility policy established

STUDIO
    [ ] primary workflows production-ready
    [ ] human acceptance passed
    [ ] persistence reliable
    [ ] no major lifecycle defects

KNOWLEDGE
    [ ] runtime trust model complete
    [ ] lifecycle complete
    [ ] provenance complete
    [ ] ingestion/review boundaries complete

EAM
    [ ] production connector policy
    [ ] secure acquisition
    [x] Acquisition Record foundation (PUSHED — commit 0494e25)
    [ ] complete provenance (rich per-acquisition metadata, custody events remain FUTURE)
    [ ] production Vault

EXCHANGE
    [ ] publisher workflow
    [ ] consumer workflow
    [ ] package trust
    [ ] dependency handling
    [ ] installation
    [ ] update lifecycle
    [ ] Studio integration
    [ ] production security

OPERATIONS
    [ ] authentication
    [ ] logging
    [ ] telemetry
    [ ] update/distribution
    [ ] recovery
    [ ] performance baselines
    [ ] security audit

DOCUMENTATION
    [ ] one authoritative status hierarchy
    [ ] architecture index
    [ ] release documentation
    [ ] API documentation
    [ ] user documentation
    [ ] developer documentation

====================================================================
24. CURRENT OVERALL SCORECARD
====================================================================

CORE FOUNDATION
    ████████████████████  HIGH MATURITY

ENGINE / EKE
    ████████████████████  HIGH MATURITY

DIAGRAM STUDIO
    █████████████████░░░  HIGH / INTEGRATION MATURITY

ELECTRICAL RUNTIME
    █████████████████░░░  HIGH VERTICAL-SLICE MATURITY

DMM / INSTRUMENTS
    ███████████████░░░░░  FUNCTIONAL FOUNDATION

KNOWLEDGE RUNTIME
    ████████████████░░░░  STRONG CORE / LIFECYCLE REMAINS

EAM / VAULT
    ████████████████░░░░  M1 COMPLETE / API AUTH+TLS COMPLETE / M2 BROADER SCOPE REQUIRED

SERVER REPOSITORY SERVICE
    ███████░░░░░░░░░░░░░  FIRST VERTICAL SLICE COMPLETE (INCL. TOMBSTONE) / NEXT WP NOT SELECTED

ENGINEERING EXCHANGE
    █████████░░░░░░░░░░░  WORKSPACE + CLIENT FOUNDATION + INSTALL BRIDGE COMPLETE (PUSHED) / RC1 NOT STARTED

SECURITY
    ████████░░░░░░░░░░░░  REFERENCE-SERVER API AUTH+TLS RESOLVED / PLATFORM-WIDE HARDENING REQUIRED

PERFORMANCE
    ██████░░░░░░░░░░░░░░  MEASUREMENT PROGRAM REQUIRED

DOCUMENTATION / RELEASE CONTROL
    ████████░░░░░░░░░░░░  RECONCILIATION REQUIRED

OVERALL OEP:
    INTEGRATED ALPHA / PRE-BETA

====================================================================
25. NEXT PRIORITY ORDER
====================================================================

1. Verify/close out the credential-exposure claim (Section 16) — a prior
   Foundation review flagged a plaintext credential file that current
   repository/filesystem inspection did not find; confirm no residual
   exposure and rotate if any doubt remains.

2. ~~Resolve ADR-0003: HttpConnector scope + security.~~ RESOLVED AND
   PUSHED 2026-09-13, commit d7df760 — see Section 11.

3. Complete Diagram Studio human UX/UI acceptance.

4. Establish canonical OEP versioning/release architecture. (This
   documentation/control-plane task addresses this directly — see
   docs/project/.)

5. Reconcile project status/documentation system. (Also addressed by
   this task — see docs/project/README.md and the supersession notices
   added to stale documents.)

6. Close high-value Foundation/API technical debt.

7. Expand Engineering Exchange toward RC1 (WP-EXC-010) — its workspace,
   client foundation, real install bridge, reproducible test gate, and
   end-to-end verification are now all complete and PUSHED
   (WP-EXC-011/012/013/013A/014), with the full workspace
   building/typechecking/testing with zero failures. What remains before
   RC1 itself is claimed is product surface area (publisher UI,
   authentication, etc.), not further architectural proof.

8. ~~Expand EAM/Vault into broader M2 API authentication.~~ RESOLVED AND
   PUSHED 2026-09-13/14, commits 0421ca2 (WP-SRV-003)/ce2fbf9
   (WP-SRV-004) — see Section 11/16. Remaining EAM M2 scope (rich
   provenance metadata, custody events) stays open, blocked on upstream
   connector producers that do not exist yet.

9. Establish formal performance/security/release gates.

10. ~~Decide when/how to push local commits (PR-014 through WP-018) to
    GitHub main.~~ DONE — all commits through the ADR-0003 follow-up
    are on origin/main as of the WP-CTRL-001 reconciliation (2026-09-13);
    see Section 0.

11. Select and authorize the next Server Repository Service work package
    (Section 11A) — WP-SRV-013 is NOT STARTED; no repository evidence
    exists for it, and this reconciliation does not select or begin it.

====================================================================
26. MASTER RULE FOR FUTURE WORK
====================================================================

Every future work package must update this record.

Every completed work package must report:

    WHAT WAS PLANNED
    WHAT WAS IMPLEMENTED
    WHAT ACTUALLY WORKS
    WHAT DOES NOT WORK
    WHAT REMAINS PARTIAL
    WHAT WAS NOT STARTED
    WHAT WAS DEFERRED
    WHAT WAS VERIFIED
    WHAT WAS NOT VERIFIED
    TEST RESULTS
    BUILD RESULTS
    KNOWN DEFECTS
    ARCHITECTURAL IMPACT
    RELEASE IMPACT
    NEXT DEPENDENCY

No capability shall be marked GREEN merely because code exists.

No capability shall be marked COMPLETE merely because tests compile.

No planned capability shall be represented as implemented.

====================================================================
27. CURRENT MASTER STATE
====================================================================

AS OF:
    2026-09-16 (WP-CTRL-002 reconciliation; origin/main at commit a36f69e)

PLATFORM:
    OEP 0.1.0 legacy development identity

NEXT TARGET:
    OEP 0.2.0

CURRENT MAJOR ACTIVE WORK:
    None actively in progress as of this reconciliation. Most recently
    completed: WP-SRV-012A (Server Repository create-shaped tombstone
    restoration correction, commit 66af1f5) and this documentation
    reconciliation itself (WP-CTRL-002). The next Server Repository work
    package (WP-SRV-013) has not been selected or started.

CURRENT EAM STATE:
    M1 COMPLETE
    Acquisition Record foundation (WP-018) COMPLETE, PUSHED
    Connector destination-security (ADR-0003) RESOLVED, PUSHED
    API authentication + TLS boundary (WP-SRV-003/004) RESOLVED, PUSHED
    Broader M2 (rich provenance, custody events) READY WITH CONDITIONS —
    blocked on upstream connector producers that do not exist yet

CURRENT SERVER REPOSITORY SERVICE STATE:
    First vertical slice COMPLETE, PUSHED (WP-SRV-011/011A/011B/011C)
    Tombstone/delete semantics COMPLETE, PUSHED, incl. create-shaped
    restoration correction (WP-SRV-012/012A, commit 66af1f5)
    514/514 assertions, 16 test cases, real PostgreSQL (per WP-SRV-012A's
    own report; not independently re-run by this reconciliation)
    WP-SRV-013: NOT STARTED — no repository evidence, not selected here

CURRENT DIAGRAM STUDIO STATE:
    FUNCTIONAL VERTICAL SLICE
    HUMAN ACCEPTANCE PENDING

CURRENT EKE STATE:
    INTERNAL v1.0 ARCHITECTURE FREEZE

CURRENT EXCHANGE STATE:
    WORKSPACE + CLIENT FOUNDATION + REAL INSTALL BRIDGE + REPRODUCIBLE
    TEST GATE + END-TO-END VERIFICATION COMPLETE
    (WP-EXC-011/012/013/013A/014, PUSHED)
    STUDIO INTEGRATION ALREADY SUBSTANTIALLY BUILT (see Section 12) — the
    install action reaches Foundation's real, trust-verifying installer,
    now proven end to end by a genuine E2E test
    RC1 SCOPED (WP-EXC-010-SCOPE.md); NOT YET CLAIMED COMPLETE — the
    vertical slice is architecturally proven; remaining product surface
    (publisher UI, authentication, etc.) is what keeps RC1 itself unclaimed

CURRENT OVERALL PLATFORM STATE:
    INTEGRATED ALPHA / PRE-BETA

NEXT MAJOR RELEASE:
    OEP 0.2.0 — INTEGRATED ENGINEERING PLATFORM FOUNDATION

FIRST STABLE RELEASE TARGET:
    OEP 1.0.0

====================================================================
END OF MASTER STATUS RECORD
====================================================================