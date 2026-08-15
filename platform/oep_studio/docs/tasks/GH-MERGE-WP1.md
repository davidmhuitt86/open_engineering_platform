TASK: AP-REPO-002 — Execute Open Engineering Platform Monorepo Migration

STATUS

PHASE 1 DISCOVERY: COMPLETE
PHASE 2 MIGRATION: AUTHORIZED

You have completed the read-only discovery and produced:

docs/MONOREPO_MIGRATION_PLAN.md

The discovery has been reviewed and the migration is now authorized.

============================================================
TARGET MONOREPO
============================================================

Local root:

C:\dev\open_engineering_platform

GitHub remote:

https://github.com/davidmhuitt86/open_engineering_platform.git

This repository is now the canonical Open Engineering Platform
monorepo.

The existing source repositories remain at:

C:\dev\platform\oep_foundation
C:\dev\platform\oep_engine
C:\dev\platform\oep_studio
C:\dev\platform\oep_instruments

Do NOT modify or delete those source repositories.

============================================================
APPROVED MIGRATION SCOPE
============================================================

MIGRATE:

1. oep_foundation
2. oep_engine
3. oep_instruments
4. oep_studio
5. legacy_wiring_sim_v2

DO NOT MIGRATE:

- oep_acquisition
- oep_design_system
- oep_exchange
- oep_reference

The four deferred repositories remain independent repositories for now.

They may be incorporated into the monorepo later through a separate
migration decision.

============================================================
TARGET STRUCTURE
============================================================

The final monorepo structure should be:

C:\dev\open_engineering_platform\
│
├── .git\
│
├── platform\
│   ├── oep_foundation\
│   ├── oep_engine\
│   ├── oep_instruments\
│   └── oep_studio\
│
├── reference\
│   └── legacy_wiring_sim_v2\
│
├── docs\
├── specifications\
├── tools\
└── README.md

Preserve the internal structure of each project.

This is a repository migration, NOT an application restructuring.

============================================================
CRITICAL SOURCE REPOSITORY SAFETY
============================================================

The source repositories are the rollback copies.

DO NOT modify:

C:\dev\platform\oep_foundation
C:\dev\platform\oep_engine
C:\dev\platform\oep_instruments
C:\dev\platform\oep_studio

Do NOT:

- reset
- clean
- restore
- checkout
- commit
- stash
- rebase
- rewrite history
- delete files
- delete .git directories
- modify source files

The source repositories must remain untouched.

============================================================
KNOWN UNCOMMITTED STUDIO FILE
============================================================

The only known source working-tree change is:

C:\dev\platform\oep_studio\docs\DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md

This file is untracked and belongs to the paused Diagram Studio
Wave 2 work.

It MUST NOT be committed to the original oep_studio repository.

After the Studio Git history has been imported into the monorepo,
explicitly copy this file into:

C:\dev\open_engineering_platform\
platform\oep_studio\docs\DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md

Verify that its contents are byte-for-byte identical to the original.

============================================================
GIT HISTORY REQUIREMENT
============================================================

Preserve the existing Git history of all four Git repositories.

The migration must NOT become a single flattened initial commit.

The approved migration mechanism is:

git subtree

Use:

git subtree add --prefix=<target-path> <source> <branch>

or the equivalent safe local form.

Use the source repository's current main branch/history identified during
Phase 1.

Do NOT use git filter-repo.

Do NOT rewrite source histories.

Do NOT squash imported histories.

The original commits must remain inspectable inside the monorepo.

============================================================
TARGET REPOSITORY INITIAL COMMIT
============================================================

The new monorepo currently contains:

HEAD:
6d0b7df

Commit:

"1"

with the placeholder README.

Preserve this commit.

Import the source histories on top of it.

Do not reset the monorepo to an imported repository's root commit.

============================================================
STEP 1 — FINAL SAFETY CHECK
============================================================

Before beginning migration, verify that the repositories have not
changed since Phase 1.

For the target:

git status --short
git branch --show-current
git rev-parse HEAD
git remote -v

For each source repository:

git status --short
git branch --show-current
git rev-parse HEAD
git remote -v

Expected:

- target remains at the discovered initial commit
- oep_foundation remains clean
- oep_engine remains clean
- oep_instruments remains clean
- oep_studio has only the known untracked
  DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md

If anything differs unexpectedly:

STOP and report the discrepancy.

============================================================
STEP 2 — FOUNDATION 594 MB GIT INVESTIGATION
============================================================

