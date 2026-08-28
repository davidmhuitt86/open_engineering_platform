/**
 * simulator/voltage-engine.js
 *
 * Future voltage propagation engine.
 *
 * Phase 3+ placeholder.
 *
 * Will calculate actual voltages through the electrical graph by solving
 * Kirchhoff's Voltage Law along each path, rather than using static
 * lookup tables from measurements.json.
 *
 * Responsibilities:
 *   - Trace power paths from source to load
 *   - Calculate voltage drop across resistances
 *   - Determine which wires are energised at each key position
 *   - Support fault injection (open circuits, shorts)
 *
 * Methods (Phase 3):
 *   voltageAt(moduleId, terminalName)  → number (volts)
 *   tracePowerPath(targetModuleId)     → wireId[]
 *   activeWires()                      → wireId[]
 *
 * No DOM. No rendering. No UI.
 */
