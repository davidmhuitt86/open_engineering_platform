# WP-EKE-013 — Complete Authoritative Knowledge Runtime Boundary

**Implementation prompt**  
**Status:** Ready for implementation  
**Related audit:** AP-EKE-012 — Reference Runtime & Diagram Knowledge Boundary Audit  
**Audit commit:** `6a0ce708df3afc038c44ea1756fc559cbc3cf9f5`

---

## Objective

Implement **WP-EKE-013 — Complete Authoritative Knowledge Runtime Boundary**.

The purpose of this work package is to close the existing AP-EK-013 Knowledge Runtime gaps identified by the AP-EKE-012 audit **before** implementing Reference Discovery or any LLM/vision interpretation pipeline.

This work package must strengthen the existing deterministic `KnowledgeRuntime`. It must **not** create a second knowledge store, search system, reference database, LLM interface, or diagram interpretation system.

The architectural boundary remains:

```
Authoritative Reference Library
        ↓
Reference Compiler
        ↓
.oerp compiled package
        ↓
OerpReader
        ↓
KnowledgeRuntime
        ↓
future Reference Discovery
```

WP-EKE-013 ends at `KnowledgeRuntime`.

---

# 1. Mandatory audit-first phase

Before modifying code:

1. Read the relevant architecture/specification documents:
   - `specifications/AP-EK-001_OEP_Knowledge_Contract.md`
   - `specifications/AP-EK-002_Reference_Compiler_Boundary.md`
   - `specifications/AP-EK-013_Knowledge_Runtime_Implementation.md`
   - `specifications/AP-EK-019_Knowledge_Package_Distribution_Exchange_Integration.md`
   - `specifications/AP-EK-020_Engineering_Knowledge_Runtime_Integration_and_First_Vertical_Slice.md`
   - `specifications/AP-ENGINEERING-KNOWLEDGE-001/`
   - relevant SDD-R001–SDD-R011 Reference Library specifications.

2. Inspect the current implementation:
   - `platform/oep_engine/lib/core/knowledge/`
   - `knowledge/reference_library/compiler/`
   - `platform/oep_engine/test/knowledge/`
   - existing `.oerp` reader tests
   - runtime fixture/package definitions
   - current `KnowledgeRuntime`
   - current `KnowledgePackage`
   - current runtime identity
   - current runtime error codes.

3. Search all current callers of:
   - `KnowledgeRuntime.activate`
   - `getUnit`
   - `getDimension`
   - `getComponentModel`
   - `getLaw`
   - `getEquation`
   - `getConstraint`
   - `getProvenance`
   - `electricalCoreRuntimeProvider`
   - any existing object/relationship runtime APIs.

4. Determine the smallest implementation consistent with the existing architecture.

Do not rewrite existing runtime architecture merely because another design could be cleaner.

---

# 2. Required architectural outcome

The runtime must represent the authoritative contents of the compiled package without silently discarding or overwriting authoritative definitions.

The target runtime boundary is:

```
KnowledgeRuntime
├── identity
├── capabilities
├── dimensions
├── units
├── objects
├── relationships
├── componentModels
├── laws
├── equations
├── constraints
└── provenance
```

The existing typed registries remain authoritative for their current domains.

Do **not** replace them with an untyped generic registry.

---

# 3. Object Registry

AP-EK-013 defines:

`getObject(id)`

Implement the minimum viable authoritative Object Registry required by the existing Reference Library schema.

First inspect the compiled package representation and existing EKO model before defining a new runtime object model.

Prefer an existing repository equivalent if one already exists rather than creating a duplicate model.

The object registry must:

- preserve canonical object identity;
- preserve object type/classification information available in the compiled representation;
- preserve relevant properties needed by downstream consumers;
- preserve provenance/reference identity;
- support deterministic lookup by ID;
- reject duplicate authoritative IDs;
- distinguish missing objects from invalid package content.

Do **not** invent a second EKO schema.

If the current `runtime.json` projection does not contain sufficient object information, determine whether the correct fix is:

1. extend `runtime_export.py`, or
2. derive the object registry from an already authoritative package member.

Do not load raw authoring YAML directly from the runtime.

The runtime must continue consuming compiled package output.

---

# 4. Relationship Registry

Implement the minimum authoritative Relationship Registry required by AP-EK-013.

Target:

`getRelationship(id)`

