#include "oep/engine/validation_types.hpp"

namespace oep::engine {

std::string to_string(ValidationProfile profile) {
    switch (profile) {
        case ValidationProfile::Structural: return "Structural";
        case ValidationProfile::Connectivity: return "Connectivity";
        case ValidationProfile::Documentation: return "Documentation";
        case ValidationProfile::Metadata: return "Metadata";
        case ValidationProfile::Complete: return "Complete";
    }
    return "Unknown";
}

std::string to_string(ValidationTargetKind kind) {
    switch (kind) {
        case ValidationTargetKind::SingleObject: return "SingleObject";
        case ValidationTargetKind::MultipleObjects: return "MultipleObjects";
        case ValidationTargetKind::EngineeringContext: return "EngineeringContext";
        case ValidationTargetKind::Package: return "Package";
        case ValidationTargetKind::QueryResult: return "QueryResult";
    }
    return "Unknown";
}

ValidationTarget ValidationTarget::for_object(std::string object_id) {
    return ValidationTarget(ValidationTargetKind::SingleObject, std::vector<std::string>{std::move(object_id)}, "");
}

ValidationTarget ValidationTarget::for_objects(std::vector<std::string> object_ids) {
    return ValidationTarget(ValidationTargetKind::MultipleObjects, std::move(object_ids), "");
}

ValidationTarget ValidationTarget::for_context() {
    return ValidationTarget(ValidationTargetKind::EngineeringContext, {}, "");
}

ValidationTarget ValidationTarget::for_package(std::string package_id) {
    return ValidationTarget(ValidationTargetKind::Package, {}, std::move(package_id));
}

ValidationTarget ValidationTarget::for_query_result(std::vector<std::string> object_ids) {
    return ValidationTarget(ValidationTargetKind::QueryResult, std::move(object_ids), "");
}

} // namespace oep::engine
