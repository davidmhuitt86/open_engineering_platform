# OEP Project Control Documentation

This directory is the canonical, whole-platform project-control documentation system for the Open Engineering Platform (OEP). It exists so that a founder or an AI agent opening this repository — today or months from now — can answer, without re-deriving anything from scratch: *What is OEP? What version are we on? What works? What doesn't? What is incomplete? What is next? What was actually verified? What is local versus merged? What milestone are we targeting? What is blocking release? What must NOT be implemented yet?*

## Documentation hierarchy

| Document | Role |
|---|---|
| [`/OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) | **ROOT / canonical.** The current, whole-platform status dashboard. Start here. |
| [`OEP_VERSIONING_POLICY.md`](OEP_VERSIONING_POLICY.md) | Canonical versioning rules — how OEP's ten-plus independent version dimensions relate, and the intended `0.1.x` → `1.0.0` progression. |
| [`OEP_MILESTONE_ROADMAP.md`](OEP_MILESTONE_ROADMAP.md) | Canonical future milestone plan — objective, scope, entry/exit criteria, blockers, and release confidence for every milestone from M0/0.1.x through 1.0.0. |
| [`OEP_RELEASE_HISTORY.md`](OEP_RELEASE_HISTORY.md) | Canonical chronological release/implementation history — every entry labeled GitHub main / local-not-pushed / working-tree / proposed. |
| [`audits/`](audits/) | Point-in-time audit records, one per audit date. The current one is [`audits/2026-09-13-OEP-MASTER-AUDIT.md`](audits/2026-09-13-OEP-MASTER-AUDIT.md). |

**Subsystem-specific status documents** (Foundation's `PROJECT_STATUS.md`/`CURRENT_SPRINT.md`, Exchange's architecture docs, EAM's WP audit docs, etc.) remain in their own subsystems and are **subordinate** to `/OEP_PROJECT_STATUS.md` — they provide subsystem/history depth this root system deliberately does not duplicate, but the root file is the one to trust for current, whole-platform status. Where a subsystem document's own claims have been found to materially disagree with direct repository inspection (Exchange's architecture docs describing a `packages/*` workspace that does not exist; three Foundation review documents describing a credential file this audit could not find), a note pointing back to the canonical system has been added to that document — see the master audit's Documentation Audit section for the full list.

## How to use this system

- **Before starting new work**: read `/OEP_PROJECT_STATUS.md` first, then the milestone roadmap to see what the current target milestone actually requires.
- **After finishing a work package**: update `/OEP_PROJECT_STATUS.md`'s relevant subsystem section and add an entry to `OEP_RELEASE_HISTORY.md`, following the existing entries' format (what was planned, implemented, verified, not verified, test results, GitHub-main-vs-local status).
- **When running a fresh whole-platform audit**: create a new dated file under `audits/` (do not overwrite a prior one), then update `/OEP_PROJECT_STATUS.md` to reflect the new findings.
- **Never** create a second competing root-level status document. Never claim a local, unpushed commit is on GitHub main. Never mark a capability GREEN/COMPLETE because code exists or tests compile — only because it was actually verified.
