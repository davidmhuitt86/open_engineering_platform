/// Public surface for the Simulation Engine (SDD-025/026).
///
/// "No simulation yet" — [NoOpSimulationProvider] is the only
/// implementation Phase 1 registers. A real electrical/hydraulic/
/// mechanical/pneumatic/thermal engine implements [SimulationProvider]
/// later without this barrel changing.
library;

export '../core/interfaces/simulation_provider.dart';
export '../core/simulation/no_op_simulation_provider.dart';
