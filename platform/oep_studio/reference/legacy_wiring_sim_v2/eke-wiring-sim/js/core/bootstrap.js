/**
 * js/core/bootstrap.js
 *
 * Orchestrates the full application startup sequence.
 *
 * Sequence:
 *   1. Load vehicle data (VehicleLoader)
 *   2. Build circuit graph (GraphBuilder)
 *   3. Run graph validators (GraphValidators)
 *   4. Store results in EKE context (app-context.js)
 *   5. Initialize subsystems in dependency order:
 *        Diagram → Editor → Simulator → Diagnostics → UI
 *
 * This is the only place that knows about startup ordering.
 * No subsystem initializer should call another.
 *
 * No DOM. No rendering. No electrical logic.
 */

const Bootstrap = {

  async run(vehicleId) {
    EKE.status = 'loading';

    // 1. Load vehicle data
    const vehicle = await VehicleLoader.load(vehicleId);

    // 2. Build circuit graph
    const graph = GraphBuilder.build(vehicle.modules, vehicle.wires);

    // 3. Validate graph
    const validationResults = GraphValidators.runAll(graph, vehicle);
    EKE.validationResults = validationResults;

    if (validationResults.some(r => r.severity === 'error')) {
      console.warn('[EKE] Graph validation errors:', validationResults.filter(r => r.severity === 'error'));
    }

    // 4. Store in application context
    // Initialise simulation conditions (keyPosition syncs with app.js keyPos global)
    EKE.conditions = {
      keyPosition:  0,
      switchStates: {},
      faults:       new Map(),
      engineState:  {},
    };
    EKE.setVehicle(vehicle, graph);

    // 5. Populate runtime globals used by renderer and editor
    // These remain for backward compatibility during the Phase 2→3 transition.
    // Phase 4 goal: subsystems read from EKE.vehicle and EKE.graph directly.
    MODULES      = vehicle.modules;
    WIRES        = vehicle.wires;
    MEASUREMENTS = vehicle.measurements;
    DEFAULT_POS  = vehicle.layout;

    // 6. Initialize each subsystem
    Bootstrap._initDiagram(vehicle);
    Bootstrap._initEditor(vehicle);
    Bootstrap._initSimulator(vehicle);
    Bootstrap._initDiagnostics(vehicle, graph);
    Bootstrap._initUI(vehicle, graph, validationResults);
  },

  // ── Subsystem initializers ────────────────────────────────────────

  _initDiagram(vehicle) {
    MODULES.forEach(m => {
      positions[m.id] = Object.assign({}, DEFAULT_POS[m.id] || { x: 50, y: 50 });
    });
    placeCards();
    requestAnimationFrame(() => {
      zReset(); drawWires(); initMinimap(); buildLegend();
      const tw = document.getElementById('topbar-wrap');
      const mp = document.getElementById('mod-panel');
      if (tw && mp) mp.style.top = tw.offsetHeight + 'px';
    });
  },

  _initEditor(_vehicle) {
    vp.addEventListener('click', e => {
      if (e.target.closest('.mod-card') || e.target.closest('#fp') || e.target.closest('#mip')) return;
      if (e.target.closest('.wire-hit')) return;
      if (wireMode || routeEditMode) return;
      if (selW) { selW = null; closePanel(); leadR = null; leadB = null; clearLeadDots(); tracedWires.clear(); drawWires(); }
      if (selM) { closeModInfo(); drawWires(); }
    });
  },

  _initSimulator(_vehicle) {
    if (window.SWPACK) SWPACK.init();
  },

  _initDiagnostics(_vehicle, graph) {
    // Diagnostics modules consume EKE.graph directly — no separate init needed.
    // CircuitGraph singleton also holds a reference for legacy callers.
    CircuitGraph.graph = graph;
    EKE.register('diagnostics', {
      graph,
      GraphTraversal,
      PathFinder,
      DependencyTracker,
      CircuitTracer,
      SystemRecognizer,
      FaultInjector,
      ElectricalSolver,
    });
  },

  _initUI(_vehicle, _graph, validationResults) {
    // Surface any validation errors through the graph inspector
    if (typeof GraphInspector !== 'undefined') {
      GraphInspector.setResults(validationResults);
    }
    EKE.register('ui', { GraphInspector });
  },
};