If the architecture supports it without unnecessary API expansion, also support:

`relationshipsForObject(objectId)`

Inspect `graph.idx` and the Reference Library relationship schema first.

Do not create a competing relationship representation.

The runtime relationship model must preserve at minimum:

```
relationshipId
relationshipType
source
target
```

plus any existing authoritative fields required by the package schema.

Validate:

- relationship ID uniqueness;
- source object existence;
- target object existence;
- valid relationship structure;
- deterministic lookup.

A relationship referring to an unknown object must make package activation fail rather than silently creating a dangling reference.

---

# 5. Duplicate-authority protection

The audit found that several registry constructions use map comprehensions. This can silently overwrite duplicate IDs.

Correct this.

At activation time, duplicate authoritative IDs must be rejected for every authoritative registry, including:

- dimensions
- units
- objects
- relationships
- componentModels
- laws
- equations
- constraints
- provenance

Do not rely on Dart `Map` construction to detect duplicates.

Create a small reusable deterministic helper if appropriate, but keep the implementation simple.

Use the repository's existing error model if possible. If no suitable error exists, introduce the smallest explicit error necessary, such as:

`DUPLICATE_AUTHORITY`

Tests must prove that a duplicate cannot silently replace the first definition.

---

# 6. Cross-reference validation

Before a package becomes active, validate all authoritative references that can be checked from the current package model.

At minimum inspect and validate:

- `Unit.dimensionId`
- `ComponentModel.equationRefs`
- `ComponentModel.constraintRefs`
- `Law.equationRefs`
- `Equation.provenanceId`
- `Law.provenanceId`
- `Constraint.provenanceId`
- `ComponentModel.provenanceId`
- dimension provenance, if represented
- unit provenance, if represented
- object provenance
- relationship source/target
- relationship provenance, if represented

Use the actual current models and specifications to determine the complete set.

Do not invent references that the schema does not have.

Failure must be deterministic and explicit.

Use the repository's existing error model where possible; otherwise use a suitable explicit error such as:

`REFERENCE_NOT_FOUND`

The package must not activate with dangling references.

---

# 7. Runtime identity correction

The current implementation conflates package identity and runtime identity.

Correct this.

The runtime must preserve separate concepts:

```
Knowledge Package
    packageId
    packageVersion
    schemaVersion
    compilerVersion

Knowledge Runtime
    runtimeVersion
    runtimeBuild
```

Do not fabricate a semantic runtime version from:

`packageId@packageVersion`

Determine the correct source of runtime version/build information from the existing project/package metadata.

If the repository has no existing runtime version/build authority:

- introduce the smallest explicit runtime identity representation;
- document where it comes from;
- do not use the knowledge package version as the runtime version.

The runtime identity must be able to support future inference provenance such as:

```
referencePackage:
    electrical-core@1.0.0

knowledgeRuntime:
    <runtime version>

inferenceModel:
    <future model identity>
```

Do not implement inference provenance in this work package.

---

# 8. Capabilities

Implement the runtime capability surface required by AP-EK-013.

At minimum expose deterministic capability information describing what the active runtime contains.

Inspect the existing AP-EK-013 specification before defining the exact API.

The result should allow callers to determine availability of domains such as:

- dimensions
- units
- objects
- relationships
- componentModels
- laws
- equations
- constraints
- provenance

Do not make capabilities dynamic or heuristic.

It should be derived directly from the active immutable package/runtime.

---

# 9. Immutability

Preserve the existing runtime principle:

```
Compiled Reference Package
        ↓
Immutable KnowledgeRuntime
```

After activation:

- callers must not be able to mutate runtime registries;
- no runtime API may modify authoritative reference content;
- no runtime API may write back to Reference Library;
- no runtime API may modify `.oerp`;
- no runtime API may modify Reference Vault;
- no repository mutation.

If current collections are exposed mutably, correct that.

---

# 10. Provenance

Every runtime object that already has a provenance reference must be resolvable through the runtime.

For example:

```
getComponentModel(id)
    ↓
component.provenanceId
    ↓
getProvenance(id)
```

must work deterministically.

Do not invent provenance where the source package does not provide it.

Do not weaken provenance requirements merely to make the fixture pass.

---

# 11. .oerp package boundary

Preserve the current rule:

```
OerpReader
    parses compiled package
        ↓
KnowledgePackage
        ↓
KnowledgeRuntime.activate()
```

