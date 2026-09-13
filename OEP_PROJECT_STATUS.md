====================================================================
OPEN ENGINEERING PLATFORM
MASTER PROJECT STATUS & RELEASE TRACKING RECORD
====================================================================

Document: OEP-PROJECT-STATUS-MASTER
Record Type: Canonical Project Status / Capability / Release Register
Organization: Divad Technology Group, LLC
Platform: Open Engineering Platform (OEP)

LAST AUDITED:
    2026-09-13

CANONICAL:
    This file is the one authoritative, current, whole-platform status
    document. See docs/project/README.md for the full documentation
    hierarchy (versioning policy, milestone roadmap, release history,
    point-in-time audits). Do not create a second competing root-level
    status document.

====================================================================
0. REPOSITORY BASELINE — GITHUB MAIN vs. LOCAL WORKING TREE
====================================================================

GITHUB main (origin/main), verified via `git log origin/main -1`:
    78ee8b0  "Boot the Workspace to a real Home/Dashboard surface
              instead of empty"

LOCAL working tree (this machine), verified via `git log --oneline`:
    7 commits ahead of origin/main, none pushed:

    0494e25  WP-018: implement Acquisition Record and provenance foundation
    8c6185c  WP-017: EAM/Reference Vault implementation audit and hardening
    bead021  Fix HTML acceptance tester sidebar nav order (N between M and O)
    84564de  PR-016A: add interactive Diagram Studio human acceptance tester
    5c231b5  PR-016: prepare Diagram Studio human acceptance testing
    8634276  PR-015: add Diagram Studio human UX/UI acceptance test system
    1a97358  PR-014: stabilize Diagram Studio WebView lifetime

RULE:
    Every status in this document that depends on local-only commits is
    explicitly labeled "LOCAL / NOT PUSHED." Nothing in this document
    should be read as a claim about what exists on GitHub main beyond
    78ee8b0 unless labeled otherwise. See docs/project/OEP_RELEASE_HISTORY.md
    for the full chronological record.

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
    GREEN / M2 FOUNDATION (ACQUISITION RECORD) COMPLETE — LOCAL / NOT PUSHED
    YELLOW / M2 BROADER SCOPE (CONNECTOR SECURITY, RICH PROVENANCE) REQUIRED

WP-001 through WP-009:
    M1 implemented.

WP-018 (Acquisition Record & Provenance Foundation):
    Complete — LOCAL / NOT PUSHED (commit 0494e25). See Section 11.2.

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

CRITICAL OUTSTANDING ISSUE:
    HttpConnector performs real outbound HTTP despite the earlier
    documented M1 exclusion.

SECURITY CONCERN:
    SSRF-shaped behavior due to insufficient destination/redirect
    restrictions and lack of authentication.

ADR:
    ADR-0003 requires explicit resolution.

EAM FOUNDATION WORK PACKAGE:
    WP-018 — Acquisition Record & Provenance Foundation
    STATUS: COMPLETE — LOCAL / NOT PUSHED (commit 0494e25)
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
    GREEN / COMPLETE WITH BOUNDED GAPS — LOCAL / NOT PUSHED (commit 0494e25)

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
    Push to GitHub main once release-worthy (not a WP-018 blocker itself
    — a project-control/release-management decision). ADR-0003 remains
    unresolved and independent of this work.

====================================================================
12. ENGINEERING EXCHANGE
====================================================================

STATUS:
    YELLOW — EXCHANGE WORKSPACE FOUNDATION RESTORED (LOCAL / NOT PUSHED)
    Exchange RC1 itself remains ORANGE / NOT STARTED.

