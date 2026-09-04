# AP-EK-019
# Knowledge Package Distribution / Engineering Exchange Integration
## Publication, Licensing, Distribution, Installation, Verification, Version Selection, and Offline Runtime Consumption

**Status:** Architecture Phase — Integration Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-001 through AP-EK-018  
**Primary objective:** Define the production boundary between authoritative compiled engineering knowledge, Engineering Exchange, Knowledge Runtime package installation, licensing, integrity verification, version selection, and offline consumption.

---

## 1. Purpose

AP-EK-019 connects the Knowledge Runtime architecture to the existing Engineering Exchange architecture.

It defines the lifecycle:

```text
Engineering Knowledge
      ↓
Reference Library
      ↓
Reference Compiler
      ↓
Validated Knowledge Package
      ↓
Engineering Exchange
      ↓
Distribution / Licensing
      ↓
OEP Installation
      ↓
Integrity / Signature Verification
      ↓
Knowledge Runtime
      ↓
Engineering Analysis
```

The objective is to make engineering knowledge distributable without changing its authority model.

---

## 2. Fundamental Authority Chain

The authority chain remains:

```text
Creator / Authoritative Source
        ↓
Acquisition
        ↓
Reference Library
        ↓
Compiler
        ↓
Compiled Knowledge Package
        ↓
Runtime
```

Engineering Exchange is a distribution and commercial boundary.

It does not become the authority for engineering truth.

---

## 3. Exchange Boundary

Engineering Exchange owns:

```text
publication
package catalog
distribution
licensing
entitlements
payments
reviews
publisher identity
package discovery
package delivery
package update metadata
```

Knowledge Runtime owns:

```text
package validation
integrity verification
signature verification
installation compatibility
activation
registry construction
runtime consumption
```

---

## 4. Reference Library Boundary

The Reference Library owns:

```text
canonical engineering knowledge
canonical schema
canonical relationships
canonical source lineage
```

It does not depend on Engineering Exchange for authoring or correctness.

---

## 5. Compiler Boundary

The compiler transforms:

```text
canonical knowledge
```

into:

```text
compiled runtime package
```

The compiler is responsible for:

```text
schema validation
semantic validation
normalization
index generation
deterministic serialization
content hashing
package generation
```

---

## 6. Package Identity

Every published package requires:

```text
packageId
packageVersion
schemaVersion
compilerVersion
contentHash
```

Optional:

```text
publisherId
publicationId
signature
```

Package identity must remain stable across distribution channels.

---

## 7. Package Version

A new semantic knowledge version must produce a new:

```text
packageVersion
```

Published packages are immutable.

A publisher must never replace the contents of an existing immutable version while retaining its identity.

---

## 8. Package Publication

Conceptual publication lifecycle:

```text
DRAFT
   ↓
COMPILED
   ↓
VALIDATED
   ↓
SIGNED
   ↓
SUBMITTED
   ↓
PUBLISHED
   ↓
DEPRECATED
   ↓
RETIRED
```

Exact Exchange workflow may contain additional states.

Runtime installation should consume only packages that satisfy its validation requirements.

---

## 9. Publication Does Not Equal Activation

These are separate:

```text
published package
```

and:

```text
active runtime package
```

A package may be published but not installed or activated.

---

## 10. Publisher Identity

Published packages should identify the publisher where applicable:

```text
publisherId
publisherName
publisherVersion/identity
```

The package's engineering identity remains separate from publisher commerce identity.

---

## 11. Signature

Where signed publication is required:

```text
Ed25519
```

should remain the signing mechanism established by OEP package architecture.

The runtime verifies the signature before activation.

---

## 12. Signature Meaning

A valid signature establishes:

```text
artifact authenticity/integrity relative to the signing identity
```

It does not prove:

```text
engineering correctness
```

Engineering correctness is established through the authoritative knowledge/compiler validation process.

---

## 13. Content Hash

Every package should carry a canonical content identity:

```text
BLAKE3
```

with:

```text
SHA-256
```

as the required fallback.

The runtime verifies the package content against its declared identity.

---

## 14. Distribution Artifact

Engineering Exchange may distribute:

```text
knowledge package
manifest
signature
license metadata
dependency metadata
compatibility metadata
```

