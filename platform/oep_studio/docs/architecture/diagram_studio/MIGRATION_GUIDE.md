# Diagram Studio — Migration Guide (Legacy Local JSON → Engineering Repository)

**Architecture Phase:** AP-DS-002

## What migrates

A legacy Diagram Studio document — the local JSON file `DiagramDocument.saveAs` wrote prior to AP-DS-002, shaped `{schemaVersion, documentId, graph, layout, metadata}` — into a repository-backed Project + Diagram, using the mapping documented in `ENGINEERING_MAPPING.md`.

## How to migrate a document

Programmatically, via `DiagramRepositoryService.migrate(legacyFilePath)` (implements the `LegacyMigrator` interface in `lib/diagram_studio/migration/legacy_migration_models.dart`). In the UI, via the "Migrate to Repository…" action (`LegacyMigrationDialog`, `lib/diagram_studio/migration/legacy_migration_dialog.dart`), reachable from the document bar per the integration spec documented in `IMPLEMENTATION_STATUS.md`'s AP-DS-002 section.

## What migration does, step by step

1. Reads and parses the legacy JSON file.
2. Creates a Project Engineering Object (title derived from the document's metadata, or the filename if none).
3. Calls `saveDiagram`, which creates the Diagram Engineering Object (content = the graph+layout snapshot) and decomposes every node/wire into Component objects/`ConnectedTo` Relationships — all wrapped in `saveDiagram`'s own transaction.
4. **Verification**: reloads the just-migrated diagram and compares node/relationship counts against the source graph. A mismatch is treated as failure, not a warning — per the spec's explicit "Verification" requirement, success is never assumed from the write path alone.
5. Returns a `LegacyMigrationResult` with a per-item description of what was converted (every node, every wire, the project, the diagram) — shown in full in the migration dialog, not collapsed into a generic "success" toast.

## Error handling and rollback — read this before relying on migration for irreplaceable documents

- Each of `createProject` and `saveDiagram` wraps **itself** in a Foundation transaction (`beginTransaction`/`commitTransaction`/`rollbackTransaction`) — if either fails partway through its own multi-step sequence, that step's own partial work is rolled back automatically.
- **`migrate` does NOT wrap its overall multi-step sequence (project creation + diagram save) in one outer transaction.** If `createProject` succeeds but the subsequent `saveDiagram` call fails, the created Project object remains in the repository even though `migrate` reports overall failure. This is a known, disclosed limitation — not a silent gap. `LegacyMigrationResult.rolledBack` reflects whether the *last attempted step's own* work was rolled back, not whether every step across the whole migration was undone.
- **The original legacy JSON file is never modified or deleted by migration** — regardless of success or failure, the source file remains exactly as it was. Migration is additive/copy-semantics, never destructive to the source. This means a failed or partially-successful migration can always be safely retried from the same source file.
- On verification failure (step 4 above), the diagram and project objects that were created remain in the repository — the same "no outer-transaction" limitation applies. A future phase should close this gap by wrapping `migrate`'s full sequence in one explicit transaction (a small, well-scoped change to `DiagramRepositoryService.migrate`, not attempted in this pass to keep `saveDiagram`/`createProject` independently reusable outside a migration context without forcing every caller to manage an outer transaction).

## What does NOT migrate

- **Autosave/recovery files** (AP-DS-001A's separate local recovery mechanism) are untouched by migration — they remain local-JSON, by design, since recovery is about surviving a crash before the next explicit save, not about the document's primary storage format.
- **Nothing is deleted.** Migration is purely additive — it creates new repository-backed objects; it never deletes or modifies the source legacy file.

## Testing

`DiagramRepositoryService` (and therefore `migrate`) cannot be exercised under `flutter test` — like every `FoundationBridge` consumer in this codebase, it requires the native `oep_foundation_bridge.dll`, which the test environment does not load (confirmed: no test anywhere in this suite constructs a real `FoundationBridge`). What IS tested under `flutter test`: the pure-Dart content-envelope serialization logic `saveDiagram`/`loadDiagram` depend on (`test/diagram_repository_service_content_test.dart`) and the migration UI's presentation of success/failure/rollback (`test/legacy_migration_dialog_test.dart`, using a fake `LegacyMigrator`). End-to-end verification of `migrate` against a real repository requires a live `flutter run`/manual test pass — noted as a real, disclosed test-coverage gap for a future phase to close (e.g. via an integration-test harness that can load the real DLL, which does not exist anywhere in this codebase today).
