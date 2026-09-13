# OEP Versioning Policy

Canonical versioning rules for the Open Engineering Platform (OEP). See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) for current status and [`OEP_MILESTONE_ROADMAP.md`](OEP_MILESTONE_ROADMAP.md) for the milestone plan this policy's release progression feeds into.

Last audited: 2026-09-13.

---

## 1. Core rule: version dimensions are never collapsed

OEP has **at least ten independent version dimensions**. A change to one must never be assumed to imply a change to another, and no single number is ever used to stand in for more than one of these:

| Dimension | Current value (verified 2026-09-13) | Source of truth |
|---|---|---|
| OEP product/platform version | `0.1.0` (legacy development identity) | Documented identity; no single repository file is the enforced source today — see Section 5 |
| Foundation package version | `0.1.0` (documented identity) | No `project(... VERSION x.y.z)` in `platform/oep_foundation/CMakeLists.txt` — not currently build-system-enforced |
| Engineering Engine (`engineering_engine`) package version | `0.1.0` | `platform/oep_engine/pubspec.yaml` |
| Studio package version | `0.1.0` | `platform/oep_studio/pubspec.yaml` |
| Exchange package/service versions | not yet unified (`services/exchange` contains multiple independently-versioned packages/apps) | individual `package.json`/manifest files under `services/exchange/` |
| Public C API version | `21` | `#define OEP_API_VERSION 21` in `platform/oep_foundation/platform/api/include/oep/api/oep_api.h` |
| ABI version | `1` | `#define OEP_ABI_VERSION 1`, same header |
| EKE internal version | `v1.0` (architecture freeze) | Documented milestone, not a single build-system field |
| `.oerp` package format version | tracked independently within `knowledge/reference_library` — see that subsystem's own documentation | `knowledge/reference_library` |
| Schema versions (e.g. Studio `UserConfiguration.currentSchemaVersion`) | tracked per-schema, independently | e.g. `platform/oep_studio` settings migration code |
| Protocol versions (e.g. OIP) | tracked independently per protocol | `platform/oep_instruments` |

**Rule**: never write code, documentation, or a release note that uses one of these numbers to answer a question about a different one. "OEP is on 0.1.0" says nothing about the API version, the ABI version, or any package version, and vice versa.

A stray artifact confirming why this matters: an orphaned Claude Code agent worktree (`platform/oep_foundation/.claude/worktrees/agent-a560bcb7977f8f129/`) contains a stale copy of `oep_api.h` still reporting `OEP_API_VERSION 9` — a live demonstration of exactly the drift this policy exists to prevent. That worktree is stray/leftover, not a second authoritative header; the live `platform/oep_foundation/platform/api/include/oep/api/oep_api.h` (API 21 / ABI 1) is authoritative.

---

## 2. OEP product/platform version — semantic versioning with explicit meaning

The OEP product/platform version follows `MAJOR.MINOR.PATCH` semantic versioning, with these platform-specific meanings:

### MAJOR
Breaking public/platform/API/ABI architectural changes. A MAJOR bump means a caller, package, or integration built against the previous MAJOR version can no longer be assumed to work without changes. Before OEP 1.0.0, the platform is understood to be pre-stable (see Section 4) — MAJOR stays `0` through the entire roadmap in Section 3, with `1.0.0` itself being the first stability commitment, not a "big feature" milestone.

### MINOR
New backwards-compatible platform capabilities — a new subsystem reaching a usable state, a new vertical slice, a new integration — that do not break any existing, documented public contract (Public C API, REST APIs, package/protocol formats a consumer already depends on).

### PATCH
Bug fixes, hardening, documentation corrections, and other compatible maintenance that do not add a new capability and do not break anything.

**Internal subsystem versions may advance independently of, and on a different cadence than, the OEP product version.** The Public C API moving from 19 to 21 while the OEP product version stayed at `0.1.0` throughout is the existing, correct precedent for this — it is not a documentation error to be "fixed," it is the policy working as intended. A subsystem package (Foundation, Engineering Engine, Studio, Exchange) advancing its own semantic version independently of the platform version is expected, not exceptional.

