/// Public surface for the Graph Engine (SDD-025/026/027).
///
/// `lib/core/graph/` holds the implementation; this barrel is what
/// consumers (the Demonstration Host, tests, and eventually Studio) import.
library;

export '../core/graph/algorithms/connection_validator.dart';
export '../core/graph/algorithms/graph_query.dart';
export '../core/graph/algorithms/graph_traversal.dart';
export '../core/graph/builders/graph_builder.dart';
export '../core/graph/models/engineering_graph.dart';
export '../core/graph/models/engineering_group.dart';
export '../core/graph/models/engineering_node.dart';
export '../core/graph/models/engineering_relationship.dart';
export '../core/graph/models/evidence_link.dart';
export '../core/graph/models/port.dart';
export '../core/graph/models/runtime_metadata.dart';
export '../core/graph/serialization/json_file_serialization_provider.dart';
export '../core/graph/services/graph_service.dart';
export '../core/graph/services/in_memory_graph_provider.dart';
export '../core/interfaces/graph_provider.dart';
export '../core/interfaces/serialization_provider.dart';
