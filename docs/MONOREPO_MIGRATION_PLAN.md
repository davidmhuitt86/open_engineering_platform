# Monorepo Migration Plan — Open Engineering Platform

Task: AP-REPO-001 (Phase 1 — read-only discovery only)
Status: DISCOVERY COMPLETE. No migration executed. Awaiting authorization for AP-REPO-002.

## 1. Purpose

Consolidate the separate OEP repositories currently checked out under
`C:\dev\platform\` into a single canonical Git monorepo at
`C:\dev\open_engineering_platform`, preserving each source repository's
commit history under a path prefix. This document is the Phase 1
discovery + plan artifact. It authorizes nothing beyond its own
creation.

## 2. Current repository topology

`C:\dev\platform\` contains:

| Directory | Is a git repo? | Notes |
|---|---|---|
| `oep_foundation` | yes | core C/C++ engineering foundation + public API |
| `oep_engine` | yes | Dart "engineering_engine" package, depends on oep_foundation via native FFI bridge (used by oep_studio's build, not a Dart path dep of oep_engine itself) |
| `oep_studio` | yes | Flutter desktop app ("Diagram Studio" etc.), has Dart `path:` deps on `../oep_engine` and `../oep_instruments/platform/oep_instruments`, and a CMake path default of `../../../oep_foundation` (relative to `native/foundation_bridge/`) |
| `oep_acquisition` | yes | "Trust Layer" — acquisition/provenance/integrity/licensing. Remote name mismatch: repo dir is `oep_acquisition`, GitHub remote is `oep_acqusition` (typo preserved in existing remote URL) |
| `oep_design_system` | yes | design system repo |
| `oep_exchange` | yes | OEP Exchange (OEX) distribution platform; its own README states it integrates with the rest of OEP only through published interfaces, not source-tree coupling |
| `oep_instruments` | yes | referenced as a build-time sibling path dependency by `oep_studio/pubspec.yaml` (`../oep_instruments/platform/oep_instruments`) |
| `oep_reference` | yes | "OEP Reference Library" (ERL); GitHub remote is named `oep_reference_library` (dir name differs from remote repo name) |
| `oep_architecture` | no | plain directory, not a git repo — architecture docs/templates |
| `platform_docs` | no | plain directory, empty at time of inspection |
| `PLATFORM_CONSTITUTION` | no | plain directory containing `CLAUDE_PROJECT_RULES.md` |
| `OEP_SNAPSHOT` (+ `.zip`) | no | plain directory + a zip archive of the same — index/snapshot docs (`ARCHITECTURE_INDEX.md`, `DEPENDENCY_GRAPH.md`, etc.) |
| `oep_design_system.zip` | n/a | zip archive sibling of the `oep_design_system` git repo — likely a stale export, not itself under git |
| `reference` | no | plain directory. Contains `reference/legacy_wiring_sim_v2/eke-wiring-sim/` — **not a git repository**, plain files (css/diagrams/docs/exports/js/tests + index.html) |

No submodules, no `.gitattributes` LFS usage, and no worktrees other than one unrelated stale item noted in §11.

## 3. Target repository topology

As specified in the task prompt (target design, not yet created beyond `docs/`):

```
C:\dev\open_engineering_platform\
│
├── .git\
├── platform\
│   ├── oep_foundation\
│   ├── oep_engine\
│   ├── oep_studio\
│   └── [other approved OEP platform projects]
├── reference\
│   └── legacy_wiring_sim_v2\
├── specifications\
├── docs\
├── tools\
└── README.md
```

Only `docs/` (and this file inside it) has been created during Phase 1, per the
prompt's "target root documentation" restriction. No other target-side
directories were created.

## 4. Repository inventory

| Repository | Current Path | Remote | Branch | HEAD | Dirty? | Purpose | Proposed Target | Migrate? |
|---|---|---|---|---|---|---|---|---|
| oep_foundation | `C:\dev\platform\oep_foundation` | `github.com/davidmhuitt86/oep_foundation.git` | main | `51a1441` | No | C/C++ engineering foundation + public API | `platform/oep_foundation` | YES |
| oep_engine | `C:\dev\platform\oep_engine` | `github.com/davidmhuitt86/oep_engine.git` | main | `3fa22c2` | No | Dart "engineering_engine" package | `platform/oep_engine` | YES |
| oep_studio | `C:\dev\platform\oep_studio` | `github.com/davidmhuitt86/oep_studio.git` | main | `5922ce8` | **Yes** (1 untracked file) | Flutter desktop app; Diagram Studio | `platform/oep_studio` | YES |
| oep_instruments | `C:\dev\platform\oep_instruments` | `github.com/davidmhuitt86/oep_instruments.git` | main | `25510a0` | No | Instruments package; **required by oep_studio's pubspec path dependency** | `platform/oep_instruments` | **DECISION REQUIRED** — functionally required for oep_studio to build if the sibling-relative path scheme is kept; recommend YES for that reason, but not in the prompt's explicit "at minimum" list, so flagging rather than assuming |
| oep_acquisition | `C:\dev\platform\oep_acquisition` | `github.com/davidmhuitt86/oep_acqusition.git` (typo in remote name, pre-existing) | main | `d062bb4` | No | Acquisition / provenance / trust layer | `platform/oep_acquisition` | DECISION REQUIRED — OEP-owned but not source-coupled to foundation/engine/studio; include if the monorepo is meant to hold the whole platform, exclude if scope is core-engineering-loop only |
| oep_design_system | `C:\dev\platform\oep_design_system` | `github.com/davidmhuitt86/oep_design_system.git` | main | `b6c0fec` | No | Design system | `platform/oep_design_system` | DECISION REQUIRED (same reasoning) |
| oep_exchange | `C:\dev\platform\oep_exchange` | `github.com/davidmhuitt86/oep_exchange.git` | main | `c6dbb75` | No | OEP Exchange (OEX) distribution platform; README states integration is via published interfaces only | `platform/oep_exchange` | DECISION REQUIRED — repo's own docs describe it as independently developed |
| oep_reference | `C:\dev\platform\oep_reference` | `github.com/davidmhuitt86/oep_reference_library.git` (dir/remote name mismatch, pre-existing) | main | `88f56d0` | No | Engineering Reference Library (ERL) | `platform/oep_reference` (or rename to match remote — DECISION REQUIRED) | DECISION REQUIRED |
| legacy_wiring_sim_v2 | `C:\dev\platform\reference\legacy_wiring_sim_v2\eke-wiring-sim` | none — not a git repo | n/a | n/a | n/a (untracked, plain files) | Legacy/reference wiring simulator, explicitly REFERENCE/LEGACY, not production source | `reference/legacy_wiring_sim_v2` | YES (as reference material, file-copy style — see §13; no history to preserve because none exists) |
| oep_architecture | `C:\dev\platform\oep_architecture` | none — not a git repo | n/a | n/a | n/a | Architecture docs/templates | Possibly `specifications/` or `docs/` | DECISION REQUIRED |
| PLATFORM_CONSTITUTION | `C:\dev\platform\PLATFORM_CONSTITUTION` | none — not a git repo | n/a | n/a | n/a | `CLAUDE_PROJECT_RULES.md` | Possibly `docs/` | DECISION REQUIRED |
| OEP_SNAPSHOT / OEP_SNAPSHOT.zip | `C:\dev\platform\OEP_SNAPSHOT[.zip]` | none — not a git repo | n/a | n/a | n/a | Index/snapshot docs (architecture index, dependency graph, etc.) — appear to be a generated point-in-time export | Not proposed for migration | NO (recommend regenerating post-migration rather than carrying stale snapshot text forward; flagging for owner decision) |
| oep_design_system.zip | `C:\dev\platform\oep_design_system.zip` | none | n/a | n/a | n/a | Appears to be a stale zip export of the `oep_design_system` git repo | Not proposed | NO — redundant with the git repo itself |
| platform_docs | `C:\dev\platform\platform_docs` | none | n/a | n/a | n/a | Empty directory at time of inspection | n/a | NO — nothing to migrate |

## 5. Source repository status (detail)

For each repo: `git status --short`, branch, HEAD, tags.

- **oep_foundation** — branch `main`, up to date with `origin/main`, HEAD `51a1441...`, clean working tree (`git status --short` empty), no tags. **Note:** `git branch -a` also shows a second local branch `worktree-agent-a560bcb7977f8f129` (HEAD `e4ca02b`) checked out in a separate worktree at `C:\Users\david\OneDrive\Desktop\Projects\platform\oep_foundation\.claude\worktrees\agent-a560bcb7977f8f129`, marked `prunable` by `git worktree list`. This is unrelated leftover agent-session state, not part of this migration's scope; not touched.
- **oep_engine** — branch `main`, up to date, HEAD `3fa22c2...`, clean, no tags.
- **oep_studio** — branch `main`, up to date, HEAD `5922ce8...`, **one untracked file**: `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` (a Wave-2-discovery artifact from the separate, currently-paused AP-DIAGRAM-W2 task — not staged, not committed). No modified tracked files, nothing staged. No tags.
- **oep_instruments** — branch `main`, up to date, HEAD `25510a0...`, clean, no tags.
- **oep_acquisition** — branch `main`, up to date, HEAD `d062bb4...`, clean, no tags.
- **oep_design_system** — branch `main`, up to date, HEAD `b6c0fec...`, clean, no tags.
- **oep_exchange** — branch `main`, up to date, HEAD `c6dbb75...`, clean, no tags.
- **oep_reference** — branch `main`, up to date, HEAD `88f56d0...`, clean, no tags.

All seven git repos have exactly one local branch (`main`) tracking `origin/main`; none have additional feature branches or tags, except the incidental stale worktree branch on `oep_foundation` noted above.

## 6. Target repository status

- Path: `C:\dev\open_engineering_platform`
- Remote: `origin` → `https://github.com/davidmhuitt86/open_engineering_platform.git` (fetch + push)
- Branch: `main`, up to date with `origin/main`
- HEAD: `6d0b7df949436bcb03b213601574c3ff76905ab2`
- Working tree: clean (before this document was added)
- Existing commits: 1 (`6d0b7df` — message `"1"`, author `davidmhuitt86`, `2026-08-14 22:38:47 -0500`), adding `README.md`
- Existing files: only `README.md` (1 line, content `"1"`, no real content)
- Existing `.gitignore`: **none**
- Existing LICENSE: **none**
- Tags: none
- GitHub-created initial commit: the single existing commit looks like a manual placeholder commit (message `"1"`, one-line README), not an autogenerated GitHub "Initial commit" — worth confirming with the owner but not a blocker either way.
- Conflicts with proposed target structure: none currently — the repo is essentially empty, so there is nothing to collide with `platform/`, `reference/`, `specifications/`, `tools/`, or a real `README.md`. The placeholder `README.md` will need to be replaced/rewritten during Phase 2 (not deleted silently — flagged here for explicit handling).