Do not:

- read authoring YAML from the runtime;
- bypass `OerpReader`;
- create another package loader;
- introduce a second package format;
- make Reference Discovery read the Reference Library directly.

If Object/Relationship data must be added to `runtime.json`, extend the compiler export deterministically.

If `graph.idx` is the authoritative compiled relationship representation, determine whether the runtime should consume it directly or whether the compiler should project the necessary relationship registry into `runtime.json`.

Make this decision from AP-EK-013/AP-EK-020 and the existing package architecture, not convenience.

Document the decision.

---

# 12. Do not implement Reference Discovery

This is a hard boundary.

Do **NOT** implement:

- `ReferenceDiscovery`
- `ReferenceSearch`
- `ReferenceResult`
- `ReferenceContext`
- semantic search
- embedding search
- LLM retrieval
- vector database
- fuzzy symbol matching

Those belong to the next work package.

The only exception is whatever minimal package loading is required to make Object/Relationship registries authoritative.

The next architecture will consume:

`KnowledgeRuntime`

as its authority.

---

# 13. Do not modify diagram ingestion

Do not modify:

- UIF
- OCR
- Tesseract
- Extraction Inspector
- EvidenceRegion
- Human Observation
- KnowledgeCandidate
- Acquisition workflow
- Reference Vault
- EAM
- LLM/Vision
- InferenceRecord.

The purpose of this work package is to make the reference authority ready for those future consumers.

---

# 14. Preserve existing electrical vertical slice

The existing AP-EK-020 acceptance circuit must remain intact:

```
compiled Reference Library
        ↓
.oerp
        ↓
OerpReader
        ↓
KnowledgeRuntime
        ↓
AnalysisEngine
        ↓
canonical 12 V / 10 Ω circuit
        ↓
1.2 A / 14.4 W
```

Do not break or bypass this path.

The current hand-built `electrical_core_package.dart` may remain as an isolated test fixture if still needed.

Do not allow it to become a production authority.

---

# 15. Tests

Add focused tests for all new behavior.

At minimum cover:

### Object registry

1. valid object lookup;
2. missing object returns the repository's not-found error;
3. object identity preserved;
4. object provenance resolvable;
5. duplicate object IDs rejected.

### Relationship registry

6. valid relationship lookup;
7. relationship source/target preserved;
8. relationship traversal for an object, if implemented;
9. missing relationship returns the repository's not-found error;
10. duplicate relationship IDs rejected;
11. unknown relationship source rejected;
12. unknown relationship target rejected.

### Existing registries

13. duplicate dimension rejected;
14. duplicate unit rejected;
15. duplicate component model rejected;
16. duplicate law rejected;
17. duplicate equation rejected;
18. duplicate constraint rejected;
19. duplicate provenance rejected.

### Cross-reference validation

20. invalid unit → dimension rejected;
21. invalid component → equation rejected;
22. invalid component → constraint rejected;
23. invalid law → equation rejected;
24. invalid equation → provenance rejected;
25. invalid component → provenance rejected;
26. invalid constraint → provenance rejected.

Only include cases that correspond to actual current schema fields.

### Runtime identity

27. package identity and runtime identity are distinct;
28. runtime version is not derived from package ID/version;
29. runtime build/version remains deterministic.

### Capabilities

30. capabilities correctly reflect the active package;
31. empty optional registry reports zero capability content without failing;
32. capability state cannot mutate after activation.

### Immutability

33. returned collections cannot mutate runtime state;
34. runtime lookup results cannot modify authoritative registry state.

### Regression

35. existing KnowledgeRuntime tests pass;
36. existing OerpReader tests pass;
37. AP-EK-020 vertical-slice test still produces 1.2 A / 14.4 W.

Use the existing test style and helpers where possible.

Do not manufacture giant fixture packages merely to increase test count.

---

# 16. Real compiled-package validation

Do not rely exclusively on hand-built fixtures.

Run the existing real-package verification path:

```
Reference Library
→ Python Reference Compiler
→ .oerp
→ OerpReader
→ KnowledgeRuntime
```

Verify that the real compiled package contains and successfully activates the newly required authoritative information.

If the current Reference Library does not contain sufficient real object/relationship data for the complete registry, document exactly what the real package proves and what remains fixture-only.