The runtime must receive enough information to validate the package independently.

---

## 15. Package Transport

Distribution may occur through:

```text
Engineering Exchange API
web download
local file
enterprise repository
removable/offline media
future peer distribution
```

Transport is not authority.

A package received through any transport must pass the same runtime validation.

---

## 16. Runtime Does Not Trust Transport

The runtime must not assume a package is valid because it came from:

```text
Engineering Exchange
local filesystem
enterprise server
USB
administrator
```

All packages pass the same required verification pipeline.

---

## 17. Package Installation

Conceptual:

```text
KnowledgePackageInstaller
  inspect()
  verify()
  install()
  activate()
  uninstall()
```

Installation and activation remain separate.

---

## 18. Installation Staging

A package should first enter a staging area:

```text
incoming/
```

Then:

```text
verified/
```

Then:

```text
installed/
```

Then:

```text
active/
```

Exact storage layout is implementation-specific.

---

## 19. Atomic Installation

Installation must not expose a partially copied package as installed.

Use an atomic staging/finalization mechanism.

A crash during installation must leave either:

```text
previous installed package
```

or:

```text
recoverable staged package
```

not a corrupted active package.

---

## 20. Activation

Activation should follow:

```text
installed
   ↓
validate
   ↓
resolve dependencies
   ↓
construct runtime snapshot
   ↓
activate atomically
```

Failure preserves the previous valid active package.

---

## 21. Rollback

If activation fails:

```text
previous active package
```

remains active.

No partial activation is permitted.

---

## 22. Package Dependencies

Packages may declare dependencies:

```text
dependencyPackageId
versionConstraint
contentHash
```

The installer/runtime must verify:

```text
dependency exists
dependency version is compatible
dependency content matches
dependency itself is valid
```

---

## 23. Dependency Graph

Dependency resolution must be deterministic.

Cycles must be rejected unless a future package model explicitly defines legal cycles.

Initial policy:

```text
DEPENDENCY_CYCLE
```

is a package installation failure.

---

## 24. Dependency Authority

A dependency cannot override the authority of another package merely because it loads later.

Conflicting definitions must produce:

```text
DUPLICATE_AUTHORITY
```

or an equivalent structured failure.

---

## 25. Package Composition

The initial runtime may support:

```text
one active domain package
```

with dependencies.

Future composition may support:

```text
base engineering
electrical
automotive electrical
mechanical
```

provided identity and authority rules remain explicit.

---

## 26. Licensing Boundary

Engineering Exchange controls licensing.

Runtime determines whether a package is:

```text
licensed/entitled for this installation
```

according to the available entitlement contract.

Runtime does not process payments.

---

## 27. License Metadata

Conceptual:

```text
LicenseReference
  licenseId
  packageId
  packageVersion
  entitlementType
  issuer
  expiration where applicable
  restrictions
```

The exact commercial license schema belongs to Engineering Exchange.

---

## 28. Runtime License Check

Where licensing requires online or signed entitlement validation, runtime should evaluate the entitlement state without embedding payment logic.

Possible states:

```text
ENTITLED
NOT_ENTITLED
EXPIRED
UNKNOWN
```

---

## 29. Offline Licensing

Offline operation must be supported where the applicable license permits it.

Possible mechanism:

```text
signed entitlement artifact
```

rather than mandatory network access for every analysis.

---

## 30. License Failure vs Package Failure

These must remain distinct:

```text
PACKAGE_INVALID
```

versus:

```text
NOT_ENTITLED
```

An engineering package can be valid but unavailable to a particular installation.

---

## 31. Free / Open Knowledge

Open or freely licensed packages should be consumable without requiring a commercial transaction.

Licensing metadata still identifies applicable terms.

---

## 32. Academic Distribution

Academic Alliance packages may contain:

```text
course-linked knowledge
teaching content
examples
assessments
```

The runtime must treat engineering knowledge and pedagogical metadata as distinct domains even when distributed together.

---

## 33. Enterprise Distribution

Enterprise customers may consume packages through:

```text
private Exchange catalog
enterprise repository
signed offline bundle
```

The same package identity/validation rules apply.

---

## 34. Updates

