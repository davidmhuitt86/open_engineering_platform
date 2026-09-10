/// Public surface for the terminal-centric Electrical Solution Engine
/// model (PRODUCT-READINESS-004 Phase A).
///
/// See `docs/architecture/diagram_studio/ELECTRICAL_SOLUTION_ENGINE.md`
/// for the full architecture this phase establishes. This phase is model/
/// contracts only — there is no solver implementation behind these types
/// yet (the Legacy V2 JS solver, `reference/legacy_wiring_sim_v2/`,
/// remains the authoritative live electrical behavior for the TRX300 in
/// the meantime; see that doc's own "Legacy V2 migration boundary"
/// section).
library;

export '../../core/simulation/electrical/electrical_reading_state.dart';
export '../../core/simulation/electrical/electrical_reading.dart';
export '../../core/simulation/electrical/electrical_conducting_state.dart';
export '../../core/simulation/electrical/electrical_solution_generation.dart';
export '../../core/simulation/electrical/electrical_terminal_state.dart';
export '../../core/simulation/electrical/electrical_branch_state.dart';
export '../../core/simulation/electrical/solved_electrical_state.dart';
export '../../core/simulation/electrical/electrical_measurement.dart';
export '../../core/simulation/electrical/electrical_operating_context.dart';
export '../../core/simulation/electrical/electrical_component_behavior.dart';
export '../../core/simulation/electrical/electrical_node_roles.dart';
export '../../core/simulation/electrical/electrical_solver.dart';
export '../../core/simulation/electrical/electrical_resistive_network.dart';
export '../../core/simulation/electrical/electrical_measurement_query.dart';
