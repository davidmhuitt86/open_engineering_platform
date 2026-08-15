# Archive

Status: Foundation (Repository Export/Import, Repository Templates)

Purpose: Distributes, reconstructs, and packages Foundation Repository content, per OEP-SPEC-017-REPOSITORY_EXPORT, OEP-SPEC-018-REPOSITORY_IMPORT, and OEP-SPEC-019-REPOSITORY_TEMPLATES. Archive does not alter Repository integrity — it only reads (export, template creation) or writes through the same validated store operations everything else uses (import, template instantiation).

**Renamed from `platform/exchange` in WP-REP-002**, per the terminology ratified in OEP-ARCH-002-REPOSITORY_RUNTIME_ASSESSMENT.md §0: this module has never had anything to do with the `oep_exchange` Engineering Exchange marketplace — it captures/restores/templates a Foundation Repository as a deterministic JSON document. "Archive" is what it does. The rename touched only the directory, the `oep::archive` C++ namespace, and this module's own includes/CMake target (`oep_archive`) — nothing public (CLI command names, spec titles) changed, since OEP-SPEC-017/018/019 were already correctly named.

## Architecture

- `include/oep/archive/export_manifest.hpp` — public `ExportManifest` and `validate_export_manifest`; `kSupportedExportVersion` is the archive format version this build produces and accepts
- `include/oep/archive/repository_exporter.hpp` — public `export_repository`: gathers data exclusively through `ObjectStore::list_all` / `RelationshipStore::list_all` / `AuditStore::list_events` / `PackageManager::list_packages`, never reading repository files directly
- `include/oep/archive/repository_importer.hpp` — public `import_repository`: validates the entire archive before writing anything, then restores content via `ObjectStore`/`RelationshipStore`/`AuditStore`'s `restore` operations (preserving original IDs and timestamps exactly)
- `include/oep/archive/template_manifest.hpp` — public `TemplateManifest` and `validate_template_manifest`
- `include/oep/archive/repository_template.hpp` — public `TemplateStore` (`create_template` / `list_templates` / `instantiate_template`), reusing the same archive codec Export/Import use — a template is a named, reusable archive with its own manifest, not a second file format
- `src/archive_codec.hpp`/`.cpp` — internal (not public) JSON marshaling shared by the archive document and the template document, independent of each store's own on-disk file schema
- `src/export_manifest.cpp`, `src/repository_exporter.cpp`, `src/repository_importer.cpp`, `src/template_manifest.cpp`, `src/repository_template.cpp` — implementation

The export archive (and, similarly, a template) is a single deterministic JSON document (not a compressed/binary container), containing metadata/manifest information, every Engineering Object, every Relationship, and — where applicable — the Audit Log and/or package manifests. This avoids an external archive/compression library dependency while still satisfying "a single archive containing" the required sections. This document format is unrelated to the `.oep` ZIP package format `platform/installer` reads — see that module's README and OEP-ARCH-002 §0 for the full terminology map.

Consumed by `platform/runtime`'s `FoundationRuntime::export_repository`/`import_repository`/`create_template`/`list_templates`/`instantiate_template`, which are in turn the only way `platform/cli`'s `export`/`import`/`template` commands touch repository content — Archive, like every other subsystem, is reached exclusively through the Runtime.
