#pragma once

#include <map>
#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/runtime/runtime_service.hpp"

namespace oep::engine {

// WP-EKE-001's Engineering Object Loader. Consumes the Foundation
// Runtime EXCLUSIVELY through oep::runtime::RuntimeService — never
// through FoundationRuntime's object_store()/relationship_store()
// accessors directly, and never by opening or reading repository files
// itself. ObjectLoader implements no persistence: every load is a
// read-through against RuntimeService (and, since WP-REP-006,
// ultimately FoundationRuntime's already-open repository), cached here
// only for the lifetime of this ObjectLoader instance.
class ObjectLoader {
public:
    explicit ObjectLoader(oep::runtime::RuntimeService& service) : service_(service) {}

    struct LoadObjectResult {
        bool success = false;
        std::string error;
        bool found = false;
        oep::repository::EngineeringObject object;
    };

    // Lazy loading: returns the cached object if this loader has
    // already fetched it; otherwise fetches it via RuntimeService and
    // caches the result (even a "not found" answer is cached as a
    // negative result implicitly by not re-querying success but simply
    // returning found == false each time, since a not-found id is cheap
    // to re-check and this loader does not assume the repository never
    // changes underneath it).
    LoadObjectResult load_object(const std::string& object_id);

    struct LoadAllResult {
        bool success = false;
        std::string error;
        std::vector<oep::repository::EngineeringObject> objects;
        std::vector<oep::repository::Relationship> relationships;
    };

    // Batch loading / graph hydration: fetches every object and
    // relationship currently in the open repository via RuntimeService,
    // populating this loader's cache with every object returned.
    LoadAllResult load_all();

    void clear_cache();
    std::size_t cached_object_count() const { return cache_.size(); }

private:
    oep::runtime::RuntimeService& service_;
    std::map<std::string, oep::repository::EngineeringObject> cache_;
};

} // namespace oep::engine