---

## 3. Intended OEP release progression (TARGETS — none of these are released)

**Every version below `1.0.0` in this section is a PLANNED MILESTONE, not a released or completed state.** See [`OEP_MILESTONE_ROADMAP.md`](OEP_MILESTONE_ROADMAP.md) for the full entry/exit criteria behind each one; this table exists only to record the intended sequence and its high-level intent.

| Version range | Intent |
|---|---|
| `0.1.x` | Original Foundation/development baseline (current — verified state, see [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md)) |
| `0.2.x` | Integrated Engineering Platform Foundation — a coherent integrated platform foundation, **not** feature completeness |
| `0.3.x` | Engineering Acquisition M2 / provenance / Exchange integration / deeper Studio integration / knowledge lifecycle expansion |
| `0.4.x` | Broader beta expansion |
| `0.5.x` | Feature-complete beta target |
| `0.6.x`–`0.8.x` | Integration, ecosystem, reliability, performance, and production hardening |
| `0.9.x` | Release candidate |
| `1.0.0` | Stable, supported platform (see Section 4 for the full gate list) |

None of `0.2.x` through `0.9.x` have been reached. The platform is currently `0.1.0`.

---

## 4. OEP 1.0.0 requires more than feature completeness

`1.0.0` is a **commitment**, not a feature count. It requires (full detail in the milestone roadmap and the master audit):

- Stable public APIs, with a documented compatibility policy
- Stable package/protocol formats
- Release reproducibility
- A security baseline (not "no known issues," but a demonstrated, gated review process)
- A performance baseline (measured, not assumed)
- Test coverage appropriate to critical paths (not 100% coverage as a number, but no critical path validated only by inspection)
- A migration/update strategy
- Documentation completeness
- Cross-platform validation
- Reliable installation
- Recovery/error behavior
- Operational supportability
- Ecosystem readiness (Exchange, third-party integration points)

A platform can have many working features and still correctly not be `1.0.0` — that is the expected, intended state of `0.4.x`/`0.5.x` in this progression, not a failure.

---

## 5. Where version numbers actually live today (as-verified, not aspirational)

- **Studio**: `platform/oep_studio/pubspec.yaml` → `version: 0.1.0`
- **Engineering Engine**: `platform/oep_engine/pubspec.yaml` → `version: 0.1.0`
- **Foundation**: no enforced version field found in `platform/oep_foundation/CMakeLists.txt` (`project(OEPFoundation LANGUAGES CXX C)`, no `VERSION` argument) — `0.1.0` is a documented, conventional identity today, not a build-system-enforced one. **This is itself a known gap** — see [`OEP_MILESTONE_ROADMAP.md`](OEP_MILESTONE_ROADMAP.md)'s 0.2.x exit criteria ("establish coherent release/version identity") and the master audit's version-audit section.
- **Public C API / ABI**: `platform/oep_foundation/platform/api/include/oep/api/oep_api.h` → `#define OEP_API_VERSION 21`, `#define OEP_ABI_VERSION 1` — this header is the single authoritative source. Any document (including historical Foundation review documents) that references API 19 or 20 is describing a past state and must be read as historical, not current.
- **OEP product/platform version**: currently a documented identity (`0.1.0`) recorded in [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md); establishing one canonical, enforced location for this number (e.g. a root `VERSION` file or equivalent) is itself tracked as a 0.2.x exit criterion, not assumed to already exist.

---

## 6. What this policy does not do

This policy does not itself bump any version. As of this document's creation:

- The OEP platform version remains `0.1.0`.
- Foundation, Engineering Engine, and Studio package versions remain `0.1.0`.
- `OEP_API_VERSION` remains `21`.
- `OEP_ABI_VERSION` remains `1`.
- EKE remains at its internal `v1.0` architecture freeze.

Bumping any of these is a separate, deliberate release decision, gated by the milestone roadmap's own exit criteria — not a side effect of writing this policy down.
