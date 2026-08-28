import 'package:engineering_engine/engineering_engine.dart' as engine;

import '../../core/models/relationship_type.dart' as foundation;

/// AP-OEP-FOUNDATION-BRIDGE-001 — maps Engine's `RelationshipType` (11
/// values, `engineering_relationship.dart`) onto Foundation's own
/// `RelationshipType` (6 values, `oep_relationship_type_t`), for
/// [StudioFoundationBridgePort.commitGraph]. Same rationale/precedent as
/// [NodeCategoryFoundationMapping] — a Studio-side `extension`, nullable,
/// only genuinely unambiguous equivalents mapped. Imports are prefixed
/// (`engine`/`foundation`) since both packages independently declare a
/// type named `RelationshipType` with no relation to each other.
extension EngineRelationshipTypeFoundationMapping on engine.RelationshipType {
  foundation.RelationshipType? get foundationType {
    switch (this) {
      case engine.RelationshipType.connectedTo:
        return foundation.RelationshipType.connectedTo;
      case engine.RelationshipType.contains:
        return foundation.RelationshipType.contains;
      case engine.RelationshipType.references:
        return foundation.RelationshipType.references;
      case engine.RelationshipType.suppliesPower:
      case engine.RelationshipType.grounds:
      case engine.RelationshipType.communicatesWith:
      case engine.RelationshipType.partOf:
      case engine.RelationshipType.mountedTo:
      case engine.RelationshipType.controls:
      case engine.RelationshipType.measures:
      case engine.RelationshipType.other:
        return null;
    }
  }
}
