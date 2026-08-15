#include "oep/engine/object_loader.hpp"

namespace oep::engine {

ObjectLoader::LoadObjectResult ObjectLoader::load_object(const std::string& object_id) {
    const auto cached = cache_.find(object_id);
    if (cached != cache_.end()) {
        return LoadObjectResult{true, "", true, cached->second};
    }

    const oep::runtime::RuntimeService::GetObjectResponse response =
        service_.get_object(oep::runtime::RuntimeService::GetObjectRequest(object_id));
    if (!response.success) {
        return LoadObjectResult{false, response.error, false, {}};
    }
    if (!response.found) {
        return LoadObjectResult{true, "", false, {}};
    }
    cache_.emplace(object_id, response.object);
    return LoadObjectResult{true, "", true, response.object};
}

ObjectLoader::LoadAllResult ObjectLoader::load_all() {
    const oep::runtime::RuntimeService::ListObjectsResponse objects_response = service_.list_objects();
    if (!objects_response.success) {
        return LoadAllResult{false, objects_response.error, {}, {}};
    }
    const oep::runtime::RuntimeService::ListRelationshipsResponse relationships_response = service_.list_relationships();
    if (!relationships_response.success) {
        return LoadAllResult{false, relationships_response.error, {}, {}};
    }

    for (const oep::repository::EngineeringObject& object : objects_response.objects) {
        cache_[object.object_id] = object;
    }

    return LoadAllResult{true, "", objects_response.objects, relationships_response.relationships};
}

void ObjectLoader::clear_cache() {
    cache_.clear();
}

} // namespace oep::engine
