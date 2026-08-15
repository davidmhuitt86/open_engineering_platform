#include "rules_command.hpp"

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>

#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/rule_types.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Mirrors engine_command.cpp's OpenedEngine, plus `rules`
// (oep::engine::RulesEngine, constructed from `context`/`kge`/`eqe` --
// never from `service`/`runtime` directly, per WP-EKE-004's layering
// requirement). `rules` starts with an EMPTY Rule Registry every time
// -- see this file's header doc comment.
struct OpenedRulesEngine {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;
    oep::engine::RulesEngine rules;

    explicit OpenedRulesEngine(const std::string& foundation_version)
        : runtime(foundation_version), service(oep::runtime::RuntimeContext(runtime, events)), context(service),
          kge(context), eqe(kge), rules(context, kge, eqe) {}
};

std::unique_ptr<OpenedRulesEngine> open_repository(const std::filesystem::path& repository_path) {
    auto engine = std::make_unique<OpenedRulesEngine>(kFoundationVersion);
    engine->runtime.initialize();

    const oep::runtime::RuntimeResult opened = engine->runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    return engine;
}

// Opens the repository and gets the Knowledge Graph fully ready for
// rule evaluation (RulesEngine::graph_ready() requires BOTH
// EngineeringContext::load_graph() and KnowledgeGraphEngine::build_graph()
// to have already succeeded). Returns nullptr (having already printed a
// descriptive error) on failure.
std::unique_ptr<OpenedRulesEngine> open_and_ready_for_evaluation(const std::filesystem::path& repository_path) {
    std::unique_ptr<OpenedRulesEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return nullptr;

    const oep::engine::EngineeringContext::LoadGraphResult loaded = engine->context.load_graph();
    if (!loaded.success) {
        std::cerr << "oep: could not load the Runtime Graph: " << loaded.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    const oep::engine::KnowledgeGraphEngine::BuildResult built = engine->kge.build_graph();
    if (!built.success) {
        std::cerr << "oep: could not build the Knowledge Graph: " << built.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    return engine;
}

void print_diagnostics(const std::vector<oep::engine::RuleDiagnostic>& diagnostics) {
    if (diagnostics.empty()) {
        std::cout << "  (none)\n";
        return;
    }
    for (const oep::engine::RuleDiagnostic& diagnostic : diagnostics) {
        std::cout << "  ";
        if (!diagnostic.object_id.empty()) std::cout << "[" << diagnostic.object_id << "] ";
        std::cout << diagnostic.detail << "\n";
    }
}

void print_affected_objects(const std::vector<std::string>& object_ids) {
    if (object_ids.empty()) {
        std::cout << "  (none)\n";
        return;
    }
    for (const std::string& id : object_ids) {
        std::cout << "  " << id << "\n";
    }
}

std::optional<oep::engine::RuleCategory> category_from_string(const std::string& value) {
    if (value == "Structural") return oep::engine::RuleCategory::Structural;
    if (value == "Connectivity") return oep::engine::RuleCategory::Connectivity;
    if (value == "Dependency") return oep::engine::RuleCategory::Dependency;
    if (value == "Reference") return oep::engine::RuleCategory::Reference;
    if (value == "Documentation") return oep::engine::RuleCategory::Documentation;
    if (value == "Metadata") return oep::engine::RuleCategory::Metadata;
    if (value == "Package") return oep::engine::RuleCategory::Package;
    return std::nullopt;
}

std::optional<oep::engine::RuleSeverity> severity_from_string(const std::string& value) {
    if (value == "Info") return oep::engine::RuleSeverity::Info;
    if (value == "Warning") return oep::engine::RuleSeverity::Warning;
    if (value == "Error") return oep::engine::RuleSeverity::Error;
    if (value == "Critical") return oep::engine::RuleSeverity::Critical;
    return std::nullopt;
}

std::optional<oep::engine::RuleConditionKind> condition_kind_from_string(const std::string& value) {
    if (value == "RequiresRelationship") return oep::engine::RuleConditionKind::RequiresRelationship;
    if (value == "ForbidsRelationship") return oep::engine::RuleConditionKind::ForbidsRelationship;
    if (value == "MinRelationshipCount") return oep::engine::RuleConditionKind::MinRelationshipCount;
    if (value == "MaxRelationshipCount") return oep::engine::RuleConditionKind::MaxRelationshipCount;
    if (value == "RequiresTag") return oep::engine::RuleConditionKind::RequiresTag;
    if (value == "ForbidsTag") return oep::engine::RuleConditionKind::ForbidsTag;
    if (value == "HasDescription") return oep::engine::RuleConditionKind::HasDescription;
    if (value == "HasAuthor") return oep::engine::RuleConditionKind::HasAuthor;
    if (value == "NoCycles") return oep::engine::RuleConditionKind::NoCycles;
    if (value == "NoIsolatedObjects") return oep::engine::RuleConditionKind::NoIsolatedObjects;
    return std::nullopt;
}

const char* kRegisterUsage =
    "Usage: oep rules register --id <rule-id> --name <name> --category <RuleCategory> --severity <RuleSeverity> "
    "--scope-type <AllObjects|ByObjectType|ByDomain|ByPackage|SingleObject> [--scope-value <value>] "
    "--condition-kind <RuleConditionKind> [--relationship-type <RelationshipType>] [--tag <tag>] [--count <n>] "
    "--message <message> [--recommendation <text>] [--description <text>] [--evaluate] [--repository <path>]\n"
    "Note: registers a SINGLE-CONDITION rule (a deliberate subset of the full multi-condition data model) "
    "and, because the registry is not persisted across CLI invocations, the rule only exists for the "
    "remainder of THIS invocation -- pass --evaluate to build the Knowledge Graph and evaluate the rule "
    "immediately in the same process.";

void print_evaluation_result(const oep::engine::RuleEvaluationResult& result) {
    std::cout << "Status: " << oep::engine::to_string(result.status()) << "\n";
    std::cout << "Message: " << result.message() << "\n";
    std::cout << "Affected objects (" << result.affected_objects().size() << "):\n";
    print_affected_objects(result.affected_objects());
    std::cout << "Diagnostics (" << result.diagnostics().size() << "):\n";
    print_diagnostics(result.diagnostics());
}

void print_rule(const oep::engine::EngineeringRule& rule) {
    std::cout << "Rule ID: " << rule.rule_id() << "\n";
    std::cout << "Name: " << rule.name() << "\n";
    std::cout << "Description: " << rule.description() << "\n";
    std::cout << "Category: " << oep::engine::to_string(rule.category()) << "\n";
    std::cout << "Severity: " << oep::engine::to_string(rule.severity()) << "\n";
    std::cout << "Scope kind: ";
    switch (rule.scope().kind) {
        case oep::engine::RuleScopeKind::AllObjects: std::cout << "AllObjects"; break;
        case oep::engine::RuleScopeKind::ByObjectType: std::cout << "ByObjectType"; break;
        case oep::engine::RuleScopeKind::ByDomain: std::cout << "ByDomain"; break;
        case oep::engine::RuleScopeKind::ByPackage: std::cout << "ByPackage"; break;
        case oep::engine::RuleScopeKind::SingleObject: std::cout << "SingleObject"; break;
    }
    std::cout << "\n";
    std::cout << "Conditions (" << rule.conditions().size() << "):\n";
    if (rule.conditions().empty()) {
        std::cout << "  (none)\n";
    } else {
        for (const oep::engine::RuleCondition& condition : rule.conditions()) {
            std::cout << "  " << oep::engine::to_string(condition.kind) << "\n";
        }
    }
    std::cout << "Message: " << rule.message() << "\n";
    std::cout << "Recommendation: " << rule.recommendation() << "\n";
}

} // namespace

std::string RulesCommand::name() const {
    return "rules";
}

std::string RulesCommand::description() const {
    return "Register and evaluate data-driven Engineering Rules (WP-EKE-004) against the Knowledge Graph: "
           "list, register, enable, disable, evaluate, info";
}

int RulesCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'rules' requires a subcommand (list, register, enable, disable, evaluate, info)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "list") return list(rest);
    if (subcommand == "register") return register_rule(rest);
    if (subcommand == "enable") return enable(rest);
    if (subcommand == "disable") return disable(rest);
    if (subcommand == "evaluate") return evaluate(rest);
    if (subcommand == "info") return info(rest);

    std::cerr << "oep: unknown 'rules' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int RulesCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedRulesEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    // A fresh CLI invocation's Rule Registry is always empty -- see
    // this file's header doc comment. This subcommand's value is
    // mainly diagnostic: confirming the registry starts empty, and as
    // a building block for a future long-lived engine process /
    // rule-loading mechanism.
    const std::vector<oep::engine::EngineeringRule> enabled = engine->rules.enabled_rules();
    const std::vector<oep::engine::EngineeringRule> disabled = engine->rules.disabled_rules();
    std::cout << "Enabled rules (" << enabled.size() << "):\n";
    for (const oep::engine::EngineeringRule& rule : enabled) {
        std::cout << "  " << rule.rule_id() << "\n";
    }
    if (enabled.empty()) std::cout << "  (none)\n";
    std::cout << "Disabled rules (" << disabled.size() << "):\n";
    for (const oep::engine::EngineeringRule& rule : disabled) {
        std::cout << "  " << rule.rule_id() << "\n";
    }
    if (disabled.empty()) std::cout << "  (none)\n";

    engine->runtime.shutdown();
    return 0;
}

