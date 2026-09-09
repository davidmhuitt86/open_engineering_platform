/**
 * knowledge/behaviors/multi-switch.js
 *
 * AP-MULTI-SWITCH-001 — real, multi-position switch continuity, per a
 * direct factory switch-continuity table (Ignition/Lighting/Dimmer/
 * Engine Stop/Starter switches) rather than the simple single-pin-pair
 * open/closed model `switch.js`'s SwitchBehavior already covers.
 *
 * Recognizes a module by its TERMINAL NAME SET (order-independent) —
 * not a hardcoded module id — so it works immediately with whatever the
 * user already has on their diagram (their own Ignition Switch/Left
 * Handlebar Switch modules, auto-generated ids and all), no re-creating
 * modules needed.
 *
 * A "closed pair" here means two of THIS SAME MODULE's own terminals
 * are internally bridged for the given state — e.g. the ignition switch
 * bridging its own BAT1 to its own BAT2. That's not a graph edge (edges
 * only ever connect two DIFFERENT modules) — it's consulted directly by
 * VoltagePropagator/GroundPropagator's own BFS (the same per-node
 * "which of my edges may this signal continue out of" mechanism
 * AP-CONNECTOR-BRIDGE-001 already added for connectors, just with a
 * different rule for deciding which pairs pass).
 *
 * No DOM. No rendering. No UI.
 */
