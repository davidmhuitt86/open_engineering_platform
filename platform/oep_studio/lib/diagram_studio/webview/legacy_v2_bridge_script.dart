/// AP-OEP-DIAGRAM-ANDROID-001 — the JS bridge payload shared verbatim by
/// both WebView hosts ([LegacyV2BridgeTransport] on Windows,
/// `LegacyV2AndroidBridgeTransport` on Android). Extracted from
/// `legacy_v2_bridge_transport.dart` (where it originated, POC-002/003)
/// so a second platform transport can reuse it byte-for-byte rather than
/// forking a ~450-line script — the only thing that differs per platform
/// is how a JS→Dart message actually gets sent, which is why every
/// `postMessage` call below goes through the single indirection
/// `window.__oepBridgePostMessage`, not a literal `window.chrome.webview.*`
/// call. [legacyV2BridgeScript] prepends a one-line shim defining that
/// indirection for whichever transport is injecting it — Windows defines
/// it as `window.chrome.webview.postMessage`, Android as the
/// `JavaScriptChannel` global `webview_flutter_android` registers
/// (`window.OepBridge.postMessage`).
///
/// Polls (V2 exposes no move-start/move-end event, so this is the
/// smallest viable observation mechanism per POC-003's own finding) V2's
/// existing globals every 400ms:
///
///  - `selM`/`MODULES`/`WIRES` (unchanged from POC-002) for the status
///    snapshot.
///  - `positions` (module id -> {x,y}, V2's own runtime layout map,
///    `js/core/bootstrap.js`/`js/editor/module-editor.js`) for module
///    movement. A position is reported as a discrete `moduleMoved` event
///    only once it has been stable for two consecutive polls AND differs
///    from the last value `sendAuthoritativeModulePosition` itself wrote
///    — the second condition is what prevents the authoritative echo
///    from being reinterpreted as a new user move (Phase 10 loop
///    prevention, POC-003).
String legacyV2BridgeScript(String postMessageImpl) {
  return 'window.__oepBridgePostMessage = function (s) { $postMessageImpl; };\n$_kRawBridgeScript';
}

