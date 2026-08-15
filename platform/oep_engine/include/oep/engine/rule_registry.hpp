#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "oep/engine/rule_types.hpp"

namespace oep::engine {

// WP-EKE-004's Rule Registry: holds loaded EngineeringRule values plus
// an enabled/disabled flag per rule. Pure in-memory bookkeeping -- no
// persistence, no Foundation access.
class RuleRegistry {
public:
    // Registers `rule`, enabled by default. Fails (returns false,
    // registers nothing) if `rule.rule_id()` is already registered --
    // re-registering the same id requires remove_rule() first.
    bool register_rule(EngineeringRule rule);

    bool remove_rule(const std::string& rule_id);

    // Fail (return false) if `rule_id` is not registered.
    bool enable_rule(const std::string& rule_id);
    bool disable_rule(const std::string& rule_id);

    bool is_registered(const std::string& rule_id) const;
    bool is_enabled(const std::string& rule_id) const;
    std::optional<EngineeringRule> find_rule(const std::string& rule_id) const;

    // All sorted by rule_id -- determinism.
    std::vector<EngineeringRule> all_rules() const;
    std::vector<EngineeringRule> enabled_rules() const;
    std::vector<EngineeringRule> disabled_rules() const;

    std::size_t count() const { return entries_.size(); }

private:
    struct Entry {
        EngineeringRule rule;
        bool enabled = true;
    };
    std::map<std::string, Entry> entries_;
};

} // namespace oep::engine