An update is a new immutable package version.

Example:

```text
electrical-core 1.0
        ↓
electrical-core 1.1
```

The original package remains available for historical reproducibility where retention permits.

---

## 35. Update Policy

The runtime should support explicit policies:

```text
manual
notify
automatic
pinned
```

A document requiring a specific package version must not be silently updated.

---

## 36. Security Updates

A package may be marked:

```text
security-revoked
```

or otherwise unavailable.

The runtime must distinguish:

```text
deprecated
revoked
unavailable
```

from ordinary version evolution.

---

## 37. Revocation

Future signed package infrastructure should support publisher/trust revocation.

Revocation must not silently rewrite historical analysis results.

Historical results retain the original package identity.

---

## 38. Package Retirement

Retirement means:

```text
new installations no longer offered
```

It does not necessarily mean:

```text
historical analysis becomes invalid
```

Historical analysis remains tied to its original package identity.

---

## 39. Knowledge Version Pinning

An engineering document or analysis may pin:

```text
packageId
packageVersion
contentHash
```

Runtime must honor the pin.

If unavailable:

```text
KNOWLEDGE_VERSION_UNAVAILABLE
```

must be returned.

---

## 40. Compatible Substitution

Substitution is allowed only where the package/document contract explicitly permits it.

Possible policy:

```text
exact
compatible-range
latest-compatible
```

The selected package identity must always be recorded.

---

## 41. Exchange Search

Engineering Exchange may expose:

```text
package search
domain
publisher
version
compatibility
license
rating
```

Search results are discovery data.

The runtime does not rely on search ranking for engineering truth.

---

## 42. Reviews

Exchange reviews are commercial/community metadata.

They must never alter:

```text
law
equation
component model
constraint
```

inside the runtime.

---

## 43. Package Metadata

Discovery metadata may include:

```text
name
description
publisher
domain
version
license
size
dependencies
compatibility
release date
```

Engineering semantics remain inside the validated package.

---

## 44. Package Download Verification

Recommended sequence:

```text
download
 ↓
size/format validation
 ↓
hash verification
 ↓
signature verification
 ↓
schema validation
 ↓
dependency validation
 ↓
installation
```

Do not activate directly from an unverified download.

---

## 45. Partial Downloads

Incomplete downloads must never enter the installed package set.

Use:

```text
temporary artifact
```

until complete verification succeeds.

---

## 46. Resumable Downloads

Engineering Exchange may support resumable transfers.

The final package still requires full verification before installation.

---

## 47. Local Package Import

A user may import:

```text
.oep knowledge package
```

or the applicable compiled package artifact.

The runtime uses the same validation path as Exchange-delivered packages.

---

## 48. Enterprise Mirror

An enterprise installation may use an internal package mirror.

The mirror is a transport/distribution mechanism.

Package identity remains determined by canonical package content.

---

## 49. Air-Gapped Installation

An air-gapped installation should support:

```text
signed package transfer
offline verification
offline installation
offline activation
```

where licensing permits it.

No cloud service should be required for engineering calculation itself.

---

## 50. Runtime Package Store

Conceptual:

```text
KnowledgePackageStore
  listInstalled()
  getInstalled(packageId, version)
  stage(package)
  verify(package)
  install(package)
  remove(package)
```

The store manages artifacts.

The runtime manages active semantic snapshots.

---

## 51. Active Package Registry

The runtime should expose:

```text
activePackageId
activePackageVersion
activePackageHash
```

and dependencies.

This must be visible to analysis provenance.

---

## 52. Package Lock

An analysis may capture a package lock:

```text
KnowledgePackageLock
  packageId
  version
  hash
  dependencies[]
```

This guarantees the exact knowledge context used by an analysis.

---

## 53. Reproducibility

AP-EK-015 analysis snapshots should retain the package lock or equivalent identity.

Reproduction requires access to the exact historical knowledge package or a verified equivalent.

---

## 54. Historical Package Retention

The repository/distribution layer should support retention of package versions required by historical analyses.

If the exact package is unavailable:

```text
historical analysis remains identifiable
```

but exact recomputation may be unavailable.

The system must state that limitation.

---

## 55. Package Migration

A new package version must not automatically rewrite historical analysis.

