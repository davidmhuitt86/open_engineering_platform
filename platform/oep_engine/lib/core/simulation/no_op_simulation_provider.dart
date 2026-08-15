import '../graph/models/engineering_graph.dart';
import '../interfaces/simulation_provider.dart';

/// Registered in place of a real simulation engine for Phase 1 —
/// WORK_PACKAGE_019 is explicit: "no simulation yet." Exists so
/// `EngineeringEngine` depends on [SimulationProvider] from day one; a real
/// electrical/hydraulic/mechanical/pneumatic/thermal engine replaces this
/// later without any caller changing (SDD-025/026).
class NoOpSimulationProvider implements SimulationProvider {
  @override
  bool get isAvailable => false;

  @override
  Future<void> run(EngineeringGraph graph) async {
    throw UnsupportedError(
      'Simulation is not available in this Phase 1 build. '
      'NoOpSimulationProvider is a placeholder — see WORK_PACKAGE_019 Phase 1 scope.',
    );
  }
}