const MultiSwitchBehavior = {

  /**
   * Real per-switch continuity, verbatim from the factory switch-
   * continuity table (photo, direct request):
   *
   *   Ignition Switch   — BAT1/BAT2/BAT3/IG1 — OFF: open. ON: BAT1-BAT2
   *                        AND BAT3-IG1 (two separate closed pairs).
   *   Left Handlebar Switch — the user's own single physical module
   *     bundles what the factory manual splits into three separate
   *     switches (Lighting/Dimmer/Engine Stop) plus the Starter button,
   *     all on one set of terminals (BAT2/TL/LO/HI/IG1/IG2/ST) — so
   *     this one definition has FOUR independent groups instead of one:
   *       lights (off/on):      ON closes BAT2-TL (taillight always
   *                              hot with lights on, regardless of beam).
   *       dimmer (hi/lo):       only matters when lights=on — closes
   *                              BAT2-HI or BAT2-LO to match.
   *       engineStop (off/run): RUN closes IG1-IG2.
   *       starter (free/push):  PUSH closes BAT2-ST.
   *   (Recognized separately if the user's diagram instead has these as
   *   4 distinct physical modules — see the 4 single-group defs below.)
   *
   * AP-MULTI-SWITCH-002 — the Dimmer's real table shows a 3rd row (an
   * up/down-arrow icon) with Hi/(HL)/Lo all three tied together. Treated
   * here as just a legend icon for "this rocker toggles between the Hi
   * and Lo rows" — NOT a real 3rd electrical position. Confirmed directly:
   * it's a genuine 2-position switch that connects either the HI filament
   * or the LO filament, never both at once.
   */
  DEFS: [
    {
      id: 'ignitionSwitch',
      terms: ['BAT1', 'BAT2', 'BAT3', 'IG1'],
      groups: { power: ['off', 'on'] },
      // AP-MULTI-SWITCH-001 — the true resting state (key out/off),
      // independent of each group's own display order — see
      // `defaultState`'s own doc comment for why this is separate from
      // `groups[g][0]`.
      defaults: { power: 'off' },
      closedPairs(state) {
        if (state.power !== 'on') return [];
        return [['BAT1', 'BAT2'], ['BAT3', 'IG1']];
      },
    },
    {
      id: 'handlebarSwitch',
      terms: ['BAT2', 'TL', 'LO', 'HI', 'IG1', 'IG2', 'ST'],
      groups: { lights: ['off', 'on'], dimmer: ['lo', 'hi'], engineStop: ['off', 'run'], starter: ['free', 'push'] },
      // AP-MULTI-SWITCH-001 — matches SWPACK's own initial `state`
      // (js/swpack.js: lights:'off', beam:'lo', kill:'run', start:false)
      // exactly, so a diagram loads with the same effective switch
      // positions SWPACK's own panel already shows as active, before the
      // user has touched anything.
      defaults: { lights: 'off', dimmer: 'lo', engineStop: 'run', starter: 'free' },
      closedPairs(state) {
        const pairs = [];
        if (state.lights === 'on') {
          pairs.push(['BAT2', 'TL']);
          pairs.push(state.dimmer === 'lo' ? ['BAT2', 'LO'] : ['BAT2', 'HI']);
        }
        if (state.engineStop === 'run') pairs.push(['IG1', 'IG2']);
        if (state.starter === 'push') pairs.push(['BAT2', 'ST']);
        return pairs;
      },
    },
    // Separate single-group definitions, for a diagram that instead has
    // these as 4 distinct physical modules rather than one bundled
    // handlebar switch — matched independently by their own terminal set.
    {
      id: 'lightingSwitch',
      terms: ['BAT2', 'TL', 'HL'],
      groups: { lights: ['off', 'on'] },
      defaults: { lights: 'off' },
      closedPairs(state) {
        if (state.lights !== 'on') return [];
        return [['BAT2', 'TL'], ['BAT2', 'HL'], ['TL', 'HL']];
      },
    },
    {
      id: 'dimmerSwitch',
      terms: ['HI', 'HL', 'LO'],
      groups: { dimmer: ['lo', 'hi'] },
      defaults: { dimmer: 'lo' },
      closedPairs(state) {
        return state.dimmer === 'lo' ? [['HL', 'LO']] : [['HL', 'HI']];
      },
    },
    {
      id: 'engineStopSwitch',
      terms: ['IG1', 'IG2'],
      groups: { engineStop: ['off', 'run'] },
      defaults: { engineStop: 'run' },
      closedPairs(state) {
        return state.engineStop === 'run' ? [['IG1', 'IG2']] : [];
      },
    },
    {
      id: 'starterSwitch',
      terms: ['BAT2', 'ST'],
      groups: { starter: ['free', 'push'] },
      defaults: { starter: 'free' },
      closedPairs(state) {
        return state.starter === 'push' ? [['BAT2', 'ST']] : [];
      },
    },
  ],

  /**
   * Does `module`'s terminal-name set match a known switch definition?
   * Order-independent, case-insensitive. Longer/more-specific
   * definitions (more required terminals) are checked first so the
   * bundled handlebar switch wins over any single-group def whose
   * terminals happen to be a subset of it.
   * @param {object} module
   * @returns {object|null}
   */
  match(module) {
    if (!module || !module.terminals) return null;
    const names = new Set(module.terminals.map(t => String(t.n || '').toUpperCase()));
    const defs = [...MultiSwitchBehavior.DEFS].sort((a, b) => b.terms.length - a.terms.length);
    return defs.find(def => def.terms.every(t => names.has(t))) || null;
  },

  /** @param {GraphNode} node */
  isMultiSwitch(node) {
    return !!(node && node.module && MultiSwitchBehavior.match(node.module));
  },

  /** Default state for a definition: the first option in every group. */
  defaultState(def) {
    const s = {};
    // AP-MULTI-SWITCH-001 — an explicit `defaults` entry (the switch's
    // true electrical resting state) wins when present; `groups[g][0]`
    // is only a fallback for a def that doesn't bother declaring one.
    // Kept separate from display/array order specifically so a group
    // can list its options in whatever order reads best in the Simulate
    // panel (js/ui/sim-panel.js) without that also silently changing
    // which position the switch starts in.
    Object.keys(def.groups).forEach(g => {
      s[g] = (def.defaults && def.defaults[g] != null) ? def.defaults[g] : def.groups[g][0];
    });
    return s;
  },

  /**
   * Resolve a module's CURRENT state, merging any saved per-group
   * overrides (`conditions.multiSwitchStates[moduleId]`, written by the
   * Simulate panel — js/ui/sim-panel.js) onto the definition's defaults.
   */
  currentState(def, moduleId, conditions) {
    const saved = (conditions && conditions.multiSwitchStates && conditions.multiSwitchStates[moduleId]) || {};
    return Object.assign(MultiSwitchBehavior.defaultState(def), saved);
  },

  /**
   * A wire's stored terminal ref (`w.from.t`/`w.to.t`, same for graph
   * edges' `fromTerm`/`toTerm`) is almost always a bare 1-based PIN
   * NUMBER (`pinKey`, renderer.js — "1", "2", …, optionally `_IN`/`_OUT`
   * for a connector), not the terminal's own free-text `n` name this
   * behavior's `closedPairs` tables are written in terms of (BAT1, IG1,
   * etc. — copied straight from the factory continuity table's own
   * column headers, which is what makes those tables readable). This
   * resolves a ref back to that name via the module's own terminal
   * list, falling back to the raw ref uppercased for the rare case it's
   * already a name (e.g. a hand-typed legacy terminal ref).
   * @param {object} module
   * @param {string} ref
   */
  _resolveTermName(module, ref) {
    const bare = String(ref == null ? '' : ref).replace(/_(IN|OUT)$/, '');
    if (/^\d+$/.test(bare) && module && module.terminals) {
      const t = module.terminals[Number(bare) - 1];
      if (t && t.n) return String(t.n).toUpperCase();
    }
    return bare.toUpperCase();
  },

  /**
   * Is the pair (viaTerm, thisTerm) — two of THIS module's own terminal
   * refs — internally bridged under the module's current state?
   * @param {GraphNode} node
   * @param {string}    viaTerm
   * @param {string}    thisTerm
   * @param {SimulationConditions} conditions
   * @returns {boolean}
   */
  pairClosed(node, viaTerm, thisTerm, conditions) {
    const def = MultiSwitchBehavior.match(node.module);
    if (!def) return false;
    const a = MultiSwitchBehavior._resolveTermName(node.module, viaTerm);
    const b = MultiSwitchBehavior._resolveTermName(node.module, thisTerm);
    if (!a || !b) return false;
    const state = MultiSwitchBehavior.currentState(def, node.id, conditions);
    const pairs = def.closedPairs(state);
    return pairs.some(p => {
      const pa = p[0].toUpperCase(), pb = p[1].toUpperCase();
      return (pa === a && pb === b) || (pa === b && pb === a);
    });
  },
};
