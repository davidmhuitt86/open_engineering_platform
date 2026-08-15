import 'package:engineering_engine/engineering_engine.dart';

import '../../diagram_studio/instruments/multimeter/multimeter_controller.dart';
import '../../diagram_studio/simulation/diagram_simulation_service.dart';

/// The OEP Context & Capability Service (Phase 1) — the normalized
/// representation of "what is the engineer's current engineering
/// situation" consumed by the Contextual Command Resolver
/// (`contextual_command_resolver.dart`).
///
/// Deliberately plain Dart: no `flutter/material.dart`, no
/// `flutter_riverpod.dart`, no widget types anywhere in this file or
/// its subcontexts, per
/// `docs/context menu service/01_OEP_Context_and_Capability_Service_Architecture.md`
/// § 2's dependency direction (`UI → Contextual Command Service →
/// Context & Capability Bridge → Foundation/Engine/Services` — never
/// the reverse) and § 6 ("Context Must Be First-Class"). `EngineeringGraph`
/// is an exception: it is `engineering_engine`'s own pure data type,
/// already the shared representation every Studio page reads, not a
/// Flutter or UI concept.
///
/// **Every field is nullable/empty by construction, never fabricated.**
/// Per the Contract spec § 17 ("Missing Context"): a field this build
/// cannot currently source from real, shared application state stays
/// `null`/empty/`false` rather than being invented. See each
/// subcontext's own doc comment for exactly which fields are backed by
/// real, currently-shared state today vs. which are structurally
/// present but have no live source yet (documented gaps, not silent
/// omissions).
class EngineeringInteractionContext {
  const EngineeringInteractionContext({
    this.workspace = const WorkspaceContext(),
    this.view = const ViewContext(),
    this.document = const DocumentContext(),
    this.selection = const SelectionContext(),
    this.cursorTarget = const CursorTarget.none(),
    this.diagram = const DiagramContext(),
    this.mode = DiagramStudioMode.edit,
    this.simulation = const SimulationContext(),
    this.measurement = const MeasurementContext(),
    this.knowledge = const KnowledgeContext(),
    this.ai = const AiContext(),
    this.permission = const PermissionContext(),
    this.services = const ServiceAvailability(),
    this.graph,
    this.layout,
    this.engine,
    this.multimeterController,
    this.simulationService,
  });

  final WorkspaceContext workspace;
  final ViewContext view;
  final DocumentContext document;
  final SelectionContext selection;
  final CursorTarget cursorTarget;
  final DiagramContext diagram;

  /// (OEP Diagram Studio -- Phase 5, Part 19.) Which of the three
  /// Diagram Studio modes (View/Edit/Simulate) the active document tab
  /// is currently in -- real, sourced from `DiagramTab.mode` via
  /// whichever page builds this context. Defaults to [DiagramStudioMode.edit]
  /// (today's only real behavior before Phase 5) so every context built
  /// without an explicit mode -- e.g. existing tests -- keeps its prior
  /// meaning.
  final DiagramStudioMode mode;
  final SimulationContext simulation;
  final MeasurementContext measurement;
  final KnowledgeContext knowledge;
  final AiContext ai;
  final PermissionContext permission;
  final ServiceAvailability services;

  /// The active Engineering Graph, if a diagram document is open —
  /// carried by reference (already-fetched, immutable data this
  /// build's own `EngineeringProjectState.session.graph` provides),
  /// not a live engine coupling. `null` when no diagram is open, never
  /// an empty placeholder graph standing in for "none."
  final EngineeringGraph? graph;

  /// The active document's real, tracked node/annotation positions —
  /// carried by reference exactly like [graph], not a live engine
  /// coupling. `null` under the same condition [graph] is `null`.
  /// Needed by executors that place something new (a port label) at a
  /// real, current position rather than the graph's fixed origin.
  final DiagramLayoutState? layout;

  /// The shared [EngineeringEngine] itself -- unlike
  /// [multimeterController]/[simulationService] (narrow, single-purpose
  /// service references), this is the one general escape hatch for a
  /// command executor that needs to run a real
  /// `EngineeringEditingService` command (create/delete a node,
  /// relationship, or annotation) rather than drive a dedicated
  /// controller. `null` under the same condition [services]'s own
  /// `ServiceAvailability.engineeringEngine` is absent -- the shared
  /// engine has not been bootstrapped yet.
  final EngineeringEngine? engine;

