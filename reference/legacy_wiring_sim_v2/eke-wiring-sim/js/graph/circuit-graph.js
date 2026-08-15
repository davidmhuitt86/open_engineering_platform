/**
 * js/graph/circuit-graph.js
 *
 * Stateful singleton holding the current vehicle's circuit graph.
 *
 * Updated every time GraphBuilder.build() or GraphBuilder.rebuild() is called.
 * All diagnostic modules access the graph via EKE.graph (preferred) or
 * CircuitGraph.graph (legacy compatibility).
 *
 * Graph structure:
 *   nodes     — Map<moduleId, GraphNode>
 *   edges     — Map<wireId, GraphEdge>
 *   modules   — Map<moduleId, module>
 *   terminals — Map<"moduleId::termName", terminal>
 *   wires     — Map<wireId, wire>
 *
 * No DOM. No rendering. No UI.
 */

const CircuitGraph = {

  /** @type {GraphData|null} */
  graph: null,

  // ── Build / rebuild ───────────────────────────────────────────────

  build(modules, wires) {
    this.graph = GraphBuilder.build(modules, wires);
    return this.graph;
  },

  rebuild(modules, wires) {
    this.graph = GraphBuilder.rebuild(modules, wires);
    return this.graph;
  },

  isReady() {
    return this.graph !== null;
  },

  // ── Node accessors ────────────────────────────────────────────────

  node(moduleId) {
    return this.graph ? this.graph.nodes.get(moduleId) : null;
  },

  edge(wireId) {
    return this.graph ? this.graph.edges.get(wireId) : null;
  },

  module(moduleId) {
    return this.graph ? this.graph.modules.get(moduleId) : null;
  },

  terminal(moduleId, termName) {
    return this.graph ? this.graph.terminals.get(`${moduleId}::${termName}`) : null;
  },

  wire(wireId) {
    return this.graph ? this.graph.wires.get(wireId) : null;
  },

  // ── Graph stats ───────────────────────────────────────────────────

  get nodeCount() { return this.graph ? this.graph.nodes.size  : 0; },
  get edgeCount() { return this.graph ? this.graph.edges.size  : 0; },
  get wireCount() { return this.graph ? this.graph.wires.size  : 0; },

  // ── Typed node finders ────────────────────────────────────────────

  grounds() {
    if (!this.graph) return [];
    return GraphTraversal.groundNodes(this.graph);
  },

  powerSources() {
    if (!this.graph) return [];
    return GraphTraversal.powerNodes(this.graph);
  },

  connectors() {
    if (!this.graph) return [];
    return GraphTraversal.findNodes(this.graph, m => m.connector === true);
  },

  // ── Traversal convenience ─────────────────────────────────────────

  reachableFrom(moduleId) {
    if (!this.graph) return new Set();
    return GraphTraversal.bfs(this.graph, moduleId);
  },

  circuitOf(moduleId) {
    if (!this.graph) return new Set();
    const nodeIds = GraphTraversal.bfs(this.graph, moduleId);
    const wireIds = new Set();
    this.graph.edges.forEach((edge, wireId) => {
      if (nodeIds.has(edge.fromNode) || nodeIds.has(edge.toNode)) wireIds.add(wireId);
    });
    return wireIds;
  },

  // ── Island detection ──────────────────────────────────────────────

  /**
   * Find disconnected sub-graphs (islands).
   * Returns an array of Sets, each containing the module ids in one island.
   *
   * @returns {Set<string>[]}
   */
  islands() {
    if (!this.graph) return [];
    const unvisited = new Set(this.graph.nodes.keys());
    const result    = [];
    while (unvisited.size > 0) {
      const start   = unvisited.values().next().value;
      const visited = GraphTraversal.bfs(this.graph, start);
      result.push(visited);
      visited.forEach(id => unvisited.delete(id));
    }
    return result;
  },
};