Migration, if ever required, creates:

```text
new analysis
```

against:

```text
new package version
```

with lineage to the original.

---

## 56. Package Compatibility Matrix

Engineering Exchange should expose compatibility information such as:

```text
minimum runtime
maximum runtime
schema compatibility
dependency versions
platform support
```

Runtime performs authoritative compatibility validation.

---

## 57. Runtime Compatibility

Runtime must reject packages that require unsupported semantics.

Example:

```text
PACKAGE_REQUIRES_NEW_RUNTIME_SEMANTICS
```

Do not attempt partial interpretation.

---

## 58. Compiler Compatibility

The package manifest identifies:

```text
compilerVersion
```

Runtime may support a declared compiler compatibility range.

Unknown compiler semantics must fail explicitly.

---

## 59. Schema Compatibility

Schema version is separate from package version.

Example:

```text
packageVersion = 2.4
schemaVersion = 1.1
```

Runtime validates both.

---

## 60. Package Content Validation

Validation must include:

```text
manifest
identity
objects
relationships
units
equations
laws
models
constraints
provenance
indexes
dependencies
```

Broken internal references are fatal.

---

## 61. Deterministic Package Generation

Two equivalent canonical knowledge inputs must generate equivalent package content.

This is essential for:

```text
content addressing
signing
reproducibility
distribution
```

---

## 62. Package Signature Lifecycle

Conceptually:

```text
compile
 ↓
canonicalize
 ↓
hash
 ↓
sign
 ↓
publish
```

Do not sign a package before canonical content is finalized.

---

## 63. Signature Verification Lifecycle

Runtime:

```text
read
 ↓
canonical content validation
 ↓
hash
 ↓
compare
 ↓
verify signature
 ↓
schema/dependency validation
 ↓
activate
```

Exact implementation may optimize the sequence while preserving security semantics.

---

## 64. Trust Store

A future runtime may maintain trusted publisher keys:

```text
TrustedPublisher
  publisherId
  publicKey
  status
  validity
```

Trust-store updates must be separately authenticated.

---

## 65. Publisher Key Rotation

Future key rotation must preserve:

```text
old package signature validity
new package signature validity
publisher identity continuity
```

Historical artifacts must remain verifiable where their signing key remains trusted for historical verification.

---

## 66. Package Encryption

Encryption is not required to establish engineering authority.

If licensed packages require confidentiality, encryption may be implemented by the distribution/licensing layer.

Decrypted packages must still undergo runtime integrity/validation.

---

## 67. No Obfuscated Engineering Semantics

Security/licensing must not require the runtime to execute opaque engineering code.

Knowledge remains structured, validated data.

---

## 68. Exchange API Boundary

Conceptual:

```text
ExchangeClient
  search()
  getPackageMetadata()
  downloadPackage()
  getLicense()
  getEntitlement()
  checkUpdates()
```

The exact API contract remains owned by Engineering Exchange.

---

## 69. Runtime API Boundary

Conceptual:

```text
PackageManager
  install()
  verify()
  activate()
  deactivate()
  list()
  remove()

KnowledgeRuntime
  capabilities()
  activePackage()
  lookup(...)
```

The runtime should not directly own Exchange HTTP semantics.

---

## 70. Separation of Client and Runtime

Recommended:

```text
Engineering Exchange Client
        ↓
Package Manager
        ↓
Knowledge Package Store
        ↓
Knowledge Runtime
```

This allows:

```text
offline installation
enterprise mirrors
local package import
future alternative distribution
```

without changing runtime semantics.

---

## 71. Update Checking

Update checking may occur asynchronously.

Engineering analysis must not depend on an update check completing.

If no network exists:

```text
runtime continues using installed valid packages
```

where licensing and package validity permit.

---

## 72. Automatic Updates

If automatic updates are enabled:

```text
download
verify
install
```

must occur independently of active analysis execution.

A currently running analysis should retain its active runtime snapshot.

---

## 73. Runtime Snapshot During Update

If package v1 is active and v2 is installed:

```text
running Analysis A
    → continues against v1

future Analysis B
    → may use v2
```

unless an explicit pin requires v1.

---

## 74. Atomic Runtime Replacement