const String _kRawBridgeScript = r'''
(function () {
  // ══════════════════════════════════════════════════════════════
  // AP-DIAGRAM-V2-UI-001 — OEP visual theme adaptation.
  //
  // V2's own `css/main.css` already routes essentially every UI chrome
  // color through `:root`/`[data-theme="dark"]` custom properties
  // (confirmed by direct read — `--surf-0..3`, `--border-0..2`,
  // `--text-hi/md/lo/faint`, `--btn-text*`, `--ink`, `--bg`, `--amber`).
  // That is exactly the "reusable V2 CSS variable" mechanism this task
  // asked to prefer over scattering literal colors — this block redefines
  // those SAME variables to OEP's own `StudioColors` hex values (see
  // `lib/core/theme/studio_colors.dart`, the single source of truth this
  // mapping was taken from), rather than inventing a second theme system
  // or duplicating V2's CSS. `!important` on every declaration makes the
  // override independent of DOM/stylesheet load order (on Windows this
  // script runs at `addScriptToExecuteOnDocumentCreated` time, before
  // V2's own `<link rel="stylesheet">` tags are even parsed, so relying
  // on source order alone would let V2's own rule win instead).
  //
  // **What is deliberately NOT remapped** (engineering-semantic, per this
  // task's own explicit protection list): `--purple`/`--green`/`--cyan`/
  // `--cyan-dim`/`--red`/`--red-dim` (category/status colors used by the
  // meter continuity display and mode badges), `--lcd-bg`/`--lcd-fg`
  // (the multimeter LCD readout), `--canvas-*`/`--card-*` (the actual
  // wiring-diagram module-card rendering on the canvas — these are the
  // engineering graphic itself, not UI chrome, and changing them risks
  // exactly the "flatten meaningful engineering colors" outcome this task
  // prohibits). None of `js/utils/colors.js`'s wire-color table is
  // touched either.
  //
  // `--amber` IS remapped, deliberately: reading its actual usage
  // (`.key-btn.active`, `.tb-btn.edit-on`-adjacent badges, `#fp-kb.active`,
  // `.mod-card.wire-selected`'s selection outline) shows it functions as
  // V2's own general **UI accent/selection color**, not an engineering
  // status color — exactly the "selection/interaction colors may be
  // adapted to OEP's accent language" case this task explicitly permits.
  // `#0891b2` (wire-mode badge) and other one-off hex values hardcoded
  // directly in CSS rules (not routed through a variable) are left as-is
  // — overriding those would mean patching individual selectors instead
  // of the token mechanism this task asked to prefer, for a handful of
  // secondary badges with no corresponding OEP token anyway.
  try {
    var oepThemeStyle = document.createElement('style');
    oepThemeStyle.id = 'oep-v2-theme-overlay';
    oepThemeStyle.textContent =
      ':root, [data-theme="dark"], [data-theme="light"] {' +
      '  --ink: #E6E9EE !important;' +          /* StudioColors.textPrimary */
      '  --bg: #0D1117 !important;' +            /* StudioColors.background */
      '  --surf-0: #0D1117 !important;' +        /* StudioColors.background */
      '  --surf-1: #11161D !important;' +        /* StudioColors.surface */
      '  --surf-2: #161C25 !important;' +        /* StudioColors.surfaceRaised */
      '  --surf-3: #232B36 !important;' +        /* StudioColors.border, doubling as an interactive-surface tone */
      '  --surf-3-hover: #2C3542 !important;' +  /* derived (no OEP hover token exists) -- documented, not a token */
      '  --border-0: #1B222C !important;' +      /* StudioColors.borderSubtle */
      '  --border-1: #232B36 !important;' +      /* StudioColors.border */
      '  --border-2: #2C3542 !important;' +      /* derived, same rationale as surf-3-hover */
      '  --text-hi: #E6E9EE !important;' +       /* StudioColors.textPrimary */
      '  --text-md: #9AA5B1 !important;' +       /* StudioColors.textSecondary */
      '  --text-lo: #9AA5B1 !important;' +       /* StudioColors.textSecondary (V2's 4-tier hierarchy collapses to OEP's 3-tier one here) */
      '  --text-faint: #5B6572 !important;' +    /* StudioColors.textDisabled */
      '  --btn-text: #9AA5B1 !important;' +      /* StudioColors.textSecondary */
      '  --btn-text-hover: #E6E9EE !important;' +/* StudioColors.textPrimary */
      '  --amber: #3B82F6 !important;' +         /* StudioColors.selection -- V2's own accent/selection role, not an engineering color (see comment above) */
      '  --shadow-soft: 0 1px 3px rgba(0,0,0,.4) !important;' +
      '  --shadow-panel: 0 8px 32px rgba(0,0,0,.65) !important;' +
      '  --shadow-modal: 0 4px 16px rgba(0,0,0,.6) !important;' +
      '}' +
      /* Typography -- OEP's own dual-font convention (Segoe UI for
         general UI text, Consolas for technical/monospace readouts,
         `studio_theme.dart`'s `_fontFamily`/`_monoFontFamily`) replaces
         V2's blanket Courier New, EXCEPT the multimeter LCD digits
         (`#lcd-*`), which keep a monospace face -- matching OEP's own
         convention of using Consolas for technical data, not abandoning
         the "instrument readout" character the LCD is meant to have. */
      'html, body {' +
      '  font-family: "Segoe UI", "Courier New", monospace !important;' +
      '}' +
      '#lcd-mode, #lcd-val, #lcd-unit, #lcd-range, #lcd-note {' +
      '  font-family: "Consolas", "Courier New", monospace !important;' +
      '}';
    (document.head || document.documentElement).appendChild(oepThemeStyle);
  } catch (e) {
    // Visual-only, non-fatal -- never block the functional bridge over
    // a theme-injection failure.
  }

  // AP-OEP-DIAGRAM-BOOT-UNTITLED-001 companion fix — V2 is a fully
  // separate legacy app that always loads its own hardcoded demo
  // vehicle ('trx300') the moment its own page bootstrap runs
  // (js/app.js's own unconditional `Bootstrap.run('trx300')`),
  // completely independent of whatever OEP document is actually active.
  // The "blank canvas on a fresh Studio launch" feature only ever reset
  // OEP's own document state -- it never had any way to stop V2 from
  // rendering its own unrelated demo diagram first, so a fresh launch
  // showed that demo full-size for however long V2's own bootstrap
  // (parsing every script, fetching the demo vehicle, building every
  // module/wire card) took, before `initializeFromDocument()` finally
  // caught up and cleared it back to the real (blank) document -- read
  // by the user as "a diagram flashes briefly then goes away." Hiding
  // #canvas/#wire-layer from the very first paint (this script runs at
  // `addScriptToExecuteOnDocumentCreated` time, before V2's own
  // `<script>` tags -- let alone the demo vehicle's fetch -- have even
  // started, so the rule is already in the stylesheet before there's
  // anything to flash) and only revealing them once Dart confirms the
  // REAL document has been seeded (`__oepBridgeRevealCanvas`, called
  // once from `_triggerInitialSeed`'s completion in
  // legacy_v2_webview.dart) means the user only ever sees the diagram
  // they actually opened, never V2's own unrelated placeholder content.
  try {
    var oepBootHideStyle = document.createElement('style');
    oepBootHideStyle.id = 'oep-v2-boot-hide';
    oepBootHideStyle.textContent = '#canvas, #wire-layer { visibility: hidden !important; }';
    (document.head || document.documentElement).appendChild(oepBootHideStyle);
    window.__oepBridgeRevealCanvas = function () {
      var el = document.getElementById('oep-v2-boot-hide');
      if (el) el.remove();
    };
  } catch (e) {
    // Visual-only, non-fatal -- never block the functional bridge over
    // a boot-hide injection failure (worst case: the old flash comes back).
  }

  var lastStatusSnapshot = null;
  var lastSeen = {};   // id -> { x, y, stableCount }
  var synced = {};     // id -> { x, y } most recent OEP-authoritative value
  var lastModules = {};       // id -> { label, cat }, previous poll's MODULES snapshot
  var syncedModuleProps = {}; // id -> { label } most recent OEP-authoritative label
  var lastWires = {};         // id -> true, previous poll's WIRES id set
  var lastSelW = null;        // previous poll's selected wire id (or null)
  var lastSelM = null;        // previous poll's selected module id (or null)
  var lastWireProps = {};     // id -> { lbl, c }, previous poll's WIRES lbl/c snapshot
  var syncedWireProps = {};   // id -> { lbl, c } most recent OEP-authoritative wire label/color
  var lastMeterKey = null;    // previous poll's "<selW.id>|<meterMode>" combined key

  window.__oepBridgeApplyAuthoritative = function (id, x, y) {
    if (typeof positions !== 'undefined') {
      positions[id] = { x: x, y: y };
    }
    var card = (typeof cardEls !== 'undefined') ? cardEls[id] : null;
    if (card) { card.style.left = x + 'px'; card.style.top = y + 'px'; }
    if (typeof drawWires === 'function') { drawWires(); }
    synced[id] = { x: x, y: y };
    lastSeen[id] = { x: x, y: y, stableCount: 99 };
  };

  window.__oepBridgeApplyModuleLabel = function (id, label) {
    if (typeof MODULES === 'undefined') return;
    var m = MODULES.find(function (x) { return x.id === id; });
    if (!m) return;
    m.label = label;
    if (typeof rebuildCard === 'function') { rebuildCard(m); }
    syncedModuleProps[id] = { label: label };
    if (lastModules[id]) { lastModules[id].label = label; }
  };

  window.__oepBridgeRemoveModule = function (id) {
    if (typeof MODULES === 'undefined') return;
    MODULES = MODULES.filter(function (m) { return m.id !== id; });
    if (typeof WIRES !== 'undefined') {
      WIRES = WIRES.filter(function (w) { return w.from.m !== id && w.to.m !== id; });
    }
    if (typeof removeCard === 'function') { removeCard(id); }
    if (typeof positions !== 'undefined') { delete positions[id]; }
    if (typeof drawWires === 'function') { drawWires(); }
    delete lastModules[id];
    delete syncedModuleProps[id];
    delete synced[id];
    delete lastSeen[id];
  };

  window.__oepBridgeConfirmWireCreated = function (id, label, color) {
    if (typeof WIRES === 'undefined') return;
    var w = WIRES.find(function (x) { return x.id === id; });
    if (!w) return;
    w.lbl = label;
    w.c = color;
    if (typeof drawWires === 'function') { drawWires(); }
    lastWires[id] = true;
    lastWireProps[id] = { lbl: label, c: color };
    syncedWireProps[id] = { lbl: label, c: color };
  };

  window.__oepBridgeRemoveWire = function (id) {
    if (typeof WIRES === 'undefined') return;
    WIRES = WIRES.filter(function (w) { return w.id !== id; });
    if (typeof wireRoutes !== 'undefined') { delete wireRoutes[id]; }
    if (typeof drawWires === 'function') { drawWires(); }
    delete lastWires[id];
    delete lastWireProps[id];
    delete syncedWireProps[id];
  };

  // AP-DIAGRAM-V2-BRIDGE-SAVE-004 — `restoreModule`/`restoreWire` are
  // called both to reconstruct a module/wire V2 doesn't have yet (e.g.
  // after an Engine undo-of-delete) AND to reseed V2 with a just-opened
  // document's authoritative state (`initializeFromDocument`). The
  // original "already present -> no-op" guard was correct for the first
  // case but silently broke the second whenever V2's OWN globals (e.g.
  // `Bootstrap.run('trx300')`'s bundled demo vehicle, app.js) already
  // populate MODULES/WIRES with the same ids before OEP's restore call
  // runs — the id-already-exists check short-circuited BEFORE the
  // position/label/color assignment below it ever ran, so a saved edit
  // to a module V2 itself had already loaded (its position, label,
  // notes; a wire's label/color) never made it back into V2 on reopen,
  // even though the OEP document on disk was correct. Restoring now
  // always applies the authoritative values — updating an existing
  // module/wire's fields in place, or creating one that's genuinely
  // missing — rather than treating "already present" as "already
  // correct."
  window.__oepBridgeRestoreModule = function (id, label, category, x, y, notes, terminals, exitDirection, connector, vertical, labelPos, pinLabelPos, subLabelPos, sub, labelJustify, kind, bulbStyle, bulbColor, flipped) {
    if (typeof MODULES === 'undefined') return;
    var m = MODULES.find(function (existing) { return existing.id === id; });
    // AP-MODULE-KIND-001 — `kind` (`m.bulb`/`m.diode`/`m.battery`/
    // `m.starterMotor`/`m.solenoid`/`m.groundedSwitch`/`m.thermistor` —
    // whichever special-glyph flag `buildCard`, renderer.js, dispatches
    // on) was never round-tripped at all before this fix: every one of
    // these module types rendered correctly live in V2 (set once at
    // creation via a PRESETS entry) but silently fell back to a plain
    // `buildStdCard` on the next document reopen through the real Studio
    // app, since this function had no way to know which flag to
    // reapply — discovered while adding the `groundedSwitch`/`thermistor`
    // types, but it was already latent for `battery`/`starterMotor`/
    // `solenoid`/`diode`/`bulb` too. A single string (empty = "no special
    // kind") round-trips the same way `category` does; the flags array
    // is cleared and only the matching one re-set, so this is also safe
    // to call on an existing module (idempotent, and correct if a
    // document somehow changes a module's kind).
    var _kindFlags = ['bulb', 'diode', 'battery', 'starterMotor', 'solenoid', 'groundedSwitch', 'thermistor', 'pulseGenerator', 'alternator'];
    var resolvedKind = kind || '';
    // AP-DIAGRAM-V2-BRIDGE-SAVE-007 — `terminals` is the OEP-authoritative
    // list (round-tripped through the saved document's node metadata);
    // only overwrite an existing module's terminals when the caller
    // actually supplied a non-empty list, so a plain position/label
    // resync (undo/redo path, which does not carry terminal data) never
    // wipes terminals V2's own bootstrap already populated.
    var hasTerminals = terminals && terminals.length > 0;
    // AP-DIAGRAM-V2-BRIDGE-SAVE-009 — `exitDirection` (which side of the
    // card its wires leave from — up/down/left/right), same "only
    // overwrite when the caller actually has real data" guard as
    // `terminals` above and for the same reason: an empty/absent value
    // here means "this document never recorded a real exit direction"
    // (e.g. an older save from before this field existed), not "this
    // module's exit is empty" — applying it anyway would silently
    // overwrite an existing module's already-correct exit (from V2's own
    // bootstrap) with the wrong hardcoded fallback on every resync.
    var hasExit = exitDirection && exitDirection.length > 0;
    // AP-DIAGRAM-V2-BRIDGE-SAVE-010 — `connector`/`vertical` (whether
    // this card renders as a connector's stacked-pin layout at all, and
    // if so, standing up vertically) round-trip the same way: `null`/
    // `undefined` (Dart sends this whenever the document has no recorded
    // value for a module, e.g. an older save) means "unknown, don't
    // touch" — `!= null` catches both null and undefined — while `true`/
    // `false` are real, always-apply values once known. Without this, a
    // reconstructed connector rendered as a plain module (losing its
    // whole IN/OUT pin-stack layout, since `buildCard` gates on
    // `m.connector`) or, if `connector` alone survived some other way,
    // silently reverted to horizontal on every reopen (`buildConnCard`
    // gates its vertical layout on `m.vertical`).
    var hasConnector = connector != null;
    var hasVertical = vertical != null;
    // AP-MODULE-LAYOUT-001 — `labelPos`/`pinLabelPos` ('top'/'bottom'/
    // 'left'/'right', or '' meaning "use the auto default" — see
    // buildCard/buildStdCard, renderer.js) round-trip the same "only
    // overwrite when the caller actually has real data" way `exitDirection`
    // does above: an empty string here means "this document never
    // recorded an explicit choice," not "explicitly reset to auto" — but
    // '' IS itself a valid, meaningful value to apply once known (it's
    // exactly what clears an override back to auto from the properties
    // panel), so the guard here is "was this argument passed at all"
    // (`!= null`), not "is it non-empty" like `hasExit`.
    var hasLabelPos = labelPos != null;
    var hasPinLabelPos = pinLabelPos != null;
    var hasSubLabelPos = subLabelPos != null;
    // AP-MODULE-LABEL-WRAP-001 — `sub` (the module's own subtitle text,
    // e.g. "12V 30A" — a PRE-EXISTING field that, until now, was never
    // actually threaded through this bridge at all: every restore always
    // hardcoded `sub: ''` below, so any subtitle set via the properties
    // panel rendered correctly live in V2 but silently vanished on the
    // next Save-through-the-Studio-app + reopen, independent of and
    // predating this task's own label-wrap/justify work) and
    // `labelJustify` (new, this task) round-trip the same `!= null` way
    // `labelPos` does above.
    var hasSub = sub != null;
    var hasLabelJustify = labelJustify != null;
    // AP-BULB-GENERIC-001 — `bulbStyle`/`bulbColor` ('' meaning "no
    // explicit choice yet," same empty-clears convention as `sub`/
    // `labelJustify` above) and `flipped` (nullable bool, same "unknown,
    // don't touch" convention as `connector`/`vertical` above) — a bulb's
    // own lit-color/incandescent choice and which side its terminals sit
    // on, none of which existed before this task.
    var hasBulbStyle = bulbStyle != null;
    var hasBulbColor = bulbColor != null;
    var hasFlipped = flipped != null;
    // AP-OEP-DIAGRAM-SPLICE-RESTORE-001 — `splice` (buildCard's gate,
    // renderer.js, for the bare-circle-dot rendering a splice actually
    // needs instead of a full bordered module card) was never
    // reconstructed here at all — a saved splice's `category` field
    // ('splice', openAddSplice's own hardcoded value, unique to
    // splices — nothing else ever uses that category string) round-
    // tripped fine, but the separate boolean flag buildCard actually
    // checks did not, so every splice fell through to buildStdCard() on
    // reopen: still functionally a splice (one "SPLICE" terminal, same
    // wires), just rendered as a full labeled card instead of its own
    // small dot. Deriving it from category, which IS already carried
    // through faithfully, needs no new bridge field or Dart-side change.
    var isSplice = category === 'splice';
    if (m) {
      m.label = label;
      m.cat = category;
      m.notes = notes || '';
      m.splice = isSplice || undefined;
      _kindFlags.forEach(function (f) { m[f] = undefined; });
      if (resolvedKind) { m[resolvedKind] = true; }
      if (hasExit) { m.exit = exitDirection; }
      if (hasTerminals) { m.terminals = terminals; }
      if (hasConnector) { m.connector = connector || undefined; }
      if (hasVertical) { m.vertical = vertical || undefined; }
      if (hasLabelPos) { m.labelPos = labelPos || undefined; }
      if (hasPinLabelPos) { m.pinLabelPos = pinLabelPos || undefined; }
      if (hasSubLabelPos) { m.subLabelPos = subLabelPos || undefined; }
      if (hasSub) { m.sub = sub; }
      if (hasLabelJustify) { m.labelJustify = labelJustify || undefined; }
      if (hasBulbStyle) { m.bulbStyle = bulbStyle || undefined; }
      if (hasBulbColor) { m.bulbColor = bulbColor || undefined; }
      if (hasFlipped) { m.flipped = flipped || undefined; }
    } else {
      m = {
        id: id, label: label, sub: hasSub ? sub : '', cat: category, notes: notes || '',
        splice: isSplice || undefined,
        exit: hasExit ? exitDirection : 'down',
        terminals: hasTerminals ? terminals : [],
        connector: hasConnector ? (connector || undefined) : undefined,
        vertical: hasVertical ? (vertical || undefined) : undefined,
        labelPos: hasLabelPos ? (labelPos || undefined) : undefined,
        pinLabelPos: hasPinLabelPos ? (pinLabelPos || undefined) : undefined,
        subLabelPos: hasSubLabelPos ? (subLabelPos || undefined) : undefined,
        labelJustify: hasLabelJustify ? (labelJustify || undefined) : undefined,
        bulbStyle: hasBulbStyle ? (bulbStyle || undefined) : undefined,
        bulbColor: hasBulbColor ? (bulbColor || undefined) : undefined,
        flipped: hasFlipped ? (flipped || undefined) : undefined,
        _user: true,
      };
      if (resolvedKind) { m[resolvedKind] = true; }
      MODULES.push(m);
    }
    // AP-WIRE-GRID-ALIGN-001 — a document saved before every module/
    // splice placed its terminals at a fixed GRID-multiple offset from
    // this anchor (renderer.js) won't have grid-exact positions of its
    // own; snapping here (this is the real reopen path for the Studio
    // app — restoreModule, not V2's own native raw-JSON Load button) is
    // idempotent, so it's safe to run unconditionally on every restore.
    var _snapGrid = (typeof GRID !== 'undefined') ? GRID : 20;
    if (typeof positions !== 'undefined') {
      positions[id] = { x: Math.round(x / _snapGrid) * _snapGrid, y: Math.round(y / _snapGrid) * _snapGrid };
    }
    if (typeof placeCards === 'function') { placeCards(); }
    if (typeof rebuildCard === 'function') { rebuildCard(m); }
    if (typeof drawWires === 'function') { drawWires(); }
    lastModules[id] = { label: label, cat: category, notes: notes || '' };
    syncedModuleProps[id] = { label: label, notes: notes || '' };
    synced[id] = { x: x, y: y };
    lastSeen[id] = { x: x, y: y, stableCount: 99 };
  };

  window.__oepBridgeRestoreWire = function (id, fromModuleId, toModuleId, label, color, fromTerminal, toTerminal, fromExit, toExit, cable) {
    if (typeof WIRES === 'undefined') return;
    var w = WIRES.find(function (existing) { return existing.id === id; });
    // AP-WIRE-EXIT-OVERRIDE-001 — `fromExit` (which side this specific
    // wire's first bend leaves its source terminal from, overriding the
    // module/splice's own default) round-trips the same way `label`/
    // `color` already do: captured live by the poller above, restored
    // here on reopen. `|| undefined` (not `''`) so route() (renderer.js)
    // falls back to the module's own exit() side when nothing was saved.
    // AP-SPLICE-INSPECTOR-001 — `toExit` is the same idea for the
    // DESTINATION end (§ route()'s own doc comment for why both ends
    // need this, not just `fromExit`).
    // AP-BATTERY-CABLE-001 — `cable` (thick Red/Black battery-cable
    // rendering, renderer.js) same round-trip treatment.
    var restoredFromExit = fromExit || undefined;
    var restoredToExit = toExit || undefined;
    var restoredCable = cable || undefined;
    if (w) {
      w.lbl = label;
      w.c = color;
      w.from = { m: fromModuleId, t: fromTerminal || '' };
      w.to = { m: toModuleId, t: toTerminal || '' };
      w.fromExit = restoredFromExit;
      w.toExit = restoredToExit;
      w.cable = restoredCable;
    } else {
      w = {
        id: id,
        c: color,
        lbl: label,
        from: { m: fromModuleId, t: fromTerminal || '' },
        to: { m: toModuleId, t: toTerminal || '' },
        fromExit: restoredFromExit,
        toExit: restoredToExit,
        cable: restoredCable,
        desc: '',
        R: Array.from({ length: 4 }, function () {
          return { VDC: '0.00', VAC: '0.00', CONT: 'OPN', RES: 'OL', DIODE: 'OL', note: '' };
        }),
      };
      WIRES.push(w);
    }
    if (typeof drawWires === 'function') { drawWires(); }
    lastWires[id] = true;
    lastWireProps[id] = { lbl: label, c: color, fromExit: fromExit || '', toExit: toExit || '', cable: cable || '' };
    syncedWireProps[id] = { lbl: label, c: color, fromExit: fromExit || '', toExit: toExit || '', cable: cable || '' };
  };

  window.__oepBridgeClearAll = function () {
    if (typeof MODULES !== 'undefined') { MODULES = []; }
    if (typeof WIRES !== 'undefined') { WIRES = []; }
    if (typeof positions !== 'undefined') { for (var pid in positions) { delete positions[pid]; } }
    if (typeof wireRoutes !== 'undefined') { for (var wid in wireRoutes) { delete wireRoutes[wid]; } }
    if (typeof cardEls !== 'undefined') {
      for (var cid in cardEls) {
        if (cardEls[cid] && cardEls[cid].remove) { cardEls[cid].remove(); }
      }
      for (var cid2 in cardEls) { delete cardEls[cid2]; }
    }
    if (typeof drawWires === 'function') { drawWires(); }
    lastModules = {};
    lastWires = {};
    synced = {};
    lastSeen = {};
    syncedModuleProps = {};
    lastWireProps = {};
    syncedWireProps = {};
  };

  window.__oepBridgeApplyMeasurementResult = function (id, mode, displayValue, unit, note) {
    // Discard a stale reply: V2 has already moved on to a different wire
    // or mode by the time this landed, so applying it would overwrite
    // what the user is currently looking at with an answer to a question
    // V2 no longer cares about (see the Dart-side doc comment).
    if (typeof selW === 'undefined' || !selW || selW.id !== id) return;
    if (typeof meterMode === 'undefined' || meterMode !== mode) return;
    var valEl = $('lcd-val'), noteEl = $('lcd-note'), unitEl = $('lcd-unit');
    if (valEl) {
      valEl.textContent = displayValue;
      valEl.style.color = (mode === 'CONT' && displayValue === 'OPN') ? '#ff6b6b'
        : (mode === 'CONT' && displayValue === '000') ? '#22d3ee'
        : 'var(--lcd-fg)';
    }
    if (unitEl) { unitEl.textContent = mode === 'CONT' ? '' : unit; }
    if (noteEl) { noteEl.textContent = note || ''; }
  };

  // AP-DMM-BRIDGE-001 — the Dart-side DMM bridge's own read primitive:
  // a synchronous, side-effect-free query into the LIVE electrical
  // solver (js/simulation/live-runner.js's LiveSim.readWireMeasurement,
  // itself a thin wrapper around the existing GraphBuilder/
  // ElectricalSolver — not a second solver). Deliberately separate from
  // __oepBridgeApplyMeasurementResult above: that function WRITES an
  // OEP-computed answer into V2's own display; this one READS V2's own
  // live-solved answer back out for OEP/Dart to use as the DMM's
  // authoritative source, replacing the old flow where Dart's
  // (non-solver) MeasurementEngine was the one overwriting V2. Returns a
  // plain JS object, same no-double-JSON-encoding convention as
  // __oepBridgeCaptureSaveSnapshot below.
  window.__oepBridgeQueryLiveMeasurement = function (wireId, mode) {
    if (typeof LiveSim === 'undefined' || !LiveSim.readWireMeasurement) {
      return { status: 'error', readingType: mode || 'voltage', value: null, unit: '',
        open: true, overload: false, fault: false, note: 'LiveSim not available',
        source: null, reference: null, solvedAt: null };
    }
    return LiveSim.readWireMeasurement(wireId, mode);
  };

  // AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the Save flush barrier's own
  // snapshot primitive. Reads V2's CURRENT globals directly (no
  // stability/debounce wait of any kind — that is the whole point: the
  // 400ms poll's 2-tick stabilization exists to avoid spamming live
  // `moduleMoved` events during an in-progress drag, which is irrelevant
  // here because Save is a discrete, deliberate user action, not a live
  // stream). Returns a plain JS object (not a JSON string) — WebView2's
  // `ExecuteScript`/Android's `evaluateJavascript` each already transport
  // the JS return value as its own JSON representation across the
  // native boundary; wrapping it in a second `JSON.stringify` here would
  // just make the Dart side undo an extra, pointless layer.
  window.__oepBridgeCaptureSaveSnapshot = function () {
    var modules = {};
    if (typeof MODULES !== 'undefined') {
      MODULES.forEach(function (m) {
        var pos = (typeof positions !== 'undefined' && positions[m.id]) ? positions[m.id] : { x: 0, y: 0 };
        modules[m.id] = { label: m.label || '', category: m.cat || '', notes: m.notes || '', x: pos.x, y: pos.y, terminals: m.terminals || [], exit: m.exit || 'down', connector: !!m.connector, vertical: !!m.vertical, labelPos: m.labelPos || '', pinLabelPos: m.pinLabelPos || '', subLabelPos: m.subLabelPos || '', sub: m.sub || '', labelJustify: m.labelJustify || '', kind: m.bulb ? 'bulb' : m.diode ? 'diode' : m.battery ? 'battery' : m.starterMotor ? 'starterMotor' : m.solenoid ? 'solenoid' : m.groundedSwitch ? 'groundedSwitch' : m.thermistor ? 'thermistor' : m.pulseGenerator ? 'pulseGenerator' : m.alternator ? 'alternator' : '', bulbStyle: m.bulbStyle || '', bulbColor: m.bulbColor || '', flipped: !!m.flipped };
      });
    }
    var wires = {};
    if (typeof WIRES !== 'undefined') {
      WIRES.forEach(function (w) {
        wires[w.id] = {
          fromModuleId: w.from.m, fromTerminal: w.from.t || '',
          toModuleId: w.to.m, toTerminal: w.to.t || '',
          label: w.lbl || '', color: w.c || '',
          fromExit: w.fromExit || '', toExit: w.toExit || '',
          cable: !!w.cable,
        };
      });
    }
    var wireRoutesSnapshot = {};
    if (typeof wireRoutes !== 'undefined') {
      for (var wid in wireRoutes) { wireRoutesSnapshot[wid] = wireRoutes[wid]; }
    }
    return { modules: modules, wires: wires, wireRoutes: wireRoutesSnapshot };
  };

  // AP-DIAGRAM-V2-BRIDGE-SAVE-001 — reseeds V2's own `wireRoutes[id]`
  // from OEP-authoritative data (document load, or resync after an Undo
  // that reverted a route edit). `offsets` is `{segIdx: offset}` or an
  // empty object (clears any existing entry, matching V2's own Reset
  // Route behavior — `delete wireRoutes[id]`).
  window.__oepBridgeApplyWireRouteOffsets = function (id, offsets) {
    if (typeof wireRoutes === 'undefined') return;
    var hasAny = false;
    for (var k in offsets) { hasAny = true; break; }
    if (hasAny) { wireRoutes[id] = offsets; } else { delete wireRoutes[id]; }
    if (typeof drawWires === 'function') { drawWires(); }
  };

  window.__oepBridgeInterceptSave = function () {
    // See the Dart-side `interceptV2Save`'s own doc comment for why this
    // must run after V2's own script has already defined `saveLayout` —
    // this simply overwrites that binding at runtime; V2's own
    // `js/storage/project-saver.js` file is never touched.
    window.saveLayout = function () {
      window.__oepBridgePostMessage(JSON.stringify({ type: 'saveRequested', payload: {} }));
    };
  };

  // AP-DIAGRAM-V2-BRIDGE-SAVE-003 — root-cause fix for the interception
  // never actually taking effect. This script is injected via
  // `addScriptToExecuteOnDocumentCreated`, which runs BEFORE any of V2's
  // own `<script src>` tags — so calling `__oepBridgeInterceptSave()`
  // directly at this point would just get clobbered the moment V2's own
  // `js/storage/project-saver.js` executes its `function saveLayout(){}`
  // declaration (a hoisted top-level function declaration, which wins
  // regardless of assignment order once IT runs). The Dart side's own
  // explicit `interceptV2Save()` call (fired after `initializeFromDocument`
  // completes) was meant to run late enough to avoid this — but
  // `WebviewController.loadUrl()` resolves as soon as WebView2's
  // `Navigate()` call is dispatched, NOT once the page has actually
  // finished loading (confirmed by reading `webview_flutter_windows`'s own
  // native `loadUrl` handler — it calls `webview_->LoadUrl(url)` and
  // returns success immediately, no NavigationCompleted wait at all), so
  // in practice the Dart-side call could still land before V2's own
  // scripts had executed. Listening for the browser's own `load` event
  // — fired only after every synchronous `<script src>` tag, including
  // project-saver.js, has already run — applies the override at the one
  // point that is actually guaranteed correct, independent of any
  // Dart-side round-trip timing. The existing Dart-side call is left in
  // place too (harmless — either it's now redundant, or it runs first
  // and gets clobbered by V2's own declaration exactly as before, in
  // which case this listener still fixes it moments later).
  window.addEventListener('load', function () {
    if (typeof window.__oepBridgeInterceptSave === 'function') {
      window.__oepBridgeInterceptSave();
    }
  });

  window.__oepBridgeReportSaveResult = function (success, message) {
    if (typeof showToast === 'function') {
      showToast(message, success ? undefined : 'warn');
    }
  };

  setInterval(function () {
    // AP-DIAGRAM-V2-WEBVIEW-003 bugfix — every event this tick detects is
    // pushed here instead of posted immediately, then sent as ONE
    // `type: 'batch'` message at the very end of the tick. This is what
    // guarantees delivery order matches detection order (see
    // `_onRawMessage`'s own comment on the Dart side for why separate
    // `postMessage` calls could not be trusted to preserve it).
    var pending = [];

    try {
      if (typeof selM !== 'undefined') {
        var statusSnapshot = JSON.stringify({
          selM: selM,
          moduleCount: (typeof MODULES !== 'undefined') ? MODULES.length : null,
          wireCount: (typeof WIRES !== 'undefined') ? WIRES.length : null,
          editMode: (typeof editMode !== 'undefined') ? editMode : null,
        });
        if (statusSnapshot !== lastStatusSnapshot) {
          lastStatusSnapshot = statusSnapshot;
          pending.push({ type: 'v2Status', payload: JSON.parse(statusSnapshot) });
        }
      }

      if (typeof positions !== 'undefined') {
        for (var id in positions) {
          var p = positions[id];
          var prev = lastSeen[id];
          if (prev && prev.x === p.x && prev.y === p.y) {
            prev.stableCount = (prev.stableCount || 0) + 1;
          } else {
            lastSeen[id] = { x: p.x, y: p.y, stableCount: 0 };
            prev = lastSeen[id];
          }
          if (prev.stableCount === 2) {
            var s = synced[id];
            if (!s || s.x !== p.x || s.y !== p.y) {
              pending.push({ type: 'moduleMoved', payload: { id: id, x: p.x, y: p.y } });
            }
          }
        }
      }
    } catch (e) {
      // V2 globals not initialized yet (bootstrap still running) — ignore
      // and try again on the next tick.
    }

    try {
      if (typeof MODULES !== 'undefined') {
        var current = {};
        MODULES.forEach(function (m) {
          current[m.id] = { label: m.label, cat: m.cat, notes: m.notes || '', terminals: m.terminals || [], exit: m.exit || 'down', connector: !!m.connector, vertical: !!m.vertical, labelPos: m.labelPos || '', pinLabelPos: m.pinLabelPos || '', subLabelPos: m.subLabelPos || '', sub: m.sub || '', labelJustify: m.labelJustify || '', kind: m.bulb ? 'bulb' : m.diode ? 'diode' : m.battery ? 'battery' : m.starterMotor ? 'starterMotor' : m.solenoid ? 'solenoid' : m.groundedSwitch ? 'groundedSwitch' : m.thermistor ? 'thermistor' : m.pulseGenerator ? 'pulseGenerator' : m.alternator ? 'alternator' : '', bulbStyle: m.bulbStyle || '', bulbColor: m.bulbColor || '', flipped: !!m.flipped };
        });

        // Created: an id present now that wasn't present last poll.
        for (var newId in current) {
          if (!(newId in lastModules)) {
            var pos = (typeof positions !== 'undefined' && positions[newId]) ? positions[newId] : { x: 0, y: 0 };
            pending.push({
              type: 'moduleCreated',
              payload: { id: newId, label: current[newId].label, category: current[newId].cat, x: pos.x, y: pos.y, terminals: current[newId].terminals, exit: current[newId].exit, connector: current[newId].connector, vertical: current[newId].vertical, labelPos: current[newId].labelPos, pinLabelPos: current[newId].pinLabelPos, subLabelPos: current[newId].subLabelPos, sub: current[newId].sub, labelJustify: current[newId].labelJustify, kind: current[newId].kind, bulbStyle: current[newId].bulbStyle, bulbColor: current[newId].bulbColor, flipped: current[newId].flipped },
            });
          }
        }

        // Deleted: an id present last poll that's gone now.
        for (var goneId in lastModules) {
          if (!(goneId in current)) {
            pending.push({ type: 'moduleDeleted', payload: { id: goneId } });
            delete syncedModuleProps[goneId];
          }
        }

        // Properties changed: label/category/notes/terminals/exit/
        // connector/vertical differ from last poll. label/notes are also
        // checked against whatever this bridge itself most recently
        // applied as authoritative (loop prevention, same pattern as
        // position sync -- AP-DIAGRAM-V2-BRIDGE-011) -- terminals/exit/
        // connector/vertical have no such loop risk since nothing on the
        // Dart side ever writes them back into V2 authoritatively (only
        // reads them once, at document load/restoreModule), so they're
        // compared directly against the last poll with no gate.
        //
        // Terminal edits used to be invisible to this bridge entirely:
        // adding/renaming/reordering a pin on an EXISTING module (as
        // opposed to a brand-new module, which IS captured once at
        // creation via 'moduleCreated') changed none of label/cat/notes,
        // so no event ever fired for it -- the edit rendered correctly
        // live in V2, then silently reverted to whatever the module's
        // terminals were at creation time on the next document
        // save-and-reopen, since OEP's authoritative metadata was never
        // updated to match. Comparing the JSON-stringified terminal list
        // (order and content both matter for pin-number identity, so a
        // plain string compare is the right amount of precision here) is
        // what actually catches that case.
        for (var existingId in current) {
          if (!(existingId in lastModules)) continue;
          var prevProps = lastModules[existingId];
          var curProps = current[existingId];
          var prevTermsJson = JSON.stringify(prevProps.terminals || []);
          var curTermsJson = JSON.stringify(curProps.terminals || []);
          var labelCatNotesChanged = prevProps.label !== curProps.label || prevProps.cat !== curProps.cat || prevProps.notes !== curProps.notes;
          var pinLayoutChanged = prevTermsJson !== curTermsJson || prevProps.exit !== curProps.exit || prevProps.connector !== curProps.connector || prevProps.vertical !== curProps.vertical
            || prevProps.labelPos !== curProps.labelPos || prevProps.pinLabelPos !== curProps.pinLabelPos || prevProps.subLabelPos !== curProps.subLabelPos
            || prevProps.sub !== curProps.sub || prevProps.labelJustify !== curProps.labelJustify || prevProps.kind !== curProps.kind
            || prevProps.bulbStyle !== curProps.bulbStyle || prevProps.bulbColor !== curProps.bulbColor || prevProps.flipped !== curProps.flipped;
          if (labelCatNotesChanged || pinLayoutChanged) {
            var syncedProps = syncedModuleProps[existingId];
            var labelNotesAlreadySynced = syncedProps && syncedProps.label === curProps.label && syncedProps.notes === curProps.notes;
            if (pinLayoutChanged || !labelNotesAlreadySynced) {
              pending.push({
                type: 'modulePropertiesChanged',
                payload: { id: existingId, label: curProps.label, category: curProps.cat, notes: curProps.notes, terminals: curProps.terminals, exit: curProps.exit, connector: curProps.connector, vertical: curProps.vertical, labelPos: curProps.labelPos, pinLabelPos: curProps.pinLabelPos, subLabelPos: curProps.subLabelPos, sub: curProps.sub, labelJustify: curProps.labelJustify, kind: curProps.kind, bulbStyle: curProps.bulbStyle, bulbColor: curProps.bulbColor, flipped: curProps.flipped },
              });
            }
          }
        }

        lastModules = current;
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-WEBVIEW-003/AP-DIAGRAM-V2-BRIDGE-004 — wire
    // create/delete detection (no property/route-edit detection —
    // out of this task's scope).
    try {
      if (typeof WIRES !== 'undefined') {
        var currentWireIds = {};
        WIRES.forEach(function (w) { currentWireIds[w.id] = true; });
        for (var wireId in currentWireIds) {
          if (!(wireId in lastWires)) {
            var w = WIRES.find(function (x) { return x.id === wireId; });
            pending.push({
              type: 'wireCreated',
              payload: {
                id: wireId,
                fromModuleId: w.from.m,
                fromTerminal: w.from.t,
                toModuleId: w.to.m,
                toTerminal: w.to.t,
                label: w.lbl || '',
                color: w.c || '',
                fromExit: w.fromExit || '',
                toExit: w.toExit || '',
                cable: !!w.cable,
              },
            });
            lastWireProps[wireId] = { lbl: w.lbl || '', c: w.c || '', fromExit: w.fromExit || '', toExit: w.toExit || '', cable: !!w.cable };
          }
        }
        for (var goneWireId in lastWires) {
          if (!(goneWireId in currentWireIds)) {
            pending.push({ type: 'wireDeleted', payload: { id: goneWireId } });
            delete lastWireProps[goneWireId];
            delete syncedWireProps[goneWireId];
          }
        }
        lastWires = currentWireIds;

        // AP-DIAGRAM-V2-BRIDGE-005 — wire property edits: V2's own
        // `saveWireProps()` mutates the wire object in place (no id
        // change), so this diffs a per-wire `{lbl, c}` snapshot, exactly
        // mirroring the module-properties-changed block above, including
        // the same loop-prevention pattern against `syncedWireProps`.
        WIRES.forEach(function (w) {
          var prevProps = lastWireProps[w.id];
          if (!prevProps) return;
          var curLbl = w.lbl || '';
          var curColor = w.c || '';
          var curFromExit = w.fromExit || '';
          var curToExit = w.toExit || '';
          var curCable = !!w.cable;
          if (prevProps.lbl !== curLbl || prevProps.c !== curColor || prevProps.fromExit !== curFromExit || prevProps.toExit !== curToExit || prevProps.cable !== curCable) {
            var syncedProps = syncedWireProps[w.id];
            if (!syncedProps || syncedProps.lbl !== curLbl || syncedProps.c !== curColor || syncedProps.fromExit !== curFromExit || syncedProps.toExit !== curToExit || syncedProps.cable !== curCable) {
              pending.push({
                type: 'wirePropertiesChanged',
                payload: { id: w.id, label: curLbl, color: curColor, fromExit: curFromExit, toExit: curToExit, cable: curCable },
              });
            }
            lastWireProps[w.id] = { lbl: curLbl, c: curColor, fromExit: curFromExit, toExit: curToExit, cable: curCable };
          }
        });
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-BRIDGE-004 — wire selection: V2 keeps the selected
    // wire object itself (`selW`, not just an id) at `app.js` scope; a
    // module and a wire are never selected at the same time in V2
    // (confirmed in earlier research — mutually exclusive with `selM`).
    try {
      var currentSelW = (typeof selW !== 'undefined' && selW) ? selW.id : null;
      if (currentSelW !== lastSelW) {
        lastSelW = currentSelW;
        pending.push({ type: 'wireSelectionChanged', payload: { id: currentSelW } });
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-BRIDGE-009 — module selection, symmetric with wire
    // selection above. V2 keeps the selected module id as a bare `selM`
    // global (`app.js`), toggled by `js/ui/inspector.js` — no
    // multi-select, and never set at the same time as `selW`.
    try {
      var currentSelM = (typeof selM !== 'undefined') ? selM : null;
      if (currentSelM !== lastSelM) {
        lastSelM = currentSelM;
        pending.push({ type: 'moduleSelectionChanged', payload: { id: currentSelM } });
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-BRIDGE-006 — a measurement request whenever the
    // selected-wire/meter-mode pair changes. V2's own `updateMeter()` is
    // a synchronous local lookup with no outward event of its own (§1 of
    // the simulation bridge doc), so this is poll-diffed like every other
    // V2-observation in this bridge. Only fires with a wire selected —
    // `updateMeter()` itself is a no-op with none (`if (!selW) return;`).
    try {
      if (typeof selW !== 'undefined' && selW && typeof meterMode !== 'undefined') {
        var meterKey = selW.id + '|' + meterMode;
        if (meterKey !== lastMeterKey) {
          lastMeterKey = meterKey;
          pending.push({ type: 'measurementRequested', payload: { id: selW.id, mode: meterMode } });
        }
      } else {
        lastMeterKey = null;
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    if (pending.length > 0) {
      window.__oepBridgePostMessage(JSON.stringify({ type: 'batch', payload: pending }));
    }
  }, 400);
})();
''';
