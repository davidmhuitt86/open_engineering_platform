import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';

import '../controller/diagram_studio_controller.dart';
import '../simulation/diagram_simulation_service.dart';
import 'legacy_v2_bridge_transport.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001/002 — the adaptation layer of the OEP↔Legacy
/// V2 bridge. Knows both V2 concepts (a module id, a category string, an
/// x/y pair) and OEP diagram concepts (`EngineeringNode`, `Point2D`), and
/// translates between them. Never touches `engine.editing.execute` or
/// any Engine internal directly — every mutation goes through the
/// existing [DiagramStudioController] methods (`addNodeWithMetadata`/
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
/// **Category → symbol mapping (AP-DIAGRAM-V2-WEBVIEW-002)**: V2's 11
/// module categories (`power`/`ignition`/`charging`/`lighting`/`starter`/
/// `switch`/`control`/`indicator`/`accessory`/`ground`/`connector`, from
/// `index.html`'s own category `<select>` options) were checked against
/// OEP's actual registered symbols
/// (`platform/oep_engine/assets/symbols/*.json`). Only two are a genuine,
/// name-identical, non-fabricated match: `ground` → `ground.json` and
/// `connector` → `connector.json`. The other 9 have no symbol whose
/// identity is deterministically implied by the category string alone
/// (e.g. `ignition` could plausibly mean `ignition_coil`, but could just
/// as easily be a CDI unit, a spark plug, or something with no existing
/// symbol at all — guessing is exactly the fabrication this task
/// prohibits). [_symbolIdForCategory] therefore returns `null` for those
/// 9, and [_handleModuleCreated] does not create an OEP node for them —
/// see the architecture doc's §6/§15 for the full account. The earlier
/// `'battery'` placeholder from AP-DIAGRAM-V2-WEBVIEW-001 (used for
/// *every* module regardless of category) has been retired, per this
/// task's explicit instruction that it "MUST NOT silently become the
/// permanent architecture."
enum _BridgedKind { module, wire }

class LegacyV2StateAdapter {
  LegacyV2StateAdapter({required this.controller, required this.channel, this.simulationServiceResolver}) {
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
    channel.onSaveRequested = _handleSaveRequested;
  }

  final DiagramStudioController controller;

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

  String? oepRelationshipIdFor(String v2WireId) => _v2ToOepRelationshipId[v2WireId];

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
  void Function(String v2ModuleId, String oepNodeId, double x, double y)? onAuthoritativeResult;

  /// Fired after a successful property edit/undo-resync with the
  /// authoritative `(v2ModuleId, oepNodeId, label)` — display-only.
  void Function(String v2ModuleId, String oepNodeId, String label)? onAuthoritativeLabel;

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
  void Function(String v2WireId, String relationshipId, String label, String color)? onAuthoritativeWireProperties;

  String? oepNodeIdFor(String v2ModuleId) => _v2ToOepNodeId[v2ModuleId];

