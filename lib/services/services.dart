/// Public surface for the Navigation, Selection, and Validation services
/// (SDD-026). Internal `EngineEventBus`/`EngineEvent` are intentionally
/// not exported — SDD-026: "Events remain internal to the Engineering
/// Engine."
library;

export '../core/interfaces/navigation_provider.dart';
export '../core/interfaces/selection_provider.dart';
export '../core/interfaces/validation_provider.dart';
export '../core/navigation/navigation_event.dart';
export '../core/navigation/navigation_service.dart';
export '../core/selection/selection_service.dart';
export '../core/selection/selection_state.dart';
export '../core/validation/validation_finding.dart';
export '../core/validation/validation_report.dart';
export '../core/validation/validation_service.dart';
