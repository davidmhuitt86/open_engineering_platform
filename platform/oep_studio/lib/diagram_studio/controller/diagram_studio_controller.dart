import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/context/engineering_interaction_context.dart';
import '../../core/models/engineering_inspectable.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../commands/studio_command_actions.dart';
import '../host/diagram_document.dart';
import '../intelligence/diagram_intelligence_service.dart';
import '../persistence/diagram_workspace_state.dart';
import '../persistence/workspace_state_storage.dart';
import '../tabs/diagram_tab.dart';
import '../tabs/diagram_tabs_controller.dart';
import '../webview/diagram_editing_host.dart';

/// The Diagram Studio Controller / Adapter (WAVE 1, AP-DIAGRAM-W1) — the
/// execution gateway for Diagram Studio's own interactive editing.
/// **Scope, stated precisely (AP-DIAGRAM-W1-R1):** all Diagram Studio
/// presentation-layer editing operations must pass through this
/// controller; it is not, and is not intended to be, the only caller of
/// `engine.editing.execute` in the entire OEP application. Every
/// `engine.editing.execute` call for interactive diagram editing (node/
/// wire/annotation/layer/placement commands, plus undo/redo/clipboard via
/// the composed [StudioCommandActions]) is issued from here, never from a
/// widget or `State` in `diagram_studio/workspaces/` directly — see
/// `docs/DIAGRAM_STUDIO_V2_RECONSTRUCTION_SPEC.md` §3.5.
///
/// **Out of scope, by design:** the global, cross-studio Contextual
/// Command System (`core/context/contextual_command_definitions.dart`,
/// resolved via `ContextualCommandResolver`) executes its own Engine
/// commands directly and independently of this controller. It predates
/// this Wave, serves every Studio (not just Diagram Studio), and is
/// reached from `diagram_studio_page.dart` only through
/// `context_menu/diagram_context_menu.dart`'s existing hand-off — this
/// controller's `markDirty()` is still the one thing the page calls
/// afterward to fold that system's side effects into Diagram Studio's own
/// dirty/Intelligence-sync pathway (see [markDirty]'s own doc comment).
/// Moving the Contextual Command System's execution into this controller
/// would conflate a Diagram-Studio-local concern with shared platform
/// infrastructure and is explicitly not part of this extraction.
///
/// This started as a WAVE 1 architectural extraction (editing command
/// execution + centralized dirty/Intelligence-sync) and was extended in
/// WAVE 2 (AP-DIAGRAM-W2) to also own bootstrap sequencing, document
/// lifecycle, tab lifecycle, and workspace-persistence orchestration —
/// see `docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` for the full
/// per-responsibility classification. Every method below is a verbatim
/// move of an existing `_DiagramStudioPageState` method body (same
/// commands, same arguments, same ordering, same side effects, same
/// guards) — none of this changes observable UI behavior. Genuinely
/// Flutter-owned or `BuildContext`-dependent state (drag deltas, spawn
/// counters, resize-preview geometry, wire-edit working-point buffers,
/// alignment guides, panel visibility/width fields, confirmation
/// dialogs, `TransformationController`) stays in the page; only the
/// points where the page previously called `engine.editing.execute`/
/// `resetSession`, or sequenced multiple provider calls together as one
/// application-level operation, move here, taking already-resolved
/// values as parameters. See spec §3.2–§3.7 for the governing boundary
/// contract ("DiagramScene in, Engine Commands out").
///
/// [StudioCommandActions] (undo/redo/clipboard) is composed, not
/// duplicated — it was already exactly this same kind of UI-agnostic,
/// Engine-facing facade (no Flutter import) before this Wave, so this
/// controller reuses its four operations instead of re-implementing them.
/// It is reachable from Diagram Studio only via this controller's
/// [commands] field — nothing in `diagram_studio/workspaces/` constructs
/// or calls a `StudioCommandActions` of its own.
///
/// **Three distinct lifetimes (WAVE 2 STAGE C, AP-DIAGRAM-W2-C):** this
/// class, the documents/tabs it orchestrates, and the widget that
/// displays them do not share a lifetime, and Stage C's whole purpose is
/// making sure the code never accidentally couples them:
///
///   A. **Application/Studio session** — this controller itself (via
///      `controller/diagram_studio_controller_provider.dart`, Stage A)
///      and the `EngineHost`/`EngineeringEngine` it wraps
///      (`engineeringProjectServiceProvider`, WORK_PACKAGE_025). Both are
///      constructed once and live for the app session.
///   B. **Document/tab** — a `DiagramDocument` (owned by
///      `EngineeringProjectNotifier`, via [newDocument]/[openDocument]/
///      [saveDocument]/[saveDocumentAs]/[closeDocument]) and a
///      `DiagramTab` (owned by `DiagramTabsNotifier`, via [closeTab]/
///      [activateTab]/[reopenRecentlyClosed]/[togglePin]/[setTabMode]).
///      Every method in this lifetime is invoked from exactly one place:
///      a `DiagramStudioPage` handler wired to an explicit user action
///      (a menu item, a tab click, a keyboard shortcut) — never from
///      `initState`/`build`/a rebuild. The one exception is [bootstrap]'s
///      own seed-tab fallback, and [bootstrap] itself belongs to lifetime
///      A, not C: it is the provider's `build()`, which Riverpod runs
///      exactly once per app session regardless of how many times the
///      widget that reads it mounts.
///   C. **Flutter widget mount** — `DiagramStudioPage`'s own `State`:
///      loading flag, panel visibility/width fields, and every
///      interaction-state field enumerated in this class's own method
///      docs below, none of which this controller touches.
///
///   Because B's operations are only ever user-triggered and A's
///   bootstrap only ever runs once, mounting/unmounting/remounting C
///   (lifetime the page's `State` goes through on every navigation)
///   cannot recreate a document, cannot recreate a tab, and cannot
///   re-invoke `engine.editing.resetSession`/`beginEditingSession` — see
///   `test/diagram_studio/controller/diagram_studio_document_tab_lifecycle_test.dart`
///   for the regression coverage proving this against the real engine
///   and tab providers, not just by inspection.
class DiagramStudioController implements DiagramEditingHost {
  DiagramStudioController({required this.engine, required Ref ref})
      : _ref = ref,
        commands = StudioCommandActions(engine);

