#include "oep/engine/reasoning_types.hpp"

namespace oep::engine {

std::string to_string(EvidenceKind kind) {
    switch (kind) {
        case EvidenceKind::Object: return "Object";
        case EvidenceKind::Relationship: return "Relationship";
        case EvidenceKind::QueryExecution: return "QueryExecution";
        case EvidenceKind::RuleEvaluation: return "RuleEvaluation";
        case EvidenceKind::ValidationFinding: return "ValidationFinding";
    }
    return "Unknown";
}

std::string to_string(RecommendationKind kind) {
    switch (kind) {
        case RecommendationKind::RelatedProcedure: return "RelatedProcedure";
        case RecommendationKind::SimilarComponent: return "SimilarComponent";
        case RecommendationKind::AdditionalInspection: return "AdditionalInspection";
        case RecommendationKind::ConnectedSystem: return "ConnectedSystem";
        case RecommendationKind::FollowUpValidation: return "FollowUpValidation";
    }
    return "Unknown";
}

} // namespace oep::engine
