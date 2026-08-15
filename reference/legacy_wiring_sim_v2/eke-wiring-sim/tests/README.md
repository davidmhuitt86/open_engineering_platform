# tests/

Test suite for the Electrical Knowledge Engine.

Phase 2+ — tests will be added as subsystems are extracted from app.js.

## Planned test files

### Unit tests (Phase 2)

- `models/vehicle.test.js`       — Vehicle, Module, Terminal, Wire construction and serialization
- `models/wire.test.js`          — Reading normalization, getReading(), fromLegacy()
- `utils/geometry.test.js`       — svgPath, cleanPoints, getMovableSegments, labelPoint
- `utils/colors.test.js`         — wireHex, stripeHex, wireName, categoryHex
- `utils/ids.test.js`            — sanitize, terminalDotId, newModuleId, isUserWireId

### Integration tests (Phase 3)

- `simulator/meter-engine.test.js`      — reading resolution, fault overrides, hasFlow
- `simulator/state-manager.test.js`     — key position, fault injection/clear
- `diagnostics/circuit-tracer.test.js`  — BFS traversal, traceFromWire, traceFromModule

### Run

```bash
# Phase 2: plain Node (no DOM required for model/utils tests)
node --experimental-vm-modules tests/models/wire.test.js

# Phase 3: add jsdom for simulator/diagnostics tests
npm test
```
