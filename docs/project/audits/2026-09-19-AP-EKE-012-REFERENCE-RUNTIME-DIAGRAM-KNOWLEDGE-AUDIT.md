# AP-EKE-012 — Reference Runtime & Diagram Knowledge Boundary Audit

**Date:** 2026-09-19  
**Disposition:** COMPLETE — ARCHITECTURAL GAPS CONFIRMED  
**Audit type:** Read-only architecture/repository audit; this commit contains documentation only.

## 1. Executive summary

The audit confirms that OEP's existing Reference Library architecture is the correct authority for reusable engineering knowledge needed to interpret engineering diagrams. The current implementation, however, does not yet expose enough of that authoritative knowledge through the production Knowledge Runtime.

The Reference Compiler already produces deterministic package artifacts including `runtime.json`, `search.idx`, and `graph.idx`. The current `OerpReader`/ `KnowledgeRuntime` path primarily consumes `manifest.json` and `runtime.json`, and the runtime currently exposes typed registries for dimensions, units, component models, laws, equations, constraints, and provenance.

The principal gaps are:

1. No authoritative Object Registry in the runtime.
2. No authoritative Relationship Registry in the runtime.
3. Duplicate IDs can be silently overwritten in several existing registry constructions.
4. Cross-reference validation is incomplete.
5. Package identity and runtime identity are conflated.
6. Compiler-produced search/graph indexes have no production Reference Discovery consumer.
7. The canonical Reference Symbol model and the Engine Symbol Library are not yet unified at an authority boundary.
8. The current runtime export is a deliberately narrow vertical slice rather than a general projection of the full EKO model.

These are prerequisites for Reference Discovery and later LLM/vision interpretation.

## 2. Architectural basis

The audit reviewed the existing Knowledge Runtime, OERP reader/package boundary, Reference Compiler/export path, Reference Library specifications, runtime tests, and existing Engine symbol/search components.

The existing architecture establishes the following authority chain:

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

The Reference Library specifications already treat engineering objects and relationships as authoritative knowledge. Relationships are not merely search metadata; they carry engineering meaning and must remain traceable.

This is consistent with the diagram-interpretation direction established during the TRX300 work: the future interpreter should combine visual evidence with authoritative reusable engineering knowledge rather than ask an LLM to invent engineering meaning from pixels alone.

## 3. Compiler/package findings

The Reference Compiler already produces:

- `reference.db`
- `search.idx`
- `graph.idx`
- `runtime.json`
- `manifest.json`
- assets/package content

The search index provides deterministic term-to-object discovery using authored names, aliases, keywords, abbreviations, manufacturer terms, standards references, and related metadata.

The graph index provides deterministic relationship adjacency.

The important architectural finding is that these are already compiled artifacts. A new independent search database is therefore unnecessary.

The missing layer is a production runtime/discovery consumer of these authoritative compiled artifacts.

## 4. KnowledgeRuntime findings

The current runtime provides typed lookup capability for:

- dimensions
- units
- component models
- laws
- equations
- constraints
- provenance

The AP-EK-013 architecture requires broader authoritative object/relationship access.

### F1 — Object Registry

The runtime lacks a general authoritative object registry equivalent to:

`getObject(id)`

This prevents consumers from resolving arbitrary canonical EKO identities through the runtime.

**Disposition:** required follow-up.

### F2 — Relationship Registry

The runtime lacks a general authoritative relationship registry equivalent to:

`getRelationship(id)`

and therefore cannot expose the Reference Library relationship graph through the authoritative runtime boundary.

**Disposition:** required follow-up.

### F3 — Duplicate authority protection

Several registry constructions use map comprehensions. Duplicate IDs can therefore overwrite earlier definitions rather than causing activation failure.

Duplicate detection is required for all authoritative registries.

**Disposition:** required follow-up.

### F4 — Cross-reference validation

Existing validation covers only part of the reference graph. The runtime must validate supported references before activation, including component/equation/constraint/provenance references and relationship source/target references where represented by the current schema.

Dangling references must fail activation rather than silently producing incomplete authority.

**Disposition:** required follow-up.

### F5 — Package/runtime identity distinction

Package identity and runtime identity must remain distinct.

A package such as:

`electrical-core@1.0.0`

identifies knowledge content. It should not simultaneously be treated as the version of the software/runtime interpreting that content.

This distinction will become important when future inference provenance records which reference package and which runtime semantics were used.

**Disposition:** required follow-up.

### F6 — Capability surface

The runtime needs a deterministic capability surface describing which authoritative domains are available in the active package.

This should be derived from immutable package/runtime state and must not become a second source of authority.

**Disposition:** required follow-up.

## 5. Reference Discovery boundary

