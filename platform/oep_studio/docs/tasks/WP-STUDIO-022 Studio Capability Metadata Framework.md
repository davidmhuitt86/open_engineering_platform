# WP-STUDIO-022 — Studio Capability Metadata Framework

Repository: `projects/platform/oep_studio`

## 1. Objective

Extend the Studio Registry implemented in WP-STUDIO-021 with capability metadata. Capability metadata belongs to the owning Studio — no separate Capability Registry is introduced; the Studio Registry remains the Platform's single source of truth. Purely declarative: no Event Bus, no command execution, no plugins, no dynamic loading. Complete backwards compatibility with WP-STUDIO-021.

## 2. Review of WP-STUDIO-021

WP-STUDIO-021 produced `StudioRegistry`/`StudioDescriptor` (`lib/core/routing/studio_registry.dart`) as the authoritative source for Navigation, Routing, Search Providers, and Settings Providers, seeded with 13 `StudioDescriptor`s (one per `StudioDestination`), of which only `knowledge`, `diagram`, and `acquisition` carry a `settingsProvider`/`searchProvider` — the other 10 are core Platform pages with no Studio-specific contribution. This Work Package extends that same descriptor shape rather than introducing a parallel structure, consistent with the objective's explicit instruction not to create a separate registry.

## 3. Updated Studio Registry Architecture

`StudioDescriptor` gains one new optional field, `capabilities: List<CapabilityDescriptor>` (default `const []`), fully backwards compatible — every existing call site that constructs a `StudioDescriptor` without `capabilities` continues to compile and behave identically. `StudioRegistry` gains four read-only query methods and one validation method, all operating over the existing `_descriptors` list; no new class holds a duplicate index of capabilities separate from the descriptors themselves.

## 4. CapabilityDescriptor Model

```dart
class CapabilityDescriptor {
  const CapabilityDescriptor({required this.id, required this.label, required this.description});
  final String id;          // globally unique, e.g. "knowledge.review"
  final String label;       // short human-readable name
  final String description; // one sentence describing what it does today
}
```

Purely declarative — three `String` fields, no callback, no handler, nothing executable. It describes a capability; it does not provide one.

## 5. Extended StudioDescriptor

```dart
class StudioDescriptor {
  const StudioDescriptor({
    required this.destination,
    required this.pageBuilder,
    this.settingsProvider,
    this.searchProvider,
    this.capabilities = const [],
  });
  // ...
  final List<CapabilityDescriptor> capabilities;
}
```

## 6. Capability Registrations

Metadata was written to describe functionality that already exists in each Studio today — verified by inspecting each Studio's own source tree before writing descriptions, not invented:

**Knowledge Studio** (`lib/knowledge/`): `knowledge.sourceIngestion` (OCR pipeline/source viewer), `knowledge.aiAssistance` (AI provider registry, suggestion parsing), `knowledge.evidence` (evidence link/provenance service), `knowledge.review` (candidate review panel, commit plan/transaction service).

**Diagram Studio** (`lib/diagram_studio/`): `diagram.editing` (engine host, node/relationship/port/group inspectors), `diagram.layersAndAnnotations` (layer panel, annotation panel), `diagram.validation` (validation panel), `diagram.aiAssistance` (diagram AI service).

**Engineering Acquisition Studio** (`lib/acquisition/`, WP-PLAT-020): `acquisition.sourceManagement`, `acquisition.jobOrchestration`, `acquisition.integrityPipeline` (download/verify/metadata), `acquisition.vaultPublishing`.

The other 10 core Platform destinations (Dashboard, Project Explorer, Repository, Objects, Relationships, Search, Graph, Validation, Packages, Settings) were left with the default empty `capabilities` list — they are Platform pages, not Studios, matching the same distinction WP-STUDIO-021 already drew for `settingsProvider`/`searchProvider`.

## 7. Registry Query APIs

| Method | Purpose |
|---|---|
| `capabilitiesFor(StudioDestination)` | A Studio's own capability list, or `[]` |
| `allCapabilities` | Every capability, flattened, in registration order |
| `findCapability(String id)` | Resolve one capability by id, or `null` |
| `ownerOf(String id)` | The `StudioDestination` that registered a given capability id, or `null` |
| `validateCapabilities()` | Consistency check (§8) — returns human-readable issues, empty when clean |

## 8. Validation

`validateCapabilities()` checks, across every registered descriptor: blank `id`, blank `label`, blank `description`, and — the one cross-Studio rule — a capability `id` registered by more than one Studio (ids must be globally unique so `findCapability`/`ownerOf` are unambiguous). It never throws; it returns a list of problem descriptions for a caller (a test, or a future startup check) to act on.

## 9. Validation Tests

New file: `test/studio_registry_test.dart`, 11 tests:
- `StudioRegistry.defaultRegistry.validateCapabilities()` is empty (the real seeded data is consistent).
- Knowledge/Diagram/Acquisition each have capabilities; a core page (Dashboard, Settings) has none.
- `allCapabilities` flattens in registration order (Knowledge before Diagram before Acquisition).
- `findCapability`/`ownerOf` resolve known ids and return `null` for unknown ones.
- Every registered capability id is unique.
- Four tests against deliberately-broken fake registries (built via the public `StudioRegistry([...])` constructor): a blank id, a blank label, a blank description, and a duplicated id across two Studios — each confirmed to produce a non-empty `validateCapabilities()` result; a registry with no capabilities at all is confirmed trivially valid.

**Test results**: `flutter analyze` — 0 issues in any changed file (2 pre-existing, unrelated informational lints elsewhere, untouched). `flutter test` — **328/328 passed** (317 prior + 11 new; 2 pre-existing unrelated skips), confirming zero behavior change to WP-STUDIO-021's routing/nav/settings/search behavior. `flutter build windows` — succeeded.

## 10. Recommendations for WP-STUDIO-023

- **Consuming this metadata**: nothing in the app reads `capabilities`/`allCapabilities` yet — this Work Package deliberately stops at declarative metadata plus query/validation APIs. A future Command Palette (still Category C per WP-PLAT-020's Outstanding Issues) is the natural first consumer: it would enumerate `StudioRegistry.defaultRegistry.allCapabilities` for display, but actually *executing* one remains explicitly out of scope until an Event Bus/Command execution model exists.
- **Startup validation**: consider calling `StudioRegistry.defaultRegistry.validateCapabilities()` once at app startup (e.g. an assertion in debug builds) so a future capability registration mistake fails fast instead of only being caught by `studio_registry_test.dart`.
- **Naming convention enforcement**: `id`'s `<studio>.<capability>` shape is documented as a convention only; `validateCapabilities()` does not enforce the prefix matches the owning Studio. If capability ids proliferate, consider whether that should become a real, enforced rule rather than a comment.
- **Do not** build the Capability Registry/Event Bus/Command execution referenced above without a new, explicit Work Package — this one is metadata-only by design.
