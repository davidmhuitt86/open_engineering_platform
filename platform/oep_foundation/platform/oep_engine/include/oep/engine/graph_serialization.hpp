#pragma once

#include <string>

#include "oep/engine/knowledge_graph.hpp"

namespace oep::engine {

// WP-EKE-002's Serialization: read-only EXPORT of the Knowledge Graph
// for diagnostics -- never a save/load mechanism, never persisted by
// this module (persistence remains exclusively Foundation's concern).
// Output is deterministic: nodes and edges are always emitted in
// ascending object_id / relationship_id order, regardless of the
// graph's internal container order.

// A complete, valid JSON document: {"objects": [...], "relationships": [...]}.
std::string to_json(const KnowledgeGraph& graph);

// GraphML PLACEHOLDER ONLY, per this work package's explicit scope
// ("GraphML (placeholder only)"): emits a minimal, well-formed
// `<graphml>` document with the correct node/edge COUNT and ids, but
// does not implement the full GraphML attribute/key schema. Not
// intended for consumption by real GraphML tooling; exists so the
// export surface has a placeholder entry to extend in a future work
// package, per this module's README.
std::string to_graphml_placeholder(const KnowledgeGraph& graph);

} // namespace oep::engine
