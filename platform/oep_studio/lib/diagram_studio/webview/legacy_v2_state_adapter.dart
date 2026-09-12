import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../simulation/diagram_simulation_service.dart';
import '../trace/trace_highlight_plan.dart';
import 'diagram_editing_host.dart';
import 'legacy_v2_bridge_transport.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001/002 — the adaptation layer of the OEP↔Legacy
/// V2 bridge. Knows both V2 concepts (a module id, a category string, an
/// x/y pair) and OEP diagram concepts (`EngineeringNode`, `Point2D`), and
/// translates between them. Never touches `engine.editing.execute` or
/// any Engine internal directly — every mutation goes through the
/// existing [DiagramEditingHost] methods (`addNodeWithMetadata`/
/// `moveNodes`/`deleteNode`/`renameNode`), unchanged.
///
/// **Identity mapping** (POC-003 finding, carried forward unchanged): V2's
/// `m.id` has no pre-existing correspondence with any OEP node in a
/// document that wasn't created from that same V2 vehicle. The mapping is
/// **established, not discovered**, the first time each V2 module is
/// created or moved, and is deliberately **not** an array index, screen
/// position, or random id — it is keyed off V2's own persistent authored
/// id. **Session-scoped only** — not persisted; restarting OEP Studio
/// loses it (`DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md` §16).
///
/// **Coordinate mapping**: identity, unchanged from POC-003/AP-DIAGRAM-
/// V2-WEBVIEW-001's conclusion.
///
/// **Category → symbol mapping (AP-DIAGRAM-V2-WEBVIEW-002, revised
/// AP-DIAGRAM-V2-BRIDGE-SAVE-007)**: V2's 11 module categories (`power`/
/// `ignition`/`charging`/`lighting`/`starter`/`switch`/`control`/
/// `indicator`/`accessory`/`ground`/`connector`, from `index.html`'s own
/// category `<select>` options) were checked against OEP's actual
/// registered symbols (`platform/oep_engine/assets/symbols/*.json`). Only
/// two are a genuine, name-identical, non-fabricated match: `ground` →
/// `ground.json` and `connector` → `connector.json`. The other 9 have no
/// symbol whose *specific* identity is deterministically implied by the
/// category string alone (e.g. `ignition` could plausibly mean
/// `ignition_coil`, but could just as easily be a CDI unit, a spark plug,
/// or something with no existing symbol at all) — [_symbolIdForCategory]
/// therefore falls back to `generic_module.json` for those 9, rather than
/// guessing a specific component identity. This is a different thing from
/// the earlier `'battery'` placeholder (AP-DIAGRAM-V2-WEBVIEW-001, retired)
/// that this class's doc comment used to warn against: `generic_module` is
/// OEP's own purpose-built "Unknown Symbol fallback" (see its own
/// `description`), not a specific-but-wrong component identity, and the
/// real V2 category is never lost — it is still stashed in
/// `metadata['v2Category']` on the created node exactly as before.
///
/// **Why this changed**: returning `null` for 9 of 11 categories meant
/// [_handleModuleCreated]/[_handleWireCreated] silently refused to create
/// an OEP node/relationship for the vast majority of a typical vehicle
/// diagram (V2's own `Bootstrap.run` demo vehicles use these categories
/// almost exclusively — `ground`/`connector` are a small minority). Save
/// As's flush-before-save reconciliation
/// (`LegacyV2StateAdapter.flushBeforeSave`) captures V2's live module/wire
/// state through these same two handlers, so a diagram that displayed
/// completely normally in V2 would silently save as a near-empty OEP
/// document — confirmed to reproduce exactly this way (Save As, then Open
/// the saved file: only the handful of `ground`/`connector` modules and
/// no wires at all came back). Falling back to `generic_module` instead
/// of refusing makes the OEP document a faithful round-trip of what V2 is
/// actually showing, for every category, not just two.
enum _BridgedKind { module, wire }

class LegacyV2StateAdapter {
  LegacyV2StateAdapter(
      {required this.controller,
      required this.channel,
      this.simulationServiceResolver}) {
    channel.onModuleMoved = _handleV2ModuleMoved;
    channel.onModuleCreated = _handleModuleCreated;
    channel.onModuleDeleted = _handleModuleDeleted;
    channel.onModulePropertiesChanged = _handleModulePropertiesChanged;
    channel.onWireCreated = _handleWireCreated;
    channel.onWireDeleted = _handleWireDeleted;
    channel.onWireSelectionChanged = _handleWireSelectionChanged;
    channel.onModuleSelectionChanged = _handleModuleSelectionChanged;
    channel.onWirePropertiesChanged = _handleWirePropertiesChanged;
    channel.onMeasurementRequested = _handleMeasurementRequested;
    channel.onOperatingStateChanged = _handleOperatingStateChanged;
    channel.onSaveRequested = _handleSaveRequested;
  }

  final DiagramEditingHost controller;

  /// [LegacyV2BridgeTransport] in production; a lightweight fake in tests.
  final LegacyV2Channel channel;

  /// AP-DIAGRAM-V2-BRIDGE-006 — resolved fresh on every measurement
  /// request rather than captured once at construction time: the adapter
  /// is built early (WebView init), while a simulation session may not
  /// exist yet, or may be created/torn down later by the user's own
  /// Simulation Center actions — a stale captured reference would miss
  /// exactly that. `null` (no resolver, or resolver returns `null`) means
  /// no simulation session infrastructure is reachable at all; `hasSession
  /// == false` means the infrastructure exists but no session has been
  /// started — both are real states this adapter reports to V2 rather
  /// than working around.
  final DiagramSimulationService? Function()? simulationServiceResolver;

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 3 — the bridge's own record of
  /// which OEP document it is currently synchronized to
  /// (`DiagramDocument.id`, § that class's own doc comment for why this
  /// is a durable-within-session identity even for a never-saved
  /// document). Set at the end of every successful
  /// [initializeFromDocument]/[reinitializeForDocument] call. Exposed
  /// publicly only for the host widget's own display/tests — nothing in
  /// this adapter currently branches on it (the invariant "old document
  /// cannot mutate new document" is enforced by [reinitializeForDocument]
  /// itself, which clears and reseeds before this token is updated, not
  /// by comparing tokens on every inbound message).
  String? currentDocumentToken;

  final Map<String, String> _v2ToOepNodeId = {};

  /// V2 module ids whose category has no deterministic OEP symbol
  /// (§ class doc comment) — tracked only so a host UI can report them;
  /// no OEP node exists for these and none is attempted again on a
  /// later move (a move for an id in this set is a no-op, not a retry).
  final Set<String> unbridgedV2ModuleIds = {};

  /// The most recently bridged V2 module id (move, create, delete, or
  /// property edit) — used by [resyncLastBridgedToV2] after an Engine
  /// undo. Single-entry, by design (§ architecture doc "Limitations") —
  /// does not generalize to a multi-module undo history.
  String? lastBridgedV2ModuleId;

  /// AP-DIAGRAM-V2-WEBVIEW-003 — the most recently bridged V2 wire id
  /// (create only, this task's sole wire operation). Tracked separately
  /// from [lastBridgedV2ModuleId] because they name different kinds of
  /// OEP entities (a node vs. a relationship); [_lastBridgedKind] records
  /// which of the two is actually the most recent bridged mutation, so
  /// [resyncLastBridgedToV2] resyncs the right one after an undo that
  /// could have reverted either a module or a wire operation.
  String? lastBridgedV2WireId;

  _BridgedKind? _lastBridgedKind;

  /// V2 wire ids whose endpoints include at least one V2 module with no
  /// OEP node mapping (§ class doc comment on module category mapping) —
  /// tracked so a host UI can report them. No OEP relationship exists for
  /// these; creating one would require fabricating a node that was
  /// already refused at module-creation time.
  final Set<String> unbridgedV2WireIds = {};

  final Map<String, String> _v2ToOepRelationshipId = {};

  String? oepRelationshipIdFor(String v2WireId) =>
      _v2ToOepRelationshipId[v2WireId];

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 7 — the readiness gate. `false`
  /// until [initializeFromDocument] has finished seeding V2 from the
  /// current OEP document; every inbound handler below early-returns
  /// while this is `false`, so a V2 mutation that races ahead of
  /// initialization (e.g. the poller detecting a "created" module during
  /// the seeding writes themselves) cannot be misinterpreted as a
  /// V2-originated user action. Distinct from
  /// `LegacyV2BridgeTransport.bridgeEnabled` (trust/security, Phase 9 of
  /// AP-STUDIO-WEB-SURFACE-002) — this is a readiness concept, which is
  /// OEP/document-specific and therefore belongs here, not in the
  /// OEP-agnostic transport.
  bool _ready = false;
  bool get isReady => _ready;

  /// Whether any bridged module or wire operation has happened yet this
  /// session — used by the host widget to enable/disable its "Undo"
  /// action rather than checking [lastBridgedV2ModuleId]/
  /// [lastBridgedV2WireId] individually.
  bool get hasBridgedAnything => _lastBridgedKind != null;

  /// Fired after a successful move/create/undo-resync with the
  /// authoritative `(v2ModuleId, oepNodeId, x, y)` — display-only.
  void Function(String v2ModuleId, String oepNodeId, double x, double y)?
      onAuthoritativeResult;

  /// Fired after a successful property edit/undo-resync with the
  /// authoritative `(v2ModuleId, oepNodeId, label)` — display-only.
  void Function(String v2ModuleId, String oepNodeId, String label)?
      onAuthoritativeLabel;

  /// Fired after a bridged module is deleted (V2-originated) or a
  /// create is undone — display-only.
  void Function(String v2ModuleId)? onModuleRemoved;

  /// AP-DIAGRAM-V2-WEBVIEW-003 — fired after a V2 wire is successfully
  /// bridged into a real OEP relationship — display-only.
  void Function(String v2WireId, String oepRelationshipId)? onWireBridged;

  /// AP-DIAGRAM-V2-WEBVIEW-003 — fired when a V2 wire's endpoints
  /// include an unbridged module, so it cannot be represented in OEP at
  /// all — display-only.
  void Function(String v2WireId)? onWireUnbridgeable;

  /// AP-DIAGRAM-V2-WEBVIEW-003 — fired when a bridged wire's creation is
  /// undone and V2 is told to remove it — display-only.
  void Function(String v2WireId)? onWireRemoved;

  /// AP-DIAGRAM-V2-BRIDGE-004 — fired after a V2-originated wire
  /// deletion is applied to OEP — display-only.
  void Function(String v2WireId, String oepRelationshipId)? onWireDeleted;

