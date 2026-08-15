#include "oep/engine/rule_registry.hpp"

namespace oep::engine {

bool RuleRegistry::register_rule(EngineeringRule rule) {
    const std::string id = rule.rule_id();
    if (entries_.find(id) != entries_.end()) return false;
    entries_.emplace(id, Entry{std::move(rule), true});
    return true;
}

bool RuleRegistry::remove_rule(const std::string& rule_id) {
    return entries_.erase(rule_id) != 0;
}

bool RuleRegistry::enable_rule(const std::string& rule_id) {
    const auto found = entries_.find(rule_id);
    if (found == entries_.end()) return false;
    found->second.enabled = true;
    return true;
}

bool RuleRegistry::disable_rule(const std::string& rule_id) {
    const auto found = entries_.find(rule_id);
    if (found == entries_.end()) return false;
    found->second.enabled = false;
    return true;
}

bool RuleRegistry::is_registered(const std::string& rule_id) const {
    return entries_.find(rule_id) != entries_.end();
}

bool RuleRegistry::is_enabled(const std::string& rule_id) const {
    const auto found = entries_.find(rule_id);
    return found != entries_.end() && found->second.enabled;
}

std::optional<EngineeringRule> RuleRegistry::find_rule(const std::string& rule_id) const {
    const auto found = entries_.find(rule_id);
    if (found == entries_.end()) return std::nullopt;
    return found->second.rule;
}

std::vector<EngineeringRule> RuleRegistry::all_rules() const {
    std::vector<EngineeringRule> rules;
    for (const auto& [id, entry] : entries_) {
        rules.push_back(entry.rule);
    }
    return rules;
}

std::vector<EngineeringRule> RuleRegistry::enabled_rules() const {
    std::vector<EngineeringRule> rules;
    for (const auto& [id, entry] : entries_) {
        if (entry.enabled) rules.push_back(entry.rule);
    }
    return rules;
}

std::vector<EngineeringRule> RuleRegistry::disabled_rules() const {
    std::vector<EngineeringRule> rules;
    for (const auto& [id, entry] : entries_) {
        if (!entry.enabled) rules.push_back(entry.rule);
    }
    return rules;
}

} // namespace oep::engine
