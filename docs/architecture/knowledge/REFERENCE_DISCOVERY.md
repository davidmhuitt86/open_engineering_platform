# Reference Discovery (WP-EKE-014)

Builds on `KNOWLEDGE_RUNTIME_BOUNDARY.md` (WP-EKE-013). Governing specs:
SDD-R004 §10-11 (package indexes), SDD-R007 (discovery; only the exact/alias
search and relationship-navigation modes the compiled indexes support),
AP-EK-013.

## Boundary

```
Reference Library -> Compiler -> .oerp
                                   |- runtime.json --> OerpReader --> KnowledgeRuntime   (authoritative typed knowledge)
                                   |- search.idx   -+
                                   |- graph.idx    -+-> OerpReader.readDiscoveryIndexes --> ReferenceDiscovery  (retrieval of ids)
                                   '- assets/
```

- **KnowledgeRuntime** = authoritative typed reference runtime. Defines objects,
  relationships, units, models, laws, equations, constraints, provenance.
- **ReferenceDiscovery** = deterministic retrieval over the package's
  precompiled indexes. It returns **identifiers** that resolve through the
  KnowledgeRuntime. It holds no object or relationship definitions, reads no
  package files, and modifies nothing.
- **Search Index** = token -> authoritative object ids.
- **Graph Index** = outgoing relationship adjacency (relationship ids).
- **ReferenceDiscovery is not a second Reference Library.** A search hit is not
  knowledge (`search("resistor")` -> `symbol.iec.resistor` says nothing about
  what the symbol *is*); a graph edge is not the relationship definition.
  Callers resolve: `hit.objectId` -> `runtime.getObject(...)`,
  `edge.relationshipId` -> `runtime.getRelationship(...)`.
- It is unrelated to the workspace/diagram `SearchService` (`lib/core/search`);
  the two are separate domains and are not merged.

## Compiled index formats (from `compiler/indexes.py`, verified on a real `.oerp`)

```
search.idx  {"version": 1, "terms": {"<token>": ["<objectId>", ...]}}
graph.idx   {"version": 1, "nodes": {"<objectId>": [
              {"relationship_id": "...", "relationship_type": "...", "target": "..."}]}}
```

- Tokens are lower-case `[a-z0-9]+` runs taken from short/display name and the
  classification fields tags, keywords, aliases, abbreviations, alternate
  names, manufacturer terms and standards references. Multi-word phrases are
  split into tokens, so phrase boundaries are not recoverable. **The index
  records no field of origin**, so results report matched tokens, not fields.
  Non-ASCII characters were dropped at compile time (e.g. `Ω` yields no token).
- `graph.idx` lists **outgoing** edges only; the edge source is the node key.
  Edges are ordered by (relationship type, target, relationship id); every
  object is a node (empty list when it has no outgoing edges). Cardinality,
  confidence, lifecycle and notes are *not* in the index.

## Behaviour

Ownership: `OerpReader` reads the archive members (`readDiscoveryIndexes`);
`ReferenceDiscoveryIndexes` parses/validates them; `ReferenceDiscovery.create(runtime, indexes)`
binds them to the runtime. Nothing above these knows how the indexes are
serialized, and the compiler is not a runtime dependency.

**Search** `search(query, {requireAllTerms = false})`
- Query normalization is exactly the compiler tokenization (lower-case,
  `[a-z0-9]+`), duplicates removed. No stemming, prefix/fuzzy matching,
  synonyms or semantic expansion.
- An object matches on at least one token (all tokens with `requireAllTerms`).
- Order is total and reproducible: score (distinct query tokens matched)
  descending, then object id ascending. Each object appears once;
  `matchedTerms` is sorted. No hash iteration order, timestamps or randomness
  affects the output.
- An empty / token-free query, and a query with no matches, are valid empty
  results (`[]`), not errors.

**Graph** `outgoing(objectId)`, `relatedObjectIds(objectId)`
- Returns the compiled outgoing edges (ids + type) / distinct sorted target ids.
- An unknown object throws `referenceNotFound` (the runtime's own error); an
  object with no edges returns `[]`.
- Incoming-edge traversal is **not** offered because `graph.idx` does not index
  it; `KnowledgeRuntime.relationshipsForObject` is the authority for both
  directions. Discovery does not build a competing index (SDD-R004 §10: the
  runtime does not build indexes).

**Errors** (existing `KnowledgeRuntimeException` taxonomy; nothing is invented)
- Missing `search.idx`/`graph.idx` in the archive, invalid JSON, wrong shape,
  bad term/edge/posting, duplicate relationship id -> `packageInvalid`.
  A malformed index is never read as empty.
- `version` other than 1 -> `schemaUnsupported`.
- Indexes that disagree with the active runtime (an object or relationship the
  runtime lacks, an edge whose source/target/type differs, or a runtime
  relationship missing from the graph) -> `packageInvalid` at `create`, so every
  id Discovery later returns is guaranteed to resolve.
- There is no backward-compatibility behaviour for packages without indexes:
  both are part of the compiled-package contract.

**Capabilities** (`ReferenceDiscovery.capabilities`, separate from
`KnowledgeRuntimeCapabilities`): `termSearch`, `relationshipTraversal`,
index versions, indexed term/object counts, graph edge count.

## Not implemented (by design)

Property, behavior, natural-language, semantic, fuzzy and vector search;
embeddings; LLM/vision; ranking by relationship distance, context or authority;
incoming-edge traversal; any Studio/UI integration.

## Symbols

Discovery treats symbols as ordinary Reference Library objects: a search may
return `symbol.iec.resistor`. It does **not** equate that with the Engine
`SymbolDefinition` `resistor`, and no mapping exists (see the symbol boundary in
`KNOWLEDGE_RUNTIME_BOUNDARY.md`). That belongs to the future Symbol Knowledge
Adapter.

## Intended future flow (none of it implemented here)

```
Diagram evidence -> deterministic extraction / OCR / vision
   -> ReferenceDiscovery -> candidate reference context (ids)
   -> KnowledgeRuntime (authoritative typed objects)
   -> LLM/Vision interpretation -> InferenceRecord
   -> human review -> KnowledgeCandidate -> Engineering Repository
```

ReferenceDiscovery retrieves. KnowledgeRuntime defines authoritative reference
knowledge. The future inference layer interprets. Human review decides.
Repository commit establishes accepted project engineering truth. The future
layer calls `ReferenceDiscovery`; it must not parse `search.idx`/`graph.idx`.

## Verification

- `test/knowledge/reference_discovery_test.dart`: index-format fixtures.
- `tool/verify_reference_discovery.dart`: real compiled `core_reference` package
  (compiler -> `.oerp` -> `OerpReader` -> `KnowledgeRuntime` -> `ReferenceDiscovery`).