  /// AP-DIAGRAM-V2-BRIDGE-004 — fired after V2's own wire selection is
  /// mirrored into OEP's selection (or after a deselect) — display-only.
  void Function(String? v2WireId)? onWireSelectionMirrored;

  /// AP-DIAGRAM-V2-BRIDGE-009 — fired after V2's own module selection is
  /// mirrored into OEP's selection (or after a deselect) — display-only,
  /// symmetric with [onWireSelectionMirrored].
  void Function(String? v2ModuleId)? onModuleSelectionMirrored;

  /// AP-DIAGRAM-V2-BRIDGE-005 — fired after a successful wire property
  /// edit/undo-resync with the authoritative `(v2WireId, relationshipId,
  /// label, color)` — display-only.
  void Function(
          String v2WireId, String relationshipId, String label, String color)?
      onAuthoritativeWireProperties;

  /// AP-DMM-BRIDGE-001 — fired after every [_handleMeasurementRequested]
  /// round trip completes with a real (non-null) answer from the live V2
  /// solver, alongside (not instead of) [LegacyV2Channel.
  /// applyMeasurementResult]'s write back into V2's own display. This is
  /// the seam a DMM host page wires into `MultimeterController` once one
  /// exists (Phase 15, deliberately deferred) — kept as a plain callback,
  /// not a `MultimeterController` reference, so this adapter (webview
  /// layer) never has to import the instruments layer. Display-only: no
  /// document/graph mutation happens here or in any handler this fires
  /// from.
  void Function(String v2WireId, String v2Mode, V2LiveMeasurementResult result)?
      onLiveMeasurement;

  /// PRODUCT-READINESS-008 §10-§14 — the most recent RAW (V2-module-id-
  /// keyed) live switch/key state, or `null` before the first
  /// `operatingStateChanged` message has arrived. Kept separately from
  /// [currentOperatingContext] so translation always runs against
  /// whatever the CURRENT `_v2ToOepNodeId` mapping is (a module bridged
  /// after this snapshot arrived is still correctly translated on the
  /// next read), never a stale, pre-translated snapshot.
  V2OperatingStateChangedMessage? _latestRawOperatingState;

  /// §10 — the live V2 switch/key state, translated into the Engine's own
  /// generic [ElectricalOperatingContext] (§11/§12: never a
  /// `Trx300SwitchState`-shaped type — this is exactly the same
  /// `ElectricalOperatingContext` any diagram's live operating state would
  /// produce). Translation rule (§12, derived from the REAL V2 data this
  /// bridge already observes, nothing invented):
  ///  - a plain switch (`V2OperatingStateChangedMessage.switchStates`,
  ///    V2's own `'open'`/`'closed'` vocabulary) becomes a `bool`
  ///    (`true` when closed) — matching [SwitchElectricalBehavior]'s own
  ///    default `closedValue: true`.
  ///  - a real multi-position switch (`multiSwitchStates`, V2's own
  ///    `{group: position}` vocabulary, e.g. the ignition switch's own
  ///    `{power: 'on'}` or the handlebar switch's own `{lights: 'on',
  ///    dimmer: 'lo', engineStop: 'run', starter: 'free'}`) becomes a
  ///    plain `Map<String, Object?>` carrying that SAME group/position
  ///    data verbatim — a real component behavior reads the specific
  ///    group(s) it cares about directly (see
  ///    `Trx300V2SwitchBehaviors` in `trx300_v2_switch_behaviors.dart`),
  ///    rather than this adapter guessing a single combined key.
  /// Each map entry is keyed by the OEP node id (via [oepNodeIdFor]) —
  /// exactly the `switchId` convention every
  /// [ElectricalComponentBehavior] in this codebase already uses
  /// (`switchId: node.id`). A V2 module with no OEP mapping yet (not yet
  /// bridged) is silently omitted, never fabricated.
  ElectricalOperatingContext get currentOperatingContext =>
      _translateOperatingState(_latestRawOperatingState);

  ElectricalOperatingContext _translateOperatingState(
      V2OperatingStateChangedMessage? raw) {
    if (raw == null) return ElectricalOperatingContext.none;
    final activeInputStates = <String, Object?>{};
    raw.switchStates.forEach((v2ModuleId, value) {
      final oepId = oepNodeIdFor(v2ModuleId);
      if (oepId != null) activeInputStates[oepId] = value == 'closed';
    });
    raw.multiSwitchStates.forEach((v2ModuleId, groupMap) {
      final oepId = oepNodeIdFor(v2ModuleId);
      if (oepId != null) {
        activeInputStates[oepId] = Map<String, Object?>.from(groupMap);
      }
    });
    return ElectricalOperatingContext(activeInputStates: activeInputStates);
  }

  /// §14 step 3/4 — fired with the freshly-translated
  /// [ElectricalOperatingContext] every time V2's own live switch/key
  /// state actually changes. A DMM host (`DigitalMultimeterInstrumentPanel`)
  /// listens here to know when to re-solve/re-measure.
  void Function(ElectricalOperatingContext context)? onOperatingStateChanged;

  void _handleOperatingStateChanged(V2OperatingStateChangedMessage message) {
    if (!_ready) return;
    _latestRawOperatingState = message;
    onOperatingStateChanged?.call(currentOperatingContext);
  }

  String? oepNodeIdFor(String v2ModuleId) => _v2ToOepNodeId[v2ModuleId];

  /// PRODUCT-READINESS-009 — the reverse of [oepNodeIdFor], needed to
  /// translate a native [TraceHighlightPlan]'s OEP node ids back into the
  /// V2 module ids the diagram's own rendering understands. Deliberately a
  /// small linear scan over the same existing [_v2ToOepNodeId] map rather
  /// than a second, independently-maintained reverse map — this is called
  /// once per trace-highlight update (a user action), not per frame.
  String? v2ModuleIdFor(String oepNodeId) {
    for (final entry in _v2ToOepNodeId.entries) {
      if (entry.value == oepNodeId) return entry.key;
    }
    return null;
  }

  /// The reverse of [oepRelationshipIdFor] — see [v2ModuleIdFor]'s own
  /// doc comment for why a linear scan over the existing
  /// [_v2ToOepRelationshipId] map, not a new reverse map.
  String? v2WireIdFor(String oepRelationshipId) {
    for (final entry in _v2ToOepRelationshipId.entries) {
      if (entry.value == oepRelationshipId) return entry.key;
    }
    return null;
  }

  /// PRODUCT-READINESS-009 §11 — translates a [TraceHighlightPlan] (pure
  /// OEP identity) into the V2 ids the real diagram rendering understands,
  /// then pushes it through [channel] exactly like every other
  /// OEP-authoritative-result-into-V2 call this adapter already makes
  /// (§21: reuse the existing bridge, minimal adapter only). IDs that
  /// cannot be resolved (not yet bridged, or since removed) are silently
  /// omitted -- never fabricated.
  Future<void> applyTraceHighlight(TraceHighlightPlan plan) {
    final wireIds = plan.relationshipIds.map(v2WireIdFor).whereType<String>().toList();
    final sourceIds = plan.sourceNodeIds.map(v2ModuleIdFor).whereType<String>().toList();
    final returnIds = plan.returnNodeIds.map(v2ModuleIdFor).whereType<String>().toList();
    final blockedIds = plan.blockedNodeIds.map(v2ModuleIdFor).whereType<String>().toList();
    final flow = <String, int>{
      for (final entry in plan.currentFlowByRelationshipId.entries)
        if (v2WireIdFor(entry.key) case final String wireId) wireId: entry.value,
    };
    return channel.applyTraceHighlight(wireIds, sourceIds, returnIds, blockedIds, flow);
  }

  /// §29 — returns the real, rendered diagram to its normal, unhighlighted
  /// state. Never mutates `DiagramDocument` (§20 — this is pure V2
  /// rendering state, exactly like [applyTraceHighlight]).
  Future<void> clearTraceHighlight() => channel.clearTraceHighlight();

  /// PRODUCT-READINESS-010 §17 — "Fit Circuit": pans/zooms the real V2
  /// viewport to the bounding region of [plan]'s own real, rendered
  /// module cards. Never moves engineering objects, never touches
  /// persisted layout (§17 — pure transient viewport state, the same
  /// "translate OEP ids -> V2 ids, then push through the existing bridge"
  /// shape as [applyTraceHighlight]).
  Future<void> fitTraceHighlight(TraceHighlightPlan plan) {
    final nodeIds = plan.allNodeIds.map(v2ModuleIdFor).whereType<String>().toList();
    return channel.fitToTraceHighlight(nodeIds);
  }

  /// AP-OEP-DIAGRAM-OPEN-RACE-001 companion — how many modules the most
  /// recent [initializeFromDocument]/[reinitializeForDocument] *attempted*
  /// to seed into V2 (i.e. how many graph nodes carried a `v2ModuleId` to
  /// restore). Every [LegacyV2Channel.restoreModule] call is a
  /// fire-and-forget `window.__oepBridgeX && window.__oepBridgeX(...)`
  /// that silently no-ops if V2's page isn't ready to receive it yet — so
  /// this count on its own does NOT prove V2 actually rendered anything;
  /// it exists so the caller (`legacy_v2_webview.dart`) can compare it
  /// against V2's own live `MODULES.length` right after seeding and turn
  /// a mismatch into a visible error instead of a diagram that looks like
  /// it "loaded" (no exception, no error state) while showing nothing.
  int get bridgedModuleCount => _v2ToOepNodeId.length;

  /// The wire-side equivalent of [bridgedModuleCount] — how many
  /// relationships [initializeFromDocument]/[reinitializeForDocument] just
  /// attempted to restore into V2 as wires. Added alongside the module
  /// check in `_verifySeedLanded` (`legacy_v2_webview.dart`): every
  /// `restoreWire` call is the same fire-and-forget
  /// `window.__oepBridgeRestoreWire && ...` shape as `restoreModule` (§
  /// [bridgedModuleCount]'s own doc comment for why that means a stuck/
  /// unready V2 page silently no-ops instead of throwing), but until now
  /// only the module count was ever compared against V2's live state —
  /// a diagram whose modules landed correctly but whose wires silently
  /// didn't produced no error at all, just a diagram that looked loaded
  /// with most of its wires missing.
  int get bridgedWireCount => _v2ToOepRelationshipId.length;

