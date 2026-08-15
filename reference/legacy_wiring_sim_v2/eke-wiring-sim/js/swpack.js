// ── LH HANDLEBAR SWITCH PACK ─────────────────────────────────────
// Manages state for all 4 switches on the left handlebar.
// State is global and influences wire diagnostic readings when the
// relevant wire is one of the handlebar-switch circuits.

window.SWPACK = (function(){

  // ── STATE ─────────────────────────────────────────────────────
  const state = {
    lights: 'off',   // 'off' | 'on'
    beam:   'lo',    // 'lo'  | 'hi'
    kill:   'run',   // 'run' | 'stop'
    start:  false,   // momentary: true while held
  };

  let open = false;

  // ── WIRE OVERRIDE TABLE ───────────────────────────────────────
  // For handlebar-switch wires, we override the diagnostic reading
  // based on the current switch state. Structure:
  //   wireId → fn(keyPos, swState) → {VDC, VAC, CONT, RES, DIODE, note} | null (use default)
  const OVERRIDES = {

    // LIGHTS SWITCH: BAT2 → TL (tail light power through lights sw)
    'hlsw-lo': (kp, s) => {
      if(kp === 0) return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Key off'};
      if(s.lights === 'off') return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Lights OFF — switch open'};
      if(s.beam === 'hi')    return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Beam HI — LO terminal open'};
      return {VDC:'12.0',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Lights ON, Low Beam active'};
    },

    'hlsw-hi': (kp, s) => {
      if(kp === 0) return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Key off'};
      if(s.lights === 'off') return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Lights OFF — switch open'};
      if(s.beam === 'lo')    return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Beam LO — HI terminal open'};
      return {VDC:'12.0',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Lights ON, High Beam active'};
    },

    // KILL SWITCH: IG1 → IG2 (CDI kill line)
    'kill-cdi': (kp, s) => {
      if(kp === 0) return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Key off'};
      if(s.kill === 'stop') return {VDC:'0.00',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'KILL active — CDI grounded, engine stops'};
      if(kp === 2 || s.start) return {VDC:'12.0',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Kill=RUN, cranking'};
      return {VDC:'12.0',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Kill=RUN, engine enabled'};
    },

    // START BUTTON: IG1 → ST → relay coil
    'start-relay': (kp, s) => {
      if(kp === 0) return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Key off'};
      if(!s.start)  return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Start not pressed — switch open'};
      if(s.kill === 'stop') return {VDC:'0.00',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Start pressed but kill=STOP'};
      return {VDC:'12.0',VAC:'0.00',CONT:'OPN',RES:'OL',DIODE:'OL',note:'Start HELD — relay coil energized'};
    },

    // LH headlight splice wires react to lights/beam
    'lh-hi-spl': (kp, s) => {
      if(kp === 0) return null;
      if(s.lights === 'off') return {VDC:'0.00',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'Lights OFF'};
      if(s.beam === 'lo')    return {VDC:'0.00',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'Beam LO — HI splice 0V'};
      return {VDC:'12.0',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'High Beam active'};
    },

    'lh-lo-spl': (kp, s) => {
      if(kp === 0) return null;
      if(s.lights === 'off') return {VDC:'0.00',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'Lights OFF'};
      if(s.beam === 'hi')    return {VDC:'0.00',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'Beam HI — LO splice 0V'};
      return {VDC:'12.0',VAC:'0.00',CONT:'000',RES:'<1Ω',DIODE:'OL',note:'Low Beam active'};
    },
  };

  // ── DESCRIPTIONS ─────────────────────────────────────────────
  const DESCS = {
    lights: {
      off: 'BAT2→TL open. No tail or headlight feed.',
      on:  'BAT2→TL closed. Tail light and headlights powered.',
    },
    beam: {
      lo: 'LO(W) terminal active when lights ON. High beam open.',
      hi: 'HI(Bu) terminal active when lights ON. Low beam open.',
    },
    kill: {
      run:  'IG1→IG2 open (RUN). CDI enabled. Engine can run.',
      stop: 'IG1→IG2 shorted to GND (STOP). CDI killed. Engine stops immediately.',
    },
    start: {
      open:  'IG1→ST open. Starter relay not energized.',
      closed:'IG1→ST closed. Starter relay coil energized. Cranking!',
    },
  };

  // ── SCHEMATIC UPDATERS ───────────────────────────────────────
  function updateSchematics(){
    // Lights switch
    const lc = document.getElementById('sw-lights-contact');
    if(lc){
      if(state.lights === 'on'){
        lc.setAttribute('stroke','#15803d');lc.setAttribute('stroke-dasharray','none');
      } else {
        lc.setAttribute('stroke','#64748b');lc.setAttribute('stroke-dasharray','4 3');
      }
    }
    // Kill switch
    const kc = document.getElementById('sw-kill-contact');
    const kg = document.getElementById('sw-kill-gnd-label');
    if(kc){
      if(state.kill === 'stop'){
        kc.setAttribute('stroke','#dc2626');kc.setAttribute('stroke-dasharray','none');
        if(kg)kg.setAttribute('opacity','1');
      } else {
        kc.setAttribute('stroke','#64748b');kc.setAttribute('stroke-dasharray','4 3');
        if(kg)kg.setAttribute('opacity','0');
      }
    }
    // Beam selector
    const loArm = document.getElementById('sw-beam-lo-arm');
    if(loArm){
      const loActive = state.beam === 'lo';
      loArm.setAttribute('stroke', loActive ? '#15803d' : '#94a3b8');
      loArm.setAttribute('stroke-width', loActive ? '1.5' : '1');
      loArm.setAttribute('stroke-dasharray', loActive ? 'none' : '3 2');
    }
    // Start button
    const sc = document.getElementById('sw-start-contact');
    const si = document.getElementById('sw-start-icon');
    if(sc){
      if(state.start){
        sc.setAttribute('stroke','#f59e0b');sc.setAttribute('stroke-dasharray','none');
        if(si)si.textContent='⚡';
      } else {
        sc.setAttribute('stroke','#64748b');sc.setAttribute('stroke-dasharray','4 3');
        if(si)si.textContent='◎';
      }
    }
    // Start button styling
    const sbtn = document.getElementById('sw-start-btn');
    if(sbtn) sbtn.classList.toggle('sw-pos-cranking', state.start);
  }

  // ── TOPBAR INDICATORS ────────────────────────────────────────
  function updateIndicators(){
    // Lights
    const li = document.getElementById('swi-lights');
    const ll = document.getElementById('swi-lights-lbl');
    if(li && ll){
      ll.textContent = state.lights === 'on' ? 'ON' : 'OFF';
      li.classList.toggle('sw-ind-active', state.lights === 'on');
    }
    // Beam
    const bi = document.getElementById('swi-beam');
    const bl = document.getElementById('swi-beam-lbl');
    if(bi && bl){
      bl.textContent = state.beam === 'hi' ? 'HI' : 'LO';
      bi.classList.toggle('sw-ind-hi', state.beam === 'hi');
      bi.classList.toggle('sw-ind-lo', state.beam === 'lo');
    }
    // Kill
    const ki = document.getElementById('swi-kill');
    const kl = document.getElementById('swi-kill-lbl');
    if(ki && kl){
      kl.textContent = state.kill === 'stop' ? 'STOP' : 'RUN';
      ki.classList.toggle('sw-ind-danger', state.kill === 'stop');
      ki.classList.toggle('sw-ind-active', state.kill === 'run');
    }
    // Start
    const sti = document.getElementById('swi-start');
    if(sti) sti.classList.toggle('sw-ind-cranking', state.start);
  }

  // ── SUMMARY TEXT ─────────────────────────────────────────────
  function updateSummary(){
    const el = document.getElementById('swpack-summary-text');
    if(!el) return;
    const lines = [];
    lines.push(`💡 Lights: <b>${state.lights.toUpperCase()}</b>`);
    lines.push(`🔆 Beam: <b>${state.beam.toUpperCase()} BEAM</b>`);
    lines.push(`🔑 Kill: <b>${state.kill.toUpperCase()}</b>${state.kill==='stop'?' ⚠ CDI grounded':' — engine enabled'}`);
    lines.push(`⚡ Start: <b>${state.start?'PRESSED — CRANKING':'not pressed'}</b>`);
    el.innerHTML = lines.join('<br>');
  }

  // ── FULL UPDATE ──────────────────────────────────────────────
  function update(){
    updateSchematics();
    updateIndicators();
    updateSummary();
    // Trigger wire inspector to refresh if a relevant wire is selected
    if(typeof updateMeter === 'function') updateMeter();
    if(typeof drawWires === 'function') drawWires();
  }

  // ── PUBLIC API ───────────────────────────────────────────────
  return {
    state,
    OVERRIDES,

    toggle(){
      open = !open;
      document.getElementById('swpack-panel').classList.toggle('open', open);
      document.getElementById('swpack-btn').classList.toggle('swpack-on', open);
    },

    set(sw, val, btn){
      state[sw] = val;
      // Update button active states within the rocker
      const rocker = document.getElementById('sw-'+sw);
      if(rocker){
        rocker.querySelectorAll('.sw-pos').forEach(b => b.classList.remove('active'));
        if(btn) btn.classList.add('active');
      }
      // Update description
      const desc = document.getElementById('sw-'+sw+'-desc');
      if(desc && DESCS[sw]) desc.textContent = DESCS[sw][val] || '';
      update();
    },

    startPress(){
      state.start = true;
      const desc = document.getElementById('sw-start-desc');
      if(desc) desc.textContent = DESCS.start.closed;
      update();
    },

    startRelease(){
      state.start = false;
      const desc = document.getElementById('sw-start-desc');
      if(desc) desc.textContent = DESCS.start.open;
      update();
    },

    // Called by app.js updateMeter to get overridden reading for a wire
    getReading(wireId, keyPos){
      const fn = OVERRIDES[wireId];
      if(!fn) return null;
      return fn(keyPos, state);
    },

    // Init
    init(){
      update();
    }
  };
})();
