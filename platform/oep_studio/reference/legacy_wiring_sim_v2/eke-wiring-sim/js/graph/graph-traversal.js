/**
 * js/graph/graph-traversal.js
 *
 * BFS, DFS, and path-finding operations on a CircuitGraph.
 *
 * Used by:
 *   diagnostics/circuit-tracer.js    — find connected sub-graph
 *   diagnostics/power-path.js        — trace source → load
 *   diagnostics/ground-path.js       — find chassis ground paths
 *   diagnostics/fault-locator.js     — walk graph to identify fault candidates
 *
 * No DOM. No rendering. No simulation state. No UI.
 */

const GraphTraversal = {

  /**
   * Breadth-first search from a start node.
   * Calls visitor(node, edge) for each visited node.
   * Returns the Set of visited module ids.
   *
   * @param {CircuitGraph} graph
   * @param {string}       startId   - module id
   * @param {Function}     [visitor] - (node: GraphNode, viaEdge: GraphEdge|null) => void
   * @returns {Set<string>}
   */
  bfs(graph, startId, visitor) {
    const visited = new Set();
    const queue   = [{ id: startId, via: null }];
    while (queue.length) {
      const { id, via } = queue.shift();
      if (visited.has(id)) continue;
      visited.add(id);
      const node = graph.nodes.get(id);
      if (!node) continue;
      if (visitor) visitor(node, via);
      node.edges.forEach(edge => {
        const nextId = edge.fromNode === id ? edge.toNode : edge.fromNode;
        if (!visited.has(nextId)) queue.push({ id: nextId, via: edge });
      });
    }
    return visited;
  },

  /**
   * Depth-first search from a start node.
   *
   * @param {CircuitGraph} graph
   * @param {string}       startId
   * @param {Function}     [visitor]
   * @returns {Set<string>}
   */
  dfs(graph, startId, visitor) {
    const visited = new Set();
    const stack   = [{ id: startId, via: null }];
    while (stack.length) {
      const { id, via } = stack.pop();
      if (visited.has(id)) continue;
      visited.add(id);
      const node = graph.nodes.get(id);
      if (!node) continue;
      if (visitor) visitor(node, via);
      node.edges.forEach(edge => {
        const nextId = edge.fromNode === id ? edge.toNode : edge.fromNode;
        if (!visited.has(nextId)) stack.push({ id: nextId, via: edge });
      });
    }
    return visited;
  },

  /**
   * Find all simple paths between two nodes (DFS with backtracking).
   * Returns an array of wire-id arrays, each representing one path.
   *
   * @param {CircuitGraph} graph
   * @param {string}       fromId
   * @param {string}       toId
   * @param {number}       [maxDepth=20]  - safety limit
   * @returns {string[][]}
   */
  allPaths(graph, fromId, toId, maxDepth = 20) {
    const results = [];
    const dfs = (nodeId, wirePath, visitedNodes) => {
      if (nodeId === toId)            { results.push([...wirePath]); return; }
      if (wirePath.length >= maxDepth) return;
      const node = graph.nodes.get(nodeId);
      if (!node) return;
      node.edges.forEach(edge => {
        if (wirePath.includes(edge.wire.id)) return; // no revisiting edges
        const nextId = edge.fromNode === nodeId ? edge.toNode : edge.fromNode;
        if (visitedNodes.has(nextId)) return;
        visitedNodes.add(nextId);
        wirePath.push(edge.wire.id);
        dfs(nextId, wirePath, visitedNodes);
        wirePath.pop();
        visitedNodes.delete(nextId);
      });
    };
    dfs(fromId, [], new Set([fromId]));
    return results;
  },

  /**
   * Find the shortest path (fewest hops) between two nodes.
   * Returns array of wire ids, or null if no path exists.
   *
   * @param {CircuitGraph} graph
   * @param {string}       fromId
   * @param {string}       toId
   * @returns {string[]|null}
   */
  shortestPath(graph, fromId, toId) {
    const prev  = new Map();   // nodeId → { via: edge, from: nodeId }
    const visited = new Set();
    const queue = [fromId];
    prev.set(fromId, null);
    while (queue.length) {
      const cur = queue.shift();
      if (cur === toId) break;
      if (visited.has(cur)) continue;
      visited.add(cur);
      const node = graph.nodes.get(cur);
      if (!node) continue;
      node.edges.forEach(edge => {
        const nextId = edge.fromNode === cur ? edge.toNode : edge.fromNode;
        if (!prev.has(nextId)) {
          prev.set(nextId, { edge, from: cur });
          queue.push(nextId);
        }
      });
    }
    if (!prev.has(toId)) return null;
    // Reconstruct path
    const wireIds = [];
    let cur = toId;
    while (prev.get(cur)) {
      const { edge, from } = prev.get(cur);
      wireIds.unshift(edge.wire.id);
      cur = from;
    }
    return wireIds;
  },

  /**
   * Find all nodes matching a predicate.
   *
   * @param {CircuitGraph} graph
   * @param {Function}     predicate  - (module: object) => boolean
   * @returns {string[]}  array of module ids
   */
  findNodes(graph, predicate) {
    const result = [];
    graph.nodes.forEach((node, id) => { if (predicate(node.module)) result.push(id); });
    return result;
  },

  /** Convenience: find all ground nodes. */
  groundNodes(graph) { return GraphTraversal.findNodes(graph, m => m.cat === 'ground'); },

  /** Convenience: find all power source nodes. */
  powerNodes(graph)  { return GraphTraversal.findNodes(graph, m => m.cat === 'power');  },
};
