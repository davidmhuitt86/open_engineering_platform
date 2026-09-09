// diagram/renderer.js
// Master diagram renderer. Coordinates module cards, wire SVG, labels, and
// flow animation. Calls module-renderer.js and wire-renderer.js sub-systems.
// Phase 1: monolithic. Phase 2: delegates to sub-renderers.
//
// Owns: buildCard, placeCards, drawWires, route, applyT, zReset, zBy,
//       initMinimap, updateMinimap, flow animation, pan/zoom/touch events.
//
// Reads from: MODULES, WIRES, positions, wireRoutes, selW, selSeg,
//             editMode, wireMode, routeEditMode, tracedWires, keyPos,
//             leadR, leadB — all declared in app.js global scope.

// diagram.js — Display layer extracted from app.js
// Same variable scope as app.js (both non-module scripts share window scope)

// ── COLOUR HELPERS ──────────────────────────────────────────────
const CAT_CLR={indicator:"#7c3aed",ignition:"#dc2626",control:"#2563eb",accessory:"#ea580c",charging:"#d97706",ground:"#374151",lighting:"#0891b2",switch:"#059669",starter:"#9333ea",power:"#b45309",connector:"#0e7490",diode:"#be123c"};
// AP-POWER-POST-001 — a terminal meant to render as a heavy power post
// (battery/solenoid/starter-motor main studs) skips the usual pin-NUMBER
// label in favor of its own free-text `n` field (already customizable
// per terminal via the terminal editor's own "Label" input — no new
// field needed) — per direct request: "the power posts do not need to
// have a number pin label but can have a label field i can customize."
// The wire-reference key itself is UNCHANGED either way (still pinKey(i)
// — see pinKey's own doc comment on why pin position, not this display
// text, is what's actually unique) — this only affects what's SHOWN.
const termLabelText=(t,i)=>t.post?(t.n||""):pinKey(i);
const HEX={Bl:"#1e293b",Br:"#7c2d12",R:"#dc2626",G:"#15803d",Gr:"#9ca3af",Lg:"#4ade80",Y:"#ca8a04",W:"#94a3b8",Bu:"#2563eb",Blu:"#2563eb",O:"#ea580c",P:"#ec4899","—":"#999"};
const CNAMES={Bl:"Black",Br:"Brown",R:"Red",G:"Green",Gr:"Gray",Lg:"Lt Green",Y:"Yellow",W:"White",Bu:"Blue",Blu:"Blue",O:"Orange",P:"Pink","P/W":"Pink/White","Y/R":"Yellow/Red","Bl/Y":"Black/Yellow","Blu/Y":"Blue/Yellow","Bl/W":"Black/White","Y/W":"Yellow/White","Lg/R":"Lt Grn/Red","G/R":"Green/Red","Br/R":"Brown/Red","Blu/R":"Blue/Red"};
const h=c=>{if(!c)return"#888";const k=c.trim();if(HEX[k])return HEX[k];return HEX[k.split("/")[0].trim()]||"#666";};
const trH=c=>{if(!c)return null;const i=c.indexOf("/");if(i<0)return null;return HEX[c.slice(i+1).trim()]||null;};
const cn=c=>CNAMES[c]||c||"—";
// A two-color wire code ("Br/R" = Brown main, Red stripe) is rendered as
// a vertically-split swatch: main on the left, stripe on the right —
// used for every terminal dot and every wire-color swatch in the UI
// (terminal dots: buildStdCard/buildConnCard below; swatches:
// inspector.js's updatePanel/renderModInfo, sidebar.js's _renderInspector)
// so the swatch always matches the two-tone convention the wire itself
// is drawn in (§ drawWires' own bi-color rendering below). A single-color
// code (no "/") renders as the plain solid color, unchanged.
// AP-WIRE-STRIPE-001 — main/stripe were swapped (main was rendering on
// the right, stripe on the left) — reported directly ("the colors on
// them are backwards. the main color should be the left hemisphere and
// the stripe should be the right").
const swatchBg=c=>{const main=h(c),stripe=trH(c);return stripe?`linear-gradient(90deg,${main} 50%,${stripe} 50%)`:main;};
// Property Inspector's "Property Type" field — a module's own cat (switch,
// connector, ignition, …) is already the most specific kind we know, so we
// just title-case it rather than collapsing everything to a generic "Module".
const capitalizeCat=cat=>cat?cat.charAt(0).toUpperCase()+cat.slice(1):"Module";
const sid=s=>s.replace(/[^a-z0-9]/gi,"_");
// A terminal's `n`/`c` fields (pin name, wire color) are free-text and
// routinely repeat on the same module — a real harness module very often
// has several pins that are simply "the blue wire" with no more specific
// name, and giving them all the same descriptive name is completely
// normal, not a data-entry mistake. Wires, DOM ids, and every other
// per-terminal identity therefore key off a terminal's PIN NUMBER
// instead — its 1-based position in `m.terminals` — which is unique on
// a module by construction and never needs validating, matching how a
// real connector/module's own physical pin numbering works. `n`/`c`
// stay exactly what they were: free-text display fields with no
// uniqueness requirement. See module-editor.js's saveModProps() for how
// existing wires get renumbered when a module's terminal order changes.
const pinKey=i=>String(i+1);
// Reverse of pinKey — for displaying a wire's stored `.from.t`/`.to.t`
// (a pin-number string, optionally suffixed `_IN`/`_OUT` for a
// connector) as something a human can actually read, e.g. "Pin 3 (OIL)"
// instead of the bare "3". Falls back to the raw value if the module or
// pin can't be resolved (e.g. a stale reference) rather than throwing.
function pinLabel(modId,pinStr){
  const m=MODULES.find(x=>x.id===modId);if(!m||pinStr==null)return pinStr;
  let ref=pinStr;
  if(!/^\d+(_IN|_OUT)?$/.test(ref)){const resolved=_resolveLegacyTerminalRef(modId,ref);if(resolved)ref=resolved;}
  const suffixMatch=/^(\d+)(_IN|_OUT)$/.exec(ref);
  const num=suffixMatch?suffixMatch[1]:ref;
  const idx=Number(num)-1,t=m.terminals&&m.terminals[idx];
  if(!t)return pinStr;
  // AP-CONNECTOR-PIN-LABEL-001 — per direct request, a connector pin's
  // IN/OUT suffix is never shown to the user, matching how every other
  // module's terminals are just "Pin N (name)" — the internal `_IN`/
  // `_OUT` distinction (still used for dataset.tn/routing/persistence)
  // stays invisible here, same as buildConnCard's own on-card number
  // label already does.
  return `Pin ${num} (${t.n})`;
}
const $=id=>document.getElementById(id);
const canvas=$("canvas"),scene=$("scene"),vp=$("viewport"),wsvg=$("wire-layer");
const cardEls={};
const STUB=14;
// AP-WIRE-GRID-ALIGN-001 — matches #canvas's own visual grid
// (`background-size:20px 20px`, main.css). Every terminal on every
// card — and every splice — must land on a multiple of this so two
// wires between grid-aligned terminals always route as clean straight/
// single-bend lines, and so AP-WIRE-TERMINAL-FAN-001's automatic
// same-terminal wire separation has a consistent, predictable geometry
// to work with instead of the few-stray-pixels-off positions flexbox-
// derived card layout used to produce (reported directly: "hit or
// miss" separation, traced to modules/terminals never actually landing
// on the grid despite looking close). See buildStdCard/buildConnCard/
// buildBulbCard/buildSpliceCard below for the per-card-type geometry,
// and module-editor.js's drag/add/splice-placement code for where a
// module's own anchor (`positions[id]`) gets snapped to this same unit.
const GRID=20;


