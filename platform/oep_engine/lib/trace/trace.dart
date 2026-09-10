/// Public surface for the Electrical Trace & Circuit Intelligence engine
/// (PRODUCT-READINESS-005).
///
/// See `docs/architecture/diagram_studio/ELECTRICAL_TRACE_ENGINE.md` for
/// the full architecture. The Trace Engine consumes `SolvedElectricalState`
/// (`simulation/electrical/electrical.dart`) — it performs no electrical
/// solving of its own.
library;

export '../core/trace/trace_mode.dart';
export '../core/trace/trace_target.dart';
export '../core/trace/trace_diagnostic.dart';
export '../core/trace/trace_path.dart';
export '../core/trace/trace_result.dart';
export '../core/trace/trace_engine.dart';