Before importing oep_foundation, investigate the approximately 594 MB
.git directory.

Run appropriate read-only diagnostics such as:

git count-objects -vH

and inspect packed objects / historical blobs as necessary.

Determine:

- total object size
- pack size
- largest historical blobs
- whether Git LFS is involved
- whether generated/build artifacts exist in history
- whether any historical file exceeds GitHub's normal file-size limits
- whether the repository contains anything likely to prevent a normal
  GitHub push

DO NOT rewrite Foundation history.

DO NOT remove historical objects.

If there is a genuine GitHub-blocking object, STOP and report it before
performing the import.

If the history is safe to import, continue.

============================================================
STEP 3 — IMPORT FOUNDATION
============================================================

Import:

C:\dev\platform\oep_foundation

to:

platform/oep_foundation

using git subtree.

Preserve the complete source history.

After import verify:

git log --oneline -- platform/oep_foundation

Confirm the source Foundation HEAD is represented.

Do not modify the source repository.

============================================================
STEP 4 — IMPORT ENGINE
============================================================

Import:

C:\dev\platform\oep_engine

to:

platform/oep_engine

using git subtree.

Verify:

git log --oneline -- platform/oep_engine

Confirm the source Engine HEAD is represented.

Do not modify the source repository.

============================================================
STEP 5 — IMPORT INSTRUMENTS
============================================================

Import:

C:\dev\platform\oep_instruments

to:

platform/oep_instruments

using git subtree.

This repository is explicitly included because oep_studio has a sibling
path dependency on it.

Verify:

git log --oneline -- platform/oep_instruments

Confirm the source Instruments HEAD is represented.

Do not redesign or alter its relationship with Studio.

============================================================
STEP 6 — IMPORT STUDIO
============================================================

Import:

C:\dev\platform\oep_studio

to:

platform/oep_studio

using git subtree.

Preserve its committed Git history.

Verify:

git log --oneline -- platform/oep_studio

Confirm the source Studio HEAD is represented.

DO NOT commit the known untracked Composition Boundary file to the
source repository.

After the subtree import, copy:

C:\dev\platform\oep_studio\docs\DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md

to:

C:\dev\open_engineering_platform\
platform\oep_studio\docs\DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md

Verify the copied file is identical.

============================================================
STEP 7 — IMPORT V2 REFERENCE
============================================================

The legacy V2 source was discovered at:

reference/legacy_wiring_sim_v2/eke-wiring-sim/

It is NOT a Git repository.

Place the V2 source under:

reference/legacy_wiring_sim_v2/

Preserve its existing internal structure.

Do NOT flatten the extra:

eke-wiring-sim/

directory unless the migration plan explicitly requires it.

Do NOT modify the V2 implementation.

Do NOT initialize a Git repository inside it.

It remains:

REFERENCE / LEGACY

and is not production OEP code.

============================================================
STEP 8 — DOCUMENTS
============================================================

Preserve the authoritative Diagram Studio documents.

At minimum verify that the monorepo contains:

DIAGRAM_STUDIO_RECONSTRUCTION_AUDIT.md

DIAGRAM_STUDIO_V2_RECONSTRUCTION_SPEC.md

DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md

Do not create duplicate authoritative copies.

The first two should come from the committed Studio history.

The Composition Boundary document comes from the known untracked source
file and must be copied explicitly as described above.

============================================================
STEP 9 — DEPENDENCY VERIFICATION
============================================================

The Phase 1 analysis determined that the existing relative dependency
paths should remain valid because the projects retain equivalent
relative depth under:

platform/

Verify this.

Specifically verify:

oep_studio
    ↓
oep_engine

oep_studio
    ↓
oep_foundation

oep_studio
    ↓
oep_instruments

Also verify:

- pubspec path dependencies
- CMake Foundation source path
- relevant Flutter/Dart paths
- build scripts
- test scripts

Do NOT redesign package architecture.

If a path is genuinely broken because of the repository move, make only
the minimum path/configuration correction required.

Document every such change.

============================================================
STEP 10 — NESTED GIT REPOSITORIES
============================================================

After each subtree import has been successfully verified, inspect the
migrated project directory.

The final monorepo must have:

C:\dev\open_engineering_platform\.git

as its only authoritative Git repository.

There must NOT be nested .git directories inside:

platform/oep_foundation
platform/oep_engine
platform/oep_instruments
platform/oep_studio

or inside the V2 reference.

