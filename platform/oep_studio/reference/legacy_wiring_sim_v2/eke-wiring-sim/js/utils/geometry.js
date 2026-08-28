/**
 * utils/geometry.js
 *
 * Pure geometry helpers used by the wire renderer for path routing.
 *
 * Phase 1: these functions live inside renderer.js (diagram.js).
 * Phase 2 goal: extract here so wire-renderer.js can import them cleanly.
 *
 * No DOM. No electrical logic. No state.
 */

const Geometry = {
  /**
   * Build an SVG path string from an array of {x, y} points.
   * @param {{ x: number, y: number }[]} pts
   * @returns {string}
   */
  svgPath(pts) {
    return 'M' + pts.map(p => `${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' L');
  },

  /**
   * Remove redundant collinear points from a path.
   * @param {{ x: number, y: number }[]} pts
   * @returns {{ x: number, y: number }[]}
   */
  cleanPoints(pts) {
    if (pts.length < 3) return pts;
    const out = [pts[0]];
    for (let i = 1; i < pts.length - 1; i++) {
      const a = out[out.length - 1], b = pts[i], c = pts[i + 1];
      const collinearH = Math.abs(a.x - b.x) < 0.5 && Math.abs(b.x - c.x) < 0.5;
      const collinearV = Math.abs(a.y - b.y) < 0.5 && Math.abs(b.y - c.y) < 0.5;
      if (!collinearH && !collinearV) out.push(b);
    }
    out.push(pts[pts.length - 1]);
    return out;
  },

  /**
   * Find the movable interior segments of a routed path.
   * Each segment is a horizontal or vertical run between two non-terminal points.
   *
   * @param {{ x: number, y: number }[]} pts
   * @returns {{ i1: number, i2: number, axis: 'x'|'y' }[]}
   */
  getMovableSegments(pts) {
    const segs = [];
    for (let i = 1; i < pts.length - 2; i++) {
      const p = pts[i], q = pts[i + 1];
      segs.push({
        i1:   i,
        i2:   i + 1,
        axis: Math.abs(p.y - q.y) < 1 ? 'y' : 'x',
      });
    }
    return segs;
  },

  /**
   * Compute the exit stub endpoint from a terminal dot position.
   * @param {{ x: number, y: number }} p  - terminal dot position
   * @param {'up'|'down'|'left'|'right'} dir
   * @param {number} stub  - stub length in canvas pixels
   * @returns {{ x: number, y: number }}
   */
  exitPoint(p, dir, stub = 14) {
    switch (dir) {
      case 'up':    return { x: p.x,        y: p.y - stub };
      case 'down':  return { x: p.x,        y: p.y + stub };
      case 'right': return { x: p.x + stub, y: p.y        };
      case 'left':  return { x: p.x - stub, y: p.y        };
      default:      return { x: p.x,        y: p.y + stub };
    }
  },

  /**
   * Find the longest horizontal segment midpoint — used for wire label placement.
   * Falls back to geometric midpoint.
   *
   * @param {{ x: number, y: number }[]} pts
   * @returns {{ x: number, y: number }}
   */
  labelPoint(pts) {
    let best = null, maxLen = 0;
    for (let i = 0; i < pts.length - 1; i++) {
      const p = pts[i], q = pts[i + 1];
      if (Math.abs(p.y - q.y) < 1) {
        const len = Math.abs(q.x - p.x);
        if (len > maxLen) { maxLen = len; best = { x: (p.x + q.x) / 2, y: p.y }; }
      }
    }
    return best || { x: (pts[0].x + pts[pts.length - 1].x) / 2, y: (pts[0].y + pts[pts.length - 1].y) / 2 };
  },

  /**
   * Snap a value to the nearest grid multiple.
   * @param {number} v
   * @param {number} grid
   * @returns {number}
   */
  snap(v, grid = 6) {
    return Math.round(v / grid) * grid;
  },

  /**
   * Clamp a value between lo and hi.
   */
  clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
  },
};
