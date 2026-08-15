import '../graph/models/engineering_graph.dart';

/// Simulation operates exclusively on the Engineering Graph (SDD-025/026).
///
/// Phase 1 registers only [NoOpSimulationProvider] — "no simulation yet"
/// per WORK_PACKAGE_019. The interface exists now so `EngineeringEngine`
/// depends on the abstraction from day one and a real electrical/hydraulic/
/// mechanical/pneumatic/thermal engine can register later without any
/// caller changing.
abstract class SimulationProvider {
  bool get isAvailable;

  Future<void> run(EngineeringGraph graph);
}
