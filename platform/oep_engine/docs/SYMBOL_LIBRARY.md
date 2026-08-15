# Symbol Library

Governed by SDD-028 (Symbol Definition Specification). Symbols are data —
never code. See `docs/ARCHITECTURE_DECISIONS.md` ADR-007.

---

## Symbol Definition shape (`lib/core/symbols/models/`)

Every symbol (`assets/symbols/<id>.json`) declares:

```json
{
  "identifier": "battery",
  "name": "Battery",
  "category": "electrical",
  "description": "...",
  "aliases": ["battery", "dc_source", "cell"],
  "standards": ["iec", "ansi"],
  "geometry": { "kind": "svgAsset", "assetPath": "assets/symbols/battery.svg", "width": 100, "height": 100 },
  "ports": [ { "id": "positive", "displayName": "Positive", "connectionType": "power", "direction": "output", "x": 0.0, "y": 0.5 } ],
  "rendering": { "defaultColor": "#1a1a1a", "strokeWidth": 1.5, "fill": false, "layer": 0, "snapPoints": [] },
  "validationRules": { "requiredPortIds": ["positive", "negative"], "allowedConnectionTypes": ["power"], "requiredMetadataKeys": [] }
}
```

`SymbolPort` (position/rotation/visibility) is deliberately a different
type from the graph's `Port` — the graph carries no layout (SDD-024), but
a Symbol legitimately needs geometric port placement to render connection
anchors. That's rendering data, not engineering knowledge.

## The 14 seed symbols

`Battery`, `Ground`, `Fuse`, `Relay`, `SPST Switch`, `SPDT Switch`,
`Connector`, `Lamp`, `Motor`, `Resistor`, `Capacitor`, `Diode`,
`Ignition Coil`, `Generic Module` — one JSON definition + one hand-authored
SVG geometry file each, under `assets/symbols/`. `Generic Module` is also
the fallback used for `SymbolDefinition.unknown()`.

## Loading (`lib/core/symbols/library/symbol_library.dart`)

`SymbolLibrary implements SymbolProvider`:

- `initialize()` — scans a real filesystem directory (`dart:io`) for
  `*.json` files and registers each. Correct for plain-Dart contexts
  (unit tests, tooling) where `assets/symbols` is a real path.
- `registerFromJson(String)` — parses and registers one definition from
  raw JSON text, for hosts that can only load bundled assets (e.g. a
  Flutter app via `rootBundle`, which has no directory-listing concept at
  runtime). The Demonstration Host uses this exclusively — see
  `example/lib/symbol_bundle_loader.dart`.
- `lookup(identifier)` — resolves by identifier or case-insensitive alias;
  `null` if unregistered.
- `resolve(identifier)` — same, but falls back to
  `SymbolDefinition.unknown(identifier)` instead of `null` (SDD-028:
  "Unknown Symbols remain valid... may later be classified").
- `search(query)` — matches identifier, name, or aliases.

## Unknown symbols

A node may reference a `symbolId` the library doesn't recognize (e.g.
mid-extraction, before classification). `resolve()` never throws or
returns `null` for this — it hands back a synthetic "Unknown Symbol"
definition using the Generic Module geometry, so rendering and validation
degrade gracefully rather than breaking. `ValidationService` still flags
it (`unknown_symbol`, warning severity) so it stays visible for review.

## Standards and categories

`SymbolCategory`: electrical, mechanical, hydraulic, pneumatic,
instrumentation, process, general.
`SymbolStandard`: SAE, IEC, ANSI, ISO, custom.

Both are enums today (Phase 1's 14 seed symbols cover a narrow domain);
SDD-028 doesn't preclude widening them as more symbol packages are added
in later phases or via Marketplace extensions (SDD-029).
