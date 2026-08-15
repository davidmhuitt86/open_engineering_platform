#include "oep/installer/dependency_resolver.hpp"

#include <algorithm>
#include <functional>
#include <map>
#include <set>

#include "oep/installer/version_constraint.hpp"

namespace oep::installer {

namespace {

// Looks up a package's declared dependency list, given either the
// candidate itself or an already-installed package. When
// `include_optional` is false, only required dependencies are returned
// (used for install-order computation -- PKG-004 §7's optional
// dependencies never force installation and are therefore never edges
// in the "what must be installed" graph). When true, every declared
// dependency is returned (used for circular-dependency detection: a
// cycle is a structural property of the FULL declared graph -- an
// already-installed package's OPTIONAL back-reference to the candidate
// still represents a real circular relationship worth surfacing, even
// though it did not itself block that package's own earlier install).
const std::vector<DependencyDeclaration>* dependencies_of(
    const std::string& package_id, const std::string& candidate_package_id,
    const std::vector<DependencyDeclaration>& candidate_dependencies,
    const std::map<std::string, InstalledPackageSnapshot>& installed_by_id, bool include_optional,
    std::vector<DependencyDeclaration>& scratch) {
    const std::vector<DependencyDeclaration>* source = nullptr;
    if (package_id == candidate_package_id) {
        source = &candidate_dependencies;
    } else {
        const auto found = installed_by_id.find(package_id);
        if (found == installed_by_id.end()) {
            return nullptr; // not installed -- a dead end, not an edge source
        }
        source = &found->second.dependencies;
    }
    if (include_optional) {
        return source;
    }
    scratch.clear();
    for (const DependencyDeclaration& dependency : *source) {
        if (!dependency.optional) {
            scratch.push_back(dependency);
        }
    }
    return &scratch;
}

// Depth-first search for a cycle reachable from `start`, following only
// required-dependency edges. `path`/`on_path` track the current DFS
// stack; successors are visited in ascending package-ID order at every
// step so the result is deterministic regardless of any incidental
// container iteration order. Returns the cycle chain (first == last) on
// success, or an empty vector if no cycle is reachable.
std::vector<std::string> find_cycle(const std::string& start, const std::string& candidate_package_id,
                                     const std::vector<DependencyDeclaration>& candidate_dependencies,
                                     const std::map<std::string, InstalledPackageSnapshot>& installed_by_id) {
    std::vector<std::string> path;
    std::set<std::string> on_path;
    std::vector<std::string> result;

    std::vector<DependencyDeclaration> scratch;

    // Explicit-stack-free recursive DFS via a small local lambda (this
    // codebase avoids clever recursion tricks elsewhere, but a bounded,
    // clearly-named recursive helper over a dependency graph -- which is
    // acyclic by construction once resolved, and whose depth is bounded
    // by the number of installed packages -- is the clearest form here).
    std::function<bool(const std::string&)> visit = [&](const std::string& node) -> bool {
        if (on_path.count(node) != 0) {
            // Found the back-edge that closes the cycle: trim `path` to
            // start at this node's first occurrence and close the loop.
            const auto start_it = std::find(path.begin(), path.end(), node);
            result.assign(start_it, path.end());
            result.push_back(node);
            return true;
        }

        // Cycle detection walks EVERY declared dependency, required or
        // optional -- see dependencies_of's own doc comment.
        const std::vector<DependencyDeclaration>* dependencies =
            dependencies_of(node, candidate_package_id, candidate_dependencies, installed_by_id,
                             /*include_optional=*/true, scratch);
        if (dependencies == nullptr) {
            return false; // unresolved/missing package: not part of any cycle
        }

        path.push_back(node);
        on_path.insert(node);

        std::vector<std::string> successors;
        for (const DependencyDeclaration& dependency : *dependencies) {
            successors.push_back(dependency.package_id);
        }
        std::sort(successors.begin(), successors.end());

        for (const std::string& successor : successors) {
            if (visit(successor)) {
                return true;
            }
        }

        path.pop_back();
        on_path.erase(node);
        return false;
    };

    visit(start);
    return result;
}

// Post-order DFS topological sort over required-dependency edges,
// restricted to nodes that are either the candidate or an installed
// package (an unresolved/missing dependency is a dead end and simply
// contributes no further edges). Deterministic: successors are always
// visited in ascending package-ID order. Assumes the graph is acyclic
// (callers only invoke this after confirming no cycle was found).
void topological_order(const std::string& node, const std::string& candidate_package_id,
                        const std::vector<DependencyDeclaration>& candidate_dependencies,
                        const std::map<std::string, InstalledPackageSnapshot>& installed_by_id,
                        std::set<std::string>& visited, std::vector<std::string>& out_order) {
    if (visited.count(node) != 0) {
        return;
    }
    visited.insert(node);

    std::vector<DependencyDeclaration> scratch;
    const std::vector<DependencyDeclaration>* dependencies = dependencies_of(
        node, candidate_package_id, candidate_dependencies, installed_by_id, /*include_optional=*/false, scratch);
    if (dependencies != nullptr) {
        std::vector<std::string> successors;
        for (const DependencyDeclaration& dependency : *dependencies) {
            successors.push_back(dependency.package_id);
        }
        std::sort(successors.begin(), successors.end());
        for (const std::string& successor : successors) {
            // Only recurse into nodes that actually resolve to
            // something installed -- an unresolved successor has no
            // dependencies of its own to contribute and is never itself
            // placed in the order (it is reported via
            // missing_required/conflicting instead).
            if (successor == candidate_package_id || installed_by_id.count(successor) != 0) {
                topological_order(successor, candidate_package_id, candidate_dependencies, installed_by_id, visited,
                                   out_order);
            }
        }
    }

    out_order.push_back(node);
}

} // namespace

std::string to_string(DependencyState state) {
    switch (state) {
        case DependencyState::Satisfied: return "Satisfied";
        case DependencyState::Missing: return "Missing";
        case DependencyState::Optional: return "Optional";
        case DependencyState::Conflicting: return "Conflicting";
        case DependencyState::Cyclic: return "Cyclic";
        case DependencyState::Unknown: return "Unknown";
    }
    return "Unknown";
}

std::string to_string(DependencyResolutionResult result) {
    switch (result) {
        case DependencyResolutionResult::Resolved: return "Resolved";
        case DependencyResolutionResult::Failed: return "Failed";
    }
    return "Failed";
}

DependencyResolutionReport resolve_dependencies(const std::string& candidate_package_id,
                                                  const std::string& candidate_version,
                                                  const std::vector<DependencyDeclaration>& candidate_dependencies,
                                                  const std::vector<InstalledPackageSnapshot>& installed_packages) {
    DependencyResolutionReport report;
    report.candidate_package_id = candidate_package_id;
    report.candidate_version = candidate_version;

    std::map<std::string, InstalledPackageSnapshot> installed_by_id;
    for (const InstalledPackageSnapshot& snapshot : installed_packages) {
        installed_by_id.emplace(snapshot.package_id, snapshot);
    }

    // Per-dependency resolution (PKG-004 §6), in declaration order.
    for (const DependencyDeclaration& dependency : candidate_dependencies) {
        DependencyResolutionEntry entry;
        entry.package_id = dependency.package_id;
        entry.version_constraint = dependency.version_constraint;
        entry.optional = dependency.optional;

        const auto found = installed_by_id.find(dependency.package_id);
        if (found == installed_by_id.end()) {
            entry.state = dependency.optional ? DependencyState::Optional : DependencyState::Missing;
            entry.detail = dependency.optional ? "not installed (optional)" : "required package is not installed";
            if (!dependency.optional) {
                report.missing_required.push_back(dependency.package_id);
                report.errors.push_back("required dependency '" + dependency.package_id + "' is not installed");
            }
        } else {
            entry.installed_version = found->second.version;
            const ConstraintCheckResult check = version_satisfies(found->second.version, dependency.version_constraint);
            if (!check.success) {
                entry.state = DependencyState::Unknown;
                entry.detail = check.error;
                report.errors.push_back("dependency '" + dependency.package_id + "': " + check.error);
            } else if (check.satisfied) {
                entry.state = DependencyState::Satisfied;
                entry.detail = "installed version " + found->second.version + " satisfies '" +
                                dependency.version_constraint + "'";
            } else {
                entry.state = DependencyState::Conflicting;
                entry.detail = "installed version " + found->second.version + " does not satisfy '" +
                                dependency.version_constraint + "'";
                report.conflicting.push_back(dependency.package_id);
                report.errors.push_back("dependency '" + dependency.package_id + "' " + entry.detail);
            }
        }
        report.entries.push_back(std::move(entry));
    }

    // Circular dependency detection (PKG-004 §10), starting from the
    // candidate -- does installing it create or reveal a cycle that
    // includes it.
    const std::vector<std::string> cycle_chain =
        find_cycle(candidate_package_id, candidate_package_id, candidate_dependencies, installed_by_id);
    if (!cycle_chain.empty()) {
        report.cycle = DependencyCycle{cycle_chain};
        for (DependencyResolutionEntry& entry : report.entries) {
            if (std::find(cycle_chain.begin(), cycle_chain.end(), entry.package_id) != cycle_chain.end()) {
                entry.state = DependencyState::Cyclic;
            }
        }
        std::string chain_description;
        for (std::size_t i = 0; i < cycle_chain.size(); ++i) {
            chain_description += cycle_chain[i];
            if (i + 1 != cycle_chain.size()) chain_description += " -> ";
        }
        report.errors.push_back("circular dependency detected: " + chain_description);
    }

    const bool has_cycle = report.cycle.has_value();
    const bool has_missing = !report.missing_required.empty();
    const bool has_conflict = !report.conflicting.empty();
    const bool has_unknown = !report.errors.empty() && !has_cycle; // malformed-constraint errors above

    if (has_cycle || has_missing || has_conflict || has_unknown) {
        report.result = DependencyResolutionResult::Failed;
        // install_order is intentionally left empty: a failed
        // resolution has no well-defined (or safe-to-act-on)
        // installation order.
    } else {
        report.result = DependencyResolutionResult::Resolved;
        std::set<std::string> visited;
        std::vector<std::string> order;
        topological_order(candidate_package_id, candidate_package_id, candidate_dependencies, installed_by_id,
                           visited, order);
        report.install_order = std::move(order);
    }

    return report;
}

} // namespace oep::installer