WORKSPACE FOUNDATION — RESTORED BY WP-EXC-011 (2026-09-13, LOCAL / NOT PUSHED):
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

    ONE CONFIRMED, UNRECOVERABLE GAP: `apps/publisher-portal` fails to
    build/typecheck and accounts for all 7 failing test files / 12
    failing tests. Its own consumer code (added in the same upstream
    `c6dbb75` commit that deleted the packages) depends on a real
    `@oep-exchange/exchange-client` `ExchangeApiClient`/`ExchangeApiError`
    implementation that was **never committed anywhere, in either
    repository, at any commit** (TASK-EXC-0007's own scope, never
    historically completed). This is not a WP-EXC-011 defect — there is
    nothing further to restore — and implementing it now would be new
    Exchange feature work, explicitly out of that WP's scope.

    Full detail: services/exchange/docs/tasks/WP-EXC-011.md,
    services/exchange/docs/audits/WP-EXC-011-IMPLEMENTATION-REPORT.md.

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
      (`GET /api/v1/health`), OpenAPI generation wired, now builds
      cleanly against its restored package dependencies.
    - `apps/exchange-admin` — React/Vite app, now builds and typechecks
      cleanly against its restored package dependencies.
    - `db/migrations` — Flyway-style migrations directory exists.
    - WP-EXC-001 through WP-EXC-010 (specifications) and WP-EXC-011
      (this workspace restoration) task documents
      (services/exchange/docs/tasks/) — WP-EXC-011 is the only one of
      these actually implemented; WP-EXC-002 through WP-EXC-010 remain
      specifications only.

NOT PRESENT / NOT COMPLETE:
    - `apps/publisher-portal`'s own build (blocked on the confirmed,
      unrecoverable `exchange_client` gap above)
    - complete publisher workflow
    - complete package publication
    - production catalog
    - complete discovery
    - complete download/install workflow
    - full Studio integration
    - production Exchange RC1
    - licensing, payments, reviews (explicitly excluded from WP-EXC-001's
      own scope, per that task's own Scope section — restored only as
      their original inert scaffolds, not implemented)