  /// Reads back [_handleModuleCreated]'s stashed `metadata['v2Terminals']`
  /// — typed `List<Map<String, String>>` in-memory, but `List<dynamic>` of
  /// `Map<String, dynamic>` once it has round-tripped through a saved
  /// document's JSON (`jsonDecode` does not restore the original generic
  /// types) — normalized back to the one shape [LegacyV2Channel.restoreModule]
  /// expects either way.
  static List<Map<String, String>> _terminalsFromMetadata(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
            (t) => t.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
        .toList();
  }

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-009 — [_terminalsFromMetadata] only has
  /// something to read for a node created (or flushed) through THIS
  /// bridge's own live create/save path, going forward from
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-007. It has nothing for a node from any
  /// other producer of `v2ModuleId`-bearing nodes — most notably
  /// `tool/import_trx300_vehicle.dart`'s standalone batch import, which
  /// predates this metadata convention entirely and instead gives each
  /// node a real `EngineeringNode.ports` list (with each port's V2 wire
  /// color code stashed at `port.metadata['v2Color']` — confirmed by
  /// reading the importer and a sample imported document directly). Both
  /// are genuine, already-existing sources for the same information V2's
  /// `restoreModule` needs (a terminal name + color code pair); this
  /// falls back to deriving it from `ports` rather than leaving a module
  /// with zero terminals — which is what silently broke, for EVERY
  /// existing document, the moment [initializeFromDocument] started
  /// unconditionally clearing V2's display first (AP-DIAGRAM-V2-BRIDGE-
  /// SAVE-008): previously, a module already present in V2 (from its own
  /// bootstrap) kept its bootstrap-provided terminals no matter what
  /// `restoreModule` sent, because `restoreModule` never overwrote an
  /// existing module's terminals unless it was actually given some.
  /// Clearing first means every module now has to be reconstructed from
  /// scratch, so `restoreModule` needs a real answer for every document,
  /// not just ones saved after AP-DIAGRAM-BRIDGE-SAVE-007 landed.
  static List<Map<String, String>> _terminalsForNode(EngineeringNode node) {
    final fromMetadata = _terminalsFromMetadata(node.metadata['v2Terminals']);
    if (fromMetadata.isNotEmpty) return fromMetadata;
    if (node.ports.isEmpty) return const [];
    return node.ports
        .map((port) => {
              'n': port.name,
              'c': port.metadata['v2Color'] as String? ?? '',
            })
        .toList();
  }

  /// Deterministic V2 category → OEP symbolId lookup — see class doc
  /// comment for why only these two categories have a specific match, and
  /// why every other category falls back to `generic_module` rather than
  /// being refused. Always returns a non-null symbolId.
  static String _symbolIdForCategory(String category) =>
      const {
        'ground': 'ground',
        'connector': 'connector',
      }[category] ??
      'generic_module';

  void _handleV2ModuleMoved(V2ModuleMovedMessage message) {
    if (!_ready) return;
    final nodeId = _v2ToOepNodeId[message.v2ModuleId];
    // AP-DIAGRAM-V2-WEBVIEW-002 retires the previous task's "auto-create
    // via a placeholder symbol on first move" behavior — creation is now
    // exclusively handled by `_handleModuleCreated`, which has real
    // category information `moduleMoved` never carried. A move for an
    // id that was never created, or whose category has no symbol
    // mapping, is legitimately a no-op: there is nothing in OEP to move.
    if (nodeId == null) return;
    controller.moveNodes({nodeId: Point2D(message.x, message.y)});
    lastBridgedV2ModuleId = message.v2ModuleId;
    _lastBridgedKind = _BridgedKind.module;
    _syncPositionToV2(message.v2ModuleId, nodeId);
  }

  /// Phase 4 — creates the corresponding OEP node via the existing
  /// `addNodeWithMetadata` (itself an existing `CreateNodeCommand` call).
  /// [_symbolIdForCategory] always resolves a symbolId now (a specific
  /// match, or the `generic_module` fallback), so every category creates
  /// a node — see that method's/the class doc comment for why
  /// [unbridgedV2ModuleIds] is effectively legacy at this point (kept for
  /// the host UI's display purposes and the theoretical case of a truly
  /// empty category string, rather than removed outright).
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-011 — a defense-in-depth guard against
  /// duplicate-creation. [_v2ToOepNodeId] is deliberately in-memory/
  /// session-scoped only (§ class doc comment) — a fresh
  /// `LegacyV2StateAdapter` (a new WebView widget instance, e.g. after
  /// its Diagram tab was closed and reopened) starts with an empty map
  /// regardless of what the graph itself already durably records via
  /// `metadata['v2ModuleId']`. [initializeFromDocument] is meant to be
  /// the ONE place that rebuilds the map from that durable source before
  /// anything else can run — but if a create event ever reaches
  /// [_handleModuleCreated] while the map is out of sync with the graph
  /// for any reason (a gap this task could not fully trace to one single
  /// root cause; confirmed symptom: a re-saved document ends up with a
  /// SECOND node for the same V2 module — a fresh generated id, the
  /// wrong `generic_module` fallback symbol instead of the original
  /// richer one, and none of the original node's other data), this
  /// check makes duplicate-creation structurally impossible rather than
  /// relying on the map alone: before creating, look for a node the
  /// graph ITSELF already durably identifies as this V2 module, and if
  /// one exists, adopt it (re-populate the map entry) instead of
  /// fabricating a second one.
  String? _existingNodeIdForV2Module(String v2ModuleId) {
    for (final node in controller.engine.editing.session.graph.nodes.values) {
      if (node.metadata['v2ModuleId'] == v2ModuleId) return node.id;
    }
    return null;
  }

  void _handleModuleCreated(V2ModuleCreatedMessage message) {
    if (!_ready) return;
    if (_v2ToOepNodeId.containsKey(message.v2ModuleId)) return;
    final existingNodeId = _existingNodeIdForV2Module(message.v2ModuleId);
    if (existingNodeId != null) {
      _v2ToOepNodeId[message.v2ModuleId] = existingNodeId;
      return;
    }
    final symbolId = _symbolIdForCategory(message.category);
    final position = Point2D(message.x, message.y);
    final before = controller.engine.editing.session.graph.nodes.keys.toSet();
    controller.addNodeWithMetadata(
      symbolId,
      position,
      displayName: message.label,
      metadata: {
        'v2ModuleId': message.v2ModuleId,
        'v2Category': message.category,
        // AP-DIAGRAM-V2-BRIDGE-SAVE-007 — V2's own terminal list, so a
        // later `restoreModule` (document reopen, undo-of-delete) can
        // reconstruct a module V2 actually renders with terminal dots.
        if (message.terminals.isNotEmpty) 'v2Terminals': message.terminals,
        // AP-DIAGRAM-V2-BRIDGE-SAVE-009 — V2's own exit side ('up'/
        // 'down'/'left'/'right'), so a later `restoreModule` reconstructs
        // a module with its real wire-exit side instead of the hardcoded
        // 'down' default.
        if (message.exit.isNotEmpty) 'v2Exit': message.exit,
        // AP-DIAGRAM-V2-BRIDGE-SAVE-010 — V2's own connector/vertical
        // flags, so a later `restoreModule` reconstructs a connector
        // module with its real stacked-pin layout and orientation
        // instead of falling back to a plain card / horizontal.
        if (message.connector != null) 'v2Connector': message.connector,
        if (message.vertical != null) 'v2Vertical': message.vertical,
        // AP-MODULE-LAYOUT-001 — V2's own label/pin label position
        // overrides, same stash-for-`restoreModule`-to-rebuild treatment
        // as `v2Exit` above.
        if (message.labelPos.isNotEmpty) 'v2LabelPos': message.labelPos,
        if (message.pinLabelPos.isNotEmpty)
          'v2PinLabelPos': message.pinLabelPos,
        if (message.subLabelPos.isNotEmpty)
          'v2SubLabelPos': message.subLabelPos,
        // AP-MODULE-LABEL-WRAP-001 — V2's own module subtitle (`m.sub`)
        // and label-justify choice, same stash-for-`restoreModule`-to-
        // rebuild treatment as `v2Exit` above. `sub` is a genuinely
        // pre-existing V2 field this bridge never captured before this
        // fix (§ `restoreModule`'s own doc comment on `hasSub`).
        if (message.sub.isNotEmpty) 'v2Sub': message.sub,
        if (message.labelJustify.isNotEmpty)
          'v2LabelJustify': message.labelJustify,
        // AP-MODULE-KIND-001 — V2's own special-render flag (`m.bulb`/
        // `m.diode`/`m.battery`/`m.starterMotor`/`m.solenoid`/
        // `m.groundedSwitch`/`m.thermistor`, collapsed to one string by
        // the bridge script), same stash-for-`restoreModule`-to-rebuild
        // treatment as `v2Exit` above — without it, a reopened Battery/
        // Starter Motor/Solenoid/Diode/Bulb/grounded-Switch/Thermistor
        // module silently fell back to a plain `buildStdCard` card,
        // losing its whole special glyph despite otherwise-correct
        // terminals/position/wires.
        if (message.kind.isNotEmpty) 'v2Kind': message.kind,
        // AP-BULB-GENERIC-001 — same stash-for-`restoreModule`-to-rebuild
        // treatment as `v2Kind` above, for a bulb's own lit-color/style/
        // flip-side choice.
        if (message.bulbStyle.isNotEmpty) 'v2BulbStyle': message.bulbStyle,
        if (message.bulbColor.isNotEmpty) 'v2BulbColor': message.bulbColor,
        if (message.flipped != null) 'v2Flipped': message.flipped,
      },
    );
    final after = controller.engine.editing.session.graph.nodes.keys.toSet();
    final nodeId = after.difference(before).single;
    _v2ToOepNodeId[message.v2ModuleId] = nodeId;
    lastBridgedV2ModuleId = message.v2ModuleId;
    _lastBridgedKind = _BridgedKind.module;
    _syncPositionToV2(message.v2ModuleId, nodeId);
  }

  /// Phase 5 — deletes the mapped OEP node via the existing
  /// `DeleteNodeCommand` (cascades relationship removal, per that
  /// command's own doc comment — matching V2's own `delModule`, which
  /// also removes the module's wires). The mapping entry is
  /// **deliberately kept**, not removed, so [resyncLastBridgedModuleToV2]
  /// can still find it if the deletion is undone.
  void _handleModuleDeleted(V2ModuleDeletedMessage message) {
    if (!_ready) return;
    final nodeId = _v2ToOepNodeId[message.v2ModuleId];
    if (nodeId == null) return;
    controller.deleteNode(nodeId);
    lastBridgedV2ModuleId = message.v2ModuleId;
    _lastBridgedKind = _BridgedKind.module;
    onModuleRemoved?.call(message.v2ModuleId);
  }