## 7. Source HEAD commits

| Repo | HEAD |
|---|---|
| oep_foundation | `51a14411fe7945fa2ecf88f5674aa55fdcb0a1a5` |
| oep_engine | `3fa22c2cf281532fd2c49d72835128b29cb6425d` |
| oep_studio | `5922ce89e1c0ac5f1ae3cf2909a805b5c9aa7dec` |
| oep_instruments | `25510a0168b957b8050ae81f8ee0eb205635c481` |
| oep_acquisition | `d062bb4051162e3cd14d3b2d7795995649aeaf90` |
| oep_design_system | `b6c0fecc60d1c734a0bdff456b31657bfdb87ca3` |
| oep_exchange | `c6dbb752e0f1cbf2260460b87f38960c821a33b2` |
| oep_reference | `88f56d0a2492bb62a9b1a7dd9f79ab909ff12618` |

(Note: these hashes are 41 hex characters as printed by `git rev-parse HEAD` in this environment's shell — verify against `git cat-file -t` / `git log -1` output at execution time rather than assuming truncation; standard SHA-1 is 40 hex chars, so re-derive exact hashes immediately before any Phase 2 operation.)

## 8. Source remotes

| Repo | Remote URL |
|---|---|
| oep_foundation | `https://github.com/davidmhuitt86/oep_foundation.git` |
| oep_engine | `https://github.com/davidmhuitt86/oep_engine.git` |
| oep_studio | `https://github.com/davidmhuitt86/oep_studio.git` |
| oep_instruments | `https://github.com/davidmhuitt86/oep_instruments.git` |
| oep_acquisition | `https://github.com/davidmhuitt86/oep_acqusition.git` (note the typo "acqusition" — pre-existing on GitHub, not something to silently "fix" during migration without owner sign-off) |
| oep_design_system | `https://github.com/davidmhuitt86/oep_design_system.git` |
| oep_exchange | `https://github.com/davidmhuitt86/oep_exchange.git` |
| oep_reference | `https://github.com/davidmhuitt86/oep_reference_library.git` (dir is `oep_reference`, remote repo is `oep_reference_library` — pre-existing mismatch) |

## 9. Source branches

All 7 git repos: single local branch `main`, tracking `origin/main`, `origin/HEAD` symbolic ref points to `origin/main`. No other branches except the incidental `worktree-agent-a560bcb7977f8f129` branch on `oep_foundation` (§5), which is out of scope.

## 10. Source tags

None on any of the 7 source repositories.

## 11. Dirty working-tree inventory

| Repo | Modified tracked | Staged | Unstaged | Untracked | Branch | HEAD |
|---|---|---|---|---|---|---|
| oep_foundation | none | none | none | none | main | `51a1441` |
| oep_engine | none | none | none | none | main | `3fa22c2` |
| oep_studio | none | none | none | **1**: `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` | main | `5922ce8` |
| oep_instruments | none | none | none | none | main | `25510a0` |
| oep_acquisition | none | none | none | none | main | `d062bb4` |
| oep_design_system | none | none | none | none | main | `b6c0fec` |
| oep_exchange | none | none | none | none | main | `c6dbb75` |
| oep_reference | none | none | none | none | main | `88f56d0` |

**Problem this poses for the migration strategy:** `oep_studio` currently has one untracked file that is a working artifact of the separate, in-progress AP-DIAGRAM-W2 task (Wave 2 composition-root refactor of Diagram Studio). This file is not part of AP-REPO-001 and must not be committed, discarded, or silently carried across as part of a history-preserving migration operation (e.g. `git subtree`/`filter-repo` only operate on committed history — an untracked file would simply be left behind in the old working tree unless explicitly copied). **This is not solved in Phase 1** per the prompt's explicit instruction; it is recorded here so Phase 2 planning treats it as a known input. See §16 for the general dirty-work-preservation strategy this falls under.

No other repository has any dirty state. This significantly simplifies Phase 2: only `oep_studio` needs explicit dirty-work handling.

## 12. Target paths

| Source repo | Target path under `C:\dev\open_engineering_platform` |
|---|---|
| oep_foundation | `platform/oep_foundation/` |
| oep_engine | `platform/oep_engine/` |
| oep_studio | `platform/oep_studio/` |
| oep_instruments | `platform/oep_instruments/` (recommended — see §4) |
| oep_acquisition / oep_design_system / oep_exchange / oep_reference | `platform/<name>/`, pending owner scope decision (§4) |
| `reference/legacy_wiring_sim_v2/eke-wiring-sim` | `reference/legacy_wiring_sim_v2/` (flatten the extra `eke-wiring-sim` nesting level, or preserve it — DECISION REQUIRED, see §22) |
| `oep_architecture` | likely `specifications/` or `docs/architecture/` — DECISION REQUIRED |
| `PLATFORM_CONSTITUTION` | likely `docs/` — DECISION REQUIRED |

## 13. History-preservation strategy

**Selected mechanism: `git subtree add` (per source repo, into the target monorepo, run from the target repo).**

Rationale (§14 elaborates): `git subtree` was chosen over `git filter-repo` + merge and over a bare `git merge --allow-unrelated-histories` because:

- It imports full commit history for each source repo **rewritten under a path prefix** (`platform/oep_foundation/...` etc.) in a single, reviewable operation per repo, without requiring history rewriting of the *source* repositories themselves (source repos are never touched — critical given the "originals act as rollback source" requirement in §"Source Repositories After Migration").
- It does not require installing `git-filter-repo` (a separate tool not confirmed present in this environment) — `git subtree` ships with standard Git.
- It naturally supports "one command per source repo, add a remote, subtree add with `--prefix`," which maps cleanly onto this repo inventory (independent repos, no cross-repo path collisions expected under a `platform/<name>/` scheme, single branch each, no tags to preserve).
- `filter-repo` would be preferable if we needed to *rewrite* each source repo's history in place (e.g., to prune large binaries, restructure paths within the source before import) — nothing discovered in Phase 1 indicates that's needed. If large-blob history bloat is discovered in Phase 2 verification (`oep_foundation/.git` is already 594 MB — see §29 risk), `filter-repo` remains an option to reduce it, but that is a separate, explicit decision, not bundled into the base migration.
- Plain `git merge --allow-unrelated-histories` was rejected: it does not automatically rewrite paths under a prefix, so all repos' root-level files (README.md, CLAUDE.md, CMakeLists.txt, etc.) would collide on merge — exactly the "simple copy-and-commit" outcome the task prohibits.

### How each repository will be placed under its target prefix

Per source repo, from inside the (clean, up-to-date) target monorepo working tree:

```
git remote add <name>-src <local-path-to-source-repo>   # local path, not GitHub, for speed + no push risk
git fetch <name>-src
git subtree add --prefix=platform/<name> <name>-src main
```

This creates one merge commit per repo on the monorepo's `main`, whose parent includes the entire imported history rewritten under `platform/<name>/`. `git log --follow -- platform/oep_foundation/<file>` (or plain `git log -- platform/oep_foundation/`) will then recover original history.

`reference/legacy_wiring_sim_v2` has **no git history to preserve** (§2 — confirmed not a git repo), so it is migrated as a plain file copy + single commit, not via subtree. This is the one exception to "no simple copy-and-commit migration," and it's correct because there is no history to lose.

### Tags

No source repo has tags (§10). No tag-migration mechanics are required. If tags are added to any source repo before Phase 2 executes, re-verify this section before proceeding, since `git subtree add` does not automatically import tags.

### Non-default branches

No source repo has non-`main` branches besides the incidental stale `oep_foundation` worktree branch (§5, §9), which is explicitly out of scope and will not be imported. If that determination changes, it needs separate authorization.

### Remote strategy

Local-path remotes (`<name>-src` pointing at `C:\dev\platform\<name>`) will be added temporarily to the target repo for the `subtree add` operations, then removed after each import is verified (`git remote remove <name>-src`). No GitHub remote other than `origin` (the monorepo's own) is touched. Source repositories' own remotes are never modified (prohibited explicitly in the prompt).

### Dirty working-tree protection

`git subtree add` (and `git fetch`) only ever reads from the source repository's committed history — via its local `.git` object database — never its working tree. Fetching from a local path does not require a clean working tree in the source and does not stage, commit, stash, or discard anything there. This satisfies the "working trees are authoritative" constraint. The one exception, `oep_studio`'s untracked file, is not part of committed history and needs separate, explicit handling per §16 before or after the subtree import — never silently.

### Rollback

Because source repositories are never modified (no reset/clean/checkout/branch/remote changes), rollback is simple at every stage:
- **Before push:** if anything about the local monorepo import is wrong, the fix is to reset the monorepo's local `main` back to its pre-migration commit (`6d0b7df`) or delete and re-clone the monorepo from GitHub — the source repos are untouched and can be re-imported from scratch.
- **After push (not authorized in this phase):** would require a force-push or a revert strategy, decided explicitly with the owner at that time; not planned further here since push is out of scope for Phase 1 and likely Phase 2 as well per the prompt's sequencing.

## 14. Selected Git migration mechanism (summary)

`git subtree add --prefix=platform/<name> <local-remote> main`, once per source repository, run from within the target monorepo. See §13 for full rationale and mechanics.

## 15. Exact migration sequence (planned for Phase 2 — not executed)

1. Confirm all source repos are clean or their dirty state is explicitly resolved (currently only `oep_studio` has one untracked file — see §16).
2. In the target monorepo, replace the placeholder `README.md` content (own commit, owner-approved wording) — or defer this and do it after subtree imports, owner's choice.
3. Add `.gitignore` at the monorepo root appropriate for a mixed Dart/Flutter + C/C++ + docs monorepo (each source repo already has its own `.gitignore`; subtree-imported files keep working because `.gitignore` is evaluated per path at commit time in the target repo — but the target repo needs its own top-level `.gitignore` too, especially given `oep_foundation`'s 594 MB `.git` likely reflects large tracked/rebuilt artifacts worth double-checking are actually ignored).
4. For each of `oep_foundation`, `oep_engine`, `oep_studio` (and, pending owner decision, `oep_instruments`, `oep_acquisition`, `oep_design_system`, `oep_exchange`, `oep_reference`), run the `remote add` / `fetch` / `subtree add --prefix=platform/<name>` sequence from §13, verifying after each import that `git log -- platform/<name>/` shows the full imported history and that no unexpected root-level file collisions occurred.
5. Copy `reference/legacy_wiring_sim_v2/eke-wiring-sim/*` (or the resolved nesting — §22) into `reference/legacy_wiring_sim_v2/` in the monorepo as a plain file copy, single commit, clearly labeled REFERENCE/LEGACY in the commit message and ideally a short `reference/legacy_wiring_sim_v2/README.md` note.
6. Resolve `oep_studio`'s untracked file per the owner-selected option in §16, before or after step 4's `oep_studio` subtree import (order matters — document which was chosen and why at execution time).
7. Apply the dependency/path changes enumerated in §20.
8. Run build verification (§23) and test verification (§24) inside the monorepo's new `platform/oep_studio` (and `oep_engine`, `oep_foundation`) locations.
9. Run git-history verification (§25).
10. Present results to the owner for explicit approval before any push (§26 push is out of scope here regardless).

## 16. Dirty-work preservation strategy

Only `oep_studio` has dirty state (§11): one untracked file, `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md`, belonging to the separate AP-DIAGRAM-W2 task.

Per the task prompt's three options, the recommended approach is:

**Option C (migration of committed history, then controlled transfer of the dirty working-tree delta), not Option A.** Reasoning: the file is a work product of a *different, currently-paused* task (Diagram Studio Wave 2), not something that should be bundled into a "checkpoint commit" authored as part of a repository-migration task — mixing concerns in one commit would make history harder to audit later. Concretely, once `oep_studio`'s history has been subtree-imported into the monorepo:

- Copy `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` from the original `C:\dev\platform\oep_studio\` working tree into `platform/oep_studio/docs/` in the monorepo, as a plain file copy (not a git operation on the source repo).
- Whether to commit it immediately in the monorepo, or leave it untracked/unstaged pending the AP-DIAGRAM-W2 task's own continuation, is an explicit owner decision at Phase 2 time — not decided here.
- The **original file in `C:\dev\platform\oep_studio\` is left untouched** either way, since the source repos remain the rollback source until migration is independently verified.

If any *other* repo develops dirty state before Phase 2 executes, re-run the discovery in §5/§11 immediately before migrating that repo, and apply the same decision framework (owner picks A/B/C per repo, not a blanket policy) — do not assume Option C is universally correct without re-checking what the dirty content actually is (e.g. genuine mid-feature work would more plausibly warrant Option A, a deliberate checkpoint commit).

## 17. Tag migration strategy

Not applicable — no tags exist on any source repository (§10). No action planned.

## 18. Branch migration strategy

Not applicable beyond `main` — no non-default branches exist on any source repository apart from the out-of-scope stale worktree branch on `oep_foundation` (§5, §9), which will not be imported.

## 19. Remote strategy

- Source repositories' remotes are never modified (explicitly prohibited).
- Target monorepo's `origin` (`github.com/davidmhuitt86/open_engineering_platform.git`) is never modified in Phase 1 or the planned Phase 2 (no push planned).
- Temporary local-path remotes added to the target repo during subtree imports (`<name>-src`) are removed after each import is verified — see §13.

## 20. Dependency/path changes required

Discovered via direct inspection (§ references below point to source evidence found during discovery):

1. **`oep_studio/pubspec.yaml`** has two `path:` dependencies:
   - `engineering_engine: path: ../oep_engine`
   - `oep_instruments_runtime: path: ../oep_instruments/platform/oep_instruments`
   
   Both are relative to `oep_studio`'s own directory. Under the target layout `platform/oep_studio/`, `platform/oep_engine/`, and `platform/oep_instruments/`, the sibling relationship `../oep_engine` and `../oep_instruments/...` is **preserved automatically** — no pubspec edit needed, *provided* `oep_instruments` is included in the migration (§4 decision) and lands at `platform/oep_instruments/`. If `oep_instruments` is excluded from the monorepo, this path dependency breaks and must be repointed (e.g. to a published package or an out-of-tree path), which is a real architectural decision, not a mechanical fix — flagging, not solving.

2. **`oep_studio/native/foundation_bridge/CMakeLists.txt`** defaults `OEP_FOUNDATION_SOURCE_DIR` to `${CMAKE_CURRENT_SOURCE_DIR}/../../../oep_foundation`, with an explicit comment: *"place oep_studio and oep_foundation as sibling directories."* Under `platform/oep_studio/native/foundation_bridge/` and `platform/oep_foundation/`, the same three-levels-up-then-sibling relationship holds — **no CMake edit needed**, provided `oep_foundation` lands at `platform/oep_foundation/` (which it does, per §4/§12 — this one is not a decision, it's in the "at minimum" required set).

3. No `.github/` CI workflows were found in `oep_engine` or `oep_studio` that reference build paths (`oep_foundation` only has `CODEOWNERS`, `dependabot.yml`, `PULL_REQUEST_TEMPLATE.md` — no workflow YAML in any of the three). **No CI path changes identified** as required, but this should be re-verified once the monorepo needs its own CI, since none of the source repos' (nonexistent) workflows can simply be concatenated.

4. No absolute `C:\dev\platform` (or `C:/dev/platform`) path references were found in any tracked source file across the three core repos — the only hits were inside `build/` and `.dart_tool/` generated artifacts (both gitignored, regenerated on build, not tracked). **No source-level absolute-path fixes required.**

5. `oep_engine/lib/core/bridge/foundation_bridge_port.dart` references `oep_foundation` in a comment/identifier context (FFI bridge naming), not a build-time path — needs a read at Phase 2 time to confirm it doesn't hardcode a filesystem path, but nothing found in Phase 1 grep suggests it does.

6. Every repo's own `.gitignore`, `.git/`, and repo-relative doc links (e.g. `oep_exchange`'s README pointing at its own `docs/architecture/...`) remain valid as-is after a prefix move, since they're relative to each repo's own root, which becomes `platform/<name>/` — a straightforward prefix, not a restructuring of the repo's internal layout.

No other path/config dependencies were discovered. This list should be re-verified once the actual subtree imports happen, since generated build directories (currently gitignored, ~3.8 GB in `oep_foundation`, ~1.5 GB in `oep_engine`, ~1.6 GB in `oep_studio` before subtracting `.git` size) were not exhaustively searched file-by-file for hardcoded absolute paths beyond the `grep` performed in Phase 1.

## 21. Expected configuration changes (Phase 2, not yet made)

- `oep_studio/pubspec.yaml`: none, if `oep_instruments` is included (§20.1); otherwise a real repointing decision.
- `native/foundation_bridge/CMakeLists.txt`: none expected (§20.2).
- New top-level `.gitignore` and `README.md` for the monorepo itself (currently only a placeholder `README.md`, no `.gitignore` — §6).
- Possible root-level `CLAUDE.md`/project-rules consolidation if `PLATFORM_CONSTITUTION/CLAUDE_PROJECT_RULES.md` is migrated into `docs/` (§12) — an editorial decision, not assumed here.
- No Engine or Foundation API changes of any kind (explicitly out of scope and not needed based on discovery).

## 22. Potential file conflicts

- Every source repo has its own root-level `README.md`, `CLAUDE.md`/similar, `.gitignore`, and (for oep_foundation) `CMakeLists.txt`. Under `git subtree add --prefix=platform/<name>`, these land inside their own prefixed directory and **do not collide** with each other or with the monorepo's own root-level files. No conflicts expected from the subtree mechanism itself.
- The monorepo's own placeholder `README.md` (§6) does not collide with any subtree import (different path), but its *content* will need real authoring — flagged, not a blocker.
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/` nesting: the source path is `reference/legacy_wiring_sim_v2/eke-wiring-sim/{css,diagrams,docs,exports,index.html,js,tests}`. The target design says `reference/legacy_wiring_sim_v2/` directly. **DECISION REQUIRED:** keep the extra `eke-wiring-sim/` path segment (safer, zero risk of losing the original name/identity) or flatten it (matches the target tree literally as drawn in the prompt). Not resolved here — flagging for owner choice in Phase 2.
- `oep_reference` (dir name) vs. `oep_reference_library` (GitHub remote name) and `oep_acquisition` (dir name) vs. `oep_acqusition` (GitHub remote name, typo) — pre-existing naming mismatches unrelated to this migration; whichever name is used for the `platform/<name>/` target prefix should be an explicit owner choice, not silently inherited from either the local dir or the remote.
- `oep_design_system.zip` and `OEP_SNAPSHOT.zip`/`OEP_SNAPSHOT/` at `C:\dev\platform` root are not part of any proposed target path — no conflict, simply excluded (§4).

## 23. Build verification procedure (planned for Phase 2, not executed)

After subtree import and any required path fixes:
1. `flutter pub get` inside `platform/oep_studio/` — verify the `path:` deps to `oep_engine` and `oep_instruments` resolve.
2. `flutter pub get` inside `platform/oep_engine/`.
3. CMake configure + build of `platform/oep_studio/native/foundation_bridge/` (and the full Windows Flutter build) — verify `OEP_FOUNDATION_SOURCE_DIR` auto-resolves to `platform/oep_foundation/` and the smoke-test/`.def` export table story described in the CMakeLists comments still holds.
4. `oep_foundation`'s own top-level `CMakeLists.txt` build, unchanged, to confirm the move alone didn't break its self-contained build.

## 24. Test verification procedure (planned for Phase 2, not executed)

- Run `oep_foundation`'s existing test suite (as invoked today, path-adjusted only if its own scripts assumed `C:\dev\platform\oep_foundation` — none found in Phase 1 grep, see §20.4).
- Run `oep_engine`'s Dart test suite.
- Run `oep_studio`'s Flutter test suite, including whatever Diagram Studio Controller/workflow tests exist per the parallel AP-DIAGRAM-W2 task's own testing section — those tests are unaffected by this migration's scope (no source changes planned to Diagram Studio) but should still pass post-move as a sanity check that nothing broke.
- Compare pass/fail counts before (in `C:\dev\platform\...`) and after (in the monorepo) for each suite; any new failure blocks proceeding.

## 25. Git-history verification procedure (planned for Phase 2, not executed)

For each imported repo, after `subtree add`:
- `git log --oneline -- platform/<name>/` should show a commit count matching (or exceeding, due to the merge commit) the source repo's own `git log --oneline` count.
- Spot-check `git log -p --follow -- platform/oep_studio/pubspec.yaml` (or another frequently-changed file) recovers meaningful prior revisions, not just the single import commit.
- Confirm authorship/dates are preserved on the imported commits (subtree preserves original commit metadata; only a synthetic merge commit is new).
- Confirm `platform/oep_foundation/`, `platform/oep_engine/`, `platform/oep_studio/` (and any other imported repo) each independently satisfy the above before considering the migration verified.

## 26. Rollback procedure

See §13 "Rollback" — summarized: source repositories are never modified, so at any point before a GitHub push, rollback is either resetting the monorepo's local `main` to its pre-migration commit, or discarding the local monorepo clone and re-cloning from `origin` (which still only has the single placeholder commit `6d0b7df` unless/until Phase 2 pushes). Push itself remains unauthorized and out of scope for both Phase 1 and this plan's proposed Phase 2 sequence, which ends at "owner approval" (§ Sequence step 10) before any push.

## 27. Post-migration source-repository disposition

Per the task prompt's explicit sequencing, the original repositories under `C:\dev\platform\` are **not deleted** as part of the initial migration. They remain in place as the rollback source through: history import → dirty-work transfer → dependency fixes → build/test → git-history verification → local approval → push → GitHub-remote verification. Only *after* all of that is independently verified does the question of archiving/removing the old local clones become a separate, later, explicitly-authorized decision — not addressed further here.

## 28. Claude Code workspace configuration

Not yet addressed in Phase 1 beyond this observation: once the monorepo exists with real content under `platform/oep_studio/`, `platform/oep_engine/`, `platform/oep_foundation/`, any `.claude/` project-level configuration (settings, CLAUDE.md, hooks) currently scoped to the individual `C:\dev\platform\oep_*` working directories will need an explicit decision about whether/how it's consolidated at the monorepo root vs. kept per-subdirectory. Also note: `oep_foundation` currently has a stray Claude-Code worktree artifact at `C:\Users\david\OneDrive\Desktop\Projects\platform\oep_foundation\.claude\worktrees\agent-a560bcb7977f8f129` (§5) — unrelated to this migration, but worth the owner's awareness since it's a `prunable` git worktree outside the normal repo path entirely (on OneDrive, not under `C:\dev\platform`). Not touched, not resolved here.

## 29. Known risks

1. **`oep_foundation/.git` is 594 MB** while `oep_engine/.git` is 1.6 MB and `oep_studio/.git` is 28 MB — a large disparity. This may indicate large binaries or generated artifacts committed to history at some point. Importing it via `subtree add` brings that full `.git` history weight into the monorepo. Worth a deliberate look (e.g. `git count-objects -v` / largest-blob scan) before Phase 2, since `filter-repo`-based history trimming (mentioned as an alternative in §13) might be worth doing *before* import rather than after, if this repo is the primary offender for future monorepo `.git` size.
2. **Naming mismatches** between local directory names and GitHub remote repo names (`oep_acquisition`/`oep_acqusition`, `oep_reference`/`oep_reference_library`) create ambiguity about what the canonical `platform/<name>/` prefix should be called — needs an explicit owner decision, not an assumption in either direction.
3. **Scope ambiguity** on which of the 5 non-core repos (`oep_instruments`, `oep_acquisition`, `oep_design_system`, `oep_exchange`, `oep_reference`) belong in this monorepo at all — `oep_instruments` is functionally required by `oep_studio`'s build if the sibling-path scheme is kept, the other four are OEP-owned but architecturally independent per their own READMEs. Migrating the "wrong" scope now is expensive to unwind later given the history-import approach.
4. **`oep_studio`'s untracked file** (§11, §16) is a live cross-task dependency risk: if AP-DIAGRAM-W2 (Diagram Studio Wave 2, currently paused between Stage 1 boundary-doc and code-moving stages) resumes and produces more uncommitted work in `C:\dev\platform\oep_studio` before this migration's Phase 2 executes, the dirty-work inventory in this document will be stale and must be re-run immediately before migrating `oep_studio`.
5. **`reference/legacy_wiring_sim_v2` has no git history** — migrating it as a plain file copy is correct given no history exists, but means its *pre-repo* history (if any existed before landing at `C:\dev\platform\reference\...`) is not recoverable through this process; if such history matters, it needs to be sourced separately before Phase 2, not invented after the fact.
6. **No CI workflows exist yet** in any of the three core repos — the monorepo will need CI designed fresh rather than merged from existing workflows; not a blocker, but worth scoping into whichever phase handles "Claude Code workspace configuration" / general tooling (§28), since none of that was discovered as pre-existing.
7. Repo working-tree sizes (3.8 GB / 1.5 GB / 1.6 GB inclusive of build artifacts) mean local disk headroom at `C:\dev\open_engineering_platform` should be checked before Phase 2 — importing `.git` history (§29.1) plus fresh `flutter pub get`/CMake build output in the new location could require several more GB.

## 30. Explicit stop conditions

Phase 1 stops here. The following remain **unauthorized** until AP-REPO-002 (or equivalent) is explicitly granted:

- Adding remotes to, fetching into, or running `git subtree add` against the target monorepo.
- Any copy or move of files from `C:\dev\platform\...` into `C:\dev\open_engineering_platform\...`.
- Any commit in the target monorepo beyond this planning document.
- Any push to `github.com/davidmhuitt86/open_engineering_platform`.
- Resolving the five "DECISION REQUIRED" scope questions in §4/§12/§22 without owner input.
- Touching `oep_studio`'s untracked file in any way (commit, discard, or even copy) — recorded only, not acted on.
- Continuing AP-DIAGRAM-W2 (Diagram Studio Wave 2) as part of this task — that task remains separately paused at "Stage 1 boundary doc complete, code-moving stages not started," and is unaffected by this discovery.
- Any modification to `oep_engine` or `oep_foundation` source, or to their public APIs.
- Any modification to any source repository's branches or remotes.

---

*Generated during Phase 1 (read-only discovery) of AP-REPO-001. No migration was executed.*
