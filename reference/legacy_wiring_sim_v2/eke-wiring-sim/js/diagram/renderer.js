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
const CAT_CLR={indicator:"#7c3aed",ignition:"#dc2626",control:"#2563eb",accessory:"#ea580c",charging:"#d97706",ground:"#374151",lighting:"#0891b2",switch:"#059669",starter:"#9333ea",power:"#b45309",connector:"#0e7490"};
const HEX={Bl:"#1e293b",Br:"#7c2d12",R:"#dc2626",G:"#15803d",Gr:"#9ca3af",Lg:"#4ade80",Y:"#ca8a04",W:"#94a3b8",Bu:"#2563eb",Blu:"#2563eb",O:"#ea580c",P:"#ec4899","—":"#999"};
const CNAMES={Bl:"Black",Br:"Brown",R:"Red",G:"Green",Gr:"Gray",Lg:"Lt Green",Y:"Yellow",W:"White",Bu:"Blue",Blu:"Blue",O:"Orange",P:"Pink","P/W":"Pink/White","Y/R":"Yellow/Red","Bl/Y":"Black/Yellow","Blu/Y":"Blue/Yellow","Bl/W":"Black/White","Y/W":"Yellow/White","Lg/R":"Lt Grn/Red","G/R":"Green/Red","Br/R":"Brown/Red","Blu/R":"Blue/Red"};
const h=c=>{if(!c)return"#888";const k=c.trim();if(HEX[k])return HEX[k];return HEX[k.split("/")[0].trim()]||"#666";};
const trH=c=>{if(!c)return null;const i=c.indexOf("/");if(i<0)return null;return HEX[c.slice(i+1).trim()]||null;};
const cn=c=>CNAMES[c]||c||"—";
const sid=s=>s.replace(/[^a-z0-9]/gi,"_");
const $=id=>document.getElementById(id);
const canvas=$("canvas"),scene=$("scene"),vp=$("viewport"),wsvg=$("wire-layer");
const cardEls={};
const STUB=14;