  /// Phase 6 — bridges exactly one V2 module property: `label` ↔ OEP's
  /// `displayName`, via the existing `RenameNodeCommand`. `cat`/`sub`/
  /// `exit`/`terminals` are explicitly not bridged (see the architecture
  /// doc's property classification table).
  /// AP-DIAGRAM-V2-BRIDGE-011 — also bridges V2's free-text module
  /// `notes` field into `metadata['notes']` via the new
  /// `DiagramStudioController.updateNodeMetadata`
  /// (`UpdateNodeMetadataCommand` — see that command's own doc comment
  /// for why `metadata`, not `properties`, is correct here; this closes
  /// the gap BRIDGE-009 §18.3 classified as "a small, well-scoped,
  /// defensible future addition," not a new decision). V2's own
  /// `saveWireProps`-style blank-falls-back-to-previous convention does
  /// NOT apply to notes (`js/editor/module-editor.js`'s `saveModProps()`:
  /// `m.notes = $('mpm-notes').value.trim();` — a genuinely blank notes
  /// field IS written as `''`, unlike label/wire-color), so an empty
  /// string here is a real "clear the notes" request and is patched as
  /// `null` (removing the key), matching this bridge's existing
  /// null-removes-key convention elsewhere.
  void _handleModulePropertiesChanged(
      V2ModulePropertiesChangedMessage message) {
    if (!_ready) return;
    final nodeId = _v2ToOepNodeId[message.v2ModuleId];
    if (nodeId == null) return;
    final currentNode = controller.engine.editing.session.graph.nodes[nodeId];
    if (currentNode == null) return;
    var bridgedSomething = false;
    if (currentNode.displayName != message.label) {
      controller.renameNode(nodeId, message.label);
      bridgedSomething = true;
    }
    // Compared against '' (not `null`), so "no notes key at all" and "V2
    // sent an empty notes field" are treated as equal — a real bug this
    // task's own test caught: without this, every label-only edit also
    // fired a spurious `updateNodeMetadata({'notes': null})` (a no-op
    // patch that still pushes a real, empty undo-stack entry, since
    // `UpdateNodeMetadataCommand.apply` has no "did anything actually
    // change" short-circuit of its own).
    final currentNotes = currentNode.metadata['notes'] as String? ?? '';
    if (currentNotes != message.notes) {
      controller.updateNodeMetadata(
          nodeId, {'notes': message.notes.isEmpty ? null : message.notes});
      bridgedSomething = true;
    }
    // Terminal-list/exit/connector/vertical edits on an already-bridged
    // module (adding/renaming/reordering a pin via V2's own Edit Module
    // modal) used to have nowhere to go: only a brand-new module's
    // terminals were ever captured, once, via _handleModuleCreated — so
    // an edit here rendered correctly live in V2, then silently reverted
    // to the module's original terminal list on the next document
    // save-and-reopen, since restoreModule() had nothing but that stale
    // metadata to reconstruct from. The bridge script only sends this
    // message with updated terminals/exit/connector/vertical when at
    // least one of them actually changed (see its own doc comment), so
    // this always applies what it's given rather than re-diffing.
    if (message.terminals.isNotEmpty) {
      controller.updateNodeMetadata(nodeId, {'v2Terminals': message.terminals});
      bridgedSomething = true;
    }
    if (message.exit.isNotEmpty &&
        currentNode.metadata['v2Exit'] != message.exit) {
      controller.updateNodeMetadata(nodeId, {'v2Exit': message.exit});
      bridgedSomething = true;
    }
    if (message.connector != null &&
        currentNode.metadata['v2Connector'] != message.connector) {
      controller.updateNodeMetadata(nodeId, {'v2Connector': message.connector});
      bridgedSomething = true;
    }
    if (message.vertical != null &&
        currentNode.metadata['v2Vertical'] != message.vertical) {
      controller.updateNodeMetadata(nodeId, {'v2Vertical': message.vertical});
      bridgedSomething = true;
    }
    // AP-MODULE-LAYOUT-001 — unlike `exit` above, an empty `labelPos`/
    // `pinLabelPos` IS a meaningful, real value here (clearing an
    // override back to "Auto" from the properties panel), so this
    // compares against the current metadata value directly (not just
    // `isNotEmpty`) and patches `null` (removes the key) for empty,
    // matching this bridge's existing empty-string-clears convention
    // (§ `notes` above) rather than the "empty means untouched" gate
    // `exit`/`terminals` use.
    final currentLabelPos = currentNode.metadata['v2LabelPos'] as String? ?? '';
    if (currentLabelPos != message.labelPos) {
      controller.updateNodeMetadata(nodeId,
          {'v2LabelPos': message.labelPos.isEmpty ? null : message.labelPos});
      bridgedSomething = true;
    }
    final currentPinLabelPos =
        currentNode.metadata['v2PinLabelPos'] as String? ?? '';
    if (currentPinLabelPos != message.pinLabelPos) {
      controller.updateNodeMetadata(nodeId, {
        'v2PinLabelPos': message.pinLabelPos.isEmpty ? null : message.pinLabelPos
      });
      bridgedSomething = true;
    }
    final currentSubLabelPos =
        currentNode.metadata['v2SubLabelPos'] as String? ?? '';
    if (currentSubLabelPos != message.subLabelPos) {
      controller.updateNodeMetadata(nodeId, {
        'v2SubLabelPos':
            message.subLabelPos.isEmpty ? null : message.subLabelPos
      });
      bridgedSomething = true;
    }
    final currentSub = currentNode.metadata['v2Sub'] as String? ?? '';
    if (currentSub != message.sub) {
      controller.updateNodeMetadata(
          nodeId, {'v2Sub': message.sub.isEmpty ? null : message.sub});
      bridgedSomething = true;
    }
    final currentLabelJustify =
        currentNode.metadata['v2LabelJustify'] as String? ?? '';
    if (currentLabelJustify != message.labelJustify) {
      controller.updateNodeMetadata(nodeId, {
        'v2LabelJustify':
            message.labelJustify.isEmpty ? null : message.labelJustify
      });
      bridgedSomething = true;
    }
    final currentKind = currentNode.metadata['v2Kind'] as String? ?? '';
    if (currentKind != message.kind) {
      controller.updateNodeMetadata(
          nodeId, {'v2Kind': message.kind.isEmpty ? null : message.kind});
      bridgedSomething = true;
    }
    final currentBulbStyle =
        currentNode.metadata['v2BulbStyle'] as String? ?? '';
    if (currentBulbStyle != message.bulbStyle) {
      controller.updateNodeMetadata(nodeId, {
        'v2BulbStyle': message.bulbStyle.isEmpty ? null : message.bulbStyle
      });
      bridgedSomething = true;
    }
    final currentBulbColor =
        currentNode.metadata['v2BulbColor'] as String? ?? '';
    if (currentBulbColor != message.bulbColor) {
      controller.updateNodeMetadata(nodeId, {
        'v2BulbColor': message.bulbColor.isEmpty ? null : message.bulbColor
      });
      bridgedSomething = true;
    }
    if (message.flipped != null &&
        currentNode.metadata['v2Flipped'] != message.flipped) {
      controller.updateNodeMetadata(nodeId, {'v2Flipped': message.flipped});
      bridgedSomething = true;
    }
    if (!bridgedSomething) return;
    lastBridgedV2ModuleId = message.v2ModuleId;
    _lastBridgedKind = _BridgedKind.module;
    _syncLabelToV2(message.v2ModuleId, nodeId);
  }

  /// AP-DIAGRAM-V2-WEBVIEW-003, Phases 2/3/6 — creates the corresponding
  /// OEP relationship via the existing `createRelationship`
  /// (`CreateRelationshipCommand`, node-to-node — `EngineeringRelationship`
  /// itself still has no dedicated port field, confirmed unchanged this
  /// task). Only proceeds if **both** endpoint V2 modules are already
  /// mapped to an OEP node (i.e. both were created with a deterministic
  /// category → symbol mapping, § `_symbolIdForCategory`) — a wire
  /// touching an unbridged module cannot be represented in OEP at all,
  /// and is recorded, not fabricated.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-011 — terminal identity is now bridged too,
  /// via `metadata['sourcePort']`/`['targetPort']`. This is **not** a new
  /// or fabricated mechanism: it is the exact existing informal
  /// port-reference convention `VerificationEngine._portReferenced`
  /// (`verification_engine.dart`) and `StateConditionResolver
  /// ._relationshipsForComponent` (`state_condition_resolver.dart`)
  /// already read (`r.metadata['sourcePort'] == portId`), confirmed by
  /// direct source read to be a plain string-equality match — no `Port`
  /// object resolution, no schema change, no Engine work needed. V2's
  /// own `fromTerminal`/`toTerminal` (received on every `V2WireCreatedMessage`
  /// since AP-DIAGRAM-V2-WEBVIEW-003 but never written anywhere until
  /// now — the wire bridge doc's own §13 flagged this as the reason
  /// terminal fidelity was classified ENGINE EXTENSION REQUIRED) are
  /// exactly the kind of string this convention already expects. Empty
  /// terminal names are never written (V2 sometimes omits them, e.g. for
  /// non-connector modules with no terminal list) — matching this
  /// bridge's existing null-means-absent convention elsewhere, and the
  /// convention's own existing consumers already treat an absent
  /// `sourcePort`/`targetPort` as "not port-scoped," not as an error.
  void _handleWireCreated(V2WireCreatedMessage message) {
    if (!_ready) return;
    if (_v2ToOepRelationshipId.containsKey(message.v2WireId)) return;
    final sourceNodeId = _v2ToOepNodeId[message.fromModuleId];
    final targetNodeId = _v2ToOepNodeId[message.toModuleId];
    if (sourceNodeId == null || targetNodeId == null) {
      unbridgedV2WireIds.add(message.v2WireId);
      onWireUnbridgeable?.call(message.v2WireId);
      return;
    }
    final before =
        controller.engine.editing.session.graph.relationships.keys.toSet();
    controller.createRelationship(sourceNodeId, targetNodeId);
    final after =
        controller.engine.editing.session.graph.relationships.keys.toSet();
    final relationshipId = after.difference(before).single;
    controller.updateRelationshipMetadata(relationshipId, {
      // AP-DIAGRAM-V2-BRIDGE-002, Phase 5/6 — stashed so
      // `initializeFromDocument` can durably rebuild
      // `_v2ToOepRelationshipId` from the document itself (the map is an
      // in-memory *index* over this metadata, not the source of truth).
      'v2WireId': message.v2WireId,
      'label': message.label,
      'wireColor': message.color,
      if (message.fromTerminal.isNotEmpty) 'sourcePort': message.fromTerminal,
      if (message.toTerminal.isNotEmpty) 'targetPort': message.toTerminal,
      // AP-WIRE-EXIT-OVERRIDE-001 — V2's own `w.fromExit` (this wire's
      // per-instance override of which side it leaves its source
      // terminal from — arrow keys during creation, or the wire
      // properties panel's "Exit Side" dropdown), same
      // stash-for-`initializeFromDocument`-to-rebuild treatment as
      // `v2WireId` above.
      if (message.fromExit.isNotEmpty) 'v2FromExit': message.fromExit,
      // AP-SPLICE-INSPECTOR-001 — same idea for the DESTINATION end.
      if (message.toExit.isNotEmpty) 'v2ToExit': message.toExit,
      // AP-BATTERY-CABLE-001 — V2's own `w.cable` (thick Red/Black
      // battery-cable rendering), same stash-for-restore treatment.
      if (message.cable) 'v2Cable': true,
    });
    _v2ToOepRelationshipId[message.v2WireId] = relationshipId;
    lastBridgedV2WireId = message.v2WireId;
    _lastBridgedKind = _BridgedKind.wire;

    // Phase 7 — read back what the Engine actually stored, not what was
    // requested, before confirming to V2.
    final relationship =
        controller.engine.editing.session.graph.relationships[relationshipId]!;
    channel.confirmWireCreated(
      message.v2WireId,
      relationship.metadata['label'] as String? ?? '',
      relationship.metadata['wireColor'] as String? ?? '',
    );
    onWireBridged?.call(message.v2WireId, relationshipId);
  }

