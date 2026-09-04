/// Public surface for Engineering Analysis (AP-EK-020).
///
/// `lib/core/analysis/` holds the implementation; this barrel is what
/// consumers (Diagram Studio, tests) import.
library;

export '../core/analysis/analysis_engine.dart';
export '../core/analysis/analysis_persistence.dart';
export '../core/analysis/explanation_service.dart';
export '../core/analysis/fixtures/canonical_circuit_fixture.dart';
export '../core/analysis/linear_system.dart';
export '../core/analysis/models/analysis_request.dart';
export '../core/analysis/models/analysis_result.dart';
export '../core/analysis/models/electrical_topology.dart';
export '../core/analysis/topology_extractor.dart';
