#include "oep/engine/query_types.hpp"

#include <sstream>

namespace oep::engine {

std::string to_string(QueryCategory category) {
    switch (category) {
        case QueryCategory::Object: return "Object";
        case QueryCategory::Relationship: return "Relationship";
        case QueryCategory::Domain: return "Domain";
        case QueryCategory::Type: return "Type";
        case QueryCategory::Dependency: return "Dependency";
        case QueryCategory::Neighborhood: return "Neighborhood";
        case QueryCategory::Path: return "Path";
        case QueryCategory::Reference: return "Reference";
        case QueryCategory::Metadata: return "Metadata";
        case QueryCategory::Composite: return "Composite";
    }
    return "Unknown";
}

std::string to_string(TraversalStrategy strategy) {
    switch (strategy) {
        case TraversalStrategy::None: return "None";
        case TraversalStrategy::BreadthFirst: return "BreadthFirst";
        case TraversalStrategy::DepthFirst: return "DepthFirst";
    }
    return "Unknown";
}

std::string cache_key(const QueryRequest& request) {
    std::ostringstream out;
    out << to_string(request.category()) << '|' << request.primary_object_id() << '|' << request.secondary_object_id()
        << '|';
    const QueryFilter& filter = request.filter();
    out << (filter.object_type.has_value() ? oep::repository::to_string(*filter.object_type) : "") << '|';
    out << filter.domain.value_or("") << '|';
    out << (filter.relationship_type.has_value() ? oep::repository::to_string(*filter.relationship_type) : "") << '|';
    out << filter.publisher_id.value_or("") << '|';
    out << filter.package_id.value_or("") << '|';
    for (const std::string& tag : filter.tags) {
        out << tag << ',';
    }
    out << '|';
    out << (filter.max_depth.has_value() ? std::to_string(*filter.max_depth) : "") << '|';
    out << (filter.outgoing_only.has_value() ? (*filter.outgoing_only ? "out" : "in") : "both");
    return out.str();
}

} // namespace oep::engine
