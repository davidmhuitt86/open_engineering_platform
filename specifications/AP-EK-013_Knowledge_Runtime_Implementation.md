# AP-EK-013
# Knowledge Runtime Implementation
## Runtime Package, Registry, Loading, Versioning, and Integrity Architecture

**Status:** Architecture Phase — Implementation Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-012  
**Primary objective:** Define the first concrete implementation boundary for the OEP Knowledge Runtime.

---

## 1. Purpose

AP-EK-013 converts the preceding Knowledge Runtime architecture into an implementable runtime boundary.

The runtime is the deterministic execution environment that consumes compiled authoritative engineering knowledge and provides that knowledge to:

```text
Engineering Analysis
Component Model Resolution
Law / Equation Resolution
Constraint Evaluation
Provenance
Future Explanation Services
```

The runtime is not the authoritative authoring environment.

Authority remains:

```text
oep_acqusition
      ↓
oep_reference_library
      ↓
Reference Compiler
      ↓
Compiled Knowledge Runtime
```

---

## 2. Runtime Responsibility

The Knowledge Runtime owns:

```text
package loading
package validation
version verification
registry construction
knowledge lookup
model lookup
law lookup
equation lookup
constraint lookup
unit lookup
provenance metadata access
runtime capability discovery
```

It does not own:

```text
reference authoring
source acquisition
diagram editing
Flutter UI
repository workspace behavior
circuit topology
numerical solving
AI reasoning
```

---

## 3. Runtime Boundary

Canonical architecture:

```text
                AUTHORITATIVE
                     │
          ┌──────────▼──────────┐
          │ Reference Library   │
          └──────────┬──────────┘
                     │
                     ▼
             Reference Compiler
                     │
                     ▼
          ┌─────────────────────┐
          │ Knowledge Package   │
          │ immutable / signed  │
          └──────────┬──────────┘
                     │
                     ▼
          ┌─────────────────────┐
          │ Knowledge Runtime   │
          └──────────┬──────────┘
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
    Analysis      Constraints   Provenance
```

---

## 4. Compiled Package

The runtime consumes a compiled package rather than arbitrary source documents.

Conceptual package:

```text
KnowledgePackage
  manifest
  schema
  objects
  relationships
  units
  equations
  laws
  models
  constraints
  indexes
  provenance
  integrity
```

The package format must be deterministic.

The existing OEP `.oep` package architecture remains the authoritative packaging convention where applicable.

---

## 5. Package Manifest

Conceptual:

```text
KnowledgePackageManifest
  packageId
  packageName
  packageVersion
  schemaVersion
  sourceKnowledgeVersion
  compilerVersion
  createdUtc
  contentHash
  signature
  domains[]
  capabilities[]
```

The manifest must identify the exact knowledge package loaded by the runtime.

---

## 6. Runtime Identity

The runtime itself has identity:

```text
runtimeVersion
runtimeBuild
schemaVersion
compilerCompatibility
```

Runtime identity must be included in analysis provenance.

---

## 7. Package Identity vs Runtime Identity

These are different:

```text
Knowledge Package
  = engineering knowledge content

Runtime
  = software semantics used to interpret that content
```

Example:

```text
knowledgePackage = electrical-core 1.2
runtime = OEP Knowledge Runtime 0.4
```

A result must preserve both identities.

---

## 8. Package Loading

Conceptual:

```text
KnowledgeRuntime
  load(package)
  unload(package)
  activate(package)
  getActivePackage()
```

Loading and activation are separate operations.

A package must validate successfully before activation.

---

## 9. Validation Before Activation

The runtime must verify:

```text
package structure
manifest
schema
required fields
IDs
relationships
units
equations
models
constraints
indexes
provenance
content hashes
signature where required
compiler compatibility
```

Invalid packages must never become active runtime knowledge.

---

## 10. Activation Atomicity

Activation must be atomic from the consumer perspective.

Consumers must see either:

```text
previous valid package
```

or:

```text
new valid package
```

never:

```text
partially loaded package
```

---

## 11. Immutable Active Runtime