Switching:

```text
v1 → v2
```

must be atomic.

No analysis may observe a partially constructed mixture of v1/v2 registries.

---

## 75. Package Garbage Collection

Unused packages may be removed only if:

```text
no active runtime
no pinned document
no reproducibility retention requirement
```

requires them.

The repository should warn before removing packages needed for historical reproducibility.

---

## 76. Offline Cache

A runtime may maintain a local cache of:

```text
validated packages
metadata
entitlements
```

Cache entries must not bypass required verification.

---

## 77. Network Failure

Network failure must be distinguished from package failure:

```text
NETWORK_UNAVAILABLE
```

versus:

```text
PACKAGE_INVALID
```

Offline-capable workflows continue where permitted.

---

## 78. Entitlement Failure

An entitlement service may be unavailable.

If an offline entitlement remains valid:

```text
runtime continues
```

If no valid entitlement exists:

```text
NOT_ENTITLED
```

must be explicit.

---

## 79. Engineering Analysis Independence

Once a valid package is activated, Engineering Analysis must not require Exchange connectivity to calculate.

This is mandatory for offline-first engineering operation.

---

## 80. Provenance

Analysis provenance must record:

```text
packageId
packageVersion
packageHash
publisherId where applicable
runtimeVersion
compilerVersion
```

The distribution channel itself is not part of engineering semantics unless relevant for audit.

---

## 81. Explanation Integration

AP-EK-014 may explain:

```text
which knowledge package was used
which version
who published it
whether the package is licensed
```

but must distinguish:

```text
engineering authority
```

from:

```text
publisher/commercial metadata
```

---

## 82. Teaching Integration

Academic content may reference a pinned knowledge package.

Students should receive reproducible results when:

```text
same document
same knowledge package
same runtime semantics
```

are used.

---

## 83. Exchange Publication Validation

Before publication, Engineering Exchange should require:

```text
valid package
valid manifest
valid hash
valid signature where required
valid dependency metadata
license metadata
publisher identity
```

The Reference Compiler remains responsible for canonical engineering validation.

---

## 84. Publication Rejection

Engineering Exchange must reject publication if required package metadata is missing or malformed.

It must not silently repair engineering package content.

---

## 85. Runtime Rejection

Runtime independently rejects:

```text
tampered package
invalid signature
unsupported schema
broken dependencies
duplicate authority
invalid internal references
```

Even if Exchange marked the package published.

---

## 86. Distribution Reproducibility

A package downloaded from two locations should have the same:

```text
packageId
version
contentHash
```

if they represent the same artifact.

Different hashes mean different artifacts.

---

## 87. Marketplace vs Runtime

Engineering Exchange is the marketplace/distribution surface.

Knowledge Runtime is the engineering execution surface.

Do not merge:

```text
commerce
```

with:

```text
engineering semantics
```

---

## 88. First Commercial Vertical Slice

The first end-to-end commercial knowledge package should be:

```text
Electrical Core Knowledge Package
```

containing the validated definitions needed for:

```text
DC analysis
nonlinear electrical analysis
transient analysis
AC analysis
```

only to the extent actually implemented.

---

## 89. First Publication Workflow

```text
Reference Library
      ↓
Compiler
      ↓
Package
      ↓
Validation
      ↓
Hash
      ↓
Signature
      ↓
Engineering Exchange
      ↓
Publish
      ↓
OEP client discovers package
      ↓
Download
      ↓
Verify
      ↓
Install
      ↓
Activate
      ↓
Knowledge Runtime
      ↓
Analysis
```

---

## 90. First Acceptance Test

Publish:

```text
electrical-core 1.0
```

Install it locally.

Verify:

```text
signature
hash
schema
dependencies
registry construction
activation
capabilities
```

Then run:

```text
12 V
10 Ω
```

and verify the analysis can resolve:

```text
resistor
voltage source
Ohm's Law
power
```

through the installed runtime package.

---

## 91. Update Acceptance Test

Publish:

```text
electrical-core 1.1
```

Install alongside 1.0.

Verify:

```text
1.0 remains intact
1.1 verifies
1.1 can activate
running analysis against 1.0 is unaffected
new analysis can use 1.1
```

---

