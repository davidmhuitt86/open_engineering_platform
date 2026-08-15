/**
 * js/diagnostics/system-recognizer.js
 *
 * Identifies electrical systems directly from graph topology.
 *
 * Systems detected:
 *   Starting System      — battery → relay → starter motor
 *   Charging System      — stator → regulator-rectifier → battery
 *   Ignition System      — battery → CDI → ignition coil → spark plug
 *   Lighting System      — battery → headlights / tail light
 *   Safety Interlock     — kill switch, neutral switch, oil switch in CDI path
 *
 * This is foundational for AI reasoning — the engine must understand
 * WHAT systems exist before it can diagnose which one failed.
 *
 * Consumes: EKE.graph via GraphTraversal — never walks WIRES directly.
 *
 * No DOM. No rendering. No UI.
 */

const SystemRecognizer = {

  /**
   * Identify all electrical systems present in the current graph.
   * Returns an array of recognized systems.
   *
   * @returns {ElectricalSystem[]}
   */
  recognize() {
    const graph = EKE.graph;
    if (!graph) return [];

    const systems = [];

    systems.push(...SystemRecognizer._findStartingSystem(graph));
    systems.push(...SystemRecognizer._findChargingSystem(graph));
    systems.push(...SystemRecognizer._findIgnitionSystem(graph));
    systems.push(...SystemRecognizer._findLightingSystem(graph));
    systems.push(...SystemRecognizer._findSafetyInterlocks(graph));

    return systems;
  },

  /**
   * Get a specific system by name.
   * @param {string} name
   * @returns {ElectricalSystem|null}
   */
  getSystem(name) {
    return SystemRecognizer.recognize().find(s => s.name === name) || null;
  },

  // ── System detectors ──────────────────────────────────────────────

  _findStartingSystem(graph) {
    const battery = SystemRecognizer._findByCategory(graph, 'power');
    const starter = SystemRecognizer._findByCategory(graph, 'starter');
    if (!battery.length || !starter.length) return [];

    const path = PathFinder.findShortestPath(battery[0], starter[0]);
    if (!path) return [];

    return [{
      name:        'Starting System',
      description: 'Battery → Starter Relay → Starter Motor',
      components:  [...battery, ...starter, ...SystemRecognizer._nodesOnPath(path, graph)],
      wireIds:     path,
      health:      SystemRecognizer._pathHealth(path),
    }];
  },

  _findChargingSystem(graph) {
    const stator  = graph.nodes.get('alternator-stator');
    const regrect = graph.nodes.get('regulator-rectifier');
    const battery = SystemRecognizer._findByCategory(graph, 'power');

    if (!stator || !regrect || !battery.length) return [];

    const path = PathFinder.findShortestPath('alternator-stator', battery[0]);
    if (!path) return [];

    return [{
      name:        'Charging System',
      description: 'Alternator Stator → Regulator/Rectifier → Battery',
      components:  ['alternator-stator', 'regulator-rectifier', ...battery],
      wireIds:     path,
      health:      SystemRecognizer._pathHealth(path),
    }];
  },

  _findIgnitionSystem(graph) {
    const cdi   = graph.nodes.get('cdi-unit');
    const coil  = graph.nodes.get('ignition-coil');
    const plug  = graph.nodes.get('spark-plug');
    const pulse = graph.nodes.get('pulser-coil');

    if (!cdi) return [];

    const components = ['cdi-unit'];
    if (coil)  components.push('ignition-coil');
    if (plug)  components.push('spark-plug');
    if (pulse) components.push('pulser-coil');

    return [{
      name:        'Ignition System',
      description: 'CDI Unit → Ignition Coil → Spark Plug (triggered by Pulser Coil)',
      components,
      wireIds:     SystemRecognizer._wiresConnecting(components, graph),
      health:      'unknown',
    }];
  },

  _findLightingSystem(graph) {
    const lights = [...graph.nodes.values()].filter(n =>
      n.module && (n.module.cat === 'lighting' || n.module.cat === 'indicator')
    ).map(n => n.id);

    if (!lights.length) return [];

    return [{
      name:        'Lighting System',
      description: 'Headlights, Tail Light, Indicator Lights',
      components:  lights,
      wireIds:     SystemRecognizer._wiresConnecting(lights, graph),
      health:      'unknown',
    }];
  },

  _findSafetyInterlocks(graph) {
    const interlocks = ['kill-switch', 'neutral-switch', 'reverse-switch', 'oil-temp-switch',
                        'left-handlebar-switch'].filter(id => graph.nodes.has(id));

    if (!interlocks.length) return [];

    return [{
      name:        'Safety Interlock System',
      description: 'Kill switch, neutral switch, oil switch, reverse lock — protect CDI circuit',
      components:  interlocks,
      wireIds:     SystemRecognizer._wiresConnecting([...interlocks, 'cdi-unit'], graph),
      health:      'unknown',
    }];
  },

  // ── Helpers ───────────────────────────────────────────────────────

  _findByCategory(graph, cat) {
    return GraphTraversal.findNodes(graph, m => m.cat === cat);
  },

  _nodesOnPath(wireIds, graph) {
    const nodes = new Set();
    wireIds.forEach(wid => {
      const edge = graph.edges.get(wid);
      if (edge) { nodes.add(edge.fromNode); nodes.add(edge.toNode); }
    });
    return [...nodes];
  },

  _wiresConnecting(nodeIds, graph) {
    const nodeSet = new Set(nodeIds);
    const wires   = [];
    graph.edges.forEach((edge, wid) => {
      if (nodeSet.has(edge.fromNode) || nodeSet.has(edge.toNode)) wires.push(wid);
    });
    return wires;
  },

  _pathHealth(wireIds) {
    // Placeholder: future implementation checks active faults on path
    return EKE.conditions && EKE.conditions.faults && wireIds.some(wid => EKE.conditions.faults.has(wid))
      ? 'fault'
      : 'ok';
  },
};

/**
 * @typedef {{
 *   name:        string,
 *   description: string,
 *   components:  string[],
 *   wireIds:     string[],
 *   health:      'ok'|'fault'|'unknown'
 * }} ElectricalSystem
 */