Once activated, the knowledge package is immutable for the lifetime of the runtime context.

Runtime consumers cannot:

```text
edit law
edit equation
edit model
edit constraint
edit unit
```

Any change requires:

```text
new package
new validation
new activation
```

---

## 12. Multiple Packages

The runtime may eventually support:

```text
base electrical package
automotive package
HVAC package
industrial package
mechanical package
```

The initial implementation may activate one package at a time.

Package composition must not permit ambiguous duplicate authoritative definitions.

---

## 13. Domain Profiles

Conceptually:

```text
KnowledgeDomain
  domainId
  name
  version
  dependencies[]
```

Examples:

```text
electrical
automotive-electrical
mechanical
hydraulic
thermal
```

Domain profiles may be composed only through explicit dependency/version rules.

---

## 14. Dependency Resolution

A package may depend on:

```text
base units
base quantities
common equations
common laws
```

Dependencies must identify:

```text
packageId
version/range
content identity
```

The runtime must reject unresolved dependencies.

---

## 15. Duplicate Definitions

If two active packages provide incompatible definitions for the same authoritative identity:

```text
DUPLICATE_AUTHORITY
```

must be returned.

The runtime must not choose one based on:

```text
load order
filename
network availability
UI preference
AI preference
```

---

## 16. Registry Architecture

The runtime should expose typed registries:

```text
UnitRegistry
EquationRegistry
LawRegistry
ComponentModelRegistry
ConstraintRegistry
ObjectRegistry
RelationshipRegistry
```

Registries provide deterministic lookup.

---

## 17. Common Registry Contract

Conceptual:

```text
get(id)
contains(id)
list(filter)
version(id)
provenance(id)
```

The registry must return immutable definitions.

---

## 18. Engineering Object Registry

The Object Registry provides canonical Engineering Object identity.

It must preserve the existing Engineering Object Model identity:

```text
objectId
objectType
name
description
createdUtc
lastModifiedUtc
version
author
tags
```

The Knowledge Runtime must not create a competing object identity system.

---

## 19. Relationship Registry

Relationships preserve graph connectivity and knowledge relationships.

Existing relationship identity remains authoritative:

```text
relationshipId
sourceObjectId
targetObjectId
relationshipType
createdUtc
author
description
```

The runtime may build indexes for lookup but does not redefine relationship semantics.

---

## 20. Unit Registry

The Unit Registry provides:

```text
unitId
symbol
dimension
scale
offset
aliases
```

The exact Quantity/Unit contract is governed by AP-EK-003.

Unit definitions are immutable at runtime.

---

## 21. Equation Registry

The Equation Registry provides:

```text
equationId
version
expression
variables
dimensions
applicability
provenance
```

Expressions must conform to the deterministic expression contract established by AP-EK-001/AP-EK-002.

---

## 22. Law Registry

The Law Registry provides:

```text
lawId
version
name
equationRefs[]
applicability
provenance
```

A law is not arbitrary executable code.

---

## 23. Component Model Registry

The Component Model Registry provides:

```text
modelId
version
domain
terminals
parameters
states
equationRefs[]
constraints[]
applicability
provenance
```

The model contract is governed by AP-EK-006.

---

## 24. Constraint Registry

The Constraint Registry provides:

```text
constraintId
version
type
operands
condition
severity
applicability
provenance
```

The Constraint Engine consumes these definitions.

---

## 25. Provenance Registry

The runtime should expose immutable provenance metadata for compiled knowledge:

```text
sourceObjectId
sourceReference
sourceKnowledgeVersion
compilerVersion
contentHash
```

Analysis creates result-specific provenance from this metadata.

---

## 26. Indexes

Compiled packages should include deterministic indexes for frequent lookup.

Examples:

```text
objectId -> object
unitId -> unit
equationId -> equation
lawId -> law
modelId -> model
constraintId -> constraint
```

Additional indexes may support:

```text
domain
object type
component category
applicability
terminal type
```

---

## 27. Canonical Serialization

Package generation must use canonical serialization.

Equivalent source knowledge must produce equivalent canonical package content when all semantic inputs are equivalent.

