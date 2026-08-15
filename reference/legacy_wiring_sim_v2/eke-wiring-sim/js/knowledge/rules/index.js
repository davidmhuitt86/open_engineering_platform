/**
 * knowledge/rules/index.js
 *
 * Electrical reasoning rules for diagnostic inference.
 *
 * Rules express known electrical relationships as testable conditions.
 * The reasoning engine (future Phase 6) will apply these rules to
 * the current electrical state to generate findings.
 *
 * Rule structure:
 *   { id, symptom, condition(state, graph) → boolean, causes: string[], tests: TestStep[] }
 *
 * No DOM. No rendering. No UI.
 */

const ElectricalRules = {

  rules: [

    {
      id:      'no-spark-no-power',
      symptom: 'No spark',
      label:   'CDI has no supply voltage',
      condition(state, graph) {
        if (!state || !graph) return false;
        const cdiNode = graph.nodes.get('cdi-unit');
        if (!cdiNode) return false;
        return (state.nodeVoltage.get('cdi-unit') || 0) < 0.5;
      },
      causes:  ['Blown main fuse', 'Open ignition switch circuit', 'Broken wire to CDI P5'],
      tests: [
        { description: 'Check voltage at CDI P5 with key ON',         expectedReading: '12.0V DC' },
        { description: 'Check continuity of fuse block F1',           expectedReading: 'Continuity' },
        { description: 'Check voltage at ignition switch IG1 output', expectedReading: '12.0V DC' },
      ],
    },

    {
      id:      'no-spark-no-ground',
      symptom: 'No spark',
      label:   'CDI has no ground path',
      condition(state, graph) {
        if (!state || !graph) return false;
        return !(state.nodeGround.get('cdi-unit') || false);
      },
      causes:  ['Broken ground wire CDI P2', 'Corroded chassis ground point'],
      tests: [
        { description: 'Check continuity CDI P2 to chassis ground', expectedReading: '<1Ω' },
        { description: 'Check resistance at chassis ground bolt',    expectedReading: '<0.5Ω' },
      ],
    },

    {
      id:      'no-spark-kill-active',
      symptom: 'No spark',
      label:   'Kill switch is grounding CDI',
      condition(state, graph) {
        if (!state) return false;
        const swState = (state.conditions && state.conditions.switchStates) || {};
        return swState['kill'] === 'stop' ||
               (window.SWPACK && SWPACK.state && SWPACK.state.kill === 'stop');
      },
      causes:  ['Kill switch in STOP position', 'Kill switch wire shorted to ground'],
      tests: [
        { description: 'Verify kill switch in RUN position',              expectedReading: 'RUN' },
        { description: 'Check CDI P4 voltage with kill switch in RUN',    expectedReading: '12.0V DC' },
        { description: 'Check continuity CDI P4 to ground (should be OL when RUN)', expectedReading: 'OL' },
      ],
    },

    {
      id:      'starter-no-crank-no-power',
      symptom: 'Starter does not crank',
      label:   'Starter relay contacts not closing',
      condition(state, graph) {
        if (!state || !graph) return false;
        return (state.nodeVoltage.get('starter-motor') || 0) < 9.0;
      },
      causes:  ['Starter relay failed', 'No voltage at relay coil', 'Low battery voltage'],
      tests: [
        { description: 'Check voltage at starter relay MB+ with start pressed', expectedReading: '11.8V+ DC' },
        { description: 'Check voltage at relay coil C+ with start pressed',     expectedReading: '12.0V DC' },
        { description: 'Check battery voltage under load',                       expectedReading: '>11.5V DC' },
      ],
    },

    {
      id:      'no-charge-no-stator-ac',
      symptom: 'Battery not charging',
      label:   'No AC from stator',
      condition(state, graph) {
        if (!state || !graph) return false;
        // Check stator AC wire
        const statorEdge = graph.edges.get('stator-ac1');
        if (!statorEdge) return false;
        const reading = state.wireReadings.get('stator-ac1');
        return !reading || parseFloat(reading.VAC || '0') < 5;
      },
      causes:  ['Broken stator winding', 'Disconnected stator connector', 'Open stator wire'],
      tests: [
        { description: 'Check AC voltage at stator output with engine running', expectedReading: '14-30V AC' },
        { description: 'Check stator winding resistance (between any two AC terminals)', expectedReading: '0.5-2.0Ω' },
      ],
    },

  ],

  /**
   * Evaluate all rules against the current electrical state.
   * Returns rules whose conditions are met.
   *
   * @param {ElectricalState} state
   * @param {GraphData}       graph
   * @returns {object[]}  matching rules
   */
  evaluate(state, graph) {
    return ElectricalRules.rules.filter(rule => {
      try { return rule.condition(state, graph); }
      catch { return false; }
    });
  },
};
