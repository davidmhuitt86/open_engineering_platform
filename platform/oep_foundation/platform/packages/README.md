# Packages

Status: Foundation (Package System Foundation)

Purpose: Discovery, loading, and validation of packages under a repository's `packages/` directory, per OEP-SPEC-010-PACKAGE_SYSTEM. Packages are the mechanism by which OEP is extended without modifying Foundation.

This module was not pre-scaffolded in the frozen architecture; it is added here because the spec describes a distinct Foundation subsystem ("Foundation shall expose a Package Manager") rather than a capability of an existing module.

## Architecture

- `include/oep/packages/package_manifest.hpp` — public `PackageManifest` model, `PackageType`, and `validate_package_manifest`
- `include/oep/packages/package_manager.hpp` — public `PackageManager` (`discover_packages` / `load_package` / `list_packages`), `PackageState`, and `DiscoveredPackage`
- `src/package_manifest.cpp`, `src/package_manager.cpp` — manifest parsing (reusing `platform/repository`'s JSON parser), validation, and Foundation-version compatibility

Package installation, an online registry, updates, and dependency resolution are explicitly out of scope for this module and are deferred to future specifications.
