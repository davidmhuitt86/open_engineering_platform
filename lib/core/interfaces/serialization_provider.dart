import '../graph/models/engineering_graph.dart';

/// Storage-independent persistence for an [EngineeringGraph].
///
/// Not one of SDD-026's named public services — this is the abstraction
/// `GraphProvider` implementations delegate to so the *storage medium* can
/// change without `GraphService` or `GraphProvider` changing. Phase 1 ships
/// `JsonFileSerializationProvider` only (local JSON, for verification). A
/// future Foundation- or OEP-Package-backed serializer implements the same
/// contract. See ADR entries in docs/ARCHITECTURE_DECISIONS.md.
abstract class SerializationProvider {
  Future<void> write(EngineeringGraph graph, String destination);

  Future<EngineeringGraph> read(String source);
}