  /// AP-DIAGRAM-V2-BRIDGE-004, Phase 9 — deletes the mapped OEP
  /// relationship via the existing `DeleteRelationshipCommand`. The
  /// mapping entry is **deliberately kept**, not removed, so
  /// [resyncLastBridgedToV2] can still find it if the deletion is undone
  /// — same pattern `_handleModuleDeleted` already established.
  void _handleWireDeleted(V2WireDeletedMessage message) {
    if (!_ready) return;
    final relationshipId = _v2ToOepRelationshipId[message.v2WireId];
    if (relationshipId == null) return;
    controller.deleteRelationship(relationshipId);
    lastBridgedV2WireId = message.v2WireId;
    _lastBridgedKind = _BridgedKind.wire;
    onWireDeleted?.call(message.v2WireId, relationshipId);
  }

  /// AP-DIAGRAM-V2-BRIDGE-004, Phase 8 — mirrors V2's own wire selection
  /// into OEP's existing `GraphSelection` via
  /// `engine.registry.selection.selectRelationship`/`deselectAll` — OEP
  /// remains the sole authoritative selection; this never creates a
  /// second selection concept. A V2 wire with no OEP mapping (an
  /// unbridged wire, § `unbridgedV2WireIds`) selecting in V2 has nothing
  /// to mirror — OEP's own selection is left exactly as it was, not
  /// cleared, since "V2 selected something OEP doesn't know about" is
  /// not the same as "V2 selected nothing."
  void _handleWireSelectionChanged(V2WireSelectionChangedMessage message) {
    if (!_ready) return;
    final v2Id = message.v2WireId;
    if (v2Id == null) {
      controller.engine.registry.selection.deselectAll();
      onWireSelectionMirrored?.call(null);
      return;
    }
    final relationshipId = _v2ToOepRelationshipId[v2Id];
    if (relationshipId == null) return;
    controller.engine.registry.selection.selectRelationship(relationshipId);
    onWireSelectionMirrored?.call(v2Id);
  }

  /// AP-DIAGRAM-V2-BRIDGE-009 — mirrors V2's own module selection
  /// (`selM`) into OEP's existing `GraphSelection` via
  /// `engine.registry.selection.selectNode`/`deselectAll`, symmetric with
  /// [_handleWireSelectionChanged]. A V2 module with no OEP mapping (an
  /// unbridged module, § `unbridgedV2ModuleIds`) selecting in V2 has
  /// nothing to mirror — OEP's own selection is left exactly as it was,
  /// same "unmapped selection is not the same as no selection" rationale
  /// wire selection already established. Selection is a pure read of
  /// existing OEP state — this never issues a Command, never dirties the
  /// document (confirmed by inspection: `GraphSelectionService.selectNode`/
  /// `deselectAll` mutate only the selection service's own state, never
  /// touch `EditingService`/the command stack).
  void _handleModuleSelectionChanged(V2ModuleSelectionChangedMessage message) {
    if (!_ready) return;
    final v2Id = message.v2ModuleId;
    if (v2Id == null) {
      controller.engine.registry.selection.deselectAll();
      onModuleSelectionMirrored?.call(null);
      return;
    }
    final nodeId = _v2ToOepNodeId[v2Id];
    if (nodeId == null) return;
    controller.engine.registry.selection.selectNode(nodeId);
    onModuleSelectionMirrored?.call(v2Id);
  }

  /// AP-DIAGRAM-V2-BRIDGE-005 — bridges V2's post-Save `lbl`/`c` wire
  /// fields into the already-established `metadata['label']`/
  /// `['wireColor']` keys via the existing `updateRelationshipMetadata` →
  /// `UpdateRelationshipPropertiesCommand` (no new mutation mechanism, no
  /// second wire-property model). Both fields are written as V2 supplies
  /// them — this is the same treatment `_handleWireCreated` already gives
  /// `message.color` (a raw V2 wire-color CODE string, e.g. `"R"`/
  /// `"Bl/Y"`, never hex — confirmed by reading `js/utils/colors.js`
  /// directly), so this task does not introduce a new representation for
  /// `wireColor`, it continues the one wire creation already established.
  ///
  /// **Known gap, not fabricated around**: the native Flutter property
  /// editor (`EngineeringRelationshipProperties`) independently enforces
  /// strict `#RRGGBB`/`#AARRGGBB` hex for the same `wireColor` key (see
  /// `v2_wire_painter.dart`'s `isValidWireHexColor`). That validation
  /// lives in the Flutter *widget*, not in `UpdateRelationshipPropertiesCommand`
  /// itself (confirmed by reading the command — it merges any patch with
  /// no validation of its own), so a V2-sourced code string is not
  /// rejected by the Engine/Controller layer. The result is two
  /// legitimate but differently-shaped producers of `wireColor` today:
  /// V2's bridge (code strings) and the native editor (hex). Converting
  /// V2's code to hex was considered and rejected — V2's own renderer
  /// (`Colors.wireHex`) only understands its own code vocabulary, so
  /// writing a hex value into V2's `w.c` would silently break V2's own
  /// rendering (falls back to a generic gray for anything not in its
  /// `WIRE_HEX` table). This is documented as an **OPEN, cross-producer
  /// representation gap**, not silently resolved by fabricating a
  /// code→hex conversion table on top of V2's real one.
  ///
  /// **Blank-value semantics**: V2's own `saveWireProps()` cannot produce
  /// a blank `lbl`/`c` (falls back to the previous value — confirmed by
  /// reading `wire-editor.js`), so unlike the native editor's
  /// empty-string-means-remove-the-key convention, this handler never
  /// sends a `null` patch value.
  void _handleWirePropertiesChanged(V2WirePropertiesChangedMessage message) {
    if (!_ready) return;
    final relationshipId = _v2ToOepRelationshipId[message.v2WireId];
    if (relationshipId == null) return;
    final current =
        controller.engine.editing.session.graph.relationships[relationshipId];
    if (current == null) return;
    final currentFromExit = current.metadata['v2FromExit'] as String? ?? '';
    final currentToExit = current.metadata['v2ToExit'] as String? ?? '';
    final currentCable = current.metadata['v2Cable'] as bool? ?? false;
    if (current.metadata['label'] == message.label &&
        current.metadata['wireColor'] == message.color &&
        currentFromExit == message.fromExit &&
        currentToExit == message.toExit &&
        currentCable == message.cable) {
      return;
    }
    controller.updateRelationshipMetadata(relationshipId, {
      'label': message.label,
      'wireColor': message.color,
      // AP-WIRE-EXIT-OVERRIDE-001 — `null` (removes the key), not `''`,
      // when the dropdown was set back to "Auto" — matches this bridge's
      // existing null-means-absent convention (§ `sourcePort`/`targetPort`
      // above), so `initializeFromDocument` correctly omits `fromExit`
      // when restoring rather than passing a literal empty string through
      // to `restoreWire` (harmless either way, but this keeps the
      // document's own metadata clean once an override is cleared).
      'v2FromExit': message.fromExit.isNotEmpty ? message.fromExit : null,
      // AP-SPLICE-INSPECTOR-001 — same idea for the DESTINATION end.
      'v2ToExit': message.toExit.isNotEmpty ? message.toExit : null,
      // AP-BATTERY-CABLE-001 — `null` when unchecked, matching the same
      // null-means-absent convention above.
      'v2Cable': message.cable ? true : null,
    });
    lastBridgedV2WireId = message.v2WireId;
    _lastBridgedKind = _BridgedKind.wire;

    // Phase 7 — read back what the Engine actually stored, not what was
    // requested, before confirming to V2. Reuses `confirmWireCreated`
    // (identical `(v2WireId, label, color)` shape) rather than a second
    // outbound method.
    final authoritative =
        controller.engine.editing.session.graph.relationships[relationshipId]!;
    final label = authoritative.metadata['label'] as String? ?? '';
    final color = authoritative.metadata['wireColor'] as String? ?? '';
    channel.confirmWireCreated(message.v2WireId, label, color);
    onAuthoritativeWireProperties?.call(
        message.v2WireId, relationshipId, label, color);
  }

