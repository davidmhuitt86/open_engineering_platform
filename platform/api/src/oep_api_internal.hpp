#pragma once

// Private implementation details for oep_api.cpp. Never installed or
// exposed to API consumers — the public ABI is oep_api.h alone.

#include <algorithm>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

#include "oep/api/oep_api.h"
#include "oep/engine/analysis_engine.hpp"
#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_intelligence_platform.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/reasoning_engine.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/repository_events.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"

// The concrete type behind the opaque OEP_Runtime handle. Applications
// only ever see a pointer to this type as `struct oep_runtime_impl*`;
// its layout is never part of the ABI contract.
//
// WP-REP-006 adds `events` and `service` alongside the existing
// `runtime` member. `service` is a thin orchestration layer over
// `runtime` (RuntimeService — see runtime_service.hpp); it owns no
// business logic of its own. API functions are migrated to call
// through `service` incrementally, starting with
// oep_package_install; every other function continues to call
// `runtime` directly, exactly as before this work package, and remains
// fully functional (WP-REP-006 requirement #11: "Existing APIs remain
// functional but become thin wrappers" describes an incremental
// migration, not a one-shot rewrite of every function).
// WP-EKE-001 adds `engine_context`, constructed from `service` (never
// from `runtime` directly) -- the Engineering Knowledge Runtime's
// EngineeringContext consumes Foundation EXCLUSIVELY through
// RuntimeService, matching WP-REP-007/WP-REP-008's established pattern
// for newer capabilities. `engine_context` holds this handle's Object
// Loader cache and Runtime Graph; both persist for the handle's
// lifetime (oep_engine_load_graph must be called at least once, and
// again after any mutation the caller wants reflected in subsequent
// queries/traversals).
// WP-EKE-002 adds `knowledge_graph_engine`, constructed from
// `engine_context` (never from `service`/`runtime` directly) --
// KnowledgeGraphEngine consumes Foundation EXCLUSIVELY through
// EngineeringContext, preserving the same "consume only the layer
// directly beneath you" boundary WP-EKE-001 established for
// `engine_context` itself. `knowledge_graph_engine` holds this handle's
// canonical Knowledge Graph; it persists for the handle's lifetime
// (oep_kge_build_graph must be called at least once, and again --
// or oep_kge_refresh_graph -- after any mutation the caller wants
// reflected in subsequent validation/algorithm/statistics/export calls).
// WP-EKE-003 adds `engineering_query_engine`, constructed from
// `knowledge_graph_engine` (never from `engine_context`/`service`/
// `runtime` directly) -- EngineeringQueryEngine consumes the Knowledge
// Graph Engine EXCLUSIVELY, preserving the same layering boundary.
// `engineering_query_engine` holds this handle's query plan/result
// cache and most-recently-executed QueryStatistics; both persist for
// the handle's lifetime and require a prior oep_kge_build_graph/
// oep_kge_refresh_graph call before any oep_eqe_* function succeeds.
// WP-EKE-004 adds `rules_engine`, constructed from `engine_context`,
// `knowledge_graph_engine`, and `engineering_query_engine` (never from
// `service`/`runtime` directly) -- RulesEngine consumes exactly those
// three, preserving the same layering boundary. `rules_engine` holds
// this handle's in-memory Rule Registry; it persists for the handle's
// lifetime but is NEVER persisted to the repository itself -- a fresh
// oep_runtime_impl always starts with zero registered rules.
// WP-EKE-005 adds `validation_engine`, constructed from `engine_context`,
// `knowledge_graph_engine`, `engineering_query_engine`, and
// `rules_engine` (never from `service`/`runtime` directly) --
// ValidationEngine consumes exactly those four, preserving the same
// layering boundary. `validation_engine` holds this handle's in-memory
// ValidationSession registry; it persists for the handle's lifetime but
// is NEVER persisted to the repository itself -- a fresh
// oep_runtime_impl always starts with zero validation sessions.
// WP-EKE-006 adds `reasoning_engine`, constructed from `engine_context`,
// `knowledge_graph_engine`, `engineering_query_engine`, `rules_engine`,
// and `validation_engine` (never from `service`/`runtime` directly) --
// ReasoningEngine consumes exactly those five, preserving the same
// layering boundary. `reasoning_engine` holds this handle's in-memory
// ReasoningSession registry (used by both its own sessions and the
// AnalysisEngine it owns internally); it persists for the handle's
// lifetime but is NEVER persisted to the repository itself -- a fresh
// oep_runtime_impl always starts with zero reasoning sessions.
// WP-EKE-007 adds `analysis_engine` and `intelligence_platform`.
// `analysis_engine` is constructed from `knowledge_graph_engine` alone
// (never from `service`/`runtime` directly) -- AnalysisEngine's own
// constructor takes only a KnowledgeGraphEngine&. Note that
// `reasoning_engine` already owns its OWN internal AnalysisEngine
// instance (see reasoning_engine.hpp); this handle-level
// `analysis_engine` is a SEPARATE instance, required because
// EngineeringIntelligencePlatform's constructor takes an
// AnalysisEngine& of its own (distinct from the one ReasoningEngine
// privately owns) -- both are stateless wrappers over the same
// KnowledgeGraphEngine, so holding two instances has no behavioral
// difference. `intelligence_platform` is constructed from
// `engine_context`, `knowledge_graph_engine`, `engineering_query_engine`,
// `rules_engine`, `validation_engine`, `analysis_engine`, and
// `reasoning_engine` (never from `service`/`runtime` directly) --
// EngineeringIntelligencePlatform consumes exactly those seven,
// preserving the same layering boundary. `intelligence_platform` holds
// this handle's in-memory KnowledgeSession registry and Runtime
// Metrics; both persist for the handle's lifetime but are NEVER
// persisted to the repository itself -- a fresh oep_runtime_impl always
// starts with zero sessions and all-zero metrics.
struct oep_runtime_impl {
    explicit oep_runtime_impl(std::string foundation_version)
        : runtime(std::move(foundation_version)), service(oep::runtime::RuntimeContext(runtime, events)),
          engine_context(service), knowledge_graph_engine(engine_context),
          engineering_query_engine(knowledge_graph_engine),
          rules_engine(engine_context, knowledge_graph_engine, engineering_query_engine),
          validation_engine(engine_context, knowledge_graph_engine, engineering_query_engine, rules_engine),
          reasoning_engine(engine_context, knowledge_graph_engine, engineering_query_engine, rules_engine,
                            validation_engine),
          analysis_engine(knowledge_graph_engine),
          intelligence_platform(engine_context, knowledge_graph_engine, engineering_query_engine, rules_engine,
                                 validation_engine, analysis_engine, reasoning_engine) {}

    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext engine_context;
    oep::engine::KnowledgeGraphEngine knowledge_graph_engine;
    oep::engine::EngineeringQueryEngine engineering_query_engine;
    oep::engine::RulesEngine rules_engine;
    oep::engine::ValidationEngine validation_engine;
    oep::engine::ReasoningEngine reasoning_engine;
    oep::engine::AnalysisEngine analysis_engine;
    oep::engine::EngineeringIntelligencePlatform intelligence_platform;
};