CURRENT DOCUMENTED WORK:
    WP-EXC-001 through WP-EXC-010 specifications exist. WP-EXC-011
    (Exchange Workspace Reconstruction) is implemented, LOCAL / NOT
    PUSHED. Exchange RC1 itself (WP-EXC-010's own objective) has not
    been started.

MAJOR REMAINING PROGRAM:
    Resolve the `exchange_client`/TASK-EXC-0007 gap (a scoped follow-up,
    not yet a numbered work package) before `publisher-portal`-specific
    feature work proceeds; then WP-EXC-010 (Exchange RC1 + Studio
    integration) itself. `exchange-api` and `exchange-admin` have no such
    blocker and are ready for further work today.

EXCHANGE RC1 IS NOT CURRENTLY A RELEASE-READY OEP SUBSYSTEM. Its
workspace FOUNDATION, as of WP-EXC-011, now is (with the one named
exception above).

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

OTHER, UNCHANGED:
    - API authentication not mature
    - HttpConnector SSRF-shaped behavior (ADR-0003 unresolved)
    - connector authorization not complete
    - trust-store architecture incomplete (Ed25519 not implemented)
    - production security boundary incomplete

SECURITY IS A RELEASE GATE FOR OEP 1.0. This section must not be marked
GREEN until ADR-0003 is resolved, API authentication exists, and the
credential-exposure claim above is personally confirmed closed.

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
   ACTION:
       Resolve ADR-0003 before expanding network acquisition.

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

COMPLETED / VERIFIED (LOCAL — see Section 0 for what is/is not on GitHub main):

    WP-REP-001..008
    WP-EKE-001..008
    EAM WP-001..009
    Diagram Studio PR-002..014
    PR-015 testing system
    PR-016 human-test preparation
    Home/Dashboard integration
    WP-017 (EAM / Reference Vault audit) — READY WITH CONDITIONS, commit 8c6185c, NOT PUSHED
    WP-018 (Acquisition Record & Provenance Foundation) — COMPLETE, commit 0494e25, NOT PUSHED

CURRENT / IMMEDIATE:

    This documentation/project-control task (OEP_PROJECT_STATUS.md and the
    docs/project/ canonical documentation system).

NEXT (see Section 25 for the full recommended priority order):

    1. Credential/security exposure verification (Section 16 — claim not
       corroborated by current repository inspection; verify and close out)
    2. ADR-0003 — HttpConnector scope/security decision
    3. Diagram Studio human UX/UI acceptance execution
    4. Push local commits (PR-014 through WP-018) to GitHub main once a
       release/merge decision is made — this is a project-control decision,
       not a WP-018 blocker

PARALLEL / GATED:

    ADR-0003
        HttpConnector scope/security decision

PENDING HUMAN:

    Diagram Studio Human UX/UI Acceptance Test

MAJOR FUTURE PROGRAM:

    Engineering Exchange completion/integration

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
    [x] Acquisition Record (LOCAL / NOT PUSHED — commit 0494e25)
    [ ] Network connector security decision (ADR-0003)

EXCHANGE
    [x] Foundation
    [ ] RC1
    [ ] Complete publisher workflow
    [ ] Complete consumer workflow
    [ ] Studio integration

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
    [x] Acquisition Record foundation (LOCAL / NOT PUSHED)
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
    ████████████████░░░░  M1 COMPLETE / M2 REQUIRED

ENGINEERING EXCHANGE
    ████████░░░░░░░░░░░░  WORKSPACE FOUNDATION RESTORED (LOCAL) / RC1 NOT STARTED

SECURITY
    ███████░░░░░░░░░░░░░  HARDENING REQUIRED

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

2. Resolve ADR-0003:
       HttpConnector scope + security.

3. Complete Diagram Studio human UX/UI acceptance.

4. Establish canonical OEP versioning/release architecture. (This
   documentation/control-plane task addresses this directly — see
   docs/project/.)

5. Reconcile project status/documentation system. (Also addressed by
   this task — see docs/project/README.md and the supersession notices
   added to stale documents.)

6. Close high-value Foundation/API technical debt.

7. Resolve the `exchange_client`/TASK-EXC-0007 gap (Section 12), then
   expand Engineering Exchange toward RC1 (WP-EXC-010) — the workspace
   foundation itself is now restored (WP-EXC-011, LOCAL / NOT PUSHED).

8. Expand EAM/Vault into broader M2 (rich provenance metadata, custody
   events, connector security policy) — the Acquisition Record
   foundation itself (WP-018) is now complete, LOCAL / NOT PUSHED.

9. Establish formal performance/security/release gates.

10. Decide when/how to push local commits (PR-014 through WP-018) to
    GitHub main — a release-management decision, not a blocker on any
    of the above.

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
    2026-09-13

PLATFORM:
    OEP 0.1.0 legacy development identity

NEXT TARGET:
    OEP 0.2.0

CURRENT MAJOR ACTIVE WORK:
    OEP project-control/versioning/master-status documentation system
    (this record and docs/project/) — WP-018 is COMPLETE, LOCAL / NOT
    PUSHED (commit 0494e25).

CURRENT EAM STATE:
    M1 COMPLETE
    Acquisition Record foundation (WP-018) COMPLETE, LOCAL / NOT PUSHED
    Broader M2 (connector security, rich provenance) READY WITH CONDITIONS

CURRENT DIAGRAM STUDIO STATE:
    FUNCTIONAL VERTICAL SLICE
    HUMAN ACCEPTANCE PENDING

CURRENT EKE STATE:
    INTERNAL v1.0 ARCHITECTURE FREEZE

CURRENT EXCHANGE STATE:
    WORKSPACE FOUNDATION RESTORED (WP-EXC-011, LOCAL / NOT PUSHED)
    RC1 NOT STARTED

CURRENT OVERALL PLATFORM STATE:
    INTEGRATED ALPHA / PRE-BETA

NEXT MAJOR RELEASE:
    OEP 0.2.0 — INTEGRATED ENGINEERING PLATFORM FOUNDATION

FIRST STABLE RELEASE TARGET:
    OEP 1.0.0

====================================================================
END OF MASTER STATUS RECORD
====================================================================