  /// Deterministic V2 category → OEP symbolId lookup — see class doc
  /// comment for why only these two entries exist.
  static String? _symbolIdForCategory(String category) => const {
        'ground': 'ground',
        'connector': 'connector',
      }[category];

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
  /// `addNodeWithMetadata` (itself an existing `CreateNodeCommand` call)
  /// only when [message.category] has a deterministic symbol mapping;
  /// otherwise records the module as unbridged and leaves it as a
  /// V2-only, non-authoritative object (documented, not silently
  /// papered over).
  void _handleModuleCreated(V2ModuleCreatedMessage message) {
    if (!_ready) return;
    if (_v2ToOepNodeId.containsKey(message.v2ModuleId)) return;
    final symbolId = _symbolIdForCategory(message.category);
    if (symbolId == null) {
      unbridgedV2ModuleIds.add(message.v2ModuleId);
      return;
    }
    final position = Point2D(message.x, message.y);
    final before = controller.engine.editing.session.graph.nodes.keys.toSet();
    controller.addNodeWithMetadata(
      symbolId,
      position,
      displayName: message.label,
      metadata: {'v2ModuleId': message.v2ModuleId, 'v2Category': message.category},
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
  void _handleModulePropertiesChanged(V2ModulePropertiesChangedMessage message) {
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
      controller.updateNodeMetadata(nodeId, {'notes': message.notes.isEmpty ? null : message.notes});
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
    final before = controller.engine.editing.session.graph.relationships.keys.toSet();
    controller.createRelationship(sourceNodeId, targetNodeId);
    final after = controller.engine.editing.session.graph.relationships.keys.toSet();
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
    });
    _v2ToOepRelationshipId[message.v2WireId] = relationshipId;
    lastBridgedV2WireId = message.v2WireId;
    _lastBridgedKind = _BridgedKind.wire;

    // Phase 7 — read back what the Engine actually stored, not what was
    // requested, before confirming to V2.
    final relationship = controller.engine.editing.session.graph.relationships[relationshipId]!;
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
    final current = controller.engine.editing.session.graph.relationships[relationshipId];
    if (current == null) return;
    if (current.metadata['label'] == message.label && current.metadata['wireColor'] == message.color) {
      return;
    }
    controller.updateRelationshipMetadata(relationshipId, {
      'label': message.label,
      'wireColor': message.color,
    });
    lastBridgedV2WireId = message.v2WireId;
    _lastBridgedKind = _BridgedKind.wire;

    // Phase 7 — read back what the Engine actually stored, not what was
    // requested, before confirming to V2. Reuses `confirmWireCreated`
    // (identical `(v2WireId, label, color)` shape) rather than a second
    // outbound method.
    final authoritative = controller.engine.editing.session.graph.relationships[relationshipId]!;
    final label = authoritative.metadata['label'] as String? ?? '';
    final color = authoritative.metadata['wireColor'] as String? ?? '';
    channel.confirmWireCreated(message.v2WireId, label, color);
    onAuthoritativeWireProperties?.call(message.v2WireId, relationshipId, label, color);
  }

  /// AP-DIAGRAM-V2-BRIDGE-006 — V2's own `updateMeter()` (`meter-panel.js`)
  /// is a synchronous local lookup into the selected wire's authored
  /// `R[keyPos]` table; it does not know about OEP's simulation subsystem
  /// at all. This redirects the reading to the real
  /// `SimulationEngine.measure` (via [DiagramSimulationService]) and
  /// pushes the authoritative result back over V2's own local one —
  /// V2's local computed value still displays first (its own
  /// `updateMeter()` already ran synchronously before this message even
  /// left the WebView), then is overwritten once the async round trip
  /// completes (§9/§11 of the simulation bridge doc: OEP is authoritative,
  /// V2's static table is never allowed to be the last word).
  ///
  /// **Probe mapping** (§4 of the task, §3 of the doc): V2's multimeter
  /// reading depends only on *which wire is selected*, not on
  /// `leadR`/`leadB` (confirmed by reading `updateMeter()` directly — those
  /// fields are cosmetic location labels, never read by the lookup). There
  /// is therefore no terminal-precise "point A/point B" to bridge at all —
  /// this measures across the bridged relationship's own two node
  /// endpoints, the same node-level (not terminal-level) precision the
  /// wire-creation bridge already established and documented as
  /// **ADAPTER REQUIRED** (§3/§14 of the wire bridge doc). No port id is
  /// fabricated; `ProbePoint.portId` is left `null`.
  ///
  /// **Key-state is intentionally NOT bridged** — see §5/§21 of the
  /// simulation bridge doc for why V2's fixed 4-position `keyPos` has no
  /// deterministic mapping to OEP's open-ended, document-authored
  /// `OperatingStateDefinition` set. V2's key buttons keep controlling only
  /// V2's own cosmetic bulb-glow display; the measurement itself reflects
  /// whatever operating/input state is already active in OEP's own current
  /// session (set through OEP's own Simulation Center controls, unchanged).
  void _handleMeasurementRequested(V2MeasurementRequestedMessage message) {
    if (!_ready) return;
    final relationshipId = _v2ToOepRelationshipId[message.v2WireId];
    if (relationshipId == null) return;
    final type = _measurementTypeForV2Mode(message.mode);
    if (type == null) return;
    final simulation = simulationServiceResolver?.call();
    if (simulation == null || !simulation.hasSession) {
      channel.applyMeasurementResult(
        message.v2WireId,
        message.mode,
        '—',
        '',
        'No active OEP simulation session — start one from the Simulation Center.',
      );
      return;
    }
    final relationship = controller.engine.editing.session.graph.relationships[relationshipId];
    if (relationship == null) return;
    final probeA = ProbePoint(nodeId: relationship.sourceNode, relationshipId: relationshipId);
    final probeB = ProbePoint(nodeId: relationship.targetNode, relationshipId: relationshipId);
    unawaited(_runMeasurement(simulation, message.v2WireId, message.mode, type, probeA, probeB));
  }