Reference Discovery should be a separate layer above KnowledgeRuntime.

Recommended boundary:

```
KnowledgeRuntime
    ↓
Reference Discovery
    ↓
Engineering Context
    ↓
future LLM / interpretation
```

KnowledgeRuntime should answer:

> Give me authoritative knowledge by identity.

Reference Discovery should answer:

> Given evidence/context, which authoritative knowledge is relevant?

These are different responsibilities.

The existing Engine/Studio SearchService should not simply be repurposed as Reference Discovery because it searches workspace/diagram state rather than the immutable Reference Library authority.

## 6. Symbol authority

The repository contains two related but currently separate symbol representations.

### Canonical Reference Library

The Reference Library contains Symbol EKOs with canonical identity, classification, relationships, visualization/assets, authority, evidence, and provenance.

The canonical knowledge model already supports relationships such as component-to-symbol representation.

### Engine Symbol Library

The Engine contains a SymbolDefinition/SymbolLibrary representation used by diagram/runtime functionality. It includes concepts such as:

- identifier
- name
- category
- description
- aliases
- standards
- geometry
- ports
- rendering
- validation rules

This is valuable runtime/rendering information.

### Architectural conclusion

Do not create a third symbol database.

The intended future direction should be:

```
Reference Symbol EKO
        ↓
Reference Compiler
        ↓
authoritative runtime knowledge
        ↓
Engine SymbolProvider / rendering adapter
```

The exact field mapping requires a dedicated follow-up audit/implementation package.

## 7. Diagram interpretation implications

The audit confirms the following future conceptual boundary:

```
Diagram
  ↓
OCR / vision / geometry
  ↓
visual evidence
  ↓
Reference Discovery
  ↓
symbols + components + terminals + relationships + terminology
  ↓
Engineering Context
  ↓
LLM / deterministic interpretation
  ↓
Interpretation Record
  ↓
Human Review
  ↓
Engineering Repository
```

The LLM should therefore operate over evidence plus authoritative reference context.

It should not become the authority for engineering facts.

This also explains why the TRX300 annotation exercise should not be expanded merely to collect arbitrary properties such as manufacturer, part number, gauge, or frequency. Those are not inherently required for visual deciphering; reusable engineering meaning belongs in Reference Knowledge when it is needed for interpretation.

## 8. Current runtime export limitation

The current runtime export is a narrow vertical slice.

The component-model projection currently uses a constrained terminal convention rather than providing a general faithful projection of all possible authored component terminal semantics.

This is acceptable for the existing electrical vertical slice but is not sufficient as the final representation for broad diagram interpretation.

This must be addressed before treating the runtime as a complete diagram-interpretation authority.

## 9. Required follow-up sequence

Recommended implementation sequence:

### AP-EKE-013
Complete the authoritative Knowledge Runtime boundary:

- Object Registry
- Relationship Registry
- duplicate-authority rejection
- cross-reference validation
- package/runtime identity separation
- deterministic capabilities
- immutability preservation

### AP-EKE-014
Implement Reference Discovery over the compiled reference package:

- deterministic lookup
- search-index consumption
- graph-index consumption
- alias/terminology discovery
- relationship-aware discovery
- structured ReferenceResult/ReferenceContext

### AP-EKE-015
Resolve the authoritative Symbol boundary between Reference Library Symbol EKOs and the Engine Symbol Library.

### AP-EKE-016
Define the structured Engineering Context delivered to future interpretation.

Only after these boundaries are established should the LLM/vision inference architecture proceed.

## 10. Explicit non-goals

This audit does not authorize or implement:

- LLM inference
- vision inference
- embeddings
- vector search
- automatic diagram extraction
- ReferenceUsage
- InferenceRecord
- training pipelines
- a new symbol database
- a new reference database
- UIF changes
- Reference Vault changes
- EAM changes
- Repository changes

## 11. Audit limitations

This was an architecture/repository audit. It did not modify production implementation.

The audit did not establish that the full Reference Library contains sufficient real-world symbol/component/relationship coverage for production diagram interpretation. That is a content/population question separate from the runtime boundary.

The existing AP-EK-020 electrical vertical slice remains the appropriate regression target while the runtime boundary is expanded.

## 12. Final conclusion

The existing Reference Library architecture is the correct authority for reusable engineering knowledge required to interpret diagrams.

The immediate architectural task is not to build an LLM or make the human annotator enter more engineering properties. It is to expose the existing authoritative knowledge through a complete deterministic runtime and then provide a dedicated Reference Discovery layer.

The next implementation package is therefore:

**AP-EKE-013 / WP-EKE-013 — Complete Authoritative Knowledge Runtime Boundary.**