Serialization must define:

```text
field ordering
collection ordering
number formatting
Unicode normalization
newline policy
encoding
```

---

## 28. Hashing

The package content hash must be calculated from canonical content.

The existing OEP content-addressing convention should be reused:

```text
BLAKE3
```

with:

```text
SHA-256
```

available as the required fallback.

The hash must not include mutable transport metadata unless explicitly defined by the package format.

---

## 29. Signature

Where package signing is required, the existing OEP signing convention should be used:

```text
Ed25519
```

Signature verification occurs before activation.

Signature validity does not establish engineering correctness by itself; it establishes integrity/authenticity of the signed artifact.

---

## 30. Trust States

Package trust should be explicit:

```text
UNVERIFIED
HASH_VERIFIED
SIGNATURE_VERIFIED
VALIDATED
ACTIVE
REJECTED
```

A package cannot become:

```text
ACTIVE
```

unless required verification/validation gates pass.

---

## 31. Offline Operation

The runtime must operate without network access after required packages are available locally.

No analysis should require:

```text
cloud lookup
internet access
AI service
remote API
```

for authoritative electrical knowledge.

---

## 32. Runtime Startup

Conceptual startup:

```text
1. initialize runtime
2. load package metadata
3. verify package integrity
4. verify signature if required
5. validate schema
6. construct registries
7. validate registry cross-references
8. activate immutable runtime snapshot
9. expose capabilities
```

Failure at any mandatory stage prevents activation.

---

## 33. Capability Discovery

Conceptual:

```text
KnowledgeRuntimeCapabilities
  domains[]
  units[]
  laws[]
  equations[]
  componentModels[]
  constraints[]
  analysisModes[]
```

Analysis capability itself remains owned by the Analysis subsystem.

The runtime reports available knowledge/model capabilities.

---

## 34. Compatibility

The runtime must validate compatibility between:

```text
runtime version
package schema version
compiler version
```

Compatibility rules must be explicit.

Unknown future schema versions must not be silently interpreted.

---

## 35. Version Selection

Where multiple compatible packages are installed, selection must be explicit.

Possible strategies:

```text
exact version
declared compatible range
document-pinned version
runtime-default version
```

The selected package must be recorded in analysis provenance.

---

## 36. Document-Pinned Knowledge

A future engineering document may explicitly require:

```text
knowledgePackageId
knowledgePackageVersion
```

When pinned, the runtime must use the required compatible package or report:

```text
KNOWLEDGE_VERSION_UNAVAILABLE
```

It must not silently substitute another version.

---

## 37. Runtime Context

Conceptual:

```text
KnowledgeRuntimeContext
  runtimeIdentity
  packageIdentity
  registries
  capabilities
```

Analysis receives a stable runtime context.

The context must not mutate during an active analysis.

---

## 38. Thread Safety

The active knowledge snapshot should be immutable and safe for concurrent read access.

Multiple analyses may read the same package concurrently.

Mutation requires constructing a new runtime snapshot.

---

## 39. Memory Model

The implementation should prefer:

```text
immutable definitions
shared references
indexed lookup
lazy loading where practical
```

Large knowledge packages should not require unnecessary duplication per analysis.

---

## 40. Runtime API

Conceptual:

```text
KnowledgeRuntime
  initialize()
  loadPackage(source)
  validatePackage(package)
  activatePackage(package)
  capabilities()
  getObject(id)
  getRelationship(id)
  getUnit(id)
  getEquation(id)
  getLaw(id)
  getComponentModel(id)
  getConstraint(id)
  getProvenance(id)
```

The concrete programming-language API is an implementation concern.

---

## 41. Error Contract

At minimum:

```text
PACKAGE_NOT_FOUND
PACKAGE_INVALID
PACKAGE_HASH_MISMATCH
PACKAGE_SIGNATURE_INVALID
SCHEMA_UNSUPPORTED
COMPILER_INCOMPATIBLE
DEPENDENCY_MISSING
DUPLICATE_AUTHORITY
REFERENCE_NOT_FOUND
INVALID_REFERENCE
KNOWLEDGE_VERSION_UNAVAILABLE
ACTIVATION_FAILED
```