  /// OEP Context & Capability Service — Phase 2: the same authoritative
  /// [MultimeterController]/[DiagramSimulationService] instances
  /// `multimeterRuntimeServiceProvider`/`diagramSimulationServiceProvider`
  /// expose — real, shared, plain-Dart application services (not
  /// Flutter widgets), carried by reference so command executors can
  /// actually perform a real operation (place a probe, run a
  /// measurement, inject a fault) rather than merely reporting a
  /// snapshot. `null` under exactly the same condition [measurement]/
  /// [simulation]'s own booleans are `false`/default — the shared
  /// engine has not been bootstrapped yet.
  final MultimeterController? multimeterController;
  final DiagramSimulationService? simulationService;

  /// The effective target for an object-scoped command: the explicit
  /// [cursorTarget] if one exists (Contract spec § 7 — "right-clicking
  /// an object must work even if it was never left-click selected"),
  /// otherwise a single item from [selection] when exactly one thing is
  /// selected. `null` when there is no target at all (empty canvas,
  /// multi-selection with no explicit cursor target).
  EngineeringTargetRef? get effectiveTarget {
    if (cursorTarget.kind != CursorTargetKind.none && cursorTarget.targetId != null) {
      return EngineeringTargetRef(kind: cursorTarget.kind, id: cursorTarget.targetId!, ownerNodeId: cursorTarget.ownerNodeId);
    }
    if (selection.isSingle) {
      if (selection.selectedNodeIds.length == 1) {
        return EngineeringTargetRef(kind: CursorTargetKind.node, id: selection.selectedNodeIds.single);
      }
      if (selection.selectedRelationshipIds.length == 1) {
        return EngineeringTargetRef(kind: CursorTargetKind.relationship, id: selection.selectedRelationshipIds.single);
      }
      if (selection.selectedPortIds.length == 1) {
        return EngineeringTargetRef(kind: CursorTargetKind.port, id: selection.selectedPortIds.single);
      }
      if (selection.selectedAnnotationIds.length == 1) {
        return EngineeringTargetRef(kind: CursorTargetKind.annotation, id: selection.selectedAnnotationIds.single);
      }
    }
    return null;
  }
}

/// A single resolved target — either the explicit cursor target or the
/// sole item of a single selection (see [EngineeringInteractionContext.effectiveTarget]).
class EngineeringTargetRef {
  const EngineeringTargetRef({required this.kind, required this.id, this.ownerNodeId});
  final CursorTargetKind kind;
  final String id;

  /// The owning node's id, when [kind] is [CursorTargetKind.port] --
  /// real data (`PortReference.nodeId`, `oep_engine`'s own composite
  /// port identity), never inferred. `null` for every other kind.
  final String? ownerNodeId;
}

/// Where the user is working (Contract spec § 3). Real today: `studioId`
/// is always populated by whichever `StudioDestination` constructs the
/// context (a real, existing routing concept — `studio_destination.dart`).
/// `workspaceId`/`perspectiveId` have no shared source yet in this build
/// (Perspectives are Workbench-page-local state today) and stay `null`.
class WorkspaceContext {
  const WorkspaceContext({this.studioId, this.route});
  final String? studioId;
  final String? route;
}

/// The current view/panel (Contract spec § 4). No shared "active view"
/// registry exists anywhere in this build today — every field stays
/// `null` until one does. Kept as a real, present type (not omitted)
/// so future work has a stable place to populate it without changing
/// this context's shape.
class ViewContext {
  const ViewContext({this.viewId, this.viewType, this.activeTab});
  final String? viewId;
  final String? viewType;
  final String? activeTab;
}

/// The active engineering document (Contract spec § 5), sourced from
/// `EngineeringProjectState.document`/`.session` — real today.
class DocumentContext {
  const DocumentContext({this.documentPath, this.isOpen = false, this.isDirty = false});
  final String? documentPath;
  final bool isOpen;
  final bool isDirty;
}

/// What kind of engineering element a [CursorTarget] or selected item
/// refers to (Contract spec § 6/§ 7).
enum CursorTargetKind { none, node, relationship, port, annotation, testPoint }

/// (OEP Diagram Studio -- Phase 5, Part 19.) The three real Diagram
/// Studio operating modes for one open diagram document -- NOT three
/// separate Studios (Part "Important Product Decision"). [edit] is the
/// mode every pre-Phase-5 build of Diagram Studio behaved as
/// unconditionally (full editing toolset always visible), so it is
/// this enum's default everywhere a mode isn't yet threaded through.
enum DiagramStudioMode { view, edit, simulate }

