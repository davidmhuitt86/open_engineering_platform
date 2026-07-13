import '../views/diagram/diagram_layout_state.dart';

/// Backing store for [DiagramLayoutState] (SDD-024 Rule 5: layout is not
/// Engineering Knowledge, so it is never part of [GraphProvider]).
///
/// Resolved through [EngineRegistry] exactly like every other capability
/// (ADR-001) — a future Foundation-backed or per-View layout provider
/// implements the same contract without `EditingService` changing.
abstract class LayoutProvider {
  DiagramLayoutState currentLayout(String graphId);

  Future<DiagramLayoutState> updateLayout(String graphId, DiagramLayoutState layout);
}