Errors must be structured.

---

## 42. Runtime Logging

Runtime diagnostics should record:

```text
package identity
runtime identity
activation status
validation diagnostics
dependency resolution
```

Logs must not become the authority for engineering results.

---

## 43. Caching

Runtime may cache immutable registry lookups.

Cache contents are derived data.

They may be discarded and reconstructed without changing engineering semantics.

---

## 44. Analysis Integration

AP-EK-007 analysis obtains knowledge through:

```text
KnowledgeRuntime
   |
   +-- ComponentModelRegistry
   +-- LawRegistry
   +-- EquationRegistry
   +-- UnitRegistry
   +-- ConstraintRegistry
```

The solver does not read raw reference-library files.

---

## 45. Provenance Integration

AP-EK-009 obtains source/version identity from the runtime.

Example:

```text
equationId
equationVersion
knowledgePackageId
knowledgePackageVersion
compilerVersion
contentHash
```

The analysis result then combines this with:

```text
input lineage
derivation
solver identity
```

---

## 46. DS Integration

Diagram Studio must not load authoritative knowledge packages directly merely to calculate values.

DS requests analysis through AP-EK-010.

DS may query capability metadata where useful for UI presentation.

---

## 47. Reference Library Boundary

The runtime does not become a second reference library.

```text
oep_reference_library
    = canonical authored knowledge

Knowledge Runtime
    = compiled executable/read-only knowledge view
```

Changes originate in the reference library/compiler pipeline.

---

## 48. Acquisition Boundary

The runtime does not ingest raw external sources.

Acquisition remains responsible for:

```text
source acquisition
trust metadata
immutable acquisition records
```

The runtime consumes compiled knowledge only.

---

## 49. Exchange Boundary

The runtime does not own:

```text
marketplace
licensing
payments
publication workflow
package distribution
```

Engineering Exchange may distribute signed knowledge packages.

The runtime verifies and consumes them.

---

## 50. First Electrical Package

The initial package should contain only the knowledge necessary for the first vertical slice:

```text
Quantities:
  voltage
  current
  resistance
  power

Units:
  V
  A
  Ω
  W

Laws:
  Ohm's Law
  Electrical Power
  KCL
  KVL

Equations:
  V = I × R
  I = V / R
  R = V / I
  P = V × I
  P = I² × R
  P = V² / R

Models:
  ideal voltage source
  ideal current source
  resistor
  reference node
  switch

Constraints:
  KCL residual
  KVL residual
  power balance
  component power limit
```

Only definitions that pass the authoritative knowledge/compiler validation may be included.

---

## 51. First Runtime Acceptance

The runtime must successfully:

```text
load electrical package
verify integrity
validate schema
construct registries
activate package
resolve resistor model
resolve voltage-source model
resolve Ohm's Law
resolve I = V/R
resolve power equation
resolve constraints
return provenance metadata
```

---

## 52. End-to-End Runtime Acceptance

Given:

```text
12 V source
10 Ω resistor
reference
```

the runtime/analysis stack must support:

```text
model resolution
topology analysis
equation selection
calculation
constraint evaluation
derivation
provenance
AnalysisResult
```

Expected:

```text
I = 1.2 A
P = 14.4 W
```

---

## 53. Package Rejection Acceptance

The runtime must reject:

```text
modified package content
invalid signature
unsupported schema
missing dependency
broken equation reference
broken model reference
duplicate authority
```

before activation.

---

## 54. Version Acceptance

Two package versions may coexist on disk.

The active runtime must clearly identify:

```text
package A
version 1
```

versus:

```text
package B
version 2
```

Analysis provenance must preserve the selected version.

---

## 55. Implementation Sequence

Recommended implementation order:

```text
1. runtime core types
2. package manifest parser
3. canonical package reader
4. integrity verification
5. signature verification
6. schema validation
7. dependency validation
8. registry construction
9. capability discovery
10. immutable runtime snapshot
11. typed lookup APIs
12. provenance metadata access
13. electrical package fixture
14. integration with Analysis
15. validation-suite integration
```