/// The current multi-selection (Contract spec § 6), sourced from
/// `GraphSelection` (`oep_engine`) — real today for nodes/relationships/
/// groups/annotations. `selectedPortIds`/`selectedTestPointIds` are
/// structurally present but have no populated source in this build:
/// `GraphSelection` itself carries no port or test-point selection
/// concept today (port interaction is callback-driven —
/// `PortReference` passed directly to a handler — not selection
/// state), and no test-point/probe-placement selection is tracked as
/// "selection" either (it lives in `MultimeterController.probeA/B`,
/// itself page-private — see [MeasurementContext]'s own doc comment).
class SelectionContext {
  const SelectionContext({
    this.selectedNodeIds = const {},
    this.selectedRelationshipIds = const {},
    this.selectedGroupIds = const {},
    this.selectedAnnotationIds = const {},
    this.selectedPortIds = const {},
    this.selectedTestPointIds = const {},
  });

  final Set<String> selectedNodeIds;
  final Set<String> selectedRelationshipIds;
  final Set<String> selectedGroupIds;
  final Set<String> selectedAnnotationIds;
  final Set<String> selectedPortIds;
  final Set<String> selectedTestPointIds;

  int get length =>
      selectedNodeIds.length +
      selectedRelationshipIds.length +
      selectedGroupIds.length +
      selectedAnnotationIds.length +
      selectedPortIds.length +
      selectedTestPointIds.length;

  bool get isEmpty => length == 0;
  bool get isSingle => length == 1;
  bool get isMultiple => length > 1;

  factory SelectionContext.fromGraphSelection(GraphSelection selection) => SelectionContext(
        selectedNodeIds: selection.nodeIds,
        selectedRelationshipIds: selection.relationshipIds,
        selectedGroupIds: selection.groupIds,
        selectedAnnotationIds: selection.annotationIds,
      );
}

/// What is under the cursor right now, independent of [SelectionContext]
/// (Contract spec § 7 — the reason this exists at all: "right-clicking
/// an object must work even if it was never left-click selected").
///
/// **Documented gap**: no shared cursor-hit-testing provider exists
/// anywhere in this build today. `diagram_studio_page.dart`'s own
/// `_nodeAt` is a private geometry scan with no public/shared surface,
/// and no right-click/context-menu handling exists anywhere in Diagram
/// Studio yet (confirmed by inspection before this file was written).
/// This type is real and ready to receive that data once a future
/// phase wires Diagram Studio's canvas to actually report a cursor
/// target — until then, every context built by this phase's own
/// adapters constructs `CursorTarget.none()`.
class CursorTarget {
  const CursorTarget({required this.kind, this.targetId, this.diagramX, this.diagramY, this.ownerNodeId});
  const CursorTarget.none()
      : kind = CursorTargetKind.none,
        targetId = null,
        diagramX = null,
        diagramY = null,
        ownerNodeId = null;

  final CursorTargetKind kind;
  final String? targetId;
  final double? diagramX;
  final double? diagramY;

  /// (OEP Diagram Studio — Phase 4, Part 2.) The owning node's real id,
  /// populated only when [kind] is [CursorTargetKind.port] --
  /// `PortReference.nodeId` (`oep_engine`), the actual, already-real
  /// node association the view layer establishes when it renders a
  /// port (see `GraphViewPanel`/`SymbolNodeWidget`). `null` for every
  /// other kind; never inferred or guessed for a port whose owning node
  /// genuinely isn't known.
  final String? ownerNodeId;
}

/// Real diagram-level facts (Contract spec § 8), sourced from
/// `EngineeringProjectState`/`ValidationReport`.
class DiagramContext {
  const DiagramContext({this.diagramOpen = false, this.editable = false, this.validated = false, this.hasValidationErrors = false});
  final bool diagramOpen;
  final bool editable;
  final bool validated;
  final bool hasValidationErrors;
}

/// Simulation modes this build can actually distinguish today (Contract
/// spec § 9). **Documented gap**: only one simulation concept
/// (`DiagramSimulationService`) exists in the whole codebase — there is
/// no "diagnostic vs. engineering simulation" distinction anywhere in
/// current code. [SimulationMode.diagnostic] and [.engineering] are
/// real, distinct enum values ready for that future distinction, but
/// no adapter in this build can currently tell them apart; every
/// adapter shipped in this phase resolves to [.none] or, when a caller
/// explicitly supplies simulation state (e.g. a test), whatever that
/// caller asserts — never inferred from UI appearance (Contract § 9's
/// own explicit rule).
enum SimulationMode { none, diagnostic, engineering }

