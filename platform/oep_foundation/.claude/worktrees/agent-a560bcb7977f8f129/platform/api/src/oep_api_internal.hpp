#pragma once

// Private implementation details for oep_api.cpp. Never installed or
// exposed to API consumers — the public ABI is oep_api.h alone.

#include <algorithm>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

#include "oep/api/oep_api.h"
#include "oep/runtime/foundation_runtime.hpp"

// The concrete type behind the opaque OEP_Runtime handle. Applications
// only ever see a pointer to this type as `struct oep_runtime_impl*`;
// its layout is never part of the ABI contract.
struct oep_runtime_impl {
    explicit oep_runtime_impl(std::string foundation_version) : runtime(std::move(foundation_version)) {}

    oep::runtime::FoundationRuntime runtime;
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
