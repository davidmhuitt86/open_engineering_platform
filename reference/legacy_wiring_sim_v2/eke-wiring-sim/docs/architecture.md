# Electrical Knowledge Engine — Architecture

## Core Rule

The electrical graph is the source of truth.

```
Electrical Graph → Diagram    ✓
Diagram → Data               ✗
```

Modules, terminals, wires, and faults exist independently of the UI.
The diagram is only a visual representation of the electrical model.

---

## Repository Structure

```
trx300-eke/
│
├── index.html                        ← Single HTML page
│
├── css/
│   ├── main.css                      ← All styles (Phase 1)
│   ├── editor.css                    ← Editor-specific styles
│   ├── modules.css                   ← Phase 2: module card styles
│   ├── wires.css                     ← Phase 2: SVG wire styles
│   ├── inspector.css                 ← Phase 2: panel styles
│   └── meter.css                     ← Phase 2: meter panel styles
│
├── js/
│   ├── app.js                        ← Bootstrap (Phase 1: monolith)
│   ├── swpack.js                     ← Switch-pack reading overrides
│   │
│   ├── models/                       ← Electrical graph (no DOM, no UI)
│   │   ├── vehicle.js                ← Root container
│   │   ├── module.js                 ← Component (relay, CDI, battery…)
│   │   ├── terminal.js               ← Connection point
│   │   ├── wire.js                   ← Connection + meter readings
│   │   ├── connector.js              ← Pass-through connector (Phase 3)
│   │   └── fault.js                  ← Injected fault (Phase 3)
│   │
│   ├── diagram/                      ← Visual rendering (no electrical calc)
│   │   ├── renderer.js               ← Master renderer (Phase 1: monolith)
│   │   ├── module-renderer.js        ← Phase 2: card builders
│   │   ├── wire-renderer.js          ← Phase 2: SVG path drawing
│   │   ├── label-renderer.js         ← Phase 2: text labels
│   │   └── viewport.js               ← Phase 2: zoom/pan
│   │
│   ├── editor/                       ← User modifications (no sim, no rendering)
│   │   ├── module-editor.js          ← Drag, add, delete, edit modules
│   │   ├── wire-editor.js            ← Create, delete, edit wires
│   │   ├── routing-editor.js         ← Wire segment nudging
│   │   ├── selection-manager.js      ← Single source of truth for selection
│   │   ├── undo-redo.js              ← Command stack
│   │   └── clipboard.js              ← Copy/paste (Phase 3)
│   │
│   ├── simulator/                    ← Electrical behavior (no DOM, no rendering)
│   │   ├── state-manager.js          ← Key position, fault registry
│   │   ├── meter-engine.js           ← Reading resolution + display values
│   │   ├── voltage-engine.js         ← Phase 3: voltage propagation
│   │   ├── continuity-engine.js      ← Phase 3: continuity/resistance
│   │   ├── resistance-engine.js      ← Phase 3: resistance calculation
│   │   └── diode-engine.js           ← Phase 3: diode test mode
│   │
│   ├── diagnostics/                  ← Fault analysis (no DOM, no rendering)
│   │   ├── circuit-tracer.js         ← Trace connected sub-graph
│   │   ├── power-path.js             ← Phase 3: "show path to starter"
│   │   ├── ground-path.js            ← Phase 3: "all grounds affecting CDI"
│   │   ├── dependency-tracker.js     ← Phase 3: upstream/downstream analysis
│   │   └── fault-locator.js          ← Phase 3/4: "what causes no spark?"
│   │
│   ├── ui/                           ← Visible interface (no electrical calc)
│   │   ├── toolbar.js                ← Mode buttons, zoom, search, legend
│   │   ├── inspector.js              ← Wire/module property panels
│   │   ├── meter-panel.js            ← Multimeter LCD display
│   │   ├── notifications.js          ← Toast messages
│   │   └── dialogs.js                ← Modal forms
│   │
│   ├── storage/                      ← Persistence (no rendering, no electrical)
│   │   ├── vehicle-loader.js         ← Load vehicle from diagrams/
│   │   ├── project-loader.js         ← Load saved project file
│   │   ├── project-saver.js          ← Save project to file/localStorage
│   │   ├── autosave.js               ← Debounced autosave
│   │   └── import-export.js          ← File I/O utilities
│   │
│   └── utils/                        ← Pure helpers (no DOM, no state)
│       ├── geometry.js               ← Wire routing geometry
│       ├── colors.js                 ← Color codes and hex values
│       ├── ids.js                    ← ID generation and sanitization
│       └── events.js                 ← EventBus for inter-module comms
│
├── diagrams/
│   ├── trx300/
│   │   ├── project.json              ← Vehicle metadata
│   │   ├── modules.json              ← Component definitions
│   │   ├── wires.json                ← Wire connections (no readings)
│   │   ├── measurements.json         ← Meter readings per wire per key state
│   │   ├── layout.json               ← Default visual positions
│   │   └── vehicle.json              ← Original source (used to generate data-bundle.js)
│   └── templates/                    ← Starter templates for new vehicles
│
├── docs/
│   └── architecture.md               ← This file
│
├── tests/                            ← Phase 2+
└── exports/                          ← SVG/JSON export output
```