// ── CARD BUILDER ─────────────────────────────────────────────────
function buildCard(m){
  const card=document.createElement("div");card.className="mod-card";card.dataset.mid=m.id;
  const stripe=document.createElement("div");stripe.className="cat-stripe";stripe.style.background=CAT_CLR[m.cat]||"#888";card.appendChild(stripe);
  if(m.bulb)buildBulbCard(m,card);
  else if(m.connector)buildConnCard(m,card);
  else buildStdCard(m,card);
  const lbl=document.createElement("div");lbl.className="mod-label";lbl.innerHTML=`${m.label}<br><span class="mod-sub">${m.sub||""}</span>`;card.appendChild(lbl);
  return card;
}
function buildStdCard(m,card){
  card.style.paddingLeft="4px";
  const inner=document.createElement("div");inner.style.cssText="display:flex;flex-direction:column;min-height:28px;";
  const strip=document.createElement("div");strip.className="t-strip"+(m.exit==="down"?" bot":" top");
  strip.innerHTML=m.terminals.map(t=>{const k=`${m.id}::${t.n}`;return`<div class="t-cell"><div class="t-lbl">${t.c}</div><div class="t-dot" id="d_${sid(k)}" style="background:${h(t.c)}" title="${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${t.n}"></div></div>`;}).join("");
  if(m.exit==="down"){const sp=document.createElement("div");sp.style.cssText="flex:1 1 auto;min-height:6px";inner.appendChild(sp);inner.appendChild(strip);}
  else{inner.appendChild(strip);const sp=document.createElement("div");sp.style.minHeight="6px";inner.appendChild(sp);}
  card.appendChild(inner);
}
function buildBulbCard(m,card){
  const iL=m.exit==="right",R=13,sW=7,sH=5,svgW=R*2+sW,svgH=R*2+2,cx=iL?R:svgW-R,cy=R+1;
  const svg=document.createElementNS("http://www.w3.org/2000/svg","svg");svg.setAttribute("width",svgW);svg.setAttribute("height",svgH);svg.style.overflow="visible";
  const gl=document.createElementNS("http://www.w3.org/2000/svg","circle");gl.setAttribute("cx",cx);gl.setAttribute("cy",cy);gl.setAttribute("r",R);gl.setAttribute("fill","#fffde7");gl.setAttribute("stroke","#0d0d0d");gl.setAttribute("stroke-width","1.2");gl.classList.add("bgl");gl.dataset.mid=m.id;svg.appendChild(gl);
  const fil=document.createElementNS("http://www.w3.org/2000/svg","path");fil.setAttribute("d",`M${cx-5} ${cy} Q${cx} ${cy-5} ${cx+5} ${cy}`);fil.setAttribute("fill","none");fil.setAttribute("stroke","#ca8a04");fil.setAttribute("stroke-width","1");svg.appendChild(fil);
  const stX=iL?R*2:0;const st=document.createElementNS("http://www.w3.org/2000/svg","rect");st.setAttribute("x",stX);st.setAttribute("y",cy-sH/2);st.setAttribute("width",sW);st.setAttribute("height",sH);st.setAttribute("fill","#d4d4d4");st.setAttribute("stroke","#0d0d0d");st.setAttribute("stroke-width","0.8");svg.appendChild(st);
  const tp=document.createElement("div");tp.style.cssText="display:flex;flex-direction:column;justify-content:center;gap:3px;padding:3px 4px;background:#fff;border:1.2px solid #0d0d0d;";
  tp.innerHTML=m.terminals.map(t=>{const k=`${m.id}::${t.n}`;return`<div style="display:flex;align-items:center;gap:3px"><div class="t-dot" id="d_${sid(k)}" style="background:${h(t.c)};width:6px;height:6px" title="${t.n}: ${t.c}" data-mid="${m.id}" data-tn="${t.n}"></div><div class="t-lbl" style="font-size:4.5px">${t.c}</div></div>`;}).join("");
  const row=document.createElement("div");row.style.cssText="display:flex;align-items:center;padding:2px;";
  if(iL){row.appendChild(svg);row.appendChild(tp);}else{row.appendChild(tp);row.appendChild(svg);}
  card.appendChild(row);
}
function buildConnCard(m,card){
  card.style.paddingLeft="4px";
  const inner=document.createElement("div");inner.style.cssText="display:flex;flex-direction:column;align-items:center;padding:3px 4px;";
  const body=document.createElement("div");body.style.cssText="display:flex;flex-direction:row;align-items:center;gap:0;background:#e2e8f0;border:1.5px solid #475569;border-radius:3px;padding:2px 4px;";
  m.terminals.forEach((t,i)=>{
    const parts=t.c.split("|");const cIn=parts[0]||"W",cOut=parts[1]||cIn;
    const slot=document.createElement("div");slot.style.cssText="display:flex;flex-direction:column;align-items:center;gap:1px;padding:0 3px;";
    const dIn=document.createElement("div");dIn.className="t-dot";dIn.id="d_"+sid(`${m.id}::${t.n}_IN`);dIn.style.background=h(cIn);dIn.title=`${t.n} IN: ${cIn}`;dIn.dataset.mid=m.id;dIn.dataset.tn=t.n+"_IN";
    const pin=document.createElement("div");pin.style.cssText="width:6px;height:8px;background:#94a3b8;border:1px solid #475569;border-radius:1px;";
    const dOut=document.createElement("div");dOut.className="t-dot";dOut.id="d_"+sid(`${m.id}::${t.n}_OUT`);dOut.style.background=h(cOut);dOut.title=`${t.n} OUT: ${cOut}`;dOut.dataset.mid=m.id;dOut.dataset.tn=t.n+"_OUT";
    const lbl=document.createElement("div");lbl.style.cssText="font-size:4px;color:#334155;font-weight:700;text-align:center;font-family:'Courier New',monospace;white-space:nowrap;";lbl.textContent=t.n;
    slot.appendChild(dIn);slot.appendChild(pin);slot.appendChild(dOut);slot.appendChild(lbl);
    body.appendChild(slot);
    if(i<m.terminals.length-1){const sep=document.createElement("div");sep.style.cssText="width:1px;height:20px;background:#475569;margin:0 1px;";body.appendChild(sep);}
  });
  inner.appendChild(body);card.appendChild(inner);
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
function applyT(){scene.style.transform=`translate(${tx}px,${ty}px) scale(${scale})`;$("zoom-display").textContent=Math.round(scale*100)+"%";updateMinimap();}
function zBy(d,px,py){const ns=Math.min(3,Math.max(.15,scale+d));if(px!=null){tx=px-(px-tx)*(ns/scale);ty=py-(py-ty)*(ns/scale);}scale=ns;applyT();drawWires();}
function zReset(){const vw=vp.offsetWidth,vh=vp.offsetHeight,cw=canvas.offsetWidth,ch=canvas.offsetHeight;const s=Math.min(.9,vw/cw,(vh-20)/ch);scale=s;tx=Math.max(10,(vw-cw*s)/2);ty=14;applyT();drawWires();}

// Pan — only when NOT in edit/wire/route-edit mode and not clicking a card
vp.addEventListener("mousedown",e=>{
  if(editMode||wireMode||routeEditMode)return;
  if(e.target.closest(".mod-card")||e.target.closest("#fp"))return;
  // In normal mode, wire-hits have their own listeners; background pan is safe
  panActive=true;panSX=e.clientX;panSY=e.clientY;panOX=tx;panOY=ty;vp.classList.add("panning");
});
window.addEventListener("mousemove",e=>{if(!panActive)return;tx=panOX+(e.clientX-panSX);ty=panOY+(e.clientY-panSY);applyT();});
window.addEventListener("mouseup",()=>{panActive=false;vp.classList.remove("panning");});
vp.addEventListener("mousemove",e=>{if(!wireMode||!wireSrc)return;const cr=canvas.getBoundingClientRect();mcX=(e.clientX-cr.left)/scale;mcY=(e.clientY-cr.top)/scale;drawWires();});
vp.addEventListener("wheel",e=>{if(!e.ctrlKey&&!e.metaKey)return;e.preventDefault();const r=vp.getBoundingClientRect();zBy(e.deltaY>0?-.1:.1,e.clientX-r.left,e.clientY-r.top);},{passive:false});

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
function getPos(modId,termName){const dot=document.getElementById("d_"+sid(`${modId}::${termName}`));if(!dot)return null;const cr=canvas.getBoundingClientRect(),dr=dot.getBoundingClientRect();return{x:(dr.left-cr.left+dr.width/2)/scale,y:(dr.top-cr.top+dr.height/2)/scale};}
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
    if(termName.endsWith("_IN"))return"up";
    if(termName.endsWith("_OUT"))return"down";
  }
  return m.exit;
}
function exitPt(p,dir){return dir==="down"?{x:p.x,y:p.y+STUB}:dir==="up"?{x:p.x,y:p.y-STUB}:dir==="right"?{x:p.x+STUB,y:p.y}:{x:p.x-STUB,y:p.y};}
let usedY=new Set(),usedX=new Set();const LG=6;
function allocY(pref,lo,hi){for(let off=0;off<600;off+=LG){for(const s of[0,1,-1]){const y=Math.round((pref+s*off)/LG)*LG;if(lo!=null&&y<lo)continue;if(hi!=null&&y>hi)continue;if(!usedY.has(y)){usedY.add(y);return y;}}}return pref;}
function allocX(pref,lo,hi){for(let off=0;off<600;off+=LG){for(const s of[0,1,-1]){const x=Math.round((pref+s*off)/LG)*LG;if(lo!=null&&x<lo)continue;if(hi!=null&&x>hi)continue;if(!usedX.has(x)){usedX.add(x);return x;}}}return pref;}
function svgP(pts){return"M"+pts.map(p=>`${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" L");}
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
  const dA=exitDir(w.from.m,w.from.t),dB=exitDir(w.to.m,w.to.t);const ea=exitPt(a,dA),eb=exitPt(b,dB);const sD=(dA===dB);
  let pts;
  if(dA==="right"||dA==="left"||dB==="right"||dB==="left"){const lx=allocX((ea.x+eb.x)/2);pts=[a,ea,{x:lx,y:ea.y},{x:lx,y:eb.y},eb,b];}
  else if(sD&&dA==="down"){const ly=allocY(Math.min(ea.y,eb.y)-8,null,Math.min(ea.y,eb.y));pts=[a,ea,{x:ea.x,y:ly},{x:eb.x,y:ly},eb,b];}
  else if(sD&&dA==="up"){const ly=allocY(Math.max(ea.y,eb.y)+8,Math.max(ea.y,eb.y),null);pts=[a,ea,{x:ea.x,y:ly},{x:eb.x,y:ly},eb,b];}
  else{const mY=allocY((ea.y+eb.y)/2),gxA=allocX(ea.x),gxB=allocX(eb.x);pts=[a,ea,{x:gxA,y:ea.y},{x:gxA,y:mY},{x:gxB,y:mY},{x:gxB,y:eb.y},eb,b];}
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
  return{path:svgP(c),hit:svgP(c.slice(1,-1)),lp,pts:c};
}


// ── DRAW WIRES ───────────────────────────────────────────────────
// CRITICAL: #wire-layer always has pointer-events:none (set in CSS and never changed).
// Individual SVG children get pointer-events:auto only when needed.
function drawWires(){
  wsvg.innerHTML="";
  wsvg.setAttribute("width",canvas.offsetWidth);
  wsvg.setAttribute("height",canvas.offsetHeight);
  wsvg.setAttribute("viewBox",`0 0 ${canvas.offsetWidth} ${canvas.offsetHeight}`);
  usedY.clear();usedX.clear();
  const normalMode=!editMode&&!wireMode&&!routeEditMode;
  WIRES.forEach(w=>{
    const rt=route(w);if(!rt)return;
    const isSel=selW&&selW.id===w.id;
    const isTr=tracedWires.size>0&&tracedWires.has(w.id);
    const isDim=(selW&&!isSel&&tracedWires.size===0)||(tracedWires.size>0&&!isTr);
    const bc=h(w.c),tc=trH(w.c);
    const g=document.createElementNS("http://www.w3.org/2000/svg","g");
    g.dataset.wid=w.id;g.style.opacity=isDim?"0.1":"1";
    // Glow for selected / traced
    if(isSel||isTr){
      const gl=document.createElementNS("http://www.w3.org/2000/svg","path");
      gl.setAttribute("d",rt.path);gl.setAttribute("stroke",isSel?"#f59e0b":"#10b981");
      gl.setAttribute("stroke-width","8");gl.setAttribute("fill","none");
      gl.setAttribute("stroke-linecap","round");gl.setAttribute("stroke-linejoin","round");
      gl.setAttribute("stroke-opacity","0.4");gl.style.pointerEvents="none";g.appendChild(gl);
    }
    // Main wire path
    const path=document.createElementNS("http://www.w3.org/2000/svg","path");
    path.setAttribute("d",rt.path);path.setAttribute("stroke",bc);
    path.setAttribute("stroke-width",isSel?"2.6":isTr?"2.2":"1.6");
    path.setAttribute("fill","none");path.setAttribute("stroke-linecap","round");path.setAttribute("stroke-linejoin","round");
    path.classList.add("wp");path.style.pointerEvents="none";g.appendChild(path);
    // Stripe for bi-color wires
    if(tc){
      const tp=document.createElementNS("http://www.w3.org/2000/svg","path");
      tp.setAttribute("d",rt.path);tp.setAttribute("stroke",tc);tp.setAttribute("stroke-width",isSel?"1.4":"0.9");
      tp.setAttribute("fill","none");tp.setAttribute("stroke-dasharray","5 4");tp.setAttribute("stroke-linecap","round");
      tp.style.pointerEvents="none";g.appendChild(tp);
    }
    // ── ROUTE EDIT MODE: segment handles (only for selected wire) ──
    if(routeEditMode&&isSel){
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
          let dragged=false;
          const onMove=ev=>{
            const dx=(ev.clientX-startClientX)/scale,dy=(ev.clientY-startClientY)/scale;
            const delta=seg.axis==="y"?dy:dx;
            if(Math.abs(delta)>0.5)dragged=true;
            wireRoutes[w.id][i]=startOff+delta;
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
          let dragged=false;
          const onMove=ev=>{
            const t=ev.touches[0];if(!t)return;
            ev.preventDefault();
            const dx=(t.clientX-startClientX)/scale,dy=(t.clientY-startClientY)/scale;
            const delta=seg.axis==="y"?dy:dx;
            if(Math.abs(delta)>0.5)dragged=true;
            wireRoutes[w.id][i]=startOff+delta;
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
    // ── NORMAL MODE: wide transparent hit zone for clicking wires ──
    else if(normalMode){
      const hit=document.createElementNS("http://www.w3.org/2000/svg","path");
      hit.setAttribute("d",rt.hit||rt.path);hit.setAttribute("stroke","transparent");
      hit.setAttribute("stroke-width","10");hit.setAttribute("fill","none");hit.setAttribute("stroke-linecap","round");
      hit.classList.add("wire-hit");
      hit.style.pointerEvents="auto"; // clickable in normal mode only
      hit.addEventListener("click",e=>{e.stopPropagation();selWire(w,e);});
      hit.addEventListener("contextmenu",e=>{
        e.preventDefault();e.stopPropagation();
        ctxTarget=w;$("ctx-edit").style.display="";$("ctx-trace").style.display="";$("ctx-route").style.display="";$("ctx-del").textContent="✕ Delete Wire";
        selWire(w,e);$("ctx").style.left=e.clientX+"px";$("ctx").style.top=e.clientY+"px";$("ctx").classList.add("open");
      });
      g.appendChild(hit);
    }
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

