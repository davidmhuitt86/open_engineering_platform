/**
 * diagram/label-renderer.js
 *
 * Responsible for rendering text labels on the diagram:
 *   - Wire color + label badges at wire midpoints
 *   - Terminal name labels on module cards
 *   - Category labels on legend
 *
 * Phase 1 placeholder — label rendering is currently inline in renderer.js
 * and module card innerHTML.
 *
 * Phase 2 goal: dedicated label placement engine that avoids overlapping,
 * supports zoom-aware font sizing, and separates label data from rendering.
 *
 * No electrical calculations. No editing logic.
 */