  @override
  final EngineeringEngine engine;

  /// AP-DIAGRAM-W2-A: typed as the Riverpod-generic [Ref] rather than
  /// Flutter's [WidgetRef] so this controller can be constructed from
  /// inside a `Notifier.build()` (see
  /// `controller/diagram_studio_controller_provider.dart`) as well as
  /// from a widget's own `WidgetRef` — `WidgetRef` does not itself
  /// extend `Ref`, so it cannot be passed where a `Ref` is required, but
  /// every call site below only ever uses `.read(...)`, which both
  /// interfaces expose identically. This controller never calls
  /// `.watch(...)`/`.listen(...)`, so nothing here depends on which one
  /// it actually is at the call site.
  final Ref _ref;

  /// Composed, not duplicated — see class doc comment.
  @override
  final StudioCommandActions commands;

  bool get canUndo => commands.canUndo;
  bool get canRedo => commands.canRedo;
  bool get hasClipboardContent => commands.hasClipboardContent;

  /// Set once per open document by the page, immediately after
  /// `DiagramIntelligenceService` is constructed (bridge-dependent, per
  /// that class's own doc comment) — `null` until then, mirroring the
  /// page's own existing tolerate-a-not-yet-started-bridge convention.
  /// Lifecycle (construction/disposal) remains page-owned; this is a
  /// reference only.
  DiagramIntelligenceService? intelligence;

  EngineeringProjectState get _projectState => _ref.read(engineeringProjectServiceProvider);
  GraphSelection get selection => _projectState.selection;
  EditingSession? get session => _projectState.session;
  ViewState get viewState => _projectState.viewState;
  @override
  DiagramDocument get document => _projectState.document;
  DiagramDocument get _document => document;

  @override
  String? get documentPath => document.path;
  bool get isDirty => document.isDirty;

  ViewStateService get _viewStateService => engine.registry.viewState as ViewStateService;

  String? get activeTabId => _ref.read(diagramTabsProvider).activeTabId;
  bool isActiveTab(String id) => activeTabId == id;

