import '../views/diagram/diagram_layout_state.dart';

/// Backing store for [DiagramLayoutState] (SDD-024 Rule 5: layout is not
/// Engineering Knowledge, so it is never part of [GraphProvider]).
///
/// Resolved through [EngineRegistry] exactly like every other capability
/// (ADR-001) — a future Foundation-backed or per-View layout provider
/// implements the same contract without `EditingService` changing.
///
/// WORK_PACKAGE_022 (ENGINE-TASK-000089) adds named layouts: a graph may
/// have several saved layouts (e.g. "Default", "Print Layout", "Compact"),
/// independent of the one [currentLayout] the active `EditingSession`
/// tracks. Saving/loading a named layout never touches the Engineering
/// Graph.
abstract class LayoutProvider {
  DiagramLayoutState currentLayout(String graphId);

  Future<DiagramLayoutState> updateLayout(String graphId, DiagramLayoutState layout);

  Future<void> saveNamedLayout(String graphId, String layoutName, DiagramLayoutState layout);

  DiagramLayoutState? loadNamedLayout(String graphId, String layoutName);

  List<String> listNamedLayouts(String graphId);

  Future<void> deleteNamedLayout(String graphId, String layoutName);

  Future<DiagramLayoutState> resetLayout(String graphId);
}