---

## 56. Repository Placement

The runtime implementation belongs within the existing OEP platform architecture.

Recommended conceptual boundary:

```text
platform/
  oep_engine/
    knowledge/
      runtime/
      registry/
      package/
      provenance/
```

Exact paths should follow the existing repository taxonomy after inspection.

No new top-level competing Engine should be created.

---

## 57. Language Boundary

The runtime should remain compatible with the existing OEP Engine implementation language/toolchain.

The authoritative reference compiler may remain implemented in its existing reference-library environment.

The compiled package is the language-neutral boundary.

---

## 58. No Raw Knowledge Execution

The runtime must never execute:

```text
Python from a reference document
JavaScript from a package
arbitrary native code
LLM-generated code
```

Knowledge is represented as validated data interpreted by deterministic runtime semantics.

---

## 59. Security

Package processing must defend against:

```text
path traversal
zip bombs
malformed serialization
oversized collections
hash confusion
signature bypass
dependency cycles
resource exhaustion
```

The exact packaging threat model should align with the existing `.oep` security specification.

---

## 60. Testing

### Package

- valid package;
- malformed package;
- missing manifest;
- invalid hash;
- invalid signature;
- unsupported schema.

### Registry

- lookup;
- missing identity;
- duplicate authority;
- broken reference.

### Versioning

- exact version;
- compatible version;
- unavailable version;
- historical version.

### Runtime

- activation;
- atomic replacement;
- immutable reads;
- concurrent reads.

### Integration

- Analysis resolves models/laws/equations;
- Constraint Engine resolves constraints;
- Provenance resolves source/version metadata.

### End-to-End

First electrical vertical slice passes.

---

## 61. Definition of Done

AP-EK-013 is complete when:

1. runtime boundary is implemented;
2. compiled package can be loaded;
3. package integrity is verified;
4. signatures are verified where required;
5. schema compatibility is enforced;
6. dependencies are resolved;
7. immutable registries are constructed;
8. duplicate authority is rejected;
9. typed lookups work;
10. capabilities are discoverable;
11. runtime/package/version identity is exposed;
12. provenance metadata is available;
13. offline operation works;
14. first electrical knowledge package activates;
15. AP-EK-007 can resolve required knowledge through the runtime;
16. AP-EK-008 can resolve required constraints;
17. AP-EK-009 can obtain knowledge lineage;
18. AP-EK-012 acceptance tests pass against the runtime;
19. no raw external source code is executed;
20. DS consumes the resulting analysis through AP-EK-010.

---

## 62. Follow-On

```text
AP-EK-014  Engineering Explanation / Teaching Layer
AP-EK-015  Analysis Result Persistence
AP-EK-016  Nonlinear Electrical Solver Implementation
AP-EK-017  Dynamic Electrical Solver Implementation
AP-EK-018  Frequency-Domain / Complex Quantity Implementation
AP-EK-019  Knowledge Package Distribution / Exchange Integration
```

---

## Architectural Non-Negotiables

1. The Reference Library is authoritative; the Runtime is compiled/read-only knowledge.
2. Acquisition remains outside the runtime.
3. Exchange remains outside the runtime.
4. Runtime packages must validate before activation.
5. Activation is atomic.
6. Active knowledge is immutable.
7. Package identity and runtime identity are distinct.
8. Version selection is explicit.
9. Missing versions are explicit failures.
10. Duplicate authority is rejected.
11. Registries expose immutable definitions.
12. The runtime does not calculate circuit topology or solve circuits.
13. Analysis consumes knowledge through typed runtime APIs.
14. DS does not load raw authoritative knowledge to perform engineering calculations.
15. Knowledge is data, not executable arbitrary code.
16. Package integrity/authenticity does not itself establish engineering correctness.
17. Engineering correctness comes from authoritative validated knowledge.
18. Offline authoritative operation is mandatory.
19. Runtime semantics must remain deterministic.
20. No second competing Engineering Object identity system may be introduced.
