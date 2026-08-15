#include "oep/engine/intelligence_types.hpp"

namespace oep::engine {

std::string to_string(WorkflowKind kind) {
    switch (kind) {
        case WorkflowKind::Inspect: return "Inspect";
        case WorkflowKind::Query: return "Query";
        case WorkflowKind::Validate: return "Validate";
        case WorkflowKind::Analyze: return "Analyze";
        case WorkflowKind::Reason: return "Reason";
        case WorkflowKind::Recommend: return "Recommend";
    }
    return "Unknown";
}

std::string to_string(InspectionTargetKind kind) {
    switch (kind) {
        case InspectionTargetKind::Object: return "Object";
        case InspectionTargetKind::Package: return "Package";
        case InspectionTargetKind::Context: return "Context";
    }
    return "Unknown";
}

} // namespace oep::engine