  // --- Centralized dirty-state + Intelligence sync (WAVE 1 Step 4) --------
  //
  // The single authoritative pathway: command execution -> document dirty
  // marking -> debounced Intelligence synchronization. Every mutating
  // method below calls this exactly once, at the same point in its own
  // body the page's former `_markDirty()` call previously sat — this is a
  // verbatim move of the page's former `_markDirty()`/
  // `_scheduleIntelligenceSync()` pair (WAVE 1: no change to when the
  // document is considered dirty).

  void markDirty() {
    _ref.read(engineeringProjectServiceProvider.notifier).markDocumentDirty();
    _scheduleIntelligenceSync();
  }

  void _scheduleIntelligenceSync() {
    final currentIntelligence = intelligence;
    final currentSession = session;
    if (currentIntelligence == null || currentSession == null) return;
    currentIntelligence.scheduleSync(
      title: _document.path ?? 'Untitled Diagram',
      graph: currentSession.graph,
      layout: currentSession.layout,
    );
  }

  // --- Undo / redo / clipboard (delegates to StudioCommandActions) --------

  void undo() {
    commands.undo();
    markDirty();
  }

  void redo() {
    commands.redo();
    markDirty();
  }

  // AP-DS-001A: OS-level clipboard support, moved verbatim from the page's
  // former `_copy`/`_cut`/`_paste` — the in-process `ClipboardProvider`
  // stays the fast/primary path; `Clipboard.setData`/`getData` is a
  // fallback/cross-instance path only (see `StudioCommandActions`'s own
  // doc comment on this design).
  void copy() {
    commands.copy(session!, selection);
    final entry = engine.clipboard.provider.content;
    if (entry != null && !entry.isEmpty) {
      unawaited(Clipboard.setData(ClipboardData(text: ClipboardCodec.encode(entry))));
    }
  }

  void cut() {
    copy();
    commands.cut(session!, selection);
    markDirty();
  }