## 92. Tamper Acceptance Test

Modify package contents after download.

Expected:

```text
HASH_MISMATCH
```

and:

```text
activation prohibited
```

---

## 93. Signature Acceptance Test

Use an invalid signing key.

Expected:

```text
SIGNATURE_INVALID
```

and:

```text
activation prohibited
```

---

## 94. Dependency Acceptance Test

Remove a required dependency.

Expected:

```text
DEPENDENCY_MISSING
```

and:

```text
activation prohibited
```

---

## 95. Offline Acceptance Test

Install and validate a package.

Disconnect network.

Run:

```text
engineering analysis
```

Expected:

```text
analysis succeeds
```

subject to valid licensing and installed package state.

---

## 96. Historical Acceptance Test

Run Analysis A against:

```text
electrical-core 1.0
```

Then activate:

```text
electrical-core 1.1
```

Verify Analysis A still identifies:

```text
1.0
```

and is not rewritten.

---

## 97. Implementation Sequence

```text
1. define package publication contract
2. define package distribution metadata
3. define PackageManager boundary
4. define KnowledgePackageStore
5. implement package staging
6. implement hash verification
7. implement signature verification
8. implement schema/dependency validation
9. implement installation
10. implement atomic activation
11. implement rollback
12. implement version inventory
13. implement package pinning
14. implement ExchangeClient boundary
15. implement entitlement boundary
16. implement offline operation
17. integrate runtime snapshots
18. integrate provenance
19. integrate AP-EK-015 historical analysis
20. add end-to-end Exchange acceptance tests
```

---

## 98. Recommended Repository Boundary

Conceptual:

```text
platform/
  oep_engine/
    knowledge/
      runtime/
      package/
      registry/

services/
  exchange/
```

The existing Engineering Exchange repository/service remains the distribution/commercial implementation boundary.

Do not move Exchange commerce logic into Engine.

---

## 99. Definition of Done

AP-EK-019 is complete when:

1. package publication contract is defined;
2. package identity/versioning is immutable;
3. Exchange distribution boundary is defined;
4. runtime package-management boundary is defined;
5. package staging is supported;
6. hash verification is supported;
7. signature verification is supported;
8. schema compatibility is enforced;
9. dependency resolution is deterministic;
10. atomic installation exists;
11. atomic activation exists;
12. rollback is supported;
13. package pinning is supported;
14. licensing/entitlement remains separate from engineering semantics;
15. offline operation is supported where licensed;
16. Exchange connectivity is not required during engineering calculation;
17. runtime snapshots remain stable during updates;
18. historical analyses retain original package identity;
19. tampered packages cannot activate;
20. invalid signatures cannot activate;
21. missing dependencies cannot activate;
22. first electrical package can travel from compiler → Exchange → installation → Runtime → Analysis;
23. AP-EK-012 distribution/runtime validation passes.

---

## 100. Architectural Non-Negotiables

1. Reference Library remains authoritative.
2. Compiler remains the canonical package-generation boundary.
3. Engineering Exchange distributes; it does not define engineering truth.
4. Runtime consumes; it does not author.
5. Published package versions are immutable.
6. Package identity is content-based and versioned.
7. Hash verification is mandatory.
8. Signature verification is mandatory where package trust policy requires it.
9. Signature validity does not prove engineering correctness.
10. Package validation occurs independently of transport.
11. Installation and activation are separate.
12. Activation is atomic.
13. Failed activation preserves the previous valid runtime.
14. Dependencies are explicit and deterministic.
15. Duplicate authority is rejected.
16. Licensing does not become engineering semantics.
17. Offline engineering analysis is mandatory where package/license conditions permit.
18. Network availability must not be required for already-installed authoritative knowledge.
19. Runtime updates must not alter a running analysis snapshot.
20. Historical analyses retain their original knowledge identity.
21. A new package version produces new analysis lineage when recomputed.
22. Exchange reviews, rankings, and commerce cannot alter engineering definitions.
23. No arbitrary executable engineering code is distributed as knowledge.
24. Package security must not require opaque engineering semantics.
25. The complete lifecycle must preserve the chain:
   authoritative knowledge → compiled package → verified distribution → immutable runtime → deterministic analysis.
