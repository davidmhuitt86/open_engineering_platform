/// Engineering Engine — Open Engineering Platform (OEP).
///
/// Import this single file to consume the entire public API:
/// `EngineeringEngine`, the Engineering Graph, Symbol Library, Diagram
/// View, and the Navigation/Selection/Validation/Import/Export/Simulation
/// services. Everything under `lib/core/` is implementation detail
/// (SDD-026: "Studio shall never depend upon Engineering implementation
/// details.").
library;

export 'core/engine_diagnostics.dart';
export 'core/engine_registry.dart';
export 'core/engine_state.dart';
export 'core/engineering_engine.dart';
export 'analysis/analysis.dart';
export 'bridge/bridge.dart';
export 'clipboard/clipboard.dart';
export 'diagrams/diagrams.dart';
export 'editing/editing.dart';
export 'exporters/exporters.dart';
export 'graph/graph.dart';
export 'importers/importers.dart';
export 'knowledge/knowledge.dart';
export 'services/services.dart';
export 'shared/shared.dart';
export 'simulation/simulation.dart';
export 'symbols/symbols.dart';
export 'viewstate/viewstate.dart';
export 'views/dialogs/dialogs.dart';
export 'views/widgets/widgets.dart';