  Future<void> paste() async {
    if (!commands.hasClipboardContent) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      final entry = text == null ? null : ClipboardCodec.decode(text);
      if (entry != null && !entry.isEmpty) {
        engine.clipboard.provider.write(entry);
      }
    }
    commands.paste();
    markDirty();
  }

  void duplicateSelection() {
    commands.duplicate(selection);
    markDirty();
  }

  void deleteSelection() {
    commands.delete(selection);
    markDirty();
  }

  // --- Node commands --------------------------------------------------------

  void addNode(String symbolId, Point2D position) {
    final symbol = engine.registry.symbols.resolve(symbolId);
    final id = engine.graph.generateId('node');
    final node = EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: symbol.name,
      symbolId: symbolId,
    );
    engine.editing.execute(CreateNodeCommand(node, position: position));
    engine.registry.selection.selectNode(id);
    markDirty();
  }

  /// AP-DIAGRAM-V2-WEBVIEW-002 — same shape as [addNode], generalized
  /// with an explicit [displayName] and [metadata] so a caller (the
  /// Legacy V2 module-lifecycle bridge, `diagram_studio/webview/
  /// legacy_v2_state_adapter.dart`) can stash bridge-owned extension data
  /// on the node it creates (e.g. the originating V2 module's own
  /// label/category, so a later Engine undo-of-delete can be
  /// re-synchronized back into V2 with more than a bare id) — using
  /// `EngineeringNode.metadata`, which the Engine's own doc comment
  /// already describes as "Extension-contributed data... never
  /// interpreted by the core engine," not a new storage mechanism.
  @override
  void addNodeWithMetadata(
    String symbolId,
    Point2D position, {
    String? displayName,
    Map<String, Object?> metadata = const {},
  }) {
    final symbol = engine.registry.symbols.resolve(symbolId);
    final id = engine.graph.generateId('node');
    final node = EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: displayName ?? symbol.name,
      symbolId: symbolId,
      metadata: metadata,
    );
    engine.editing.execute(CreateNodeCommand(node, position: position));
    engine.registry.selection.selectNode(id);
    markDirty();
  }

  /// AP-DIAGRAM-V2-WEBVIEW-002 — existing [DeleteNodeCommand], exposed
  /// by explicit node id rather than current selection (unlike
  /// [deleteSelection]) so a caller like the V2 module-lifecycle bridge
  /// can delete a specific bridged node without depending on, or
  /// perturbing, whatever OEP's own selection currently is.
  @override
  void deleteNode(String nodeId) {
    engine.editing.execute(DeleteNodeCommand(nodeId));
    markDirty();
  }

  /// AP-DIAGRAM-V2-WEBVIEW-002 — existing [RenameNodeCommand], exposed
  /// by explicit node id for the same reason as [deleteNode].
  @override
  void renameNode(String nodeId, String newDisplayName) {
    engine.editing.execute(RenameNodeCommand(nodeId, newDisplayName));
    markDirty();
  }

  void groupSelection() {
    if (selection.nodeIds.length < 2) return;
    final group = EngineeringGroup(
      id: engine.graph.generateId('group'),
      kind: GroupKind.other,
      displayName: 'Group',
      memberNodeIds: selection.nodeIds.toList(),
    );
    engine.editing.execute(CreateGroupCommand(group));
    engine.registry.selection.selectGroup(group.id);
    markDirty();
  }

  void ungroupSelection() {
    for (final groupId in selection.groupIds.toList()) {
      engine.editing.execute(UngroupCommand(groupId));
    }
    engine.registry.selection.deselectAll();
    markDirty();
  }

  @override
  void moveNodes(Map<String, Point2D> newPositions) {
    engine.editing.execute(MoveNodesCommand(newPositions));
    markDirty();
  }

  void resizeNode(String nodeId, Size2D size, {Point2D? newPosition}) {
    engine.editing.execute(ResizeNodeCommand(nodeId, size, newPosition: newPosition));
    markDirty();
  }

  // --- Wire / relationship commands ------------------------------------------

  @override
  void createRelationship(String sourceNodeId, String targetNodeId) {
    engine.editing.execute(CreateRelationshipCommand(EngineeringRelationship(
      id: engine.graph.generateId('rel'),
      relationshipType: RelationshipType.connectedTo,
      sourceNode: sourceNodeId,
      targetNode: targetNodeId,
    )));
    markDirty();
  }

  /// AP-DIAGRAM-V2-BRIDGE-004 — existing `DeleteRelationshipCommand`,
  /// exposed by explicit id for the same reason `deleteNode` is: a
  /// caller (the V2 wire-deletion bridge) can delete a specific
  /// relationship without depending on, or perturbing, whatever OEP's
  /// own selection currently is.
  @override
  void deleteRelationship(String relationshipId) {
    engine.editing.execute(DeleteRelationshipCommand(relationshipId));
    markDirty();
  }

  void reconnectRelationship(String relationshipId, {String? newSourceNode, String? newTargetNode}) {
    engine.editing.execute(ReconnectRelationshipCommand(
      relationshipId,
      newSourceNode: newSourceNode,
      newTargetNode: newTargetNode,
    ));
    markDirty();
  }

  void setWireRoute(String relationshipId, List<Point2D>? points) {
    engine.editing.execute(SetWireRouteCommand(relationshipId, points));
    markDirty();
  }

  /// Merges [patch] into a relationship's `metadata` bag (AP-DIAGRAM-V2-006)
  /// via the existing, previously-unused `UpdateRelationshipPropertiesCommand`
  /// (`oep_engine/lib/core/editing/commands/update_relationship_properties_command.dart`,
  /// ENGINE-TASK-000085) — a generic metadata-patch command, not written
  /// for this task. A `null` value in [patch] removes that key (the
  /// command's own documented convention), which is how the Property
  /// Inspector's Wire Label/Wire Color fields clear a value. Used for the
  /// `wireColor`/`label` keys AP-DIAGRAM-V2-005 already established as
  /// real, but any relationship metadata key could go through this same
  /// method — it is not wire-specific itself.
  @override
  void updateRelationshipMetadata(String relationshipId, Map<String, Object?> patch) {
    engine.editing.execute(UpdateRelationshipPropertiesCommand(relationshipId, patch));
    markDirty();
  }

  /// AP-DIAGRAM-V2-BRIDGE-011 — the node-side sibling of
  /// [updateRelationshipMetadata], via the newly-added
  /// `UpdateNodeMetadataCommand` (§ that command's own doc comment for
  /// why `metadata`, not `properties`, is the correct field). Same
  /// generic, key-agnostic shape — a `null` patch value removes that key.
  /// First real use is bridging V2's module "notes" field
  /// (`LegacyV2StateAdapter._handleModulePropertiesChanged`), but this
  /// method is not notes-specific.
  @override
  void updateNodeMetadata(String nodeId, Map<String, Object?> patch) {
    engine.editing.execute(UpdateNodeMetadataCommand(nodeId, patch));
    markDirty();
  }

  // --- Annotations ------------------------------------------------------------

  void addAnnotation(AnnotationType type, Point2D position) {
    final id = engine.graph.generateId('annotation');
    engine.editing.execute(CreateAnnotationCommand(DiagramAnnotation(
      id: id,
      type: type,
      text: 'New ${type.name}',
      position: position,
    )));
    engine.registry.selection.selectAnnotation(id);
    markDirty();
  }

  void moveAnnotation(String id, Point2D position) {
    engine.editing.execute(UpdateAnnotationCommand(id, position: position));
    markDirty();
  }

  void updateAnnotationText(String id, String text) {
    engine.editing.execute(UpdateAnnotationCommand(id, text: text));
    markDirty();
  }

  void deleteAnnotation(String id) {
    engine.editing.execute(DeleteManyCommand(annotationIds: {id}));
    markDirty();
  }

  // --- Placement tools -------------------------------------------------------

  void rotateSelection(double degrees) {
    if (selection.nodeIds.isEmpty) return;
    engine.editing.execute(RotateNodesCommand(selection.nodeIds, degrees));
    markDirty();
  }

  void mirrorSelection(MirrorAxis axis) {
    if (selection.nodeIds.isEmpty) return;
    engine.editing.execute(MirrorNodesCommand(selection.nodeIds, axis));
    markDirty();
  }

  void arrayPlace({
    required int countX,
    required int countY,
    required double spacingX,
    required double spacingY,
  }) {
    if (selection.nodeIds.isEmpty) return;
    engine.editing.execute(ArrayPlaceCommand(
      selection.nodeIds,
      countX: countX,
      countY: countY,
      spacingX: spacingX,
      spacingY: spacingY,
    ));
    markDirty();
  }

  void replaceSymbol(String symbolId) {
    if (selection.nodeIds.length != 1) return;
    engine.editing.execute(ReplaceSymbolCommand(selection.nodeIds.single, symbolId));
    markDirty();
  }

  // --- Align / Distribute ------------------------------------------------------

  void alignSelection(AlignmentMode mode) {
    if (selection.nodeIds.length < 2) return;
    engine.editing.execute(AlignNodesCommand(selection.nodeIds, mode));
    markDirty();
  }

  void distributeSelection(DistributionAxis axis) {
    if (selection.nodeIds.length < 3) return;
    engine.editing.execute(DistributeNodesCommand(selection.nodeIds, axis));
    markDirty();
  }

  // --- Layers ------------------------------------------------------------------

  void createLayer() {
    final count = session!.layout.layers.length;
    final layer = DiagramLayer(
      id: engine.graph.generateId('layer'),
      name: 'Layer ${count + 1}',
      order: count,
    );
    engine.editing.execute(CreateLayerCommand(layer));
    markDirty();
  }

  void deleteLayer(String layerId) {
    engine.editing.execute(DeleteLayerCommand(layerId));
    markDirty();
  }

  void toggleLayerVisible(String layerId) {
    final layer = session!.layout.layerById(layerId);
    if (layer == null) return;
    engine.editing.execute(UpdateLayerCommand(layerId, visible: !layer.visible));
    markDirty();
  }

  void toggleLayerLocked(String layerId) {
    final layer = session!.layout.layerById(layerId);
    if (layer == null) return;
    engine.editing.execute(UpdateLayerCommand(layerId, locked: !layer.locked));
    markDirty();
  }

  // --- Named layouts (View toolbar) --------------------------------------------
  //
  // Matches existing behavior exactly: neither operation calls
  // `_markDirty()` today (named-layout load/reset does not mark the
  // document dirty in the current implementation) — not changed here.

  void loadNamedLayout(DiagramLayoutState layout) {
    engine.editing.resetSession(session!.copyWith(layout: layout));
  }

  void resetLayout() {
    engine.editing.resetSession(session!.copyWith(layout: DiagramLayoutState.empty));
  }

  void restoreViewState(ViewState saved) {
    _viewStateService
      ..setGridSettings(saved.grid)
      ..setZoom(saved.zoom)
      ..setPan(saved.pan)
      ..setGuidesVisible(saved.guidesVisible)
      ..setConstraints(saved.constraints)
      ..setTheme(saved.theme);
  }

  /// The tab title for a document path — just the file's own basename,
  /// no `package:path` dependency needed for this simple case. `null` ->
  /// the same "Untitled Diagram" default `DiagramTab` itself defaults to.
  /// (WAVE 2, AP-DIAGRAM-W2 — moved verbatim from
  /// `_DiagramStudioPageState._titleForPath`.)
  static String titleForPath(String? path) {
    if (path == null) return 'Untitled Diagram';
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash == -1 ? normalized : normalized.substring(slash + 1);
  }

  // --- Bootstrap (WAVE 2, AP-DIAGRAM-W2 Step 3) ----------------------------

  /// The full engine/document/tab bootstrap sequence, moved out of
  /// `_DiagramStudioPageState._bootstrap()` verbatim — same steps, same
  /// order, same first-start guard, same try/catch-and-ignore fallback
  /// for a moved/deleted last-open file. Constructing this controller
  /// requires a live [EngineeringEngine] (see the constructor), which in
  /// turn requires `ensureEngineStarted()` to have already run — so this
  /// static factory owns that first step too, rather than forcing the
  /// page to construct an engine-less controller and mutate it into
  /// validity afterward.
  ///
  /// Returns the controller alongside the loaded [DiagramWorkspaceState]
  /// so the page can apply its own UI-only fields (panel visibility,
  /// panel widths — genuinely Flutter-presentation state this controller
  /// has no business owning) without this controller needing to know
  /// those fields exist. The document-relevant fields of that same
  /// loaded state (`lastDocumentPath`, `viewState`) are already applied
  /// internally, exactly where the page used to apply them.
  static Future<(DiagramStudioController, DiagramWorkspaceState)> bootstrap({required Ref ref}) async {
    final notifier = ref.read(engineeringProjectServiceProvider.notifier);
    final isFirstStart = ref.read(engineeringProjectServiceProvider).engineHost == null;
    final host = await notifier.ensureEngineStarted();
    final controller = DiagramStudioController(engine: host.engine, ref: ref);

    // The persisted tab list is the authoritative "what was open last"
    // record, superseding `workspace.lastDocumentPath` (unifying
    // restoration under one source instead of two potentially-conflicting
    // ones). Must be awaited before checking `tabs`/`activeTab` below —
    // restoration runs async and would otherwise race the fallback logic.
    await ref.read(diagramTabsProvider.notifier).ensureRestored();
    final restoredTabs = ref.read(diagramTabsProvider);
    final restoredActivePath = restoredTabs.activeTab?.path;

    final workspace = await WorkspaceStateStorage.load();

    // Only restore a document on the engine's very first start in this
    // Studio session — on a later revisit (navigated away and back) the
    // engine is already running with whatever document the user was
    // last editing, and re-opening a persisted path here would discard
    // that live state.
    if (isFirstStart) {
      final lastPath = restoredTabs.tabs.isNotEmpty ? restoredActivePath : workspace.lastDocumentPath;
      if (lastPath != null) {
        try {
          await notifier.openDocument(lastPath);
          if (workspace.viewState != null) controller.restoreViewState(workspace.viewState!);
        } catch (_) {
          // The last-open file may have moved or been deleted — fall
          // back to the blank document `ensureEngineStarted` already
          // began rather than surfacing an error on launch.
        }
      }
    }

    // Seed a real tab for whatever document is now open (restored or
    // blank) only if restoration found none at all — e.g. the very
    // first launch ever.
    if (ref.read(diagramTabsProvider).tabs.isEmpty) {
      ref.read(diagramTabsProvider.notifier).openTab(path: controller.documentPath, title: titleForPath(controller.documentPath));
    }

    // AP-DIAGRAM-V2-BRIDGE-010 — extracted from the retired native
    // `DiagramStudioPage._bootstrap`'s own `_selectionSub` (this half of
    // it only — the other half, wire-edit-mode point reseeding, was
    // genuinely native-canvas-specific and did not move). Selection→
    // Property-Inspector sync is real, UI-independent business logic
    // (confirmed by this task's own extraction audit): the shared,
    // cross-Studio `PropertyInspectorPanel`
    // (`lib/shared/widgets/property_inspector_panel.dart`) needs
    // *something* feeding it `EngineeringInspectable` selections
    // regardless of which surface (native canvas or the V2 bridge, via
    // `LegacyV2StateAdapter`'s `GraphSelection` mirroring) actually
    // changed the selection. Living here, keyed off `engine.registry
    // .selection.changes` directly, makes it work for both without
    // either needing to know about the other. Not torn down explicitly
    // — this controller is app-wide/session-long-lived (§ this class's
    // own provider's doc comment), the same lifetime `engine` itself
    // already has, so there is nothing shorter-lived for this
    // subscription to leak past.
    controller.engine.registry.selection.changes.listen((_) => controller._syncPropertyInspectorSelection(ref));
    controller._syncPropertyInspectorSelection(ref);

    return (controller, workspace);
  }

  void _syncPropertyInspectorSelection(Ref ref) {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final session = this.session;
    final currentSelection = selection;
    if (session == null || currentSelection.length != 1) {
      notifier.clearEngineeringInspectableSelection();
      return;
    }
    if (currentSelection.nodeIds.isNotEmpty) {
      final node = session.graph.nodes[currentSelection.nodeIds.first];
      if (node != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.node(node));
        return;
      }
    }
    if (currentSelection.relationshipIds.isNotEmpty) {
      final relationship = session.graph.relationships[currentSelection.relationshipIds.first];
      if (relationship != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.relationship(relationship));
        return;
      }
    }
    if (currentSelection.groupIds.isNotEmpty) {
      final group = session.graph.groups[currentSelection.groupIds.first];
      if (group != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.group(group));
        return;
      }
    }
    if (currentSelection.annotationIds.isNotEmpty) {
      final annotation = session.layout.annotationOf(currentSelection.annotationIds.first);
      if (annotation != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.annotation(annotation));
        return;
      }
    }
    notifier.clearEngineeringInspectableSelection();
  }

  // --- Workspace persistence ------------------------------------------------
  //
  // WAVE 2 Step 8 originally put the `WorkspaceStateStorage.save` call
  // here, reasoning that the disk write was a legitimate Controller
  // responsibility while the `DiagramWorkspaceState` value itself
  // (panel visibility/width fields) stayed page-assembled. WAVE 2 STAGE
  // D (AP-DIAGRAM-W2-D) supersedes that: workspace persistence is a
  // separate concern from Engine editing orchestration, so it now has
  // its own dedicated, non-widget, app-session-scoped owner —
  // `diagramWorkspacePersistenceProvider`
  // (`persistence/diagram_workspace_persistence_provider.dart`) — rather
  // than living partly here and partly on the page. This controller no
  // longer has a `persistWorkspaceState` method; `DiagramStudioPage`
  // calls the provider directly. This keeps the existing, correct
  // separation between `DiagramDocument` (engineering data),
  // `DiagramWorkspaceState` (UI state), `DiagramTabsStorage` (temporary
  // workspace state), and `DiagramStudioSettings` (user preferences)
  // exactly as it was — nothing is conflated by this move, only
  // relocated to a more appropriate owner.

  // --- Document lifecycle (WAVE 2, AP-DIAGRAM-W2 Step 6) --------------------
  //
  // Every method below is the exact sequencing the page's own
  // `_newDocument`/`_openDocument`/`_saveDocument`/`_saveAsDocument`/
  // `_closeDocument`/`_closeTab`/`_activateTab`/`_reopenRecentlyClosed`
  // bodies used to perform inline. The "discard unsaved changes?"
  // confirmation dialog itself stays page-side (it needs a
  // `BuildContext`, which must never cross into this controller — spec
  // §3.4's "never crosses" list) and is still evaluated at exactly the
  // same point in the sequence as before; only the confirmed sequencing
  // of Engine/tab calls that follows it moves here.

  Future<void> newDocument() async {
    await _ref.read(engineeringProjectServiceProvider.notifier).newDocument();
    _ref.read(diagramTabsProvider.notifier).openTab(path: null, title: 'Untitled Diagram');
  }

  Future<void> openDocument(String path) async {
    await _ref.read(engineeringProjectServiceProvider.notifier).openDocument(path);
    _ref.read(diagramTabsProvider.notifier).openTab(path: path, title: titleForPath(path));
  }

  @override
  Future<void> saveDocument() => _ref.read(engineeringProjectServiceProvider.notifier).saveDocument();

  Future<void> saveDocumentAs(String path) async {
    await _ref.read(engineeringProjectServiceProvider.notifier).saveDocumentAs(path);
    _ref.read(diagramTabsProvider.notifier).updateActiveTabDocument(path: path, title: titleForPath(path));
  }

  Future<void> closeDocument() => _ref.read(engineeringProjectServiceProvider.notifier).closeDocument();

  // --- Tab lifecycle (WAVE 2, AP-DIAGRAM-W2 Step 7) -------------------------

  /// [wasActive] is computed by the page (a plain `diagramTabsProvider`
  /// read, not a mutation) *before* it decides whether to show the
  /// discard-confirmation dialog — the original code only shows that
  /// dialog when the tab being closed is the active one, so the page
  /// needs this fact before this method ever runs.
  Future<void> closeTab(String id, {required bool wasActive}) async {
    if (wasActive) {
      await _ref.read(engineeringProjectServiceProvider.notifier).closeDocument();
    }
    _ref.read(diagramTabsProvider.notifier).closeTab(id);
    if (wasActive) {
      final newActive = _ref.read(diagramTabsProvider).activeTab;
      if (newActive != null) {
        if (newActive.path != null) {
          await _ref.read(engineeringProjectServiceProvider.notifier).openDocument(newActive.path!);
        } else {
          await _ref.read(engineeringProjectServiceProvider.notifier).newDocument();
        }
      }
    }
  }

  /// Returns the newly-active tab's own mode (so the page can re-apply
  /// its panel-visibility defaults, exactly as before — see
  /// `_applyModeDefaults`, which stays page-side since it drives
  /// `setState`), or `null` if [id] does not name a real tab.
  Future<DiagramStudioMode?> activateTab(String id) async {
    final tabsState = _ref.read(diagramTabsProvider);
    final target = tabsState.tabs.where((t) => t.id == id).toList();
    if (target.isEmpty) return null;
    if (target.single.path != null) {
      await _ref.read(engineeringProjectServiceProvider.notifier).openDocument(target.single.path!);
    } else {
      await _ref.read(engineeringProjectServiceProvider.notifier).newDocument();
    }
    _ref.read(diagramTabsProvider.notifier).activate(id);
    return target.single.mode;
  }

  Future<void> reopenRecentlyClosed(DiagramTab entry) async {
    if (entry.path != null) {
      await _ref.read(engineeringProjectServiceProvider.notifier).openDocument(entry.path!);
      _ref.read(diagramTabsProvider.notifier).openTab(path: entry.path, title: entry.title);
    } else {
      await _ref.read(engineeringProjectServiceProvider.notifier).newDocument();
      _ref.read(diagramTabsProvider.notifier).openTab(path: null, title: entry.title);
    }
    _ref.read(diagramTabsProvider.notifier).removeFromRecentlyClosed(entry.id);
  }

  /// Single, unsequenced tab-state mutations wired directly to a tab
  /// chip's own controls — unlike [closeTab]/[activateTab]/
  /// [reopenRecentlyClosed], neither one coordinates with document
  /// lifecycle or needs a discard-confirmation, so there is nothing to
  /// sequence; these exist purely so `diagram_studio_page.dart` has no
  /// reason to read `diagramTabsProvider`'s notifier directly at all.
  void togglePin(String id) => _ref.read(diagramTabsProvider.notifier).togglePin(id);

  void setTabMode(String id, DiagramStudioMode mode) => _ref.read(diagramTabsProvider.notifier).setMode(id, mode);
}