DO NOT remove a nested .git directory until its corresponding history
has been successfully imported and verified.

The original repositories under C:\dev\platform\ remain untouched and
serve as rollback copies.

============================================================
STEP 11 — FILE INTEGRITY
============================================================

Verify that the migration did not lose files.

For each imported Git repository compare the source tracked-file
inventory against the corresponding monorepo subtree:

oep_foundation
oep_engine
oep_instruments
oep_studio

The known untracked Composition Boundary file must also be verified
against its source copy.

Verify the V2 reference tree exists.

If anything is missing:

STOP and investigate before committing.

============================================================
STEP 12 — HISTORY VERIFICATION
============================================================

Verify all four imported Git histories.

Run appropriate history checks such as:

git log --oneline -- platform/oep_foundation
git log --oneline -- platform/oep_engine
git log --oneline -- platform/oep_instruments
git log --oneline -- platform/oep_studio

Verify:

- source HEAD commits are present
- historical commits remain inspectable
- imported histories were not squashed
- source history remains attributable to the imported project

Do not claim history preservation without verifying it.

============================================================
STEP 13 — BUILD VERIFICATION
============================================================

From the new monorepo, verify the existing platform build chain.

At minimum verify:

1. oep_foundation
2. oep_engine
3. oep_instruments
4. oep_studio

Use the existing project build/test procedures.

Do NOT introduce a new build system.

Do NOT refactor code to make builds pass.

If a failure is pre-existing, document it.

If a failure is caused by the migration, make only the minimum
repository-path/configuration correction required.

============================================================
STEP 14 — TEST VERIFICATION
============================================================

Run the relevant existing tests.

For Studio, include the current Diagram Studio tests/workflow tests.

Do NOT use this migration to fix:

- Property Inspector issues
- Wave 2 issues
- V2 parity issues
- routing issues
- interaction-state issues
- existing correctness ambiguities

Separate pre-existing failures from migration failures.

============================================================
STEP 15 — FINAL WORKING TREE REVIEW
============================================================

Before committing the monorepo migration, run:

git status
git diff --stat
git diff --name-status

Verify that every change is expected.

Verify:

- no source repository was modified
- no uncommitted Studio work was lost
- the Composition Boundary file is present
- V2 is present
- all four projects are present
- no unexpected files were introduced
- no files were silently deleted

============================================================
STEP 16 — MONOREPO MIGRATION COMMIT
============================================================

After all migration, history, file-integrity, dependency, build, and test
verification succeeds, create ONE migration commit for the monorepo
changes.

Use:

Establish OEP platform monorepo

Do NOT squash the imported source histories.

The subtree histories must remain part of the repository history.

============================================================
STEP 17 — DO NOT PUSH
============================================================

DO NOT run:

git push

The migration must be reviewed locally first.

The GitHub repository must remain untouched beyond its existing
placeholder commit.

STOP after the local migration commit and verification.

============================================================
ABSOLUTE PROHIBITIONS
============================================================

This task must NOT:

- modify source repositories
- commit to source repositories
- delete source repositories
- archive source GitHub repositories
- rewrite source Git history
- use git filter-repo
- change Engine architecture
- change Foundation architecture
- change Studio architecture
- continue Diagram Studio Wave 2
- begin V2 reconstruction
- modify V2
- migrate deferred repositories
- fix unrelated bugs
- redesign dependencies

============================================================
FINAL COMPLETION REPORT
============================================================

Report:

1. Final monorepo structure.
2. Foundation Git-size investigation.
3. Foundation migration result.
4. Engine migration result.
5. Instruments migration result.
6. Studio migration result.
7. V2 reference migration result.
8. Composition Boundary file transfer result.
9. Git history verification for each imported repository.
10. Source HEAD verification for each imported repository.
11. File-integrity verification.
12. Dependency/path verification.
13. Any path/configuration changes made.
14. Build results.
15. Test results.
16. Nested Git repository status.
17. Source repository status proving they were untouched.
18. Confirmation uncommitted Studio work was preserved.
19. Monorepo migration commit hash.
20. Final monorepo git status.
21. Confirmation NOTHING was pushed to GitHub.
22. Any remaining risks or blockers.

============================================================
FINAL STOP CONDITION
============================================================

After the local migration commit and verification:

STOP.

Do not push.

Do not begin Diagram Studio Wave 2.

Do not migrate the deferred repositories.

Do not perform any additional cleanup or refactoring.

Await further authorization.