  Future<void> _runMeasurement(
    DiagramSimulationService simulation,
    String v2WireId,
    String v2Mode,
    MeasurementType type,
    ProbePoint probeA,
    ProbePoint probeB,
  ) async {
    try {
      final result = await simulation.measure(probeA: probeA, probeB: probeB, type: type);
      final (display, unit, note) = _formatMeasurementForV2(v2Mode, result);
      await channel.applyMeasurementResult(v2WireId, v2Mode, display, unit, note);
    } catch (e) {
      await channel.applyMeasurementResult(v2WireId, v2Mode, '—', '', 'Measurement failed: $e');
    }
  }

  /// V2's 5 meter-mode codes verbatim (`meter-panel.js`'s `ML`/`MU` maps)
  /// → OEP's [MeasurementType]. V2 has no current/amps mode — confirmed
  /// by direct source read, not an oversight here.
  static MeasurementType? _measurementTypeForV2Mode(String v2Mode) => const {
        'VDC': MeasurementType.voltageDc,
        'VAC': MeasurementType.voltageAc,
        'RES': MeasurementType.resistance,
        'CONT': MeasurementType.continuity,
        'DIODE': MeasurementType.diode,
      }[v2Mode];

  /// Translates [MeasurementResult] semantics into V2's own display
  /// vocabulary — a plain formatted number, or one of V2's existing
  /// sentinel strings (`'OPN'`/`'OL'`), never a fabricated numeric
  /// substitute for an unreachable/unavailable/errored reading (§8/§11 of
  /// the simulation bridge doc — "do not silently display 0").
  ///
  ///  - **Continuity/diode** (`result.continuous` is the authoritative
  ///    signal OEP provides for these two types): `true` → V2's own
  ///    `'000'` code (which `updateMeter()`'s own display logic already
  ///    renders as `'· · ·'`); `false`/unreachable → V2's own `'OPN'`.
  ///  - **Voltage/resistance**: unreachable → V2's own `'OL'` (matches the
  ///    convention V2's authored table already uses for resistance-mode
  ///    open circuits; extended here to voltage modes for the same
  ///    "cannot complete the measurement" reason — not a value OEP ever
  ///    invented, since `reachable: false` is exactly what triggers it).
  ///  - A reachable result with no `measuredValue` (a legitimate
  ///    "this type has no numeric reading" case per [MeasurementResult]'s
  ///    own doc comment) displays `'—'` (em dash) with the engine's own
  ///    `notes` explaining why, rather than `0.00`.
  (String, String, String) _formatMeasurementForV2(String v2Mode, MeasurementResult result) {
    final notes = result.notes ?? '';
    if (v2Mode == 'CONT' || (v2Mode == 'DIODE' && result.continuous != null)) {
      final isContinuous = result.reachable && (result.continuous ?? false);
      return (isContinuous ? '000' : 'OPN', '', notes);
    }
    if (!result.reachable) {
      return ('OL', '', notes.isEmpty ? 'Unreachable under the current simulation state.' : notes);
    }
    final value = result.measuredValue;
    if (value == null) {
      return ('—', result.unit, notes.isEmpty ? 'No numeric reading reported for this measurement.' : notes);
    }
    return (value.toStringAsFixed(2), result.unit, notes);
  }