// ── CARD BUILDER ─────────────────────────────────────────────────
function buildCard(m){
  const card=document.createElement("div");card.className="mod-card";card.dataset.mid=m.id;
  if(m.splice){buildSpliceCard(m,card);return card;}
  const stripe=document.createElement("div");stripe.className="cat-stripe";stripe.style.background=CAT_CLR[m.cat]||"#888";card.appendChild(stripe);
  if(m.bulb)buildBulbCard(m,card);
  else if(m.diode)buildDiodeCard(m,card);
  else if(m.starterMotor)buildStarterMotorCard(m,card);
  else if(m.solenoid)buildSolenoidCard(m,card);
  else if(m.battery)buildBatteryCard(m,card);
  else if(m.groundedSwitch)buildGroundedSwitchCard(m,card);
  else if(m.thermistor)buildThermistorCard(m,card);
  else if(m.pulseGenerator)buildPulseGeneratorCard(m,card);
  else if(m.alternator)buildAlternatorCard(m,card);
  else if(m.connector)buildConnCard(m,card);
  else buildStdCard(m,card);
  // AP-MODULE-LAYOUT-001 — `m.labelPos` ('top'/'bottom'/'left'/'right')
  // independently controls where the module's own name/sub text sits,
  // regardless of which side its terminal strip is anchored to. Default
  // (when unset) is 'top' for a normal horizontal module — the original
  // always-above behavior — but 'left' for a vertical one: a vertical
  // card is narrow, and a nowrap label centered above it (the old
  // unconditional default) reads as cramped/overlapping its neighbors —
  // per direct user feedback confirming this is a real problem for both
  // vertical standard modules and vertical connectors, not just cosmetic.
  // Still fully overridable per module via the properties panel.
  const defaultLabelPos=m.vertical?"left":"top";
  // AP-MODULE-LABEL-WRAP-001 — `m.label`/`m.sub` may now contain literal
  // `\n` characters (typed as Enter in the properties panel's Label/
  // Sub-label textareas) — rendered as-is via innerHTML, honored as real
  // line breaks by `.mod-label`'s own `white-space:pre-line` (main.css),
  // no HTML transformation needed here. `m.labelJustify` ('left'/'right',
  // default unset = center, unchanged) controls how those lines align
  // relative to each other, independent of `lp-*`'s block positioning.
  const lbl=document.createElement("div");lbl.className="mod-label lp-"+(m.labelPos||defaultLabelPos)+" lj-"+(m.labelJustify||"center");lbl.innerHTML=`${m.label}<br><span class="mod-sub">${m.sub||""}</span>`;card.appendChild(lbl);
  return card;
}
// A splice is a joint/junction point, not a real component — it renders
// as a small dot (the real electrical-diagram symbol for a spliced
// joint), not a labeled card with a terminal strip. It still carries
// exactly one terminal ("SPLICE") so every existing wire/terminal-click/
// routing code path (setupTermClicks, getPos, exitDir, WIRES.from/to)
// keeps working on it completely unchanged — a splice is deliberately
// just a MODULES entry with `splice:true`, not a parallel data model.
function buildSpliceCard(m,card){
  card.classList.add("splice-card");
  card.style.cssText+="padding:0;min-width:0;background:transparent;border:none;box-shadow:none;";
  const k=`${m.id}::SPLICE`;
  const dot=document.createElement("div");
  dot.className="t-dot";dot.id="d_"+sid(k);
  const c=(m.terminals&&m.terminals[0]&&m.terminals[0].c)||"W";
  // AP-WIRE-GRID-ALIGN-001 — a splice's dot CENTER (not its top-left
  // corner) is its electrical connection point (getPos measures the
  // dot's own bounding-box center). This used to be offset from
  // `positions[id]` by the dot's own half-size (+5,+5, from a plain
  // top-left-at-0,0 10x10 box) — not a multiple of GRID, so a splice
  // whose `positions[id]` was itself grid-snapped could still land its
  // actual connection point a few px off the grid. Centering the dot
  // exactly ON `positions[id]` (absolute + translate(-50%,-50%), same
  // technique buildStdCard's own .t-cell now uses) makes the connection
  // point and the snapped anchor the same point, with zero offset.
  dot.style.cssText=`position:absolute;left:0;top:0;transform:translate(-50%,-50%);width:10px;height:10px;border-radius:50%;background:${swatchBg(c)};border:1.5px solid #0d0d0d;cursor:pointer;`;
  dot.title=m.label+(m.location?` — ${m.location}`:"");
  dot.dataset.mid=m.id;dot.dataset.tn="SPLICE";
  card.appendChild(dot);
}
// AP-WIRE-GRID-ALIGN-001 — every terminal's on-screen position is now
// computed directly as `positions[id] + i*GRID` along one axis (fixed
// JS math), not derived from flexbox flow/padding — see this file's own
// GRID constant doc comment for why. `m.exit`/`side` no longer changes
// where a pin actually sits (that would reintroduce non-grid-multiple
// offsets depending on which side was picked); it still fully controls
// the wire STUB direction via exitDir()/route() below, same as always —
// only the on-card cosmetic position of the strip itself is now fixed
// regardless of side. Per direct user feedback: snapping only the first
// terminal (an earlier attempt) doesn't work, because the remaining
// pins' spacing has to be grid-exact TOO, not just corrected once and
// left at its old flex-derived spacing.
const CARD_PAD=GRID; // fixed grid-multiple inset from the card's own anchor to pin 0
function buildStdCard(m,card){
  const vertical=!!m.vertical;
  const n=m.terminals.length;
  const stripLen=(n-1)*GRID;
  card.style.width=(vertical?CARD_PAD*2:stripLen+CARD_PAD*2)+"px";
  card.style.height=(vertical?stripLen+CARD_PAD*2:CARD_PAD*2)+"px";
  // AP-WIRE-GRID-ALIGN-001 — deliberately NO card-level padding: the
  // strip below is absolutely positioned with `left:0;top:0`, and any
  // padding on `.mod-card` itself would silently shift that origin by
  // the padding amount (an absolutely positioned child's offsets are
  // measured from its containing block's PADDING edge, not its border
  // edge), reintroducing exactly the kind of non-grid-multiple offset
  // this whole rewrite exists to remove.
  const pinLabelPos=m.pinLabelPos||(vertical?"left":"top");
  const OPPOSITE_SIDE={top:"bottom",bottom:"top",left:"right",right:"left"};
  const subLabelPos=m.subLabelPos||OPPOSITE_SIDE[pinLabelPos]||"bottom";
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  // The primary label under/beside each dot is the pin NUMBER, not the
  // wire color — a module's pin numbering is fixed and unique, so it's
  // what actually lets you find "pin 3" again later; the dot itself
  // still carries the real wire color via swatchBg so color is never
  // lost, just no longer duplicated as text (per direct user request:
  // pin number + color dot + traceable destination should be readable
  // at a glance). The optional sub-label (this pin's own `n` field, e.g.
  // a wire's function name) is purely additive on top of that.
  strip.innerHTML=m.terminals.map((t,i)=>{
    const k=`${m.id}::${pinKey(i)}`;
    const cx=vertical?CARD_PAD:CARD_PAD+i*GRID;
    const cy=vertical?CARD_PAD+i*GRID:CARD_PAD;
    const subLbl=t.showLabel?`<div class="t-lbl sub pos-${subLabelPos}">${t.n||""}</div>`:"";
    return`<div class="t-cell" style="left:${cx}px;top:${cy}px"><div class="t-lbl pos-${pinLabelPos}">${pinKey(i)}</div>${subLbl}<div class="t-dot" id="d_${sid(k)}" style="background:${swatchBg(t.c)}" title="Pin ${pinKey(i)} — ${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  }).join("");
  card.appendChild(strip);
}
// AP-DIODE-SYMBOL-001 — a real 2-terminal component meant to sit INLINE
// with a wire run (per direct request: "a diode symbol to add inline
// with wires either vertical or horizontal"), same way a splice sits
// inline — see insertDiodeOnWire (wire-editor.js) for how right-
// clicking an existing wire cuts it and inserts one. Anode (pin 1) and
// Cathode (pin 2) are placed exactly GRID apart, same fixed-offset-
// from-anchor treatment as buildStdCard/buildConnCard, so it lands on
// the grid like everything else; `m.vertical` picks which axis they're
// stacked on, matching whichever axis the wire being spliced was
// running along (mirrors insertSpliceOnWire's own axis-matching).
// Drawn as the real schematic symbol (triangle pointing from anode to
// cathode, bar at the cathode end) rather than a plain 2-dot strip, so
// current direction is visible at a glance on the diagram itself.
function buildDiodeCard(m,card){
  const vertical=!!m.vertical;
  card.style.width=(vertical?CARD_PAD*2:GRID+CARD_PAD*2)+"px";
  card.style.height=(vertical?GRID+CARD_PAD*2:CARD_PAD*2)+"px";
  const aX=CARD_PAD,aY=CARD_PAD;
  const kX=vertical?CARD_PAD:CARD_PAD+GRID,kY=vertical?CARD_PAD+GRID:CARD_PAD;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",card.style.width.replace("px",""));
  svg.setAttribute("height",card.style.height.replace("px",""));
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const TRI=6; // triangle half-height/half-width
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  const cIn=(m.terminals[0]&&m.terminals[0].c)||"W";
  if(vertical){
    const triTopY=aY+4,triTipY=kY-6,barY=kY-6;
    line(aX,aY,aX,triTopY); // anode lead
    const tri=document.createElementNS("http://www.w3.org/2000/svg","polygon");
    tri.setAttribute("points",`${aX-TRI},${triTopY} ${aX+TRI},${triTopY} ${aX},${triTipY}`);
    tri.setAttribute("fill",h(cIn));tri.setAttribute("stroke","#0d0d0d");tri.setAttribute("stroke-width","1");
    svg.appendChild(tri);
    line(aX-TRI,barY,aX+TRI,barY); // cathode bar
    line(aX,barY,aX,kY); // cathode lead
  }else{
    const triLeftX=aX+4,triTipX=kX-6,barX=kX-6;
    line(aX,aY,triLeftX,aY); // anode lead
    const tri=document.createElementNS("http://www.w3.org/2000/svg","polygon");
    tri.setAttribute("points",`${triLeftX},${aY-TRI} ${triLeftX},${aY+TRI} ${triTipX},${aY}`);
    tri.setAttribute("fill",h(cIn));tri.setAttribute("stroke","#0d0d0d");tri.setAttribute("stroke-width","1");
    svg.appendChild(tri);
    line(barX,aY-TRI,barX,aY+TRI); // cathode bar
    line(barX,aY,kX,aY); // cathode lead
  }
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  const pinLabelPos=m.pinLabelPos||(vertical?"left":"top");
  const mk=(i,cx,cy,name)=>{
    const t=m.terminals[i]||{n:name,c:"W"};
    const k=`${m.id}::${pinKey(i)}`;
    return`<div class="t-cell" style="left:${cx}px;top:${cy}px"><div class="t-lbl pos-${pinLabelPos}">${pinKey(i)}</div><div class="t-dot" id="d_${sid(k)}" style="background:${swatchBg(t.c)}" title="Pin ${pinKey(i)} — ${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  };
  strip.innerHTML=mk(0,aX,aY,"A")+mk(1,kX,kY,"K");
  card.appendChild(strip);
}
// AP-POWER-POST-001 — starter motor, per direct request + reference
// photo: a circle body with "M", ONE main power post (top, `post`-style
// terminal — big ring look, no pin-number label, customizable via its
// own `n` field), and a real, wireable ground terminal (bottom) with a
// small chassis-ground hatch glyph next to it, so the motor's "metal
// body grounded to the chassis" is an actual electrical connection on
// the diagram (to a Ground Point module), not just decoration.
function buildStarterMotorCard(m,card){
  const W=GRID*2+CARD_PAD*2,H=GRID*3+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const cx=CARD_PAD+GRID,cy=CARD_PAD+GRID*1.5,R=GRID+2;
  const pY=CARD_PAD,gY=CARD_PAD+GRID*3;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const circ=document.createElementNS("http://www.w3.org/2000/svg","circle");
  circ.setAttribute("cx",cx);circ.setAttribute("cy",cy);circ.setAttribute("r",R);
  circ.setAttribute("fill","#f4f4f5");circ.setAttribute("stroke","#0d0d0d");circ.setAttribute("stroke-width","1.4");
  svg.appendChild(circ);
  const txt=document.createElementNS("http://www.w3.org/2000/svg","text");
  txt.setAttribute("x",cx);txt.setAttribute("y",cy+4);txt.setAttribute("text-anchor","middle");
  txt.setAttribute("font-size","13");txt.setAttribute("font-weight","800");txt.setAttribute("fill","#0d0d0d");
  txt.textContent="M";svg.appendChild(txt);
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  line(cx,pY,cx,cy-R);
  line(cx,cy+R,cx,gY);
  // Chassis-ground hatch — purely decorative, just past the ground terminal.
  [0,4,8].forEach((dy,i)=>{const w2=10-i*3;line(cx-w2/2,gY+5+dy,cx+w2/2,gY+5+dy);});
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  const pinLabelPos=m.pinLabelPos||"left";
  const mk=(i,x,y,name)=>{
    const t=m.terminals[i]||{n:name,c:"W"};
    const k=`${m.id}::${pinKey(i)}`;
    return`<div class="t-cell" style="left:${x}px;top:${y}px"><div class="t-lbl pos-${pinLabelPos}">${termLabelText(t,i)}</div><div class="t-dot post" id="d_${sid(k)}" style="background:${swatchBg(t.c)}" title="${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  };
  strip.innerHTML=mk(0,cx,pY,"B+")+mk(1,cx,gY,"GND");
  card.appendChild(strip);
}
// AP-GROUNDED-SWITCH-001 — a switch whose own metal body/case is
// grounded to the chassis, per direct request: a normal, numbered
// terminal on TOP (wires up like any other pin) and a `post`-style
// ground terminal on the BOTTOM with the same chassis-ground hatch
// glyph buildStarterMotorCard already uses — a real, wireable
// connection to a Ground Point module, not just decoration. The switch
// symbol itself (hinge dot, open lever, fixed-contact dot) sits between
// the two terminals.
function buildGroundedSwitchCard(m,card){
  const W=GRID+CARD_PAD*2,H=GRID*2+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const cx=CARD_PAD,topY=CARD_PAD,gY=CARD_PAD+GRID*2;
  const hingeY=topY+9,contactY=gY-9;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  const dot=(x,y)=>{const c=document.createElementNS("http://www.w3.org/2000/svg","circle");c.setAttribute("cx",x);c.setAttribute("cy",y);c.setAttribute("r","1.6");c.setAttribute("fill","#0d0d0d");svg.appendChild(c);};
  line(cx,topY,cx,hingeY);
  dot(cx,hingeY);
  // The open lever: pivots at the hinge, angled away from the fixed
  // contact below it — the gap between the lever's own end and the
  // fixed-contact dot is what reads as "switch open" (the schematic
  // convention), not touching it.
  line(cx,hingeY,cx+7,contactY-3);
  dot(cx,contactY);
  line(cx,contactY,cx,gY);
  // Chassis-ground hatch — same glyph/rationale as buildStarterMotorCard.
  [0,4,8].forEach((dy,i)=>{const w2=10-i*3;line(cx-w2/2,gY+5+dy,cx+w2/2,gY+5+dy);});
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  strip.innerHTML=`<div class="t-cell" style="left:${cx}px;top:${topY}px"><div class="t-lbl pos-bottom">1</div><div class="t-dot" id="d_${sid(m.id+'::1')}" style="background:${swatchBg((m.terminals[0]||{c:'W'}).c)}" title="Pin 1 — ${(m.terminals[0]||{n:''}).n}" data-mid="${m.id}" data-tn="1"></div></div>`+
    `<div class="t-cell" style="left:${cx}px;top:${gY}px"><div class="t-lbl pos-bottom">${termLabelText(m.terminals[1]||{n:'GND'},1)}</div><div class="t-dot post" id="d_${sid(m.id+'::2')}" style="background:${swatchBg((m.terminals[1]||{c:'G'}).c)}" title="${(m.terminals[1]||{n:'GND'}).n}" data-mid="${m.id}" data-tn="2"></div></div>`;
  card.appendChild(strip);
}
// AP-GROUNDED-SWITCH-001 — same card shell as buildGroundedSwitchCard
// (normal pin on top, chassis-grounded `post` pin on bottom, per direct
// follow-up request: "a similar module... but instead of the switch
// symbol... a temperature sensor or a thermistor symbol"), swapping only
// the middle glyph for the standard thermistor symbol: a resistor body
// with a diagonal arrow through it (the schematic convention for a
// temperature-variable resistive sensor).
function buildThermistorCard(m,card){
  const W=GRID+CARD_PAD*2,H=GRID*2+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const cx=CARD_PAD,topY=CARD_PAD,gY=CARD_PAD+GRID*2;
  const boxTop=topY+11,boxBottom=gY-11,boxHalfW=6;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  line(cx,topY,cx,boxTop);
  const rect=document.createElementNS("http://www.w3.org/2000/svg","rect");
  rect.setAttribute("x",cx-boxHalfW);rect.setAttribute("y",boxTop);
  rect.setAttribute("width",boxHalfW*2);rect.setAttribute("height",boxBottom-boxTop);
  rect.setAttribute("fill","#f4f4f5");rect.setAttribute("stroke","#0d0d0d");rect.setAttribute("stroke-width","1.4");
  svg.appendChild(rect);
  // Diagonal sensing arrow through the resistor body — the part of the
  // symbol that reads as "thermistor" rather than a plain fixed resistor.
  line(cx-boxHalfW-3,boxBottom+3,cx+boxHalfW+3,boxTop-3);
  const ah=document.createElementNS("http://www.w3.org/2000/svg","path");
  ah.setAttribute("d",`M${cx+boxHalfW+3-4} ${boxTop-3} L${cx+boxHalfW+3} ${boxTop-3} L${cx+boxHalfW+3} ${boxTop-3+4}`);
  ah.setAttribute("fill","none");ah.setAttribute("stroke","#0d0d0d");ah.setAttribute("stroke-width","1.4");ah.setAttribute("stroke-linejoin","round");
  svg.appendChild(ah);
  line(cx,boxBottom,cx,gY);
  // Chassis-ground hatch — same glyph/rationale as buildStarterMotorCard.
  [0,4,8].forEach((dy,i)=>{const w2=10-i*3;line(cx-w2/2,gY+5+dy,cx+w2/2,gY+5+dy);});
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  strip.innerHTML=`<div class="t-cell" style="left:${cx}px;top:${topY}px"><div class="t-lbl pos-bottom">1</div><div class="t-dot" id="d_${sid(m.id+'::1')}" style="background:${swatchBg((m.terminals[0]||{c:'W'}).c)}" title="Pin 1 — ${(m.terminals[0]||{n:''}).n}" data-mid="${m.id}" data-tn="1"></div></div>`+
    `<div class="t-cell" style="left:${cx}px;top:${gY}px"><div class="t-lbl pos-bottom">${termLabelText(m.terminals[1]||{n:'GND'},1)}</div><div class="t-dot post" id="d_${sid(m.id+'::2')}" style="background:${swatchBg((m.terminals[1]||{c:'G'}).c)}" title="${(m.terminals[1]||{n:'GND'}).n}" data-mid="${m.id}" data-tn="2"></div></div>`;
  card.appendChild(strip);
}
// AP-BODY-GROUND-SYMBOL-001 — per direct correction: unlike
// buildStarterMotorCard/buildGroundedSwitchCard's `post`-style GND
// terminal (a real, wireable connection to a Ground Point module — kept
// as-is there, since a switch's simulation genuinely depends on a real
// wire completing that path), a Pulse Generator/Alternator's body-ground
// is purely informational here — neither module has any special
// electrical behavior in the solver (they're not switches or loads), so
// forcing a real terminal on it just to look right was wrong. This
// draws the SAME chassis-ground hatch glyph, plus a lead line down to
// it, but with NO `.t-dot`/`.t-cell` at all — not counted in
// `m.terminals`, not clickable, not a wire endpoint. Purely decorative,
// same as the ground symbol under a component in a real Haynes-manual
// diagram.
function _bodyGroundGlyph(svg,line,x,topY){
  line(x,topY,x,topY+10);
  [0,4,8].forEach((dy,i)=>{const w2=10-i*3;line(x-w2/2,topY+10+dy,x+w2/2,topY+10+dy);});
}
// AP-GROUNDED-SWITCH-001 — same card shell as buildGroundedSwitchCard
// (one signal pin on top — per direct correction, a single terminal
// now, not two), swapping the middle glyph for a schematic inductor/coil
// symbol (stacked bumps) — a pulse generator (pickup coil) is
// electrically just a coil between its signal lead and its body, which
// bolts straight to the case (§ _bodyGroundGlyph above for why that's
// decorative-only here, not a second wireable terminal).
function buildPulseGeneratorCard(m,card){
  const W=GRID+CARD_PAD*2,H=GRID*2+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const cx=CARD_PAD,topY=CARD_PAD,gY=CARD_PAD+GRID*2;
  const coilTop=topY+6,coilBottom=gY-6;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  line(cx,topY,cx,coilTop);
  const bumps=4,bumpH=(coilBottom-coilTop)/bumps;
  let d=`M${cx} ${coilTop}`;
  for(let i=0;i<bumps;i++){
    const yMid=coilTop+bumpH*(i+0.5),yEnd=coilTop+bumpH*(i+1);
    d+=` Q${cx+6} ${yMid} ${cx} ${yEnd}`;
  }
  const coil=document.createElementNS("http://www.w3.org/2000/svg","path");
  coil.setAttribute("d",d);coil.setAttribute("fill","none");coil.setAttribute("stroke","#0d0d0d");coil.setAttribute("stroke-width","1.3");
  svg.appendChild(coil);
  line(cx,coilBottom,cx,gY-10);
  _bodyGroundGlyph(svg,line,cx,gY-10);
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  strip.innerHTML=`<div class="t-cell" style="left:${cx}px;top:${topY}px"><div class="t-lbl pos-bottom">1</div><div class="t-dot" id="d_${sid(m.id+'::1')}" style="background:${swatchBg((m.terminals[0]||{c:'W'}).c)}" title="Pin 1 — ${(m.terminals[0]||{n:''}).n}" data-mid="${m.id}" data-tn="1"></div></div>`;
  card.appendChild(strip);
}
// AP-ALTERNATOR-001 — alternator/stator: reference photo shows a
// 3-phase winding symbol (three coil legs meeting at a center point)
// with its output leads exiting the top and its body chassis-grounded
// (decorative-only symbol, § _bodyGroundGlyph above) at the bottom.
// 5 terminals total per direct request — all 5 are numbered winding
// leads in one top row (matching buildSolenoidCard's own multi-terminal
// top-row layout); the ground glyph is NOT one of them.
function buildAlternatorCard(m,card){
  const W=GRID*4+CARD_PAD*2,H=GRID*4+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const topY=CARD_PAD,gY=CARD_PAD+GRID*4;
  const cx=W/2,cy=CARD_PAD+GRID*2.2,R=GRID+2;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  const circ=document.createElementNS("http://www.w3.org/2000/svg","circle");
  circ.setAttribute("cx",cx);circ.setAttribute("cy",cy);circ.setAttribute("r",R);
  circ.setAttribute("fill","#f4f4f5");circ.setAttribute("stroke","#0d0d0d");circ.setAttribute("stroke-width","1.4");
  svg.appendChild(circ);
  // 3-phase winding glyph: three legs from a center point out toward the
  // rim, ~120° apart, matching the reference photo's "Y" symbol.
  const legLen=R*0.7;
  for(let i=0;i<3;i++){
    const ang=-Math.PI/2+i*(2*Math.PI/3);
    line(cx,cy,cx+legLen*Math.cos(ang),cy+legLen*Math.sin(ang));
  }
  const centerDot=document.createElementNS("http://www.w3.org/2000/svg","circle");
  centerDot.setAttribute("cx",cx);centerDot.setAttribute("cy",cy);centerDot.setAttribute("r","1.6");centerDot.setAttribute("fill","#0d0d0d");
  svg.appendChild(centerDot);
  // Lead-in lines: each of the 5 top terminals runs down into the circle's rim.
  for(let i=0;i<5;i++){
    const x=CARD_PAD+i*GRID;
    line(x,topY,x,cy-R);
  }
  line(cx,cy+R,cx,gY-10);
  _bodyGroundGlyph(svg,line,cx,gY-10);
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  const mk=(i,x,y)=>{
    const t=m.terminals[i]||{n:String(i+1),c:'W'};
    const k=`${m.id}::${pinKey(i)}`;
    return`<div class="t-cell" style="left:${x}px;top:${y}px"><div class="t-lbl pos-top">${pinKey(i)}</div><div class="t-dot" id="d_${sid(k)}" style="background:${swatchBg(t.c)}" title="Pin ${pinKey(i)} — ${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  };
  let html='';
  for(let i=0;i<5;i++) html+=mk(i,CARD_PAD+i*GRID,topY);
  strip.innerHTML=html;
  card.appendChild(strip);
}
// AP-POWER-POST-001 — starter relay/solenoid switch. Per direct
// reference photo correction: all FOUR terminals sit in a single row
// along the TOP edge, all exiting upward, in real left-to-right order —
// BAT (post) — coil pin 1 — coil pin 2 — MTR (post) — not a control
// terminal off on its own at the bottom.
//
// AP-COIL-SYMBOL-002 — the coil shape itself, per a direct hand-drawn
// reference: ONE lead (from coil pin 1) runs straight down; the OTHER
// lead (from coil pin 2) is a tight, sharp zigzag — not smooth curved
// bulges (those read as a lattice/diamond pattern, explicitly rejected:
// "not diamond shapes") and not a resistor-style WIDE zigzag either
// (the previous, too-sparse version) — both leads meet at a shared
// horizontal line at the bottom, exactly matching the drawn reference's
// "U" shape with one straight side and one zigzag side.
function buildSolenoidCard(m,card){
  const W=GRID*3+CARD_PAD*2,H=GRID*2+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const xBat=CARD_PAD,xC1=CARD_PAD+GRID,xC2=CARD_PAD+GRID*2,xMtr=CARD_PAD+GRID*3,topY=CARD_PAD;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const boxX=xBat-10,boxY=topY+8,boxW=(xMtr-xBat)+20,boxH=H-boxY-6;
  const rect=document.createElementNS("http://www.w3.org/2000/svg","rect");
  rect.setAttribute("x",boxX);rect.setAttribute("y",boxY);rect.setAttribute("width",boxW);rect.setAttribute("height",boxH);
  rect.setAttribute("fill","#f4f4f5");rect.setAttribute("stroke","#0d0d0d");rect.setAttribute("stroke-width","1.4");rect.setAttribute("rx","2");
  svg.appendChild(rect);
  const line=(x1,y1,x2,y2)=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x1);l.setAttribute("y1",y1);l.setAttribute("x2",x2);l.setAttribute("y2",y2);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);};
  // BAT/MTR posts' own stub lines down into the box top edge.
  line(xBat,topY,xBat,boxY);
  line(xMtr,topY,xMtr,boxY);
  // Coil pin 1 (left): one straight lead, all the way down to the
  // shared bottom tie.
  const baseY=boxY+boxH-8;
  line(xC1,topY,xC1,baseY);
  // Coil pin 2 (right): a short straight stub, then the tight zigzag
  // (the coil itself) down to the same bottom tie.
  const zigTopY=topY+14,zigSteps=5,zigAmp=6;
  line(xC2,topY,xC2,zigTopY);
  const stepH=(baseY-zigTopY)/zigSteps;
  let d=`M${xC2} ${zigTopY}`;
  for(let i=0;i<zigSteps;i++){
    const yEnd=zigTopY+stepH*(i+1),dir=i%2===0?-1:1;
    d+=` L${xC2+dir*zigAmp} ${zigTopY+stepH*(i+0.5)} L${xC2} ${yEnd}`;
  }
  const coilPath=document.createElementNS("http://www.w3.org/2000/svg","path");
  coilPath.setAttribute("d",d);coilPath.setAttribute("fill","none");coilPath.setAttribute("stroke","#0d0d0d");
  coilPath.setAttribute("stroke-width","1.3");coilPath.setAttribute("stroke-linejoin","round");
  svg.appendChild(coilPath);
  // Bottom tie joining both leads — this is what makes it one coil
  // rather than two unrelated lines.
  line(xC1,baseY,xC2,baseY);
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  // AP-POWER-POST-001 — labels default BELOW every terminal here (not
  // `m.pinLabelPos`'s usual "top" default): every terminal on this card
  // exits UP, so a label sitting above the dot would land right on top
  // of the wire stub leaving it.
  const labelPos=m.pinLabelPos||"bottom";
  const mk=(i,x,name,isPost)=>{
    const t=m.terminals[i]||{n:name,c:"W"};
    const k=`${m.id}::${pinKey(i)}`;
    return`<div class="t-cell" style="left:${x}px;top:${topY}px"><div class="t-lbl pos-${labelPos}">${termLabelText(t,i)}</div><div class="t-dot${isPost?" post":""}" id="d_${sid(k)}" style="background:${swatchBg(t.c)}" title="${isPost?t.n:'Pin '+pinKey(i)+' — '+t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  };
  strip.innerHTML=mk(0,xBat,"BAT",true)+mk(1,xC1,"C1",false)+mk(2,xC2,"C2",false)+mk(3,xMtr,"MTR",true);
  card.appendChild(strip);
}
// AP-POWER-POST-001 — battery, per direct request ("maybe the battery
// should be similarly shaped"): same box-with-two-posts treatment as the
// solenoid above, minus the coil.
function buildBatteryCard(m,card){
  const W=GRID*2+CARD_PAD*2,H=GRID+CARD_PAD*2;
  card.style.width=W+"px";card.style.height=H+"px";
  const leftX=CARD_PAD,rightX=CARD_PAD+GRID*2,topY=CARD_PAD;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;overflow:visible;";
  const boxX=leftX-10,boxY=topY+8,boxW=(rightX-leftX)+20,boxH=H-boxY-8;
  const rect=document.createElementNS("http://www.w3.org/2000/svg","rect");
  rect.setAttribute("x",boxX);rect.setAttribute("y",boxY);rect.setAttribute("width",boxW);rect.setAttribute("height",boxH);
  rect.setAttribute("fill","#f4f4f5");rect.setAttribute("stroke","#0d0d0d");rect.setAttribute("stroke-width","1.4");rect.setAttribute("rx","2");
  svg.appendChild(rect);
  [leftX,rightX].forEach(x=>{const l=document.createElementNS("http://www.w3.org/2000/svg","line");l.setAttribute("x1",x);l.setAttribute("y1",topY);l.setAttribute("x2",x);l.setAttribute("y2",boxY);l.setAttribute("stroke","#0d0d0d");l.setAttribute("stroke-width","1.4");svg.appendChild(l);});
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  const pinLabelPos=m.pinLabelPos||"top";
  const mk=(i,x,y,name)=>{
    const t=m.terminals[i]||{n:name,c:"W"};
    const k=`${m.id}::${pinKey(i)}`;
    return`<div class="t-cell" style="left:${x}px;top:${y}px"><div class="t-lbl pos-${pinLabelPos}">${termLabelText(t,i)}</div><div class="t-dot post" id="d_${sid(k)}" style="background:${swatchBg(t.c)}" title="${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  };
  strip.innerHTML=mk(0,leftX,topY,"+")+mk(1,rightX,topY,"−");
  card.appendChild(strip);
}
// AP-WIRE-GRID-ALIGN-001 — same fixed-offset-from-anchor treatment as
// buildStdCard/buildConnCard. The glyph's own mirroring by `m.exit`
// (which side the bulb symbol faces) is dropped for the same reason
// `side` no longer changes buildStdCard's pin layout: `m.exit` still
// fully controls the wire STUB direction via exitDir()/route() below,
// unchanged — only its effect on the DECORATIVE glyph's mirroring is
// gone, since that would otherwise reintroduce a non-fixed offset
// depending on which side was picked. `GLYPH_W` is kept a whole GRID
// multiple specifically so the terminal column's own x offset stays
// grid-exact.
// AP-BULB-GENERIC-001 — one bulb card, 2 or 3 terminals (per direct
// request: "you can just make one bulb type... indicator lights would
// normally be single filament [2 terminals — signal+ground], a headlight
// [3 terminals — HI/LO filament+shared ground] would be the most any
// bulb has"), flippable both horizontal/vertical AND mirrored (`m.vertical`/
// `m.flipped`), with the terminal strip on whichever of the 4 resulting
// sides that puts it. Each of those 4 combinations is its own FIXED,
// grid-exact layout (not a continuously-variable offset computed from
// e.g. `m.exit`) — the exact invariant AP-WIRE-GRID-ALIGN-001 (this
// function's own prior version) already established elsewhere, so this
// doesn't reintroduce the misalignment that comment warns about.
function buildBulbCard(m,card){
  const n=m.terminals.length;
  const stripLen=(n-1)*GRID;
  const GLYPH_W=GRID*2;
  const vertical=!!m.vertical,flipped=!!m.flipped;
  const mainSize=GLYPH_W+CARD_PAD*2,stripSize=stripLen+CARD_PAD*2;
  const W=vertical?stripSize:mainSize,H=vertical?mainSize:stripSize;
  card.style.width=W+"px";card.style.height=H+"px";
  const R=13,sW=7,sH=5;
  let gcx,gcy;
  if(!vertical){gcx=flipped?W-GRID:GRID;gcy=CARD_PAD+stripLen/2;}
  else{gcx=CARD_PAD+stripLen/2;gcy=flipped?H-GRID:GRID;}
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");
  svg.setAttribute("width",W);svg.setAttribute("height",H);
  svg.style.cssText="position:absolute;left:0;top:0;pointer-events:none;";
  // AP-BULB-VISUAL-001 — a colored indicator lens reads as tinted glass
  // even unlit (real indicator bulbs do); an incandescent (headlight/
  // taillight-style) bulb's glass stays clear/white until lit — per
  // direct request for "a visual representation of an incandescent bulb
  // that goes from white to yellow." LiveSim (js/simulation/live-runner.js)
  // overwrites this same `fill`/`filter` once the solver has a real
  // lit/unlit answer; this is only the pre-simulation default look.
  const isIncandescent=m.bulbStyle==="incandescent"||!m.bulbColor;
  const offFill=isIncandescent?"#fffde7":"#52525b";
  const gl=document.createElementNS("http://www.w3.org/2000/svg","circle");gl.setAttribute("cx",gcx);gl.setAttribute("cy",gcy);gl.setAttribute("r",R);gl.setAttribute("fill",offFill);gl.setAttribute("stroke","#0d0d0d");gl.setAttribute("stroke-width","1.2");gl.classList.add("bgl");gl.dataset.mid=m.id;svg.appendChild(gl);
  const fil=document.createElementNS("http://www.w3.org/2000/svg","path");fil.setAttribute("d",`M${gcx-5} ${gcy} Q${gcx} ${gcy-5} ${gcx+5} ${gcy}`);fil.setAttribute("fill","none");fil.setAttribute("stroke","#ca8a04");fil.setAttribute("stroke-width","1");svg.appendChild(fil);
  // Socket/base rect sits on the terminal-facing edge of the glyph.
  const st=document.createElementNS("http://www.w3.org/2000/svg","rect");
  if(!vertical){st.setAttribute("x",flipped?0:W-sW);st.setAttribute("y",gcy-sH/2);st.setAttribute("width",sW);st.setAttribute("height",sH);}
  else{st.setAttribute("x",gcx-sW/2);st.setAttribute("y",flipped?0:H-sH);st.setAttribute("width",sH);st.setAttribute("height",sW);}
  st.setAttribute("fill","#d4d4d4");st.setAttribute("stroke","#0d0d0d");st.setAttribute("stroke-width","0.8");svg.appendChild(st);
  card.appendChild(svg);
  const strip=document.createElement("div");
  strip.className="t-strip";
  strip.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  const stripX=!vertical?(flipped?0:mainSize):null;
  const stripY=vertical?(flipped?0:mainSize):null;
  const lblPos=!vertical?(flipped?"left":"right"):(flipped?"top":"bottom");
  strip.innerHTML=m.terminals.map((t,i)=>{
    const k=`${m.id}::${pinKey(i)}`;
    const x=!vertical?stripX:CARD_PAD+i*GRID;
    const y=vertical?stripY:CARD_PAD+i*GRID;
    return`<div class="t-cell" style="left:${x}px;top:${y}px"><div class="t-lbl pos-${lblPos}">${pinKey(i)}</div><div class="t-dot" id="d_${sid(k)}" style="background:${swatchBg(t.c)};width:6px;height:6px" title="Pin ${pinKey(i)} — ${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${pinKey(i)}"></div></div>`;
  }).join("");
  card.appendChild(strip);
}
// AP-WIRE-GRID-ALIGN-001 — a connector's IN and OUT dots (per pin) used
// to sit only a few px apart (the pin-graphic's own small fixed size),
// which — like buildStdCard's old flex spacing — was never a multiple
// of GRID. Both dots are now placed a full GRID unit apart, exactly the
// same fixed-offset-from-anchor approach buildStdCard uses: horizontal
// connector -> IN above OUT (stacked in y); vertical connector -> IN
// left of OUT (stacked in x, matching exitDir()'s own m.vertical branch
// below, which already treats a vertical connector's IN as its LEFT
// side and OUT as its RIGHT side).
function _connDot(mid,pinIdx,ioSuffix,color,name,cx,cy){
  const k=`${mid}::${pinKey(pinIdx)}_${ioSuffix}`;
  const dot=document.createElement("div");
  dot.className="t-dot";dot.id="d_"+sid(k);
  dot.style.cssText=`position:absolute;left:${cx}px;top:${cy}px;transform:translate(-50%,-50%);background:${swatchBg(color)};width:6px;height:6px`;
  // AP-CONNECTOR-PIN-LABEL-001 — per direct request: connector pins are
  // plain numbered pins, same as every other module's terminals ("most
  // diagrams" label them that way) — the literal words "IN"/"OUT" in
  // this tooltip read as directional signal flow, which a connector
  // doesn't have until it's actually mated. `ioSuffix` (still used
  // internally — dataset.tn, wire pin refs, routing) is deliberately
  // left out of what the user actually sees here.
  dot.title=`Pin ${pinKey(pinIdx)} (${name}): ${color}`;
  dot.dataset.mid=mid;dot.dataset.tn=pinKey(pinIdx)+"_"+ioSuffix;
  return dot;
}
function buildConnCard(m,card){
  const vertical=!!m.vertical;
  const n=m.terminals.length;
  const stripLen=(n-1)*GRID;
  card.style.width=(vertical?GRID+CARD_PAD*2:stripLen+CARD_PAD*2)+"px";
  card.style.height=(vertical?stripLen+CARD_PAD*2:GRID+CARD_PAD*2)+"px";
  card.style.background="#e2e8f0";card.style.border="1.5px solid #475569";card.style.borderRadius="3px";
  const layer=document.createElement("div");layer.style.cssText="position:absolute;left:0;top:0;right:0;bottom:0;";
  m.terminals.forEach((t,i)=>{
    const parts=t.c.split("|");const cIn=parts[0]||"W",cOut=parts[1]||cIn;
    const inX=vertical?CARD_PAD:CARD_PAD+i*GRID, inY=vertical?CARD_PAD+i*GRID:CARD_PAD;
    const outX=vertical?CARD_PAD+GRID:CARD_PAD+i*GRID, outY=vertical?CARD_PAD+i*GRID:CARD_PAD+GRID;
    layer.appendChild(_connDot(m.id,i,"IN",cIn,t.n,inX,inY));
    layer.appendChild(_connDot(m.id,i,"OUT",cOut,t.n,outX,outY));
    // Decorative pass-through bar between this pin's IN/OUT dots —
    // purely cosmetic (no dataset/id, never a wire endpoint), so it
    // doesn't need to itself land on any particular grid point.
    const bar=document.createElement("div");
    if(vertical) bar.style.cssText=`position:absolute;left:${inX}px;top:${inY}px;width:${GRID}px;height:6px;transform:translate(0,-50%);background:#94a3b8;border:1px solid #475569;border-radius:1px;`;
    else bar.style.cssText=`position:absolute;left:${inX}px;top:${inY}px;width:6px;height:${GRID}px;transform:translate(-50%,0);background:#94a3b8;border:1px solid #475569;border-radius:1px;`;
    layer.appendChild(bar);
    const lbl=document.createElement("div");
    lbl.style.cssText=`position:absolute;left:${vertical?inX+GRID/2:inX}px;top:${vertical?inY:inY+GRID/2}px;transform:translate(-50%,-50%);font-size:4px;color:#334155;font-weight:700;text-align:center;font-family:'Courier New',monospace;white-space:nowrap;pointer-events:none;`;
    lbl.textContent=pinKey(i);
    layer.appendChild(lbl);
  });
  card.appendChild(layer);
}

function placeCards(){
  MODULES.forEach(m=>{
    const pos=positions[m.id]||DEFAULT_POS[m.id]||{x:50,y:50};
    let card=cardEls[m.id];
    if(!card){card=buildCard(m);canvas.appendChild(card);cardEls[m.id]=card;setupDrag(card,m.id);setupTermClicks(card);}
    card.style.left=pos.x+"px";card.style.top=pos.y+"px";
  });
}
function removeCard(id){const c=cardEls[id];if(c){c.remove();delete cardEls[id];}}


// ── PAN / ZOOM ───────────────────────────────────────────────────
// AP-VIEW-SETTINGS-001 — `#zoom-display` went from a read-only <span>
// to an editable <input> (per direct user request: type a zoom %
// directly instead of only the −/+ buttons) — `.value`, not
// `.textContent`, is what actually changes an <input>'s displayed text.
function applyT(){scene.style.transform=`translate(${tx}px,${ty}px) scale(${scale})`;$("zoom-display").value=Math.round(scale*100)+"%";updateMinimap();persistViewportState();}
function zBy(d,px,py){const ns=Math.min(3,Math.max(.15,scale+d));if(px!=null){tx=px-(px-tx)*(ns/scale);ty=py-(py-ty)*(ns/scale);}scale=ns;applyT();drawWires();}
function zReset(){const vw=vp.offsetWidth,vh=vp.offsetHeight,cw=canvas.offsetWidth,ch=canvas.offsetHeight;const s=Math.min(.9,vw/cw,(vh-20)/ch);scale=s;tx=Math.max(10,(vw-cw*s)/2);ty=14;applyT();drawWires();}
// AP-VIEW-SETTINGS-001 — the topbar's zoom % input (see the onblur wired
// to this in index.html) — parses whatever the user typed, clamps it to
// the same [15%,300%] range zBy()'s own −/+ buttons already respect, and
// re-centers the same way zBy() does when no anchor point is given
// (keeps the current center of the viewport fixed rather than jumping
// to the canvas origin).
function setZoomPct(pct){
  if(!Number.isFinite(pct))return;
  const ns=Math.min(3,Math.max(.15,pct/100));
  const vw=vp.offsetWidth,vh=vp.offsetHeight;
  const cx=vw/2,cy=vh/2;
  tx=cx-(cx-tx)*(ns/scale);ty=cy-(cy-ty)*(ns/scale);
  scale=ns;applyT();drawWires();
}
function setZoomPctFromInput(input){
  const n=parseFloat(input.value);
  if(Number.isFinite(n))setZoomPct(n);
  else input.value=Math.round(scale*100)+"%"; // invalid entry — revert to the real current value
}

// A full fit-to-diagram (zReset, still what "Fit"/F does on demand) puts
// a large harness well under half scale — unreadable, and the reason the
// app used to force everyone back to 40-60% by hand on every single
// open. Startup instead restores whatever viewport the user left the
// diagram at (persistViewportState, above), and only computes a fresh
// fit the very first time there's nothing saved yet — clamped to a
// legible minimum rather than however small the full diagram happens to
// need, since the user can always pan to the rest.
const VIEWPORT_MIN_SCALE=0.5;
// AP-VIEW-SETTINGS-001 — "nothing saved yet" used to always mean
// "compute a fresh fit-to-content." A user-configured default zoom %
// (set via the new ⚙ Zoom & Scale Defaults panel, loadDefaultZoomPct()
// below) now takes priority over that fit computation, so a fresh
// launch (or an explicit "Reset to these now") starts at the zoom level
// the user actually asked for, not a diagram-size-dependent guess.
function initViewport(){
  const saved=loadViewportState();
  if(saved&&saved.scale){scale=saved.scale;tx=saved.tx;ty=saved.ty;applyT();return;}
  const vw=vp.offsetWidth,vh=vp.offsetHeight,cw=canvas.offsetWidth,ch=canvas.offsetHeight;
  const defaultPct=loadDefaultZoomPct();
  scale=defaultPct!=null?Math.min(3,Math.max(.15,defaultPct/100)):Math.max(VIEWPORT_MIN_SCALE,Math.min(.9,vw/cw,(vh-20)/ch));
  tx=Math.max(10,(vw-cw*scale)/2);ty=14;
  applyT();
}

// Pan — background-drag pans in every mode now (per direct request:
// "allow panning and zooming when in edit mode"). Only wireMode/
// routeEditMode still block it — wireMode uses a background click to
// place a wire bend point, and routeEditMode's own drag targets a
// wire's route-segment hit zones, so a plain background mousedown there
// still needs to mean what it already means, not start a pan. Edit
// Mode's own module-drag (setupDrag, module-editor.js) is bound to each
// `.mod-card` individually, never the viewport background, so enabling
// background pan here can't collide with it — the `.mod-card`/`#fp`
// exclusion below already keeps a pan from starting on top of a card
// either way.
vp.addEventListener("mousedown",e=>{
  if(wireMode||routeEditMode)return;
  if(e.target.closest(".mod-card")||e.target.closest("#fp"))return;
  // Wire-hits have their own listeners; background pan is safe
  panActive=true;panSX=e.clientX;panSY=e.clientY;panOX=tx;panOY=ty;vp.classList.add("panning");
});
window.addEventListener("mousemove",e=>{if(!panActive)return;tx=panOX+(e.clientX-panSX);ty=panOY+(e.clientY-panSY);applyT();});
window.addEventListener("mouseup",()=>{panActive=false;vp.classList.remove("panning");});
vp.addEventListener("mousemove",e=>{if(!wireMode||!wireSrc)return;const cr=canvas.getBoundingClientRect();mcX=(e.clientX-cr.left)/scale;mcY=(e.clientY-cr.top)/scale;drawWires();});
// AP-SCROLL-ZOOM-001 — plain mouse-wheel now zooms directly (per direct
// request: "make the viewport scroll zoomable"), no Ctrl/Cmd modifier
// required anymore — matches the scroll-to-zoom convention most other
// diagram/canvas editors use. Works in every mode, edit included (this
// handler was never mode-gated to begin with — only the modifier-key
// requirement blocked a plain scroll before now).
vp.addEventListener("wheel",e=>{e.preventDefault();const r=vp.getBoundingClientRect();zBy(e.deltaY>0?-.1:.1,e.clientX-r.left,e.clientY-r.top);},{passive:false});

// Touch
const tDist=t=>Math.hypot(t[0].clientX-t[1].clientX,t[0].clientY-t[1].clientY);
vp.addEventListener("touchstart",e=>{
  if(e.touches.length===2){e.preventDefault();const r=vp.getBoundingClientRect(),cx=(e.touches[0].clientX+e.touches[1].clientX)/2-r.left,cy=(e.touches[0].clientY+e.touches[1].clientY)/2-r.top;pinch={active:true,d0:tDist(e.touches),cx,cy,s0:scale,tx0:tx,ty0:ty};panActive=false;}
  else if(e.touches.length===1&&!editMode&&!wireMode){const t=e.touches[0];panActive=true;panSX=t.clientX;panSY=t.clientY;panOX=tx;panOY=ty;}
},{passive:false});
vp.addEventListener("touchmove",e=>{e.preventDefault();if(pinch.active&&e.touches.length===2){const ns=Math.min(3,Math.max(.15,pinch.s0*(tDist(e.touches)/pinch.d0)));tx=pinch.cx-(pinch.cx-pinch.tx0)*(ns/pinch.s0);ty=pinch.cy-(pinch.cy-pinch.ty0)*(ns/pinch.s0);scale=ns;applyT();drawWires();}else if(panActive&&e.touches.length===1){const t=e.touches[0];tx=panOX+(t.clientX-panSX);ty=panOY+(t.clientY-panSY);applyT();}},{passive:false});
vp.addEventListener("touchend",e=>{if(e.touches.length<2)pinch.active=false;if(e.touches.length===0)panActive=false;});


// ── MINIMAP ──────────────────────────────────────────────────────
function initMinimap(){$("minimap").style.display="block";updateMinimap();}
function updateMinimap(){const mm=$("minimap"),mc=$("mm-c");const W=mm.offsetWidth,H=mm.offsetHeight;mc.width=W;mc.height=H;const ctx2=mc.getContext("2d");const cw=canvas.offsetWidth,ch=canvas.offsetHeight;const sX=W/cw,sY=H/ch;ctx2.fillStyle="#1a1a1a";ctx2.fillRect(0,0,W,H);MODULES.forEach(m=>{const pos=positions[m.id]||DEFAULT_POS[m.id];if(!pos)return;const card=cardEls[m.id];const cw2=card?card.offsetWidth||40:40,ch2=card?card.offsetHeight||30:30;ctx2.fillStyle=CAT_CLR[m.cat]||"#555";ctx2.fillRect(pos.x*sX,pos.y*sY,Math.max(3,cw2*sX),Math.max(2,ch2*sY));});const vb=$("mm-vp");const vpX=(-tx/scale)*sX,vpY=(-ty/scale)*sY,vpW=(vp.offsetWidth/scale)*sX,vpH=(vp.offsetHeight/scale)*sY;vb.style.left=Math.max(0,vpX)+"px";vb.style.top=Math.max(0,vpY)+"px";vb.style.width=Math.min(W,vpW)+"px";vb.style.height=Math.min(H,vpH)+"px";}
function minimapClick(e){const mm=$("minimap");const cx=e.offsetX/mm.offsetWidth*canvas.offsetWidth,cy=e.offsetY/mm.offsetHeight*canvas.offsetHeight;tx=vp.offsetWidth/2-cx*scale;ty=vp.offsetHeight/2-cy*scale;applyT();}


// ── WIRE ROUTING ─────────────────────────────────────────────────
// A diagram saved before terminals were keyed by pin number (see
// pinKey's own doc comment) still has its wire endpoints stored as the
// old free-text terminal name — optionally suffixed `_IN`/`_OUT` for a
// connector — which no longer matches any pin-based dot id. Resolve it
// once against the module's current terminal list and self-heal every
// WIRES entry referencing it (so this only ever runs once per legacy
// reference, not on every redraw) rather than requiring every save/load
// path in the app to know about the migration.
function _resolveLegacyTerminalRef(modId,ref){
  const m=MODULES.find(x=>x.id===modId);if(!m)return null;
  const suffixMatch=/^(.*)(_IN|_OUT)$/.exec(ref);
  const name=suffixMatch?suffixMatch[1]:ref,suffix=suffixMatch?suffixMatch[2]:"";
  const idx=m.terminals.findIndex(t=>t.n===name);
  return idx===-1?null:pinKey(idx)+suffix;
}
function getPos(modId,termName){
  let dot=document.getElementById("d_"+sid(`${modId}::${termName}`));
  if(!dot){
    const resolved=_resolveLegacyTerminalRef(modId,termName);
    if(resolved){
      WIRES.forEach(w=>{
        if(w.from.m===modId&&w.from.t===termName)w.from.t=resolved;
        if(w.to.m===modId&&w.to.t===termName)w.to.t=resolved;
      });
      dot=document.getElementById("d_"+sid(`${modId}::${resolved}`));
    }
  }
  if(!dot)return null;
  const cr=canvas.getBoundingClientRect(),dr=dot.getBoundingClientRect();
  return{x:(dr.left-cr.left+dr.width/2)/scale,y:(dr.top-cr.top+dr.height/2)/scale};
}
function exitDir(modId,termName){
  const m=MODULES.find(x=>x.id===modId);if(!m)return"down";
  // Connector cards (buildConnCard) always stack each terminal's IN dot
  // above its OUT dot in the DOM, regardless of the module's own `exit`
  // property (every catalog connector hardcodes exit:'down') — using that
  // single module-wide direction for the IN dot sent its stub straight
  // down through the card toward the OUT dot before routing away, making
  // wires off the IN pin look like they started at an arbitrary point on
  // the card instead of the actual pin. Route each dot from its own edge.
  if(m.connector&&termName){
    if(m.vertical){
      if(termName.endsWith("_IN"))return"left";
      if(termName.endsWith("_OUT"))return"right";
    }
    if(termName.endsWith("_IN"))return"up";
    if(termName.endsWith("_OUT"))return"down";
  }
  return m.exit;
}
// Resolves a terminal's own pin-number index from its stored ref
// (`"3"`, or a connector's `"3_IN"`/`"3_OUT"`), for looking the terminal
// object itself up in `m.terminals`.
function terminalIdxForRef(termName){
  if(termName==null)return -1;
  const bare=String(termName).replace(/_IN$|_OUT$/,"");
  const n=Number(bare);
  return Number.isInteger(n)?n-1:-1;
}
// AP-TERMINAL-EXIT-001 — which side a wire actually leaves/enters a given
// terminal from, per direct correction: this is a property of the
// TERMINAL itself (fixed regardless of which wire happens to be plugged
// into it), not something a wire gets to choose — the original
// `w.fromExit`/`w.toExit` per-wire override was reported as "ambiguous"
// for exactly this reason (rewiring a pin silently lost whatever
// direction had been set on the old wire). Resolution order: the
// terminal's own `t.exit` (set via the module's sidebar inspector,
// setTerminalExit(), wire-editor.js) wins if present; `legacyWireExit`
// (the older per-wire `w.fromExit`/`w.toExit`, still honored so a
// splice/wire configured before this fix doesn't silently revert) is the
// fallback for a terminal with no override of its own; `exitDir()`'s
// connector-hardcode/module-default is the final fallback, unchanged.
function effectiveExitFor(modId,termName,legacyWireExit){
  const m=MODULES.find(x=>x.id===modId);
  const idx=terminalIdxForRef(termName);
  const t=(m&&idx>=0)?m.terminals&&m.terminals[idx]:null;
  if(t&&t.exit)return t.exit;
  if(legacyWireExit)return legacyWireExit;
  return exitDir(modId,termName);
}
function exitPt(p,dir){return dir==="down"?{x:p.x,y:p.y+STUB}:dir==="up"?{x:p.x,y:p.y-STUB}:dir==="right"?{x:p.x+STUB,y:p.y}:{x:p.x-STUB,y:p.y};}
// AP-WIRE-TERMINAL-FAN-001 — when more than one wire shares the exact
// same terminal (either end — a shared ground/splice/ignition feed is
// the common real-world case), every one of those wires' stubs used to
// leave from the literal same pixel in the literal same direction,
// making them render as one indistinguishable line until they diverged
// somewhere later — reported directly, with a screenshot showing two
// wires off one ring terminal touching all the way up to their bend.
// This is deliberately NOT a revival of the old per-wire "rail"
// allocation removed from route() below (that dodged every nearby wire's
// corridor and added an unwanted staircase bend to the overwhelming
// majority of wires, per that same direct feedback) — this only ever
// fires for the genuinely narrow case data itself identifies: wires that
// share ONE EXACT terminal. A wire with no such sibling gets `count<=1`
// and renders byte-for-byte as before.
//
// AP-SPLICE-INSPECTOR-001 companion fix — grouping used to only check
// the shared TERMINAL, not whether the wires sharing it were actually
// about to overlap. Two wires off the same splice that exit in
// DIFFERENT directions (one 'up', one 'right' — e.g. because the
// splice's own inspector was used to give one of them an explicit
// fromExit/toExit override specifically so it wouldn't collide with the
// other) never actually run collinear with each other at all, so
// fanning them apart was a pure cosmetic side effect with no real
// overlap behind it — reported directly, with a screenshot showing
// small unwanted zigzags on several wires at a splice where only ONE
// pair of them actually needed separating, and confirmed again when
// setting an explicit direction on one wire barely changed anything
// (it was still being counted in the same group as everything else at
// that terminal, regardless of direction). Only wires whose EFFECTIVE
// exit direction at this terminal (their own override if set, else the
// module's/splice's plain exit() side) matches `dir` are grouped
// together now — a wire exiting a different direction gets `count<=1`
// (a group of just itself) and renders with zero offset, exactly like a
// terminal with only one wire on it.
function wireEffectiveExitAt(w,mid,tname){
  if(w.from.m===mid&&w.from.t===tname)return effectiveExitFor(mid,tname,w.fromExit);
  if(w.to.m===mid&&w.to.t===tname)return effectiveExitFor(mid,tname,w.toExit);
  return null;
}
function wireTerminalGroup(w,end,dir){
  const t=w[end];
  const group=WIRES.filter(x=>wireEffectiveExitAt(x,t.m,t.t)===dir);
  if(group.length<=1)return{index:0,count:1};
  group.sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
  return{index:group.findIndex(x=>x.id===w.id),count:group.length};
}
const TERM_FAN_SPACING=6; // px between adjacent wires sharing a terminal — matches NUDGE's own step size
function terminalFanOffset(dir,index,count){
  if(count<=1)return{x:0,y:0};
  const spread=(index-(count-1)/2)*TERM_FAN_SPACING;
  return(dir==="up"||dir==="down")?{x:spread,y:0}:{x:0,y:spread};
}
function svgP(pts){return"M"+pts.map(p=>`${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" L");}
// AP-WIRE-STRIPE-001 — builds a bi-color wire's stripe as a SEPARATE
// path offset perpendicular to the main route, segment by segment (see
// the tc-branch's own doc comment in drawWires() for why per-segment,
// not one continuous offset path). Each segment's own direction vector,
// rotated 90°, gives that segment's perpendicular — since every segment
// in this app's routing is axis-aligned (horizontal or vertical, never
// diagonal — the single exception being AP-WIRE-TERMINAL-FAN-001's tiny
// stub micro-jog, harmless here), this reduces to a plain constant
// vertical or horizontal nudge per segment, just computed generally
// enough to also cover that one diagonal case correctly.
function buildStripePath(pts,offset){
  const parts=[];
  for(let i=0;i<pts.length-1;i++){
    const p=pts[i],q=pts[i+1];
    const dx=q.x-p.x,dy=q.y-p.y,len=Math.hypot(dx,dy);
    if(len<0.01)continue;
    const nx=-dy/len*offset,ny=dx/len*offset;
    parts.push(`M${(p.x+nx).toFixed(1)} ${(p.y+ny).toFixed(1)} L${(q.x+nx).toFixed(1)} ${(q.y+ny).toFixed(1)}`);
  }
  return parts.join(" ");
}
function cleanPts(pts){const o=[pts[0]];for(let i=1;i<pts.length-1;i++){const a=o[o.length-1],b=pts[i],c=pts[i+1];if(!(Math.abs(a.x-b.x)<.5&&Math.abs(b.x-c.x)<.5)&&!(Math.abs(a.y-b.y)<.5&&Math.abs(b.y-c.y)<.5))o.push(b);}o.push(pts[pts.length-1]);return o;}
function getMovableSegs(pts){
  const segs=[];
  for(let i=1;i<pts.length-2;i++){
    const p=pts[i],q=pts[i+1];
    segs.push({i1:i,i2:i+1,axis:Math.abs(p.y-q.y)<1?"y":"x"});
  }
  return segs;
}
function route(w){
  const a=getPos(w.from.m,w.from.t),b=getPos(w.to.m,w.to.t);if(!a||!b)return null;
  // AP-TERMINAL-EXIT-001 — each end's effective exit side is now the
  // TERMINAL's own override first (any module's sidebar inspector,
  // setTerminalExit()), the older per-wire `w.fromExit`/`w.toExit` second
  // (kept only so a wire configured before this fix doesn't silently
  // revert), and exitDir()'s connector-hardcode/module-default last — see
  // effectiveExitFor()'s own doc comment for the full rationale.
  const dA=effectiveExitFor(w.from.m,w.from.t,w.fromExit),dB=effectiveExitFor(w.to.m,w.to.t,w.toExit);
  // AP-WIRE-TERMINAL-FAN-001 — fan multiple wires sharing one terminal
  // apart right at their stub (see wireTerminalGroup's own doc comment);
  // a no-op ({x:0,y:0}) whenever this wire is the only one on that
  // terminal, so the overwhelmingly common single-wire-per-terminal case
  // is completely unaffected.
  const groupA=wireTerminalGroup(w,"from",dA),groupB=wireTerminalGroup(w,"to",dB);
  const fanA=terminalFanOffset(dA,groupA.index,groupA.count),
        fanB=terminalFanOffset(dB,groupB.index,groupB.count);
  const eaBase=exitPt(a,dA),ebBase=exitPt(b,dB);
  const ea={x:eaBase.x+fanA.x,y:eaBase.y+fanA.y},eb={x:ebBase.x+fanB.x,y:ebBase.y+fanB.y};
  // Single-bend orthogonal routing: straight out from the source in its
  // own exit direction, ONE 90° turn at the exact point that lines up
  // with the destination, then straight into the destination — the real
  // convention these diagrams use almost always (per direct user
  // feedback: the previous version routed a multi-segment staircase —
  // an extra allocated "rail" offset from both stubs specifically to
  // dodge other wires' rails — which reads as several unnecessary bends
  // for the overwhelming majority of wires and made manual straightening
  // the norm instead of the exception). The bend point only depends on
  // which axis the SOURCE exits along: if vertical (up/down), the bend
  // keeps the source stub's x and takes on the destination stub's y
  // (continue vertically, then turn horizontal into the destination);
  // if horizontal (left/right), the reverse. This one rule produces a
  // correct single-corner path for all four source/destination exit-
  // direction combinations (both vertical, both horizontal, or mixed) —
  // when the two exits already align on the turning axis, `cleanPts`
  // below collapses the bend away entirely into one straight segment,
  // exactly the fully-straight common case in a same-row diagram.
  // No anti-overlap "rail" allocation anymore (the old `allocY`/`allocX`
  // pair, removed — real vehicle wiring diagrams don't actually need it:
  // per direct user feedback, a source and destination terminal never
  // face away from each other, and modules needing a direct connection
  // are almost always on opposite rows, not sitting immediately next to
  // each other in the same row — so the single-bend path essentially
  // never needs to dodge the module it's leaving or arriving at. Two
  // wires whose default routes happen to coincide are the rare
  // exception a manual route nudge (already supported, unchanged) can
  // resolve case by case, never the default cost every wire pays.
  const vertA=(dA==="up"||dA==="down");
  const bend=vertA?{x:ea.x,y:eb.y}:{x:eb.x,y:ea.y};
  const pts=[a,ea,bend,eb,b];
  let c=cleanPts(pts);
  // Apply manual overrides — clone points first so we don't mutate shared refs
  c=c.map(p=>({x:p.x,y:p.y}));
  const overrides=wireRoutes[w.id];
  if(overrides){
    const movable=getMovableSegs(c);
    movable.forEach((seg,i)=>{
      if(overrides[i]===undefined)return;
      const off=overrides[i];
      if(seg.axis==="y"){c[seg.i1].y+=off;c[seg.i2].y+=off;}
      else{c[seg.i1].x+=off;c[seg.i2].x+=off;}
    });
  }
  let lp=null,mxL=0;
  for(let i=0;i<c.length-1;i++){const p=c[i],q=c[i+1];if(Math.abs(p.y-q.y)<1){const l=Math.abs(q.x-p.x);if(l>mxL){mxL=l;lp={x:(p.x+q.x)/2,y:p.y};}}}
  if(!lp)lp={x:(a.x+b.x)/2,y:(a.y+b.y)/2};
  // `hit` used to be built from `c.slice(1,-1)` (dropping the endpoints
  // at the terminals themselves) to keep the wire's hit zone from
  // competing with the terminal dots' own click handling. But cleanPts
  // above collapses collinear points, so a wire that ends up perfectly
  // straight (both terminals already aligned, the single-bend router's
  // exact intent for the common case) reduces `c` to just its two
  // endpoints — slicing THOSE off left an empty point list, i.e.
  // `svgP([])` = the literal string "M" with no coordinates at all: a
  // degenerate, permanently unclickable hit path. The wire still
  // rendered fine (the visible path below uses the un-sliced `c`), so
  // this was invisible until someone actually tried clicking a straight
  // wire — confirmed live: which wires were selectable had nothing to
  // do with terminal naming, it was exactly this, straight vs. bent.
  // The terminal-dot concern the slice existed for doesn't actually
  // apply — dots live on `.mod-card` (z-index 10), strictly above
  // #wire-layer, so they already win any click at an overlapping pixel
  // regardless of what the wire's own hit path covers.
  return{path:svgP(c),hit:svgP(c),lp,pts:c};
}

// Projects (mx,my) onto every segment of w's rendered route and returns
// the closest point on the polyline — the geometry splice placement
// needs (AP-EK/DIAGRAM splice support) that nothing else in this file
// computed before (existing wire hit-testing only relies on the
// browser's own SVG path hit-test, never a point on the path itself).
function closestPointOnWire(w,mx,my){
  const rt=route(w);if(!rt)return null;
  const pts=rt.pts;let best=null,bestD=Infinity,bestAxis=null;
  for(let i=0;i<pts.length-1;i++){
    const p=pts[i],q=pts[i+1];
    const dx=q.x-p.x,dy=q.y-p.y;const len2=dx*dx+dy*dy;
    let t=len2>0?((mx-p.x)*dx+(my-p.y)*dy)/len2:0;
    t=Math.max(0,Math.min(1,t));
    const px=p.x+t*dx,py=p.y+t*dy;
    const d=Math.hypot(mx-px,my-py);
    if(d<bestD){bestD=d;best={x:px,y:py};bestAxis=Math.abs(dy)<Math.abs(dx)?"h":"v";}
  }
  // `axis` — "h"/"v" for the orientation of the specific route segment the
  // point landed on — is what insertSpliceOnWire (wire-editor.js) uses to
  // give a newly-placed splice an exit direction that continues straight
  // through the existing run instead of always defaulting to "up" (which
  // only matched the wire's actual direction there by chance, and forced
  // an extra bend the rest of the time — the "bend always ends up in a
  // strange place" a splice used to need manual straightening for).
  return best?{point:best,dist:bestD,axis:bestAxis}:null;
}


// ── DRAW WIRES ───────────────────────────────────────────────────
// CRITICAL: #wire-layer always has pointer-events:none (set in CSS and never changed).
// Individual SVG children get pointer-events:auto only when needed.
function drawWires(){
  // AP-LIVE-SIM-001 — drawWires() is the one universal checkpoint every
  // module/wire add/delete/edit already calls; scheduling (not running
  // inline) the real per-bulb solve here means every one of those call
  // sites gets a correct lamp refresh for free, without instrumenting
  // each individually (see live-runner.js's own doc comment on why this
  // is debounced rather than run synchronously on every call).
  if(typeof LiveSim!=="undefined")LiveSim.scheduleRefresh();
  wsvg.innerHTML="";
  wsvg.setAttribute("width",canvas.offsetWidth);
  wsvg.setAttribute("height",canvas.offsetHeight);
  wsvg.setAttribute("viewBox",`0 0 ${canvas.offsetWidth} ${canvas.offsetHeight}`);
  const normalMode=!editMode&&!wireMode&&!routeEditMode;
  // AP-MASTER-EDIT-001 — Edit Mode now covers BOTH module repositioning
  // AND wire route editing (merged per direct request: three separate
  // modes — Layout Edit, Route Edit, and click-only inspection through
  // yet another mode — forced constant toggling just to inspect
  // something you were about to move). Whenever editMode is on, a
  // selected wire gets the exact same segment-drag handles routeEditMode
  // already renders below (same grid-snapped drag logic, unchanged), and
  // an unselected one is click-to-select the same way it already is in
  // routeEditMode/normalMode. `routeEditMode` itself still exists
  // unchanged as its own, narrower manual entry point (right-click "Edit
  // Route", the auto-enter-after-wire-creation flow) for anyone/anything
  // still using it on its own, without editMode also being on.
  const wireEditCapable=editMode||routeEditMode;
  WIRES.forEach(w=>{
    const rt=route(w);if(!rt)return;
    const isSel=selW&&selW.id===w.id;
    const isTr=tracedWires.size>0&&tracedWires.has(w.id);
    const isDim=(selW&&!isSel&&tracedWires.size===0)||(tracedWires.size>0&&!isTr);
    const bc=h(w.c),tc=trH(w.c);
    const g=document.createElementNS("http://www.w3.org/2000/svg","g");
    g.dataset.wid=w.id;
    // In Route Edit mode every other wire must stay at least slightly
    // visible and clickable (see the routeEditMode-only hit zone below) —
    // 0.1 (the normal "focus on selection" dim level) reads as invisible.
    g.style.opacity=isDim?(routeEditMode?"0.4":"0.1"):"1";
    // Glow for selected / traced
    if(isSel||isTr){
      const gl=document.createElementNS("http://www.w3.org/2000/svg","path");
      gl.setAttribute("d",rt.path);gl.setAttribute("stroke",isSel?"#f59e0b":"#10b981");
      gl.setAttribute("stroke-width","8");gl.setAttribute("fill","none");
      gl.setAttribute("stroke-linecap","round");gl.setAttribute("stroke-linejoin","round");
      gl.setAttribute("stroke-opacity","0.4");gl.style.pointerEvents="none";g.appendChild(gl);
    }
    // Main wire path
    // AP-WIRE-STRIPE-001 — thicker per direct request ("thick enough
    // that we would actually show the wire color with an actual stripe
    // running down the length of it") — roughly 1.8x the previous
    // 1.6/2.2/2.6, chosen to leave visible room for the stripe overlay
    // below without the wire looking oversized relative to modules/text.
    // AP-BATTERY-CABLE-001 — a battery cable (`w.cable`, wire-editor.js's
    // saveWireProps) renders noticeably thicker than a normal wire, on
    // top of the stripe-friendly width above — per direct request: "a
    // thicker wire i can create that will represent a battery cable
    // only either red or black in color."
    const wireWidth=(isSel?4.6:isTr?3.8:3)*(w.cable?1.7:1);
    const path=document.createElementNS("http://www.w3.org/2000/svg","path");
    path.setAttribute("d",rt.path);
    path.setAttribute("stroke-width",wireWidth);
    path.setAttribute("fill","none");path.setAttribute("stroke-linecap","round");path.setAttribute("stroke-linejoin","round");
    path.classList.add("wp");path.style.pointerEvents="none";
    if(tc){
      // AP-WIRE-STRIPE-001 — a bi-color wire ("Br/R" = Brown main, Red
      // stripe) used to render as a dashed alternation of the two colors
      // ALONG the wire's length (long dash of main, short dash of
      // stripe, repeating) — not the actual convention this was named
      // after: a real automotive wire's stripe is a thin line of the
      // second color running the FULL length of the wire, parallel to
      // it, painted onto one side of the main insulation color — not
      // alternating with it. Per direct request ("thick enough that we
      // would actually show the wire color with an actual stripe running
      // down the length of it"), the main path is now solid, full-width,
      // full-length; the stripe is a separate, thinner path offset
      // slightly to one side, built segment-by-segment (buildStripePath
      // below) since an arbitrary bent polyline has no single constant
      // offset direction that works for both its horizontal and vertical
      // runs — each straight segment gets its own perpendicular offset,
      // so the stripe is made of short disconnected pieces that meet
      // (with a small, cosmetically-acceptable gap) at each bend rather
      // than one continuous offset path.
      path.setAttribute("stroke",bc);
      g.appendChild(path);
      const stripe=document.createElementNS("http://www.w3.org/2000/svg","path");
      const stripeOffset=wireWidth*0.25,stripeWidth=Math.max(1,wireWidth*0.4);
      stripe.setAttribute("d",buildStripePath(rt.pts,stripeOffset));
      stripe.setAttribute("stroke",tc);
      stripe.setAttribute("stroke-width",stripeWidth);
      stripe.setAttribute("fill","none");stripe.setAttribute("stroke-linecap","butt");
      stripe.style.pointerEvents="none";
      g.appendChild(stripe);
    } else {
      path.setAttribute("stroke",bc);
      g.appendChild(path);
    }
    // ── ROUTE EDIT MODE: segment handles for EVERY wire — per direct
    //    request ("click edit route and then you can move any wire
    //    around, not just that one"). Edit Mode alone (routeEditMode
    //    still off) keeps the narrower, selected-wire-only version, for
    //    the plain "click a wire, then drag it" case without having gone
    //    through the wire panel's own "↔ Edit Route" button at all.
    if(routeEditMode||(editMode&&isSel)){
      const pts=rt.pts;const movable=getMovableSegs(pts);
      movable.forEach((seg,i)=>{
        const p=pts[seg.i1],q=pts[seg.i2];
        const isActiveSeg=selSeg&&selSeg.wid===w.id&&selSeg.segIdx===i;
        // Wide invisible hit zone for the segment
        const sh=document.createElementNS("http://www.w3.org/2000/svg","line");
        sh.setAttribute("x1",p.x);sh.setAttribute("y1",p.y);sh.setAttribute("x2",q.x);sh.setAttribute("y2",q.y);
        sh.setAttribute("stroke","transparent");sh.setAttribute("stroke-width","18");
        sh.setAttribute("fill","none");sh.setAttribute("stroke-linecap","round");
        sh.style.pointerEvents="auto"; // only segment hits, not the whole svg
        sh.style.cursor=seg.axis==="y"?"ns-resize":"ew-resize";
        sh.addEventListener("mousedown",e=>{
          e.stopPropagation();e.preventDefault();
          selSeg={wid:w.id,segIdx:i,axis:seg.axis};
          drawWires();
          $("wep-status").textContent=`Seg ${i+1} selected (${seg.axis==="y"?"horiz → drag/↑↓":"vert → drag/←→"}) · R reset`;
          // Drag the segment directly (mousedown→mousemove→mouseup), on top
          // of the existing arrow-key nudge — both write into the same
          // `wireRoutes[w.id][segIdx]` override map, so either input method
          // works interchangeably on the same segment.
          const startClientX=e.clientX,startClientY=e.clientY;
          if(!wireRoutes[w.id])wireRoutes[w.id]={};
          const startOff=wireRoutes[w.id][i]||0;
          // AP-WIRE-GRID-ALIGN-001 — `natural` is where this segment
          // would sit with NO manual override at all (the auto-router's
          // own position, `p[axis]`, minus whatever override is already
          // applied) — dragging then snaps the segment's FINAL absolute
          // position to the nearest grid multiple, not the raw pixel
          // delta, so a manually-dragged wire lands on the same grid
          // every terminal/module/splice already does (reported directly:
          // "wires are still not snapping to the same grid lines that the
          // terminals do" — this drag was the one remaining place a wire
          // could still end up off-grid after that fix).
          const natural=(seg.axis==="y"?p.y:p.x)-startOff;
          let dragged=false;
          const onMove=ev=>{
            const dx=(ev.clientX-startClientX)/scale,dy=(ev.clientY-startClientY)/scale;
            const delta=seg.axis==="y"?dy:dx;
            if(Math.abs(delta)>0.5)dragged=true;
            const rawAbs=natural+startOff+delta;
            wireRoutes[w.id][i]=Math.round(rawAbs/GRID)*GRID-natural;
            drawWires();
          };
          const onUp=()=>{
            window.removeEventListener("mousemove",onMove);
            window.removeEventListener("mouseup",onUp);
            if(dragged)$("wep-status").textContent=`Seg ${i+1} moved · drag again, arrows nudge, or R reset`;
          };
          window.addEventListener("mousemove",onMove);
          window.addEventListener("mouseup",onUp);
        });
        // AP-OEP-DIAGRAM-ANDROID-001 — touch equivalent of the drag above.
        // Mobile browsers/WebViews do not synthesize continuous `mousemove`
        // during a touch drag (unlike `click`, which tap already
        // synthesizes fine), so segment dragging needs its own
        // touchstart/touchmove/touchend path — same
        // `wireRoutes[w.id][segIdx]` override target as the mouse-drag and
        // arrow-key paths above. `stopPropagation` keeps this from also
        // triggering the canvas's own single-finger-pan touch handler
        // (`vp`'s own `touchstart` listener, which does not check
        // `routeEditMode`).
        sh.addEventListener("touchstart",e=>{
          e.stopPropagation();e.preventDefault();
          const touch=e.touches[0];if(!touch)return;
          selSeg={wid:w.id,segIdx:i,axis:seg.axis};
          drawWires();
          $("wep-status").textContent=`Seg ${i+1} selected (${seg.axis==="y"?"horiz → drag/↑↓":"vert → drag/←→"}) · R reset`;
          const startClientX=touch.clientX,startClientY=touch.clientY;
          if(!wireRoutes[w.id])wireRoutes[w.id]={};
          const startOff=wireRoutes[w.id][i]||0;
          // AP-WIRE-GRID-ALIGN-001 — same grid-snap the mouse-drag path
          // above uses; see its own doc comment.
          const natural=(seg.axis==="y"?p.y:p.x)-startOff;
          let dragged=false;
          const onMove=ev=>{
            const t=ev.touches[0];if(!t)return;
            ev.preventDefault();
            const dx=(t.clientX-startClientX)/scale,dy=(t.clientY-startClientY)/scale;
            const delta=seg.axis==="y"?dy:dx;
            if(Math.abs(delta)>0.5)dragged=true;
            const rawAbs=natural+startOff+delta;
            wireRoutes[w.id][i]=Math.round(rawAbs/GRID)*GRID-natural;
            drawWires();
          };
          const onEnd=()=>{
            window.removeEventListener("touchmove",onMove);
            window.removeEventListener("touchend",onEnd);
            window.removeEventListener("touchcancel",onEnd);
            if(dragged)$("wep-status").textContent=`Seg ${i+1} moved · drag again, arrows nudge, or R reset`;
          };
          window.addEventListener("touchmove",onMove,{passive:false});
          window.addEventListener("touchend",onEnd);
          window.addEventListener("touchcancel",onEnd);
        },{passive:false});
        g.appendChild(sh);
        // Visible highlight overlay
        const sv=document.createElementNS("http://www.w3.org/2000/svg","line");
        sv.setAttribute("x1",p.x);sv.setAttribute("y1",p.y);sv.setAttribute("x2",q.x);sv.setAttribute("y2",q.y);
        sv.setAttribute("stroke",isActiveSeg?"#22d3ee":"rgba(34,211,238,0.35)");
        sv.setAttribute("stroke-width",isActiveSeg?"3":"2");
        sv.setAttribute("fill","none");sv.setAttribute("stroke-linecap","round");sv.style.pointerEvents="none";g.appendChild(sv);
        // Midpoint handle dot
        const mx=(p.x+q.x)/2,my=(p.y+q.y)/2;
        const dot=document.createElementNS("http://www.w3.org/2000/svg","circle");
        dot.setAttribute("cx",mx);dot.setAttribute("cy",my);dot.setAttribute("r",isActiveSeg?"5":"3.5");
        dot.setAttribute("fill",isActiveSeg?"#22d3ee":"rgba(34,211,238,0.7)");
        dot.setAttribute("stroke","#0e7490");dot.setAttribute("stroke-width","1");dot.style.pointerEvents="none";g.appendChild(dot);
      });
    }
    // ── NORMAL MODE (or Edit Mode, not yet selected): wide transparent
    //    hit zone for clicking wires — see wireEditCapable's own doc
    //    comment above for why Edit Mode reaches this branch too now.
    else if(normalMode||editMode){
      const hit=document.createElementNS("http://www.w3.org/2000/svg","path");
      hit.setAttribute("d",rt.hit||rt.path);hit.setAttribute("stroke","transparent");
      hit.setAttribute("stroke-width","10");hit.setAttribute("fill","none");hit.setAttribute("stroke-linecap","round");
      hit.classList.add("wire-hit");
      hit.style.pointerEvents="auto"; // clickable in normal mode only
      hit.addEventListener("click",e=>{
        e.stopPropagation();
        selWire(w,e);
        // AP-MASTER-EDIT-001 — selWire() alone only shows a read-only
        // summary in the sidebar — reported directly, same gap as the
        // module click fix above: "the property panel pops up... in
        // order to edit it" means the actual editable modal, not a
        // summary with its own separate Edit button buried in it. Scoped
        // to editMode only — a plain click outside Edit Mode keeps its
        // existing lightweight inspect-only behavior unchanged.
        if(editMode)editWireProps();
      });
      hit.addEventListener("contextmenu",e=>{
        e.preventDefault();e.stopPropagation();
        ctxTarget=w;
        const cr=canvas.getBoundingClientRect();
        const mx=(e.clientX-cr.left)/scale,my=(e.clientY-cr.top)/scale;
        ctxClickPoint=closestPointOnWire(w,mx,my); // {point,dist,axis} — ctxAddSplice() (wire-editor.js) reads this for a wire target
        $("ctx-add-module").style.display="none";$("ctx-add-splice").style.display=ctxClickPoint?"":"none";$("ctx-add-diode").style.display=ctxClickPoint?"":"none";$("ctx-del").style.display="";$("ctx-edit").style.display="";$("ctx-trace").style.display="";$("ctx-route").style.display="";$("ctx-del").textContent="✕ Delete Wire";
        selWire(w,e);openCtxAt(e.clientX,e.clientY);
      });
      g.appendChild(hit);
    }
    // ── WIRE MODE: clicking a point on an existing wire either starts a
    //    new wire from a splice inserted there, or (if a source is
    //    already picked) completes the in-progress wire onto a splice
    //    inserted there — see handleWireClickOnExistingWire (wire-editor.js).
    //    Terminal dots keep their own click handlers (setupTermClicks)
    //    for the "click a real terminal" path; this is the "click
    //    anywhere along the wire itself" path.
    else if(wireMode){
      const hit=document.createElementNS("http://www.w3.org/2000/svg","path");
      hit.setAttribute("d",rt.hit||rt.path);hit.setAttribute("stroke","transparent");
      hit.setAttribute("stroke-width","10");hit.setAttribute("fill","none");hit.setAttribute("stroke-linecap","round");
      hit.classList.add("wire-hit");
      hit.style.pointerEvents="auto";
      hit.addEventListener("click",e=>{e.stopPropagation();handleWireClickOnExistingWire(w,e);});
      g.appendChild(hit);
    }
    // Note: a `routeEditMode&&!isSel` click-to-select branch used to
    // live here, back when Route Edit only rendered segment handles for
    // the selected wire and unselected ones needed a separate, narrower
    // "just select" hit zone. Now that routeEditMode alone renders
    // segment handles for EVERY wire (the branch above), this case is
    // already fully covered there — removed rather than left as
    // unreachable dead code.
    // Flow animation overlay (selected wire AND any traced wire with voltage)
    if(isSel||isTr){addFlowOverlay(g,rt.path,w,isSel);}
    if(isSel&&rt.lp){
      const txt=w.lbl||w.c,rw=Math.max(11,txt.length*4.6+6),rh=9;
      const bg=document.createElementNS("http://www.w3.org/2000/svg","rect");
      bg.setAttribute("x",rt.lp.x-rw/2);bg.setAttribute("y",rt.lp.y-rh/2);bg.setAttribute("width",rw);bg.setAttribute("height",rh);
      bg.setAttribute("rx","2");bg.setAttribute("fill","#fff");bg.setAttribute("fill-opacity","0.94");bg.setAttribute("stroke","#b45309");bg.setAttribute("stroke-width","0.9");bg.style.pointerEvents="none";g.appendChild(bg);
      const t=document.createElementNS("http://www.w3.org/2000/svg","text");
      t.setAttribute("x",rt.lp.x);t.setAttribute("y",rt.lp.y+0.5);t.setAttribute("text-anchor","middle");t.setAttribute("dominant-baseline","middle");
      t.setAttribute("fill","#7c2d12");t.setAttribute("font-size","6.5");t.textContent=txt;t.style.pointerEvents="none";g.appendChild(t);
    }
    // Meter lead dots on terminals
    if(isSel&&(leadR||leadB)){
      const mk=(lead,fill,sym)=>{if(!lead)return;const p=getPos(lead.m,lead.t);if(!p)return;const c=document.createElementNS("http://www.w3.org/2000/svg","circle");c.setAttribute("cx",p.x);c.setAttribute("cy",p.y);c.setAttribute("r","5");c.setAttribute("fill",fill);c.setAttribute("stroke","#fff");c.setAttribute("stroke-width","1.2");c.style.pointerEvents="none";g.appendChild(c);const tt=document.createElementNS("http://www.w3.org/2000/svg","text");tt.setAttribute("x",p.x);tt.setAttribute("y",p.y+0.6);tt.setAttribute("text-anchor","middle");tt.setAttribute("dominant-baseline","middle");tt.setAttribute("fill","#fff");tt.setAttribute("font-size","6");tt.setAttribute("font-weight","700");tt.textContent=sym;tt.style.pointerEvents="none";g.appendChild(tt);};
      mk(leadR,"#dc2626","+");mk(leadB,"#374151","-");
    }
    wsvg.appendChild(g);
  });
  // Wire-in-progress preview line
  if(wireMode&&wireSrc&&mcX){
    const sp=getPos(wireSrc.m,wireSrc.t);
    if(sp){
      const pv=document.createElementNS("http://www.w3.org/2000/svg","line");
      pv.setAttribute("x1",sp.x);pv.setAttribute("y1",sp.y);pv.setAttribute("x2",mcX);pv.setAttribute("y2",mcY);
      pv.setAttribute("stroke","#0891b2");pv.setAttribute("stroke-width","1.5");pv.setAttribute("stroke-dasharray","6 3");pv.setAttribute("stroke-linecap","round");pv.style.pointerEvents="none";wsvg.appendChild(pv);
    }
  }
  // Start or stop flow animation based on whether any flow overlays exist
  const hasFlow=wsvg.querySelector(".flow-overlay")!==null;
  if(hasFlow)startFlowAnim();else stopFlowAnim();
  updateMinimap();
}


// ── CURRENT FLOW ANIMATION ───────────────────────────────────────
// We use a CSS-animated SVG stroke-dashoffset overlay on the selected/traced wire
// Direction: from→to. Active when key>=1 and wire has non-zero VDC reading.
// Ground wires flow TO ground (reversed). No animation when key=0 or OPN/0.00.

let flowAnimId=null;
let flowOffset=0;
const FLOW_SPEED=1.2; // px per frame
const FLOW_DASH=12;
const FLOW_GAP=8;

function wireHasFlow(w){
  if(keyPos===0)return false;
  const rd=(window.SWPACK&&SWPACK.getReading(w.id,keyPos))||(w.R?w.R[keyPos]:null);
  if(!rd)return false;
  const v=parseFloat(rd.VDC||"0");
  if(isNaN(v)||v===0)return false;
  if(rd.CONT==="OPN")return false;
  return true;
}

// Returns +1 (from→to) or -1 (to→from, ground wires) flow direction
function wireFlowDir(w){
  const m=MODULES.find(x=>x.id===w.to.m);
  if(m&&m.cat==='ground')return -1;
  return 1;
}

function startFlowAnim(){
  if(flowAnimId)return;
  function tick(){
    flowOffset=(flowOffset+FLOW_SPEED)%(FLOW_DASH+FLOW_GAP);
    // Update all active flow overlays
    document.querySelectorAll(".flow-overlay").forEach(el=>{
      const dir=+el.dataset.dir;
      el.setAttribute("stroke-dashoffset",(dir>0?-flowOffset:flowOffset).toFixed(1));
    });
    flowAnimId=requestAnimationFrame(tick);
  }
  flowAnimId=requestAnimationFrame(tick);
}
function stopFlowAnim(){
  if(flowAnimId){cancelAnimationFrame(flowAnimId);flowAnimId=null;}
}

// Called from drawWires after building a wire group to add flow overlay
function addFlowOverlay(g,path,w,isSel){
  if(!wireHasFlow(w))return;
  const dir=wireFlowDir(w);
  const wc=h(w.c);
  // Bright contrasting color: complement of wire color, or just white-ish
  const flowColor=w.c==="Bl"||w.c==="G"?"#67e8f9":"#ffffff";
  const fo=document.createElementNS("http://www.w3.org/2000/svg","path");
  fo.setAttribute("d",path);
  fo.setAttribute("stroke",flowColor);
  fo.setAttribute("stroke-width",isSel?"1.8":"1.2");
  fo.setAttribute("fill","none");
  fo.setAttribute("stroke-linecap","round");
  fo.setAttribute("stroke-dasharray",`${FLOW_DASH} ${FLOW_GAP}`);
  fo.setAttribute("stroke-dashoffset","0");
  fo.setAttribute("stroke-opacity","0.72");
  fo.classList.add("flow-overlay");
  fo.dataset.dir=String(dir);
  fo.style.pointerEvents="none";
  g.appendChild(fo);
}

// Track if any flow overlays are present this draw cycle
let _hasFlow=false;