---

## Layer Boundaries

| Layer        | May read from              | Must NOT access          |
|--------------|----------------------------|--------------------------|
| `models/`    | nothing                    | DOM, UI, storage, engine |
| `utils/`     | nothing                    | DOM, UI, state           |
| `simulator/` | models, utils              | DOM, UI, storage         |
| `diagnostics/`| models, simulator, utils  | DOM, UI, storage         |
| `storage/`   | models, utils              | simulator, diagnostics   |
| `diagram/`   | models, utils, simulator   | storage, editor          |
| `editor/`    | models, utils, storage     | simulator, diagnostics   |
| `ui/`        | all layers                 | nothing restricted       |
| `app.js`     | all layers                 | nothing restricted       |

---

## Data Flow

```
diagrams/trx300/
  ├── data-bundle.js   (pre-parsed, loaded as <script> — works on file://)
  ├── project.json     (vehicle metadata + file references)
  ├── modules.json     (component definitions)
  ├── wires.json       (wire topology)
  ├── measurements.json (meter readings per wire per key state)
  └── layout.json      (default visual positions)
         ↓
   js/storage/vehicle-loader.js
   VehicleLoader.load('trx300')
   ├── file://  → reads window.EKE_BUNDLE['trx300'] from data-bundle.js
   └── http://  → fetches the 5 JSON files directly
         ↓
   js/app.js  bootstrap()
   ├── MODULES      = vehicle.modules
   ├── WIRES        = vehicle.wires
   ├── MEASUREMENTS = vehicle.measurements
   └── DEFAULT_POS  = vehicle.layout
         ↓
   js/diagram/renderer.js
   ├── placeCards()   → builds DOM card elements
   ├── drawWires()    → builds SVG wire paths
   └── applyT()       → applies pan/zoom transform
         ↓
   js/graph/circuit-graph.js
   └── CircuitGraph.build(MODULES, WIRES)
       → adjacency graph for diagnostics
```

---

## Adding a New Vehicle (Phase 2+)

1. Create `diagrams/<vehicle-id>/` with the 5 JSON files
2. Call `VehicleLoader.load('<vehicle-id>')` in app.js
3. No engine code changes required
4. No diagram/renderer changes required

---

## Refactor Phases

### Phase 1 (current)
- Full directory structure created
- All files present (working code or documented placeholders)
- App runs from: `data-bundle.js` → `swpack.js` → `diagram/renderer.js` → subsystems → `app.js`
- All logic still in `app.js` and `diagram/renderer.js`

### Phase 2
- Extract subsystem logic from `app.js` into designated files
- `app.js` becomes bootstrap only (<200 lines)
- Convert to ES modules (`type="module"`)

### Phase 3
- Implement `models/` classes as source of truth
- Implement `simulator/` engines (voltage, continuity)
- Implement `diagnostics/` (power-path, ground-path, fault-locator)
- Fault injection and training system

### Phase 4
- AI-assisted diagnostics
- Natural-language fault reasoning
- Multi-vehicle support
