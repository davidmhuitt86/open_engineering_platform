/**
 * js/ui/sim-panel.js
 *
 * AP-LIVE-SIM-001 — the generic "Simulate Switches" panel: one row per
 * switch-type module currently on the diagram (LiveSim.isSwitchModule,
 * js/simulation/live-runner.js), rebuilt from MODULES every time it
 * opens or the diagram changes — unlike #swpack-panel, which is a fixed,
 * hand-authored panel for the bundled TRX300 demo's own 4 handlebar
 * switches specifically and knows nothing about switches the user adds.
 *
 * No electrical calculations here — this only renders rows and forwards
 * clicks to LiveSim.setSwitch()/toggleSwitch(), which do the real work.
 */

let simPanelOpen = false;

function toggleSimPanel() {
  simPanelOpen = !simPanelOpen;
  document.getElementById('sim-panel').classList.toggle('open', simPanelOpen);
  document.getElementById('sim-panel-btn').classList.toggle('swpack-on', simPanelOpen);
  if (simPanelOpen) renderSimPanel();
  // OEP-STUDIO-BRANDING-V1 — this real, pre-existing toggle IS the
  // Diagram-view/Simulation-view swap (the OEP header's own swap
  // control calls into this same function, via
  // legacyV2ToggleSimulationViewProvider, legacy_v2_webview.dart), so
  // it also drives which single-row toolbar is visible: #tb-diagram
  // while off, #tb-simulation while on. No new state — one real
  // boolean, two things now key off it.
  const diagramRow = document.getElementById('tb-diagram');
  const simRow = document.getElementById('tb-simulation');
  if (diagramRow) diagramRow.classList.toggle('tb-row-hidden', simPanelOpen);
  if (simRow) simRow.classList.toggle('tb-row-hidden', !simPanelOpen);
}

function renderSimPanel() {
  const body = document.getElementById('sim-panel-body');
  if (!body) return;
  if (typeof MODULES === 'undefined' || typeof LiveSim === 'undefined') return;
  const switches = MODULES.filter(m => LiveSim.isSwitchModule(m));
  if (!switches.length) {
    body.innerHTML = `<div class="sim-empty">No switches on this diagram yet — add one from + Module (Switch, Temp Sensor, etc.)</div>`;
    return;
  }
  // AP-OIL-TEMP-SWITCH-001 — a thermistor-flagged module models a
  // thermal switch, not a variable sensor (per direct correction: "it
  // isn't really a sensor, it's a switch that only fully closes at a
  // set temperature") — labeled NORMAL/OVER TEMP instead of a plain
  // OPEN/CLOSED rocker so flipping it reads the way the user actually
  // thinks about it ("set it to over temp limit"), even though
  // electrically it's the exact same open/closed toggle every other
  // switch here uses. The module's own Sub field (Edit Module) is where
  // its trip temperature belongs, same as any other module subtitle.
  body.innerHTML = switches.map(m => {
    const closed = LiveSim.isClosed(m.id);
    const isThermal = m.thermistor === true;
    const offLbl = isThermal ? 'NORMAL' : 'OPEN';
    const onLbl  = isThermal ? 'OVER TEMP' : 'CLOSED';
    const offIcon = isThermal ? '❄' : '○';
    const onIcon  = isThermal ? '🔥' : '●';
    const dangerOn = isThermal;
    return `<div class="sw-row">
      <div class="sw-label-col">
        <div class="sw-name">${m.label}</div>
        ${m.sub ? `<div class="sw-sub">${m.sub}</div>` : ''}
      </div>
      <div class="sw-toggle-col">
        <div class="sw-rocker">
          <button class="sw-pos${!closed ? ' active' : ''}" onclick="LiveSim.setSwitch('${m.id}',false)">
            <span class="sw-pos-icon">${offIcon}</span><span class="sw-pos-lbl">${offLbl}</span>
          </button>
          <button class="sw-pos${dangerOn ? ' sw-pos-danger' : ''}${closed ? ' active' : ''}" onclick="LiveSim.setSwitch('${m.id}',true)">
            <span class="sw-pos-icon">${onIcon}</span><span class="sw-pos-lbl">${onLbl}</span>
          </button>
        </div>
      </div>
    </div>`;
  }).join('');
}