int RulesCommand::register_rule(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const bool do_evaluate = extract_flag(remaining, "--evaluate");

    std::optional<std::string> id_value;
    std::optional<std::string> name_value;
    std::optional<std::string> description_value;
    std::optional<std::string> category_value;
    std::optional<std::string> severity_value;
    std::optional<std::string> scope_type_value;
    std::optional<std::string> scope_value_value;
    std::optional<std::string> condition_kind_value;
    std::optional<std::string> relationship_type_value;
    std::optional<std::string> tag_value;
    std::optional<int> count_value;
    std::optional<std::string> message_value;
    std::optional<std::string> recommendation_value;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--id" && has_value) {
            id_value = remaining[++i];
        } else if (flag == "--name" && has_value) {
            name_value = remaining[++i];
        } else if (flag == "--description" && has_value) {
            description_value = remaining[++i];
        } else if (flag == "--category" && has_value) {
            category_value = remaining[++i];
        } else if (flag == "--severity" && has_value) {
            severity_value = remaining[++i];
        } else if (flag == "--scope-type" && has_value) {
            scope_type_value = remaining[++i];
        } else if (flag == "--scope-value" && has_value) {
            scope_value_value = remaining[++i];
        } else if (flag == "--condition-kind" && has_value) {
            condition_kind_value = remaining[++i];
        } else if (flag == "--relationship-type" && has_value) {
            relationship_type_value = remaining[++i];
        } else if (flag == "--tag" && has_value) {
            tag_value = remaining[++i];
        } else if (flag == "--count" && has_value) {
            const std::string& value = remaining[++i];
            char* end = nullptr;
            const long parsed = std::strtol(value.c_str(), &end, 10);
            if (end == value.c_str() || *end != '\0') {
                std::cerr << "oep: '--count' requires an integer\n";
                return 1;
            }
            count_value = static_cast<int>(parsed);
        } else if (flag == "--message" && has_value) {
            message_value = remaining[++i];
        } else if (flag == "--recommendation" && has_value) {
            recommendation_value = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << kRegisterUsage << "\n";
            return 1;
        }
    }

    if (!id_value.has_value() || !name_value.has_value() || !category_value.has_value() ||
        !severity_value.has_value() || !scope_type_value.has_value() || !condition_kind_value.has_value() ||
        !message_value.has_value()) {
        std::cerr << "oep: 'rules register' requires --id, --name, --category, --severity, --scope-type, "
                     "--condition-kind, and --message\n";
        std::cerr << kRegisterUsage << "\n";
        return 1;
    }

    const std::optional<oep::engine::RuleCategory> category = category_from_string(*category_value);
    if (!category.has_value()) {
        std::cerr << "oep: unrecognized --category '" << *category_value << "'\n";
        return 1;
    }
    const std::optional<oep::engine::RuleSeverity> severity = severity_from_string(*severity_value);
    if (!severity.has_value()) {
        std::cerr << "oep: unrecognized --severity '" << *severity_value << "'\n";
        return 1;
    }
    const std::optional<oep::engine::RuleConditionKind> condition_kind = condition_kind_from_string(*condition_kind_value);
    if (!condition_kind.has_value()) {
        std::cerr << "oep: unrecognized --condition-kind '" << *condition_kind_value << "'\n";
        return 1;
    }

    oep::engine::RuleScope scope;
    if (*scope_type_value == "AllObjects") {
        scope.kind = oep::engine::RuleScopeKind::AllObjects;
    } else if (*scope_type_value == "ByObjectType") {
        scope.kind = oep::engine::RuleScopeKind::ByObjectType;
        if (!scope_value_value.has_value()) {
            std::cerr << "oep: --scope-type ByObjectType requires --scope-value <ObjectType>\n";
            return 1;
        }
        const std::optional<oep::repository::ObjectType> object_type =
            oep::repository::object_type_from_string(*scope_value_value);
        if (!object_type.has_value()) {
            std::cerr << "oep: unrecognized object type '" << *scope_value_value << "'\n";
            return 1;
        }
        scope.object_type = *object_type;
    } else if (*scope_type_value == "ByDomain") {
        scope.kind = oep::engine::RuleScopeKind::ByDomain;
        if (!scope_value_value.has_value()) {
            std::cerr << "oep: --scope-type ByDomain requires --scope-value <domain>\n";
            return 1;
        }
        scope.domain = *scope_value_value;
    } else if (*scope_type_value == "ByPackage") {
        scope.kind = oep::engine::RuleScopeKind::ByPackage;
        if (!scope_value_value.has_value()) {
            std::cerr << "oep: --scope-type ByPackage requires --scope-value <package-id>\n";
            return 1;
        }
        scope.package_id = *scope_value_value;
    } else if (*scope_type_value == "SingleObject") {
        scope.kind = oep::engine::RuleScopeKind::SingleObject;
        if (!scope_value_value.has_value()) {
            std::cerr << "oep: --scope-type SingleObject requires --scope-value <object-id>\n";
            return 1;
        }
        scope.object_id = *scope_value_value;
    } else {
        std::cerr << "oep: unrecognized --scope-type '" << *scope_type_value << "'\n";
        return 1;
    }

    oep::engine::RuleCondition condition;
    condition.kind = *condition_kind;
    if (relationship_type_value.has_value()) {
        const std::optional<oep::repository::RelationshipType> relationship_type =
            oep::repository::relationship_type_from_string(*relationship_type_value);
        if (!relationship_type.has_value()) {
            std::cerr << "oep: unrecognized relationship type '" << *relationship_type_value << "'\n";
            return 1;
        }
        condition.relationship_type = *relationship_type;
    }
    if (tag_value.has_value()) {
        condition.tag = *tag_value;
    }
    if (count_value.has_value()) {
        condition.count = *count_value;
    }

    oep::engine::EngineeringRule rule(*id_value, *name_value, description_value.value_or(""), *category, *severity,
                                       scope, std::vector<oep::engine::RuleCondition>{condition}, *message_value,
                                       recommendation_value.value_or(""));

    if (do_evaluate) {
        const std::unique_ptr<OpenedRulesEngine> engine = open_and_ready_for_evaluation(repository_path);
        if (engine == nullptr) return 1;

        if (!engine->rules.register_rule(rule)) {
            std::cerr << "oep: rule_id '" << *id_value << "' is already registered\n";
            engine->runtime.shutdown();
            return 1;
        }
        std::cout << "Rule '" << *id_value << "' registered (single invocation only; not persisted).\n";

        const std::optional<oep::engine::RuleEvaluationResult> result = engine->rules.evaluate_rule(*id_value);
        if (!result.has_value()) {
            std::cerr << "oep: internal error -- just-registered rule not found\n";
            engine->runtime.shutdown();
            return 1;
        }
        print_evaluation_result(*result);

        engine->runtime.shutdown();
        return result->status() == oep::engine::RuleEvaluationStatus::Passed ? 0 : 1;
    }

    const std::unique_ptr<OpenedRulesEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    if (!engine->rules.register_rule(rule)) {
        std::cerr << "oep: rule_id '" << *id_value << "' is already registered\n";
        engine->runtime.shutdown();
        return 1;
    }
    std::cout << "Rule '" << *id_value << "' registered (single invocation only; not persisted). Pass --evaluate "
                 "to also evaluate it immediately.\n";

    engine->runtime.shutdown();
    return 0;
}