Do not claim full real-package coverage if it was not actually exercised.

---

# 17. Verification boundaries

Report separately:

A. in-memory `KnowledgePackage` fixture  
B. generated `runtime.json`  
C. real compiled `.oerp`  
D. production `KnowledgeRuntime` activation  
E. AP-EK-020 analysis vertical slice

A fixture passing does not prove the compiler/export path.

A compiler test passing does not prove OerpReader.

An OerpReader test passing does not prove KnowledgeRuntime.

Keep those boundaries explicit.

---

# 18. Documentation

Update relevant architecture documentation to record:

```
Reference Library
    = authoritative authored knowledge

Reference Compiler
    = deterministic compilation

.oerp
    = immutable distributable knowledge package

OerpReader
    = package parser

KnowledgeRuntime
    = immutable authoritative runtime registry

Reference Discovery
    = future consumer of KnowledgeRuntime
```

Document:

- Object Registry;
- Relationship Registry;
- duplicate-authority behavior;
- cross-reference validation;
- package/runtime identity distinction;
- capability surface;
- what remains outside the runtime;
- why existing workspace/diagram SearchService is not Reference Discovery.

Do not prematurely document future LLM implementation as implemented.

---

# 19. Security / trust

Preserve current trust behavior.

Unsigned development packages may continue to work only through the existing explicit development flag.

Signed packages must not become implicitly trusted.

Do not weaken:

- package hash validation;
- signature validation;
- trust-state handling.

If an existing signing gap remains, disclose it rather than expanding scope to implement signing.

---

# 20. Expected architecture after implementation

```
                 Reference Library
                        │
                        ▼
                Reference Compiler
                        │
                        ▼
                   .oerp Package
                        │
                 ┌──────┴──────┐
                 ▼             ▼
            OerpReader      package data
                 │
                 ▼
          KnowledgePackage
                 │
                 ▼
         KnowledgeRuntime
                 │
     ┌───────────┼────────────┐
     │           │            │
     ▼           ▼            ▼
  Objects   Relationships   Typed registries
     │           │            │
     └───────────┼────────────┘
                 ▼
           Future AP-EKE-014
        Reference Discovery
```

Target runtime surface:

```
KnowledgeRuntime
    |
    +-- identity
    |
    +-- capabilities
    |
    +-- objectRegistry
    |
    +-- relationshipRegistry
    |
    +-- dimensionRegistry
    |
    +-- unitRegistry
    |
    +-- componentModelRegistry
    |
    +-- lawRegistry
    |
    +-- equationRegistry
    |
    +-- constraintRegistry
    |
    +-- provenanceRegistry
```

---

# 21. Explicit non-goals

Do not implement:

- Reference Discovery;
- LLM;
- vision;
- embeddings;
- vector DB;
- semantic ranking;
- diagram symbol recognition;
- training data;
- inference records;
- reference usage records;
- new EKO authoring system;
- new Symbol database;
- Repository changes;
- EAM changes;
- UIF changes.

---

# 22. Verification requirements

Before reporting completion, run:

1. focused Knowledge Runtime tests;
2. OerpReader tests;
3. Reference Compiler tests;
4. AP-EK-020 vertical slice;
5. relevant `oep_engine` tests;
6. full Flutter test suite if practical;
7. `dart analyze`;
8. Windows debug build;
9. real compiled `.oerp` verification.

Report exact results.

Separate:

- new failures;
- pre-existing failures;
- environmental failures;
- skipped tests.

Do not attribute unrelated existing failures to this work package.

---

# 23. Git discipline

**Do not commit or push automatically.**

At completion report:

```
Files modified:
Files added:
Files deleted:

Tests:
Analyzer:
Build:
Real .oerp verification:

Architecture decisions:
Known limitations:
Pre-existing failures:
Potential follow-ups:
```

Stop after the implementation and verification report.

---

## Acceptance criterion

WP-EKE-013 is complete when:

> `KnowledgeRuntime` can activate the compiled authoritative knowledge package without silently overwriting duplicate definitions, can deterministically resolve the authoritative object and relationship information required by AP-EK-013, validates the package's supported cross-references before activation, exposes distinct package/runtime identity and deterministic capabilities, preserves immutability and trust behavior, and leaves a clean authoritative boundary for the future Reference Discovery layer.

**Do not proceed into Reference Discovery or LLM work as part of this package.**
