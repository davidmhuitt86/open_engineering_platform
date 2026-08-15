# Repository

Status: Foundation (Metadata System, Engineering Object Model, Relationship Model, Graph Traversal, Audit Log)

Purpose: Repository-level services. Implements:

- The metadata system defined by OEP-SPEC-003-REPOSITORY_METADATA — `RepositoryMetadata`, a loader, a writer, and validation for `repository.json`.
- The Engineering Object model defined by OEP-SPEC-004-ENGINEERING_OBJECT_MODEL — `EngineeringObject`, validation, JSON serialization, and a Create/Read/Update/Delete `ObjectStore`.
- The Object Relationship model defined by OEP-SPEC-005-OBJECT_RELATIONSHIP_MODEL — `Relationship`, validation, JSON serialization, and a Create/Read/Update/Delete/Enumerate `RelationshipStore`.
- Repository Graph Traversal defined by OEP-SPEC-007-GRAPH_TRAVERSAL — `GraphEngine`, an in-memory graph over Engineering Objects (nodes) and Relationships (edges) supporting neighbor discovery, BFS/DFS traversal, and path-existence detection.
- The Repository Audit Log defined by OEP-SPEC-008-REPOSITORY_AUDIT_LOG — `AuditEvent`, an `AuditStore`, and automatic event recording wired directly into `ObjectStore`/`RelationshipStore` (applications never create audit events directly).
- Batch Operations defined by OEP-SPEC-020-BATCH_OPERATIONS — `BatchProcessor`, parsing and validating a deterministic JSON batch format (create and delete), resolving batch-local `ref` aliases to real object IDs, and executing only after the entire batch validates. Lives here rather than in `platform/exchange` because it operates on an already-open repository's objects/relationships, the same domain `GraphEngine`/`RepositoryValidator` operate in — it is not a packaging or whole-repository reconstruction concern.

AI reasoning and the rest of the Repository Engine are not yet implemented. Search is implemented separately in `platform/search`.

## Architecture

- `include/oep/repository/metadata.hpp` — public metadata model and `load_metadata` / `save_metadata` / `validate_metadata`
- `include/oep/repository/engineering_object.hpp` — public `EngineeringObject` model, `ObjectType`, and `validate_object`
- `include/oep/repository/object_store.hpp` — public `ObjectStore` (create/load/update/remove/list_all); requires an `AuditStore` and records `ObjectCreated`/`ObjectUpdated`/`ObjectDeleted` automatically
- `include/oep/repository/relationship.hpp` — public `Relationship` model, `RelationshipType`, and `validate_relationship`
- `include/oep/repository/relationship_store.hpp` — public `RelationshipStore` (create/load/update/remove/list_by_object/list_all), validated against an `ObjectStore`; requires an `AuditStore` and records `RelationshipCreated`/`RelationshipUpdated`/`RelationshipDeleted` automatically
- `include/oep/repository/graph_engine.hpp` — public `GraphEngine` (build_graph/clear_graph/get_neighbors/traverse_breadth_first/traverse_depth_first/path_exists)
- `include/oep/repository/audit_event.hpp` — public `AuditEvent` model, `AuditEventType`, and `validate_audit_event`
- `include/oep/repository/audit_store.hpp` — public `AuditStore` (record_event/list_events/list_events_for_object/clear)
- `include/oep/repository/uuid.hpp` — shared UUIDv4 generation/validation, used by metadata, objects, relationships, and audit events
- `include/oep/repository/timestamp.hpp` — shared UTC timestamp formatting
- `include/oep/repository/batch_processor.hpp` — public `BatchProcessor` types (`BatchObjectSpec`/`BatchRelationshipSpec`/`BatchCreateRequest`/`BatchDeleteRequest`) and free functions (`parse_batch_create_request`/`parse_batch_delete_request`/`validate_batch_create_request`/`execute_batch_create`/`execute_batch_delete`)
- `src/json_value.hpp` / `src/json_value.cpp` — internal minimal JSON parser/serializer (not part of the public API)
- `src/metadata.cpp`, `src/engineering_object.cpp`, `src/object_store.cpp`, `src/relationship.cpp`, `src/relationship_store.cpp`, `src/graph_engine.cpp`, `src/audit_event.cpp`, `src/audit_store.cpp`, `src/batch_processor.cpp` — schema mapping, validation rules, atomic writes, graph construction/traversal, audit recording, batch parsing/validation/execution

Consumed by the Foundation Generator (`oep init`) to populate `repository.json`. `AuditEventType::RepositoryCreated` is supported by the model but not yet wired into `oep init` — OEP-SPEC-002 does not define where an audit log lives within a generated repository, so that integration is deferred to a future, ratified task.