int RulesCommand::enable(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'rules enable' requires a rule ID\n";
        std::cerr << "Usage: oep rules enable <rule-id> [--repository <path>]\n";
        return 1;
    }
    const std::string rule_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedRulesEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    // See this file's header doc comment: a fresh invocation's registry
    // is always empty, so this will always fail unless a future
    // rule-loading mechanism pre-populates it.
    if (!engine->rules.enable_rule(rule_id)) {
        std::cerr << "oep: rule_id '" << rule_id
                   << "' is not registered (the Rule Registry is process-local and not persisted -- "
                      "register it first with 'oep rules register' in the same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    std::cout << "Rule '" << rule_id << "' enabled.\n";
    engine->runtime.shutdown();
    return 0;
}

int RulesCommand::disable(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'rules disable' requires a rule ID\n";
        std::cerr << "Usage: oep rules disable <rule-id> [--repository <path>]\n";
        return 1;
    }
    const std::string rule_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedRulesEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    if (!engine->rules.disable_rule(rule_id)) {
        std::cerr << "oep: rule_id '" << rule_id
                   << "' is not registered (the Rule Registry is process-local and not persisted -- "
                      "register it first with 'oep rules register' in the same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    std::cout << "Rule '" << rule_id << "' disabled.\n";
    engine->runtime.shutdown();
    return 0;
}

