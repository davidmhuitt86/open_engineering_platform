/// Public surface for the Simulation Engine (SDD-025/026).
///
/// AP-DS-005 replaces the "no simulation yet" placeholder with a real
/// deterministic logical Simulation Engine — see
/// `docs/architecture/diagram_studio/SIMULATION_ARCHITECTURE.md`.
/// [NoOpSimulationProvider] remains registered as the base
/// [SimulationProvider] capability marker (unchanged contract); the real
/// engine's much richer API is exposed separately below, per this
/// package's established "each capability is its own facade class"
/// pattern (matching `KnowledgeGraphEngine`/`EngineeringQueryEngine`, not
/// squeezed into one interface).
library;

export '../core/interfaces/simulation_provider.dart';
export '../core/simulation/no_op_simulation_provider.dart';
export '../core/simulation/models/signal_types.dart';
export '../core/simulation/models/simulation_fault.dart';
export '../core/simulation/propagation/signal_propagator.dart';
export '../core/simulation/verification/verification_finding.dart';
export '../core/simulation/verification/verification_engine.dart';
export '../core/simulation/diagnostics/diagnostics_models.dart';
export '../core/simulation/diagnostics/diagnostics_engine.dart';
export '../core/simulation/diagnostics/power_distribution.dart';
export '../core/simulation/measurement/measurement_types.dart';
export '../core/simulation/measurement/measurement_result.dart';
export '../core/simulation/measurement/measurement_engine.dart';
export '../core/simulation/session/simulation_event.dart';
export '../core/simulation/session/simulation_session.dart';
export '../core/simulation/session/simulation_compare_result.dart';
export '../core/simulation/simulation_engine.dart';
export '../core/simulation/state/domain_profile.dart';
export '../core/simulation/state/operating_state.dart';
export '../core/simulation/state/state_condition_resolver.dart';