/// (Contract spec § 9.) **Documented gap**: `DiagramSimulationService`
/// is constructed only inside `DiagramStudioPage`'s own private
/// `State` (confirmed by inspection) — there is no shared provider
/// anywhere a context-builder outside that page could read from. Every
/// adapter shipped in this phase therefore produces `active: false`
/// (the honest default) unless a caller passes real state in
/// explicitly (as tests do, to prove the resolver's own logic).
class SimulationContext {
  const SimulationContext({
    this.active = false,
    this.mode = SimulationMode.none,
    this.targetFaultId,
    this.activeOperatingStateId,
    this.availableOperatingStateIds = const [],
  });
  final bool active;
  final SimulationMode mode;

  /// (Phase 9 -- Operating State & Input-State Architecture, Part 14.)
  /// The real active operating state id on the current simulation
  /// session's `SimulationSession.activeOperatingStateId`, sourced
  /// exactly like [targetFaultId] is -- never inferred, never a
  /// fabricated default. `null` when there is no session or no
  /// operating state has been set yet.
  final String? activeOperatingStateId;

  /// The ids from the current session's real
  /// `SimulationSession.availableOperatingStates` -- empty by default,
  /// since this engine defines no operating states of its own (Part 4);
  /// populated only when a caller has supplied a real domain profile to
  /// the session.
  final List<String> availableOperatingStateIds;

  /// (OEP Diagram Studio -- Phase 8, Part 16/32.) The real id of the
  /// active `SimulationFault` on the current [CursorTarget], if the
  /// engine's own `session.activeFaults.active` list has one --
  /// sourced from the same real fault-list `FaultInjectionPanel`
  /// already reads, never a fabricated fault-presence flag. `null`
  /// when the target has no active fault (or there is no target/
  /// session at all).
  final String? targetFaultId;
}

/// (Contract spec § 10.) **Documented gap**: `MultimeterController` is
/// likewise constructed only inside `DiagramStudioPage`'s own private
/// `State` — no shared provider exists. `dmmAvailable` therefore
/// defaults to `false` in every adapter shipped this phase; the field
/// exists, structurally real, for the phase that adds a shared
/// accessor.
class MeasurementContext {
  const MeasurementContext({this.dmmAvailable = false, this.probeAPlaced = false, this.probeBPlaced = false});
  final bool dmmAvailable;
  final bool probeAPlaced;
  final bool probeBPlaced;
}

/// (Contract spec § 11.) Real today: sourced from
/// `FoundationServiceState.knowledgeSession`/`selectedObject`.
class KnowledgeContext {
  const KnowledgeContext({this.knowledgeAvailable = false, this.relatedKnowledgeCount = 0});
  final bool knowledgeAvailable;
  final int relatedKnowledgeCount;
}

/// (Contract spec § 12.) Real today: `aiAvailable` reflects whether
/// `AiProviderRegistry.defaultRegistry` actually resolves the
/// currently-configured provider id (real, not merely "a registry
/// object exists") — see `AiCapabilityAdapter`.
class AiContext {
  const AiContext({this.aiAvailable = false, this.contextualAnalysisAvailable = false, this.currentProviderId = 'mock'});
  final bool aiAvailable;
  final bool contextualAnalysisAvailable;

  /// The currently-configured provider id (`FoundationServiceState.currentAiProviderId`,
  /// real today — defaults to `'mock'`, matching that provider's own
  /// default, never a fabricated "connected" id).
  final String currentProviderId;
}

/// (Contract spec § 13.) **Documented gap**: no permission/authorization
/// system exists anywhere in this codebase (exhaustively grepped
/// before this file was written — the only hit was an inert Settings
/// placeholder row). Defaulting every flag to `true` is not a
/// fabrication: with no restriction system in place, nothing is
/// actually restricted today, so `true` is the accurate current state,
/// not an invented one. This is the one context field this phase
/// defaults "open" rather than "unavailable" — documented explicitly
/// so a future real authorization system knows exactly what it must
/// replace.
class PermissionContext {
  const PermissionContext({this.canRead = true, this.canEdit = true, this.canDelete = true, this.canSimulate = true});
  final bool canRead;
  final bool canEdit;
  final bool canDelete;
  final bool canSimulate;
}

/// Which real backing services are reachable right now (Contract spec
/// § 14) — a command requiring a service absent from this set must
/// never be treated as executable (§ 14's own rule).
class ServiceAvailability {
  const ServiceAvailability({this.availableServiceIds = const {}});
  final Set<String> availableServiceIds;

  bool isAvailable(String serviceId) => availableServiceIds.contains(serviceId);

  static const foundation = 'foundation';
  static const engineeringEngine = 'engineeringEngine';
  static const simulation = 'simulation';
  static const measurement = 'measurement';
  static const knowledge = 'knowledge';
  static const ai = 'ai';
  static const repository = 'repository';
  static const acquisition = 'acquisition';
  static const exchange = 'exchange';
}