int RulesCommand::evaluate(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'rules evaluate' requires a rule ID\n";
        std::cerr << "Usage: oep rules evaluate <rule-id> [--repository <path>]\n";
        std::cerr << "Note: use 'oep rules register --id <rule-id> ... --evaluate' to register and evaluate a "
                     "rule in one invocation (see 'oep rules register' usage) -- a bare 'oep rules evaluate' "
                     "only finds rules registered earlier in THIS SAME process, which a separate CLI "
                     "invocation can never be.\n";
        return 1;
    }
    const std::string rule_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedRulesEngine> engine = open_and_ready_for_evaluation(repository_path);
    if (engine == nullptr) return 1;

    const std::optional<oep::engine::RuleEvaluationResult> result = engine->rules.evaluate_rule(rule_id);
    if (!result.has_value()) {
        std::cerr << "oep: rule_id '" << rule_id
                   << "' is not registered (the Rule Registry is process-local and not persisted -- "
                      "register it first with 'oep rules register' in the same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    print_evaluation_result(*result);

    engine->runtime.shutdown();
    return result->status() == oep::engine::RuleEvaluationStatus::Passed ? 0 : 1;
}

int RulesCommand::info(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'rules info' requires a rule ID\n";
        std::cerr << "Usage: oep rules info <rule-id> [--repository <path>]\n";
        return 1;
    }
    const std::string rule_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedRulesEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    std::optional<oep::engine::EngineeringRule> found;
    for (const oep::engine::EngineeringRule& rule : engine->rules.all_rules()) {
        if (rule.rule_id() == rule_id) {
            found = rule;
            break;
        }
    }
    if (!found.has_value()) {
        std::cerr << "oep: rule_id '" << rule_id
                   << "' is not registered (the Rule Registry is process-local and not persisted -- "
                      "register it first with 'oep rules register' in the same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    print_rule(*found);

    engine->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
