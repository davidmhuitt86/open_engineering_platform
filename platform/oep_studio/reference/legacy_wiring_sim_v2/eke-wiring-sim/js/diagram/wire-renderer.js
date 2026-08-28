/**
 * diagram/wire-renderer.js
 *
 * Responsible for drawing SVG wire paths, labels, flow animation,
 * and route-edit segment handles.
 *
 * Phase 1: logic lives in renderer.js (route, drawWires, addFlowOverlay,
 *          startFlowAnim, stopFlowAnim, allocX, allocY, cleanPts, getMovableSegs).
 *
 * Phase 2 goal: extract those functions here.
 *
 * Supports:
 *   - Color coding (solid + bi-color stripe)
 *   - Wire labels at midpoint
 *   - Dimming non-selected wires
 *   - Glow highlight for selected / traced wires
 *   - Flow animation overlay (current direction indicator)
 *   - Route-edit segment handles (click to select, arrow-key nudge)
 *
 * Inputs:  EKEWire objects + layout wireRoutes + simulation state
 * Outputs: SVG elements in #wire-layer
 *
 * No editing logic. No save logic. No electrical calculations.
 */