namespace oep::api::detail {

// Copies `text` into `buffer` (of `buffer_size` bytes), truncating
// rather than overflowing, and always NUL-terminating a non-empty
// buffer.
void copy_truncated(const std::string& text, char* buffer, std::size_t buffer_size);

oep_result_t make_success_result();
oep_result_t make_error_result(oep_error_code_t code, oep_error_category_t category, const std::string& message);

// The category implied by a given code, per the mapping documented in
// oep_api.h next to oep_error_category_t.
oep_error_category_t category_for_code(oep_error_code_t code);

// Converts an internal ObjectType to its C-ABI equivalent. Both
// enumerations are kept in the same declared order deliberately.
oep_object_type_t to_capi_object_type(oep::repository::ObjectType type);

// Fills `out_object` from `object`, truncating any field that exceeds
// its fixed capacity, per oep_object_info_t's documented contract.
void populate_object_info(const oep::repository::EngineeringObject& object, oep_object_info_t* out_object);

// Converts an internal RelationshipType to its C-ABI equivalent. Both
// enumerations are kept in the same declared order deliberately.
oep_relationship_type_t to_capi_relationship_type(oep::repository::RelationshipType type);

// Fills `out_relationship` from `relationship`, truncating any field
// that exceeds its fixed capacity.
void populate_relationship_info(const oep::repository::Relationship& relationship,
                                 oep_relationship_info_t* out_relationship);

// Converts an internal MatchLocation to its C-ABI equivalent.
oep_match_location_t to_capi_match_location(oep::search::MatchLocation location);

void populate_object_search_result(const oep::search::ObjectSearchResult& result,
                                    oep_object_search_result_t* out_result);
void populate_relationship_search_result(const oep::search::RelationshipSearchResult& result,
                                          oep_relationship_search_result_t* out_result);

// Reverse of to_capi_object_type/to_capi_relationship_type, for
// mutation input (Work Package 014). Returns std::nullopt for a value
// outside the declared enum range, so an out-of-range oep_object_type_t
// / oep_relationship_type_t coming from a caller is rejected explicitly
// rather than silently mapped to a default.
std::optional<oep::repository::ObjectType> from_capi_object_type(oep_object_type_t type);
std::optional<oep::repository::RelationshipType> from_capi_relationship_type(oep_relationship_type_t type);

// Classifies a Foundation-provided error message (from
// ObjectStore/RelationshipStore, via FoundationRuntime) into an
// oep_error_code_t, by matching the small, stable set of message
// substrings those stores actually produce. Used by every object/
// relationship mutation wrapper so the classification logic lives in
// exactly one place. Defaults to OEP_ERROR_OPERATION_FAILED for any
// message that doesn't match a known pattern (e.g. a filesystem
// error), consistent with oep_runtime_open_repository's existing
// substring-based classification.
oep_error_code_t classify_mutation_error(const std::string& message);

} // namespace oep::api::detail
