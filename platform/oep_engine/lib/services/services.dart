/// Public surface for the Navigation, Selection, Validation, and Search
/// services (SDD-026 — Search Engine/`SearchService` implemented for the
/// first time in WORK_PACKAGE_023, ENGINE-TASK-000104). Internal
/// `EngineEventBus`/`EngineEvent` are intentionally not exported —
/// SDD-026: "Events remain internal to the Engineering Engine."
library;

export '../core/interfaces/navigation_provider.dart';
export '../core/interfaces/search_provider.dart';
export '../core/interfaces/selection_provider.dart';
export '../core/interfaces/validation_provider.dart';
export '../core/navigation/navigation_event.dart';
export '../core/navigation/navigation_service.dart';
export '../core/search/search_result.dart';
export '../core/search/search_service.dart';
export '../core/selection/focus_state.dart';
export '../core/selection/graph_selection.dart';
export '../core/selection/selection_service.dart';
export '../core/validation/validation_finding.dart';
export '../core/validation/validation_report.dart';
export '../core/validation/validation_service.dart';