  void _syncPositionToV2(String v2ModuleId, String nodeId) {
    final authoritative = controller.engine.editing.session.layout.positionOf(nodeId)!;
    channel.sendAuthoritativeModulePosition(v2ModuleId, authoritative.dx, authoritative.dy);
    onAuthoritativeResult?.call(v2ModuleId, nodeId, authoritative.dx, authoritative.dy);
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
    final position = controller.engine.editing.session.layout.positionOf(nodeId) ?? const Point2D(50, 50);
    final category = node.metadata['v2Category'] as String? ?? '';
    channel.restoreModule(v2Id, node.displayName, category, position.dx, position.dy, notes: node.metadata['notes'] as String? ?? '');
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
    final relationship = controller.engine.editing.session.graph.relationships[relationshipId];
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
      fromTerminal: relationship.metadata['sourcePort'] as String? ?? '',
      toTerminal: relationship.metadata['targetPort'] as String? ?? '',
    );
    channel.confirmWireCreated(v2Id, label, color);
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
  Future<void> initializeFromDocument() async {
    _ready = false;
    _v2ToOepNodeId.clear();
    _v2ToOepRelationshipId.clear();
    unbridgedV2ModuleIds.clear();
    unbridgedV2WireIds.clear();

    final graph = controller.engine.editing.session.graph;
    final layout = controller.engine.editing.session.layout;

    // Rebuild the node-id index and seed V2's MODULES/positions.
    for (final node in graph.nodes.values) {
      final v2Id = node.metadata['v2ModuleId'] as String?;
      if (v2Id == null) continue;
      _v2ToOepNodeId[v2Id] = node.id;
      final category = node.metadata['v2Category'] as String? ?? '';
      final position = layout.positionOf(node.id) ?? const Point2D(50, 50);
      await channel.restoreModule(v2Id, node.displayName, category, position.dx, position.dy, notes: node.metadata['notes'] as String? ?? '');
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
        fromTerminal: relationship.metadata['sourcePort'] as String? ?? '',
        toTerminal: relationship.metadata['targetPort'] as String? ?? '',
      );
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
  Future<void> _handleSaveRequested() async {
    if (!_ready) return;
    final path = controller.documentPath;
    if (path == null) {
      await channel.reportSaveResult(false, 'Document has never been saved — use the "Save As…" button in the Legacy V2 toolbar first.');
      return;
    }
    await controller.saveDocument();
    await channel.reportSaveResult(true, 'Saved "$path".');
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — the active OEP document changed
  /// (or is being loaded for the first time). Clears whatever V2 was
  /// showing (so document A's modules/wires cannot linger and be
  /// mutated under document B's identity map — the exact "no
  /// cross-document identity leakage" requirement), then reinitializes
  /// from the (now current) document. `_ready` is `false` for the whole
  /// duration, so any message V2 fires while it's still holding the old
  /// document's content (before the clear takes effect) is dropped by
  /// the same gate every handler already checks.
  Future<void> reinitializeForDocument() async {
    _ready = false;
    lastBridgedV2ModuleId = null;
    lastBridgedV2WireId = null;
    _lastBridgedKind = null;
    await channel.clearAllSurfaces();
    await initializeFromDocument();
  }

  String? _reverseNodeLookup(String oepNodeId) {
    for (final entry in _v2ToOepNodeId.entries) {
      if (entry.value == oepNodeId) return entry.key;
    }
    return null;
  }
}
