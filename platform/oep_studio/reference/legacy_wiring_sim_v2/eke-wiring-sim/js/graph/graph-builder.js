/**
 * js/graph/graph-builder.js
 *
 * Builds the circuit graph from vehicle data.
 *
 * Graph structure:
 *   nodes      — Map<nodeId, GraphNode>    one per module
 *   edges      — Map<wireId, GraphEdge>    one per wire
 *   modules    — Map<moduleId, module>     fast module lookup
 *   terminals  — Map<"moduleId::termName", terminal>  fast terminal lookup
 *   wires      — Map<wireId, wire>         fast wire lookup
 *
 * Node types (current):
 *   module, ground, connector
 *
 * Node types (future):
 *   splice, fuse, relay-contact, can-node, lin-node
 *
 * No DOM. No rendering. No UI. No simulation.
 */

const GraphBuilder = {

  /**
   * Build a circuit graph from vehicle module and wire arrays.
   *
   * @param {object[]} modules
   * @param {object[]} wires
   * @returns {GraphData}
   */
  build(modules, wires) {
    /** @type {Map<string, GraphNode>} */
    const nodes = new Map();

    /** @type {Map<string, GraphEdge>} */
    const edges = new Map();

    /** @type {Map<string, object>} */
    const modulesMap = new Map();

    /** @type {Map<string, object>} */
    const terminalsMap = new Map();

    /** @type {Map<string, object>} */
    const wiresMap = new Map();

    // ── Seed nodes from modules ─────────────────────────────────────
    modules.forEach(m => {
      modulesMap.set(m.id, m);

      // Determine node type
      let type = 'module';
      if (m.cat === 'ground')    type = 'ground';
      if (m.connector)           type = 'connector';

      nodes.set(m.id, {
        id:       m.id,
        type,
        module:   m,
        edges:    [],
        label:    m.label,
      });

      // Index terminals
      (m.terminals || []).forEach(t => {
        terminalsMap.set(`${m.id}::${t.n}`, {
          moduleId: m.id,
          name:     t.n,
          color:    t.c,
        });
      });
    });

    // ── Build edges from wires ──────────────────────────────────────
    wires.forEach(w => {
      wiresMap.set(w.id, w);

      const fromNode = nodes.get(w.from.m);
      const toNode   = nodes.get(w.to.m);

      // Skip wires referencing modules not in the graph
      if (!fromNode || !toNode) return;

      const edge = {
        id:       w.id,
        wire:     w,
        fromNode: w.from.m,
        toNode:   w.to.m,
        fromTerm: w.from.t,
        toTerm:   w.to.t,
        color:    w.c,
        label:    w.lbl,
      };

      edges.set(w.id, edge);
      fromNode.edges.push(edge);
      toNode.edges.push(edge);
    });

    return { nodes, edges, modules: modulesMap, terminals: terminalsMap, wires: wiresMap };
  },

  /**
   * Rebuild the graph. Returns a fresh object.
   * Call after adding, editing, or removing modules or wires.
   *
   * @param {object[]} modules
   * @param {object[]} wires
   * @returns {GraphData}
   */
  rebuild(modules, wires) {
    return GraphBuilder.build(modules, wires);
  },
};

/**
 * @typedef {{
 *   nodes:     Map<string, GraphNode>,
 *   edges:     Map<string, GraphEdge>,
 *   modules:   Map<string, object>,
 *   terminals: Map<string, object>,
 *   wires:     Map<string, object>
 * }} GraphData
 *
 * @typedef {{
 *   id: string,
 *   type: 'module'|'ground'|'connector'|'splice'|'fuse'|'relay-contact',
 *   module: object,
 *   edges: GraphEdge[],
 *   label: string
 * }} GraphNode
 *
 * @typedef {{
 *   id: string,
 *   wire: object,
 *   fromNode: string,
 *   toNode: string,
 *   fromTerm: string,
 *   toTerm: string,
 *   color: string,
 *   label: string
 * }} GraphEdge
 */
