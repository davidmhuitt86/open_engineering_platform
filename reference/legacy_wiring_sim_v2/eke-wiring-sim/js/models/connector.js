/**
 * models/connector.js
 *
 * Represents an inline pass-through connector (multi-pin harness splice).
 *
 * A connector is a specialised module where each terminal has an IN color
 * and an OUT color, representing the wire colors on each side of the connector body.
 *
 * Phase 1 placeholder — connector logic currently handled inside EKEModule
 * via the connector:true flag and "IN|OUT" color syntax.
 *
 * Phase 3 goal: dedicated Connector class with pin-mapping and continuity state.
 *
 * No DOM. No rendering. No UI.
 */

class EKEConnector {
  // Phase 3 implementation.
  // Will extend EKEModule with:
  //   - pinMap: Map<pinName, { colorIn, colorOut }>
  //   - resistance(): number (contact resistance per pin)
  //   - isSeated(): boolean
}