  /// AP-DMM-BRIDGE-001 — supersedes the earlier design where this redirected
  /// to `SimulationEngine.measure` (via [DiagramSimulationService]/
  /// [simulationServiceResolver]): that engine is reachability-only (no
  /// per-component resistance, no switch-continuity, no connector/splice
  /// pin isolation — see `MeasurementEngine`'s own disclosed notes) and has
  /// no visibility into V2's live switch state at all, so it could never be
  /// a faithful stand-in for what the diagram is actually doing. This now
  /// queries [LegacyV2Channel.queryLiveMeasurement], which reads the SAME
  /// live solver (`GraphBuilder`/`VoltagePropagator`/`GroundPropagator`/
  /// `ElectricalSolver`, via `LiveSim.readWireMeasurement`) that already
  /// drives V2's own bulb-glow simulation — the bridge no longer overrides
  /// V2's correct local answer with a worse one; it re-fetches the SAME
  /// authoritative answer in a structured form and pushes it back,
  /// incidentally also fixing V2's own LCD (`meter-panel.js`'s
  /// `updateMeter()` is itself still a static/SWPACK-only lookup — this
  /// override is what makes the on-screen reading correct).
  ///
  /// **Probe mapping**: V2's multimeter reading depends only on *which
  /// wire is selected* (confirmed by reading `updateMeter()` directly), so
  /// this measures across that wire's own two endpoints — but now WITH
  /// terminal precision: [V2LiveMeasurementResult.source]/`.reference`
  /// carry the wire's own `from.t`/`to.t` pin refs (`LiveSim.
  /// readWireMeasurement`, reusing the exact terminal identity every other
  /// part of this app already keys off), superseding the earlier
  /// node-level-only "ADAPTER REQUIRED" limitation for this path.
  ///
  /// **Key/switch-state is still correctly NOT a separate bridge concern**:
  /// V2's own live switch/key state is exactly what the solver being
  /// queried already reflects (that's the whole point of asking IT instead
  /// of the reachability engine) — there is nothing to additionally bridge.
  void _handleMeasurementRequested(V2MeasurementRequestedMessage message) {
    if (!_ready) return;
    unawaited(_runLiveMeasurement(message.v2WireId, message.mode));
  }

  Future<void> _runLiveMeasurement(String v2WireId, String v2Mode) async {
    try {
      final result = await channel.queryLiveMeasurement(v2WireId, v2Mode);
      if (result == null) {
        await channel.applyMeasurementResult(
          v2WireId,
          v2Mode,
          '—',
          '',
          'Live solver unreachable — the diagram may not be fully loaded.',
        );
        return;
      }
      final (display, unit, note) = _formatLiveMeasurementForV2(v2Mode, result);
      await channel.applyMeasurementResult(v2WireId, v2Mode, display, unit, note);
      onLiveMeasurement?.call(v2WireId, v2Mode, result);
    } catch (e) {
      await channel.applyMeasurementResult(
          v2WireId, v2Mode, '—', '', 'Measurement failed: $e');
    }
  }

  /// Translates [V2LiveMeasurementResult] semantics into V2's own display
  /// vocabulary — never a fabricated numeric substitute for an
  /// open/unreachable/unsupported reading (Phase 10/11 — "do not collapse
  /// open → 0, unknown → 0, unsupported → 0").
  ///
  ///  - `status == 'error'` (unknown wire, unsupported mode): `'—'` with
  ///    the solver's own note explaining why — never `'OL'` (that's
  ///    reserved for a genuine open-circuit reading, a different thing
  ///    from "this mode isn't supported here").
  ///  - Continuity: `open == false` → V2's own `'000'` (rendered as
  ///    `'· · ·'` by `updateMeter()`'s own display logic); `open == true`
  ///    → V2's own `'OPN'`.
  ///  - Voltage/resistance/diode: `open == true` → V2's own `'OL'`; a
  ///    non-null `value` displays with the solver's own formatting
  ///    precision (2 decimal places, matching V2's own `.toFixed(2)`
  ///    convention throughout `electrical-solver.js`).
  (String, String, String) _formatLiveMeasurementForV2(
      String v2Mode, V2LiveMeasurementResult result) {
    final note = result.note;
    if (result.status != 'ok') {
      return ('—', result.unit, note.isEmpty ? 'Measurement unavailable.' : note);
    }
    if (v2Mode == 'CONT') {
      return (result.open ? 'OPN' : '000', '', note);
    }
    if (result.open) {
      return ('OL', '', note.isEmpty ? 'Open circuit — no continuity.' : note);
    }
    final value = result.value;
    if (value == null) {
      return ('—', result.unit,
          note.isEmpty ? 'No numeric reading reported for this measurement.' : note);
    }
    return (value.toStringAsFixed(2), result.unit, note);
  }

  void _syncPositionToV2(String v2ModuleId, String nodeId) {
    final authoritative =
        controller.engine.editing.session.layout.positionOf(nodeId)!;
    channel.sendAuthoritativeModulePosition(
        v2ModuleId, authoritative.dx, authoritative.dy);
    onAuthoritativeResult?.call(
        v2ModuleId, nodeId, authoritative.dx, authoritative.dy);
  }

  void _syncLabelToV2(String v2ModuleId, String nodeId) {
    final node = controller.engine.editing.session.graph.nodes[nodeId]!;
    channel.sendAuthoritativeModuleLabel(v2ModuleId, node.displayName);
    onAuthoritativeLabel?.call(v2ModuleId, nodeId, node.displayName);
  }

  /// Re-synchronizes V2 to whichever OEP state is currently authoritative
  /// for whichever kind of bridged operation ([lastBridgedV2ModuleId] or
  /// [lastBridgedV2WireId]) actually happened most recently — the caller
  /// invokes this after `controller.commands.undo()` (or `redo()`), and
  /// [_lastBridgedKind] is what lets one "Undo" button correctly resync
  /// either a module or a wire without the caller needing to know which
  /// one the undo actually reverted.
  void resyncLastBridgedToV2() {
    switch (_lastBridgedKind) {
      case _BridgedKind.module:
        _resyncLastBridgedModule();
      case _BridgedKind.wire:
        _resyncLastBridgedWire();
      case null:
        return;
    }
  }

  /// Handles all three bridged module-mutation kinds uniformly:
  ///
  ///  - **Move/property undo**: the node still exists — its position and
  ///    label are re-sent to V2 (idempotent if V2 already matches).
  ///  - **Create undo**: the node no longer exists in the Engine graph —
  ///    V2 is told to remove the module it had (Phase 12/"create → undo →
  ///    V2 disappears").
  ///  - **Delete undo**: the node exists again — [LegacyV2Channel.restoreModule]
  ///    is called first (a no-op in V2 if the module is already present,
  ///    per the injected script's own guard), reconstructing it from the
  ///    `v2Category`/label metadata stashed at creation time, then
  ///    position/label are re-sent the same as any other case.
  void _resyncLastBridgedModule() {
    final v2Id = lastBridgedV2ModuleId;
    if (v2Id == null) return;
    final nodeId = _v2ToOepNodeId[v2Id];
    if (nodeId == null) return;
    final node = controller.engine.editing.session.graph.nodes[nodeId];
    if (node == null) {
      channel.removeModuleFromV2(v2Id);
      onModuleRemoved?.call(v2Id);
      return;
    }
    final position =
        controller.engine.editing.session.layout.positionOf(nodeId) ??
            const Point2D(50, 50);
    final category = node.metadata['v2Category'] as String? ?? '';
    channel.restoreModule(
        v2Id, node.displayName, category, position.dx, position.dy,
        notes: node.metadata['notes'] as String? ?? '',
        terminals: _terminalsForNode(node),
        exit: node.metadata['v2Exit'] as String? ?? '',
        connector: node.metadata['v2Connector'] as bool?,
        vertical: node.metadata['v2Vertical'] as bool?,
        labelPos: node.metadata['v2LabelPos'] as String?,
        pinLabelPos: node.metadata['v2PinLabelPos'] as String?,
        subLabelPos: node.metadata['v2SubLabelPos'] as String?,
        sub: node.metadata['v2Sub'] as String?,
        labelJustify: node.metadata['v2LabelJustify'] as String?,
        kind: node.metadata['v2Kind'] as String?,
        bulbStyle: node.metadata['v2BulbStyle'] as String?,
        bulbColor: node.metadata['v2BulbColor'] as String?,
        flipped: node.metadata['v2Flipped'] as bool?);
    _syncPositionToV2(v2Id, nodeId);
    _syncLabelToV2(v2Id, nodeId);
  }

