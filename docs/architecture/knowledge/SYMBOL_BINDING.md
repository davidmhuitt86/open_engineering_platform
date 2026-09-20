# Symbol Binding Contract (WP-EKE-016)

Builds on `KNOWLEDGE_RUNTIME_BOUNDARY.md` (symbol boundary) and
`REFERENCE_DISCOVERY.md`. Code: `platform/oep_engine/lib/core/symbols/binding/symbol_binding.dart`;
data: `platform/oep_engine/assets/symbol_bindings/reference_symbol_bindings.json`.

## Three things, three roles

```
Reference Symbol   = authoritative semantic/reference identity   (symbol.iec.resistor)
Engine SymbolDefinition = renderer/runtime symbol definition      (resistor)
Symbol Binding     = explicit integration mapping between them
```

**Reference Symbol ID != `SymbolDefinition.identifier`.** They are different
identity systems. A Reference id is never usable as an Engine `symbolId` and an
Engine identifier is never a Reference id, unless an explicit binding says so.
Nothing is inferred from prefixes, case, file names, display names, aliases or
similarity. Engine aliases do not qualify as binding targets.

## Audit findings that shaped the design

- Reference Symbol EKO `symbol.iec.resistor`: identity, classification
  (IEC 60617), authority/evidence, provenance, properties `default_scale`,
  `view_box` (`0 0 100 40`), `lead_count` (2), a `render` behavior ("Diagram
  Studio's own concern"), and `assets/symbol.svg` (IEC rectangle). It defines
  **no port ids, directions or connection semantics**. In the compiled runtime it
  is a `KnowledgeObject` of type `Symbol` (identity, name, domain, tags,
  provenance id); its properties, behavior and SVG stay in the package
  (`reference.db`, `assets/`) and are not exposed by `KnowledgeRuntime` today.
- Engine `SymbolDefinition` (`resistor`): geometry (its own `resistor.svg`, a
  **zigzag/ANSI-style glyph**, viewBox 100x100), renderer-local ports
  (`terminal_a`, `terminal_b`, connection type `signal`, `bidirectional`,
  positions), rendering metadata and `validationRules`.
- `EngineeringNode.symbolId` holds the Engine identifier (persisted as a plain
  string; used by rendering, search, reports, `graph_query`, validation).
- SDD-028: "Symbols contain no Engineering Knowledge... define appearance only."
  SDD-028A Amendment 6 lets a symbol *reference* Knowledge Objects "without
  changing symbol identity" (an Engine -> Reference pointer; not used here).

## Binding representation (decision)

An explicit declarative registry, `symbol_bindings/reference_symbol_bindings.json`:
`{"version": 1, "bindings": [{"referenceSymbolId", "engineSymbolId", "notes"?}]}`,
loaded into an immutable `SymbolBindingRegistry`. Why here and not elsewhere:

- Not in the Reference Library / `.oerp`: a binding is not reference knowledge,
  and putting Engine ids into the Reference Library would let an Engine detail
  leak into the authority (and needs a compiler/schema change).
- Not in `SymbolDefinition` (SDD-028A Amendment 6 alternative): that puts a
  Reference id inside the renderer's data, needs edits to symbol JSON and the
  model, and makes the Engine the holder of a pointer into reference knowledge.
  It stays available later as an *additive* Engine -> Reference annotation.
- One file makes duplicates, ambiguity and orphaned bindings checkable in one
  place. No second Reference store and no second symbol library is created.

## Cardinality

One Reference Symbol -> exactly one Engine definition, and an Engine definition
serves at most one Reference Symbol. Both violations are `ambiguousBinding`.
Renderer profiles (screen/print/alternate standard) do not exist in the
repository today, so none is modelled; a profile would be an additive field.
Engine -> Reference lookup is deliberately not provided.

## Resolution and failures

`SymbolBindingAdapter.resolve(referenceSymbolId)` uses the active
`KnowledgeRuntime` (`getObject`), an explicit `SymbolBindingRegistry`, and the
existing `SymbolProvider` (`lookup`, never `resolve`, so no "unknown" symbol is
fabricated). It reads no YAML/`reference.db`/index. Order and typed errors
(`SymbolBindingException.code`):

| Condition | Code |
|---|---|
| Reference id not in the runtime | `referenceSymbolNotFound` |
| Object exists but `objectType != Symbol` | `referenceObjectNotSymbol` |
| Symbol has no explicit binding | `bindingMissing` |
| Bound Engine symbol not registered | `engineSymbolNotFound` |
| Reference id bound twice, or one Engine id bound to two Reference ids | `ambiguousBinding` |
| Malformed file, unsupported version, empty/padded ids, target reachable only by alias | `invalidBinding` |

There is never a fallback to a similar symbol. `audit()` lists bindings that do
not resolve against the active package. "Incompatible port mapping" and
"unsupported renderer/profile" cannot arise: the Reference side defines no ports
(and the runtime exposes no `lead_count`), and no profile concept exists.

The result, `ResolvedSymbolBinding`, holds the `SymbolBinding`, the runtime's own
`KnowledgeObject` and the provider's own `SymbolDefinition`; both identities
are kept and never merged. Reference metadata such as classification, standards,
asset/visualization info stays in the package; the adapter exposes the
`KnowledgeObject` (identity, name, tags, provenance id) and does not copy
fields into the Engine model.

## Port contract (deliberate separation)

| Field | Owner |
|---|---|
| `SymbolPort.id`, `displayName` | Engine renderer-local (unresolved as a shared vocabulary; Reference defines none) |
| `SymbolPort.x/y`, `rotation`, `visible` | Rendering/layout (Engine) |
| `SymbolPort.connectionType`, `direction` | Engine renderer-local metadata; **not consumed anywhere** outside the symbol models, and not Reference knowledge |
| `Port.id/name/direction/type/metadata` (Engineering Graph) | Engineering Graph semantics (project data) |
| Reference port semantics | Do not exist today |

The adapter does not populate or mutate `EngineeringNode.ports` and takes no
graph; it fabricates no terminals from geometry. Constructing node ports from a
recognized symbol belongs to the future diagram-interpretation / graph
construction layer, until an authoritative Reference port contract exists.

## Validation rules status

`SymbolDefinition.validationRules` (`requiredPortIds`, `allowedConnectionTypes`,
`requiredMetadataKeys`) are parsed but **not enforced**: `ValidationService` only
checks that a node's `symbolId` resolves in `SymbolProvider.lookup`
(`missing_symbol` / `unknown_symbol`). They are renderer/runtime metadata, not
authoritative engineering rules, were not moved into Reference Knowledge, and no
enforcement was added. A test records the current behaviour.

## Asset contract

The Reference SVG (`symbol.svg`, IEC rectangle, viewBox `0 0 100 40`) and the
Engine SVG (`resistor.svg`, zigzag, viewBox `0 0 100 100`) are separate assets and
stay separate. The adapter migrates and duplicates no assets. **Known
caveat**: the only shipped binding maps the IEC rectangle Reference symbol to an
Engine glyph that is not the IEC rectangle. The binding is what the work package
specified; the mismatch is recorded in the binding's `notes`. Resolving it needs
an Engine symbol with matching geometry (out of scope; SDD-028 is not redesigned).

## Compatibility and versioning

- Existing diagrams keep `symbolId: resistor`; nothing is rewritten, no diagram
  serialization changed, and the binding is not persisted in diagrams. A Reference
  id is not a valid `symbolId`.
- The binding file has a schema `version` only. It records no Reference package
  version and no Engine symbol version. Changing a binding, renaming/removing an
  Engine symbol or changing Reference identity is therefore not tracked, and
  historical diagrams (which store Engine ids only) are unaffected by binding
  edits. Versioned bindings are a documented limitation, not implemented.

## Discovery and future interpretation

```
ReferenceDiscovery.search(...) -> symbol.iec.resistor (Reference id)
   -> KnowledgeRuntime.getObject -> Symbol Binding -> Engine SymbolDefinition
```

ReferenceDiscovery still returns Reference ids only. Future diagram
interpretation (evidence -> candidate Reference symbol id -> human review ->
binding -> graph construction) will use this contract; none of that, nor
recognition, LLM/vision or inference, is implemented here.
