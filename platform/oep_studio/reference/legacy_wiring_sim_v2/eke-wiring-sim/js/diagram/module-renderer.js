/**
 * diagram/module-renderer.js
 *
 * Responsible for building and updating module card DOM elements.
 *
 * Phase 1: logic lives in renderer.js (buildCard, buildStdCard, buildBulbCard,
 *          buildConnCard, placeCards, removeCard, rebuildCard).
 *
 * Phase 2 goal: extract those functions here.
 * Each module type will have its own render strategy:
 *   - StandardRenderer    → rectangular card with terminal strip
 *   - BulbRenderer        → SVG bulb symbol
 *   - ConnectorRenderer   → inline pass-through connector body
 *
 * Inputs:  EKEModule objects + layout positions
 * Outputs: DOM elements appended to #canvas
 *
 * No electrical calculations. No simulation. No save logic.
 */