  /// AP-DIAGRAM-V2-BRIDGE-004 — handles both bridged wire-mutation kinds
  /// uniformly, the same "restore-if-missing (idempotent), remove-if-
  /// gone" shape [_resyncLastBridgedModule] already uses:
  ///
  ///  - **Create undo**: the relationship no longer exists — V2 is told
  ///    to remove the wire it had.
  ///  - **Delete undo**: the relationship exists again —
  ///    [LegacyV2Channel.restoreWire] is called (a no-op in V2 if the
  ///    wire is already present, per the injected script's own guard),
  ///    reconstructed from the relationship's own current endpoints/
  ///    `label`/`wireColor` metadata, resolved back to V2 module ids via
  ///    [_reverseNodeLookup].
  void _resyncLastBridgedWire() {
    final v2Id = lastBridgedV2WireId;
    if (v2Id == null) return;
    final relationshipId = _v2ToOepRelationshipId[v2Id];
    if (relationshipId == null) return;
    final relationship =
        controller.engine.editing.session.graph.relationships[relationshipId];
    if (relationship == null) {
      channel.removeWireFromV2(v2Id);
      onWireRemoved?.call(v2Id);
      return;
    }
    final fromV2 = _reverseNodeLookup(relationship.sourceNode);
    final toV2 = _reverseNodeLookup(relationship.targetNode);
    if (fromV2 == null || toV2 == null) return;
    final label = relationship.metadata['label'] as String? ?? '';
    final color = relationship.metadata['wireColor'] as String? ?? '';
    // `restoreWire` no-ops in V2 if the wire is already present (its own
    // injected guard) — that covers delete-undo. A property-edit undo
    // leaves the wire present throughout, so `restoreWire` alone would
    // never push the restored label/color; `confirmWireCreated` (the
    // same call `_handleWirePropertiesChanged` uses) is what actually
    // applies to an existing wire.
    channel.restoreWire(
      v2Id,
      fromV2,
      toV2,
      label,
      color,
      fromTerminal: _v2TerminalRef(relationship, source: true),
      toTerminal: _v2TerminalRef(relationship, source: false),
    );
    channel.confirmWireCreated(v2Id, label, color);
    // AP-DIAGRAM-V2-BRIDGE-SAVE-001 — an Undo/Redo touching this
    // relationship may have reverted its route offsets too (they share
    // the same command stack as every other bridged wire mutation); push
    // whatever is now current back into V2's own `wireRoutes[id]`, same
    // "restore-if-missing, remove-if-gone" shape as label/color above.
    final offsets = controller.engine.editing.session.layout
            .wireSegmentOffsetsOf(relationshipId) ??
        const <int, double>{};
    channel.restoreWireRouteOffsets(v2Id,
        offsets.map((segIdx, offset) => MapEntry(segIdx.toString(), offset)));
    onWireBridged?.call(v2Id, relationshipId);
    onAuthoritativeWireProperties?.call(v2Id, relationshipId, label, color);
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 4/5/7 — seeds V2 from the OEP
  /// document that's authoritative *right now*, then flips [_ready].
  ///
  /// **Durable identity (Phase 5)**: rebuilds `_v2ToOepNodeId`/
  /// `_v2ToOepRelationshipId` by scanning the current graph for nodes/
  /// relationships carrying `metadata['v2ModuleId']`/`['v2WireId']` —
  /// metadata already round-trips through `EngineeringNode.toJson`/
  /// `EngineeringRelationship.toJson` (confirmed by reading both
  /// directly), which already round-trips through `DiagramDocument.save`/
  /// `open`. No Engine/Foundation schema change was needed: the existing
  /// metadata mechanism *is* the durable store; the in-memory maps here
  /// are a rebuildable index over it, not a second source of truth.
  ///
  /// **V2 initialization (Phase 4)**: only nodes/relationships that
  /// already carry this bridge's own stashed metadata can be represented
  /// in V2 at all — an arbitrary OEP node with no `v2ModuleId` (e.g. one
  /// created through the native renderer, or with an unbridged category)
  /// has no deterministic V2 module shape to construct (no category
  /// known to be V2-compatible, in the first place) and is silently
  /// left out of V2's view. This is a real, documented limitation (see
  /// the production architecture doc's "V2 initialization protocol"
  /// section), not a bug: fabricating a V2 category for a node OEP
  /// never got from V2 would be exactly the kind of invented mapping
  /// this bridge has refused everywhere else.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-008 — always clears V2's surfaces first,
  /// including on the very first call (WebView-ready, before any document
  /// switch). V2's own page load runs its hardcoded `Bootstrap.run`
  /// demo-vehicle script independently of whatever OEP document is
  /// actually active; without a clear here, a genuinely blank/new
  /// document left that demo vehicle on screen untouched (nothing ever
  /// told V2 to remove it, since the reseed loop below only ever *adds*
  /// nodes it recognizes) — so a brand-new document, or a fresh app
  /// launch with no document restored, looked identical to "the trx300
  /// demo is my diagram" even though the real OEP document underneath
  /// was empty. [reinitializeForDocument] already cleared for the
  /// document-switch case; this makes the initial seed symmetric with it
  /// rather than a silent special case.
  Future<void> initializeFromDocument() async {
    _ready = false;
    _v2ToOepNodeId.clear();
    _v2ToOepRelationshipId.clear();
    unbridgedV2ModuleIds.clear();
    unbridgedV2WireIds.clear();
    await channel.clearAllSurfaces();

    final graph = controller.engine.editing.session.graph;
    final layout = controller.engine.editing.session.layout;

    // Rebuild the node-id index and seed V2's MODULES/positions.
    for (final node in graph.nodes.values) {
      final v2Id = node.metadata['v2ModuleId'] as String?;
      if (v2Id == null) continue;
      _v2ToOepNodeId[v2Id] = node.id;
      final category = node.metadata['v2Category'] as String? ?? '';
      final position = layout.positionOf(node.id) ?? const Point2D(50, 50);
      await channel.restoreModule(
          v2Id, node.displayName, category, position.dx, position.dy,
          notes: node.metadata['notes'] as String? ?? '',
          terminals: _terminalsForNode(node),
          exit: node.metadata['v2Exit'] as String? ?? '',
          connector: node.metadata['v2Connector'] as bool?,
          vertical: node.metadata['v2Vertical'] as bool?,
          labelPos: node.metadata['v2LabelPos'] as String?,
          pinLabelPos: node.metadata['v2PinLabelPos'] as String?,
          subLabelPos: node.metadata['v2SubLabelPos'] as String?,
          sub: node.metadata['v2Sub'] as String?,
          labelJustify: node.metadata['v2LabelJustify'] as String?,
          kind: node.metadata['v2Kind'] as String?,
          bulbStyle: node.metadata['v2BulbStyle'] as String?,
          bulbColor: node.metadata['v2BulbColor'] as String?,
          flipped: node.metadata['v2Flipped'] as bool?);
    }

    // Rebuild the relationship-id index and seed V2's WIRES — only for
    // relationships whose *both* endpoints already have a known
    // v2ModuleId (§ class doc comment: never fabricate one).
    for (final relationship in graph.relationships.values) {
      final v2WireId = relationship.metadata['v2WireId'] as String?;
      if (v2WireId == null) continue;
      final fromV2 = _reverseNodeLookup(relationship.sourceNode);
      final toV2 = _reverseNodeLookup(relationship.targetNode);
      if (fromV2 == null || toV2 == null) continue;
      _v2ToOepRelationshipId[v2WireId] = relationship.id;
      await channel.restoreWire(
        v2WireId,
        fromV2,
        toV2,
        relationship.metadata['label'] as String? ?? '',
        relationship.metadata['wireColor'] as String? ?? '',
        fromTerminal: _v2TerminalRef(relationship, source: true),
        toTerminal: _v2TerminalRef(relationship, source: false),
        fromExit: relationship.metadata['v2FromExit'] as String? ?? '',
        toExit: relationship.metadata['v2ToExit'] as String? ?? '',
        cable: relationship.metadata['v2Cable'] as bool? ?? false,
      );
      // AP-DIAGRAM-V2-BRIDGE-SAVE-001 — reseed V2's own `wireRoutes[id]`
      // from whatever manual route offsets this relationship carries, so
      // a saved route edit survives close/reopen visually in V2, not just
      // in the OEP document.
      final offsets = layout.wireSegmentOffsetsOf(relationship.id);
      if (offsets != null && offsets.isNotEmpty) {
        await channel.restoreWireRouteOffsets(
            v2WireId,
            offsets
                .map((segIdx, offset) => MapEntry(segIdx.toString(), offset)));
      }
    }

    currentDocumentToken = controller.document.id;
    _ready = true;
  }

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 4/5 — V2's own "Save" button
  /// (`onclick="saveLayout()"`) is intercepted at the WebView boundary
  /// (`LegacyV2BridgeTransport`'s injected `__oepBridgeInterceptSave`
  /// reassigns the global `saveLayout` function once the bridge is
  /// ready — V2's own file is never modified) and turned into this
  /// message instead of V2's original file-download behavior. Uses only
  /// the existing `DiagramStudioController.saveDocument()` — no new
  /// save command. If the document has never been saved (`documentPath
  /// == null`), a full Save As flow (file picker) is not attempted from
  /// here — documented as DEFERRED in the persistence architecture doc;
  /// V2 is told why via [LegacyV2Channel.reportSaveResult] rather than
  /// silently doing nothing or falling back to V2's own file download.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — [flushBeforeSave] is awaited FIRST,
  /// so Save never depends on the 400ms poller having already caught up
  /// with a module drag or a route edit (see that method's own doc
  /// comment for the full rationale/mechanism).
  Future<void> _handleSaveRequested() async {
    if (!_ready) return;
    final path = controller.documentPath;
    if (path == null) {
      // AP-DIAGRAM-V2-BRIDGE-SAVE-005 — this message previously pointed
      // at a Legacy V2 toolbar "Save As…" button that no longer exists
      // (removed by AP-OEP-DIAGRAM-UX-002, which moved Save As to the
      // platform-wide Command Palette). Point at where the action
      // actually lives now instead of a dead UI reference.
      await channel.reportSaveResult(false,
          'Document has never been saved — open the Command Palette (Ctrl+K) and run "Save Diagram As" first.');
      return;
    }
    await flushBeforeSave();
    await controller.saveDocument();
    await channel.reportSaveResult(true, 'Saved "$path".');
  }

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the Save flush barrier. Takes ONE
  /// deterministic snapshot of V2's CURRENT module/wire/route state
  /// (`LegacyV2Channel.captureSaveSnapshot`, no polling, no stability
  /// window) and reconciles it into the Engine session before the caller
  /// proceeds to `saveDocument()`. This is what removes Save's dependency
  /// on the background poller: `saveDocument()` itself always writes
  /// whatever the current session is (verified by direct inspection of
  /// `EngineeringProjectNotifier.saveDocument`) — the only thing that was
  /// ever missing was a guarantee that the session reflects V2's true
  /// current state at the moment Save runs.
  ///
  /// Deliberately reuses the exact same handlers the live poller already
  /// drives — [_handleModuleCreated]/[_handleModuleDeleted]/
  /// [_handleModulePropertiesChanged]/[_handleV2ModuleMoved]/
  /// [_handleWireCreated]/[_handleWireDeleted]/
  /// [_handleWirePropertiesChanged] — by synthesizing the same message
  /// types from the snapshot, so there is exactly one mutation code path
  /// for each kind of change, live or flushed; both still go through
  /// `DiagramEditingHost`'s existing methods (`EditingService`/
  /// `StudioCommandActions`, unchanged) and therefore participate in the
  /// existing command stack, undo/redo, and dirty tracking automatically.
  /// Wire-route offsets have no live-poller equivalent at all (§ this
  /// task's own root-cause finding — V2's `wireRoutes` was never observed
  /// before this), so that reconciliation is new, driven directly by
  /// [DiagramEditingHost.setWireSegmentOffsets].
  Future<void> flushBeforeSave() async {
    if (!_ready) return;
    final snapshot = await channel.captureSaveSnapshot();
    if (snapshot == null || !_ready) return;

    // Modules: creations and deletions first (so the survivor loop below
    // always has an up-to-date `_v2ToOepNodeId`), then property/position
    // reconciliation for whatever now maps to a real OEP node.
    for (final entry in snapshot.modules.entries) {
      if (_v2ToOepNodeId.containsKey(entry.key) ||
          unbridgedV2ModuleIds.contains(entry.key)) {
        continue;
      }
      _handleModuleCreated(V2ModuleCreatedMessage(
        v2ModuleId: entry.key,
        label: entry.value.label,
        category: entry.value.category,
        x: entry.value.x,
        y: entry.value.y,
        terminals: entry.value.terminals,
        exit: entry.value.exit,
        connector: entry.value.connector,
        vertical: entry.value.vertical,
        labelPos: entry.value.labelPos,
        pinLabelPos: entry.value.pinLabelPos,
        subLabelPos: entry.value.subLabelPos,
        sub: entry.value.sub,
        labelJustify: entry.value.labelJustify,
        kind: entry.value.kind,
        bulbStyle: entry.value.bulbStyle,
        bulbColor: entry.value.bulbColor,
        flipped: entry.value.flipped,
      ));
    }
    for (final v2Id in _v2ToOepNodeId.keys.toList()) {
      if (!snapshot.modules.containsKey(v2Id)) {
        _handleModuleDeleted(V2ModuleDeletedMessage(v2ModuleId: v2Id));
      }
    }
    for (final entry in snapshot.modules.entries) {
      final nodeId = _v2ToOepNodeId[entry.key];
      if (nodeId == null) continue;
      if (controller.engine.editing.session.graph.nodes[nodeId] == null) {
        continue;
      }
      // AP-MODULE-KIND-002 — this used to synthesize only label/category/
      // notes, leaving every other field (terminals/exit/connector/
      // vertical/labelPos/pinLabelPos/subLabelPos/sub/labelJustify/kind)
      // at its default. `_handleModulePropertiesChanged` treats a default
      // empty string/null for most of those as "explicitly cleared" (the
      // same convention that lets the properties panel reset an override
      // back to Auto) — so pressing V2's own Save button erased an
      // already-bridged module's `v2Kind` (and `v2Sub`/`v2LabelJustify`/
      // etc.) metadata on EVERY save, before the file was ever written to
      // disk: a Battery/Starter Motor/Solenoid/Diode/Bulb/grounded-Switch/
      // Thermistor module rendered correctly live, then reverted to a
      // plain card on the very next reopen, because Save itself destroyed
      // the data. Passing the full snapshot entry (matching the
      // moduleCreated synthesis just above, for a not-yet-bridged module)
      // fixes this the same way for every one of these fields at once.
      _handleModulePropertiesChanged(V2ModulePropertiesChangedMessage(
        v2ModuleId: entry.key,
        label: entry.value.label,
        category: entry.value.category,
        notes: entry.value.notes,
        terminals: entry.value.terminals,
        exit: entry.value.exit,
        connector: entry.value.connector,
        vertical: entry.value.vertical,
        labelPos: entry.value.labelPos,
        pinLabelPos: entry.value.pinLabelPos,
        subLabelPos: entry.value.subLabelPos,
        sub: entry.value.sub,
        labelJustify: entry.value.labelJustify,
        kind: entry.value.kind,
        bulbStyle: entry.value.bulbStyle,
        bulbColor: entry.value.bulbColor,
        flipped: entry.value.flipped,
      ));
      final currentPosition =
          controller.engine.editing.session.layout.positionOf(nodeId);
      if (currentPosition == null ||
          currentPosition.dx != entry.value.x ||
          currentPosition.dy != entry.value.y) {
        _handleV2ModuleMoved(V2ModuleMovedMessage(
            v2ModuleId: entry.key, x: entry.value.x, y: entry.value.y));
      }
    }

    // Wires: creations and deletions first, then property/route
    // reconciliation for survivors.
    for (final entry in snapshot.wires.entries) {
      if (_v2ToOepRelationshipId.containsKey(entry.key) ||
          unbridgedV2WireIds.contains(entry.key)) {
        continue;
      }
      _handleWireCreated(V2WireCreatedMessage(
        v2WireId: entry.key,
        fromModuleId: entry.value.fromModuleId,
        fromTerminal: entry.value.fromTerminal,
        toModuleId: entry.value.toModuleId,
        toTerminal: entry.value.toTerminal,
        label: entry.value.label,
        color: entry.value.color,
        fromExit: entry.value.fromExit,
        toExit: entry.value.toExit,
        cable: entry.value.cable,
      ));
    }
    for (final v2Id in _v2ToOepRelationshipId.keys.toList()) {
      if (!snapshot.wires.containsKey(v2Id)) {
        _handleWireDeleted(V2WireDeletedMessage(v2WireId: v2Id));
      }
    }
    for (final entry in snapshot.wires.entries) {
      final relationshipId = _v2ToOepRelationshipId[entry.key];
      if (relationshipId == null) continue;
      final relationship =
          controller.engine.editing.session.graph.relationships[relationshipId];
      if (relationship == null) continue;
      final currentFromExit =
          relationship.metadata['v2FromExit'] as String? ?? '';
      final currentToExit = relationship.metadata['v2ToExit'] as String? ?? '';
      final currentCable = relationship.metadata['v2Cable'] as bool? ?? false;
      if (relationship.metadata['label'] != entry.value.label ||
          relationship.metadata['wireColor'] != entry.value.color ||
          currentFromExit != entry.value.fromExit ||
          currentToExit != entry.value.toExit ||
          currentCable != entry.value.cable) {
        _handleWirePropertiesChanged(V2WirePropertiesChangedMessage(
          v2WireId: entry.key,
          label: entry.value.label,
          color: entry.value.color,
          fromExit: entry.value.fromExit,
          toExit: entry.value.toExit,
          cable: entry.value.cable,
        ));
      }
      final currentOffsets = controller.engine.editing.session.layout
          .wireSegmentOffsetsOf(relationshipId);
      final snapshotOffsets = snapshot.wireRoutes[entry.key];
      if (!_wireOffsetsEqual(currentOffsets, snapshotOffsets)) {
        controller.setWireSegmentOffsets(
            relationshipId,
            (snapshotOffsets != null && snapshotOffsets.isNotEmpty)
                ? snapshotOffsets
                : null);
        lastBridgedV2WireId = entry.key;
        _lastBridgedKind = _BridgedKind.wire;
      }
    }
  }

  static bool _wireOffsetsEqual(Map<int, double>? a, Map<int, double>? b) {
    final left = a ?? const <int, double>{};
    final right = b ?? const <int, double>{};
    if (left.length != right.length) return false;
    for (final e in left.entries) {
      if (right[e.key] != e.value) return false;
    }
    return true;
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — the active OEP document changed.
  /// Clears whatever V2 was showing (so document A's modules/wires cannot
  /// linger and be mutated under document B's identity map — the exact
  /// "no cross-document identity leakage" requirement), then
  /// reinitializes from the (now current) document. `_ready` is `false`
  /// for the whole duration, so any message V2 fires while it's still
  /// holding the old document's content (before the clear takes effect)
  /// is dropped by the same gate every handler already checks.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-008 — the actual clear now happens inside
  /// [initializeFromDocument] itself (it always clears first, § that
  /// method's own doc comment), so this only resets the undo-resync
  /// bookkeeping that's specific to a genuine document switch, not a
  /// first-ever load.
  Future<void> reinitializeForDocument() async {
    lastBridgedV2ModuleId = null;
    lastBridgedV2WireId = null;
    _lastBridgedKind = null;
    await initializeFromDocument();
  }

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-006 — Save As assigning a document its
  /// first path is NOT a document switch: it is the exact same document
  /// (same `document.id`, same content — [flushBeforeSave] already
  /// reconciled V2's current state into the OEP graph moments earlier,
  /// as part of the same save), only now with a path attached.
  /// [reinitializeForDocument] was being reused for this case (the
  /// `documentPath` null→non-null listener in `legacy_v2_webview.dart`)
  /// under the theory that "reseed after Save As" was harmless — but
  /// [reinitializeForDocument] is built for genuine document switching:
  /// `clearAllSurfaces()` wipes V2's *entire* MODULES/WIRES arrays, and
  /// [initializeFromDocument]'s reseed loop only restores nodes/
  /// relationships that already carry this bridge's own `v2ModuleId`/
  /// `v2WireId` metadata (§ that method's own doc comment — "an
  /// arbitrary OEP node with no v2ModuleId... is silently left out of
  /// V2's view"). Any V2 content that only ever existed via V2's own
  /// independent bootstrap and was never individually touched (so never
  /// went through a live-poller create event, and — before the flush
  /// barrier existed — was never captured any other way either) has no
  /// `v2ModuleId`-bearing OEP node, so a full clear+reseed here silently
  /// dropped it. This is what a first "Save" on a large, V2-bootstrap-
  /// heavy diagram looked like from the user's side: "the diagram is
  /// mostly gone" immediately after Save As.
  ///
  /// The correct operation for "the document I already had open just
  /// got a path" is: don't touch V2's display at all — its content
  /// didn't change — only update the token this class exposes for
  /// display/test purposes (see [currentDocumentToken]'s own doc
  /// comment: nothing else branches on it).
  void acknowledgeSaveAs() {
    currentDocumentToken = controller.document.id;
  }

  /// AP-DIAGRAM-V2-BRIDGE-PORT-SUFFIX-001 — the terminal ref V2's own
  /// `restoreWire` needs to find the correct dot (a connector-type module
  /// renders TWO dots per logical pin, `"<pin>_IN"`/`"<pin>_OUT"`).
  /// `normalizeV2RelationshipPortReferences` (`v2_terminal_port_bridge
  /// .dart`) strips that suffix from `sourcePort`/`targetPort` for the
  /// solver's own `Port.id`-shaped matching, stashing the original,
  /// un-normalized reference under `v2RawSourcePort`/`v2RawTargetPort`
  /// only when it actually changed something — so this prefers the raw
  /// key when present (a normalized document) and falls back to the
  /// plain key otherwise (a freshly-created wire this session, whose
  /// metadata was never run through normalization at all, or an
  /// already-bare reference normalization left untouched).
  static String _v2TerminalRef(EngineeringRelationship relationship, {required bool source}) {
    final raw = source
        ? relationship.metadata['v2RawSourcePort'] as String?
        : relationship.metadata['v2RawTargetPort'] as String?;
    if (raw != null) return raw;
    return (source
            ? relationship.metadata['sourcePort']
            : relationship.metadata['targetPort']) as String? ??
        '';
  }

  String? _reverseNodeLookup(String oepNodeId) {
    for (final entry in _v2ToOepNodeId.entries) {
      if (entry.value == oepNodeId) return entry.key;
    }
    return null;
  }
}

/// PRODUCT-READINESS-008 — the live [LegacyV2StateAdapter] for a given
/// Diagram instance, published once the WebView page that owns it
/// constructs it (`LegacyV2WebViewPage._ensureAdapter`), so a SIBLING
/// widget (the DMM instrument panel, mounted alongside the WebView, never
/// inside it) can reach the SAME adapter instance without the WebView
/// page needing to know the DMM exists at all. `null` before the WebView
/// has initialized (or on a platform/route with no WebView mounted) —
/// every consumer must treat that as "no live V2 state yet," never as an
/// error.
final legacyV2AdapterFamily = StateProvider.family<LegacyV2StateAdapter?, String>((ref, instanceId) => null);

/// PRODUCT-READINESS-008 §10/§14 — the live, translated
/// [ElectricalOperatingContext] for a given Diagram instance, updated
/// every time [LegacyV2StateAdapter.onOperatingStateChanged] fires. A
/// separate, directly-watchable provider (rather than requiring every
/// consumer to re-derive it from [legacyV2AdapterFamily] itself) so a DMM
/// panel's `ref.watch`/`ref.listen` naturally rebuilds/re-measures on a
/// real V2 switch-state change, exactly like any other reactive Riverpod
/// state in this app.
final legacyV2OperatingContextFamily =
    StateProvider.family<ElectricalOperatingContext, String>((ref, instanceId) => ElectricalOperatingContext.none);
