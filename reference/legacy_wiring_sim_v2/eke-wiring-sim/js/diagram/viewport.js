/**
 * diagram/viewport.js
 *
 * Controls zoom, pan, and fit-to-screen for the diagram canvas.
 *
 * Phase 1: logic lives in renderer.js (applyT, zBy, zReset, pan mousedown/mousemove,
 *          wheel listener, touch pinch handler, minimap click).
 *
 * Phase 2 goal: extract viewport state and all event listeners here.
 *
 * Owns:
 *   scale, tx, ty           — current transform
 *   panActive, panSX/SY/OX/OY — pan drag state
 *   pinch                   — two-finger pinch state
 *
 * Exposes:
 *   applyT()                — apply current transform to #scene
 *   zReset()                — fit canvas to viewport
 *   zBy(delta, cx, cy)      — zoom by delta around client point
 *   panTo(x, y)             — scroll to canvas coordinate
 *
 * No electrical logic. No editing logic. No rendering of modules/wires.
 */
