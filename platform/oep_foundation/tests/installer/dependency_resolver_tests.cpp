#include "oep/installer/dependency_resolver.hpp"

#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

using oep::installer::DependencyDeclaration;
using oep::installer::DependencyState;
using oep::installer::DependencyResolutionResult;
using oep::installer::InstalledPackageSnapshot;

DependencyDeclaration dependency(const std::string& package_id, const std::string& constraint = "",
                                  bool optional = false) {
    DependencyDeclaration declaration;
    declaration.package_id = package_id;
    declaration.version_constraint = constraint;
    declaration.optional = optional;
    return declaration;
}

InstalledPackageSnapshot installed(const std::string& package_id, const std::string& version,
                                    std::vector<DependencyDeclaration> dependencies = {}) {
    InstalledPackageSnapshot snapshot;
    snapshot.package_id = package_id;
    snapshot.version = version;
    snapshot.dependencies = std::move(dependencies);
    return snapshot;
}

void test_resolves_with_no_dependencies() {
    const auto report = oep::installer::resolve_dependencies("com.example.a", "1.0.0", {}, {});
    check(report.result == DependencyResolutionResult::Resolved, "a package with no dependencies always resolves");
    check(report.install_order == std::vector<std::string>{"com.example.a"},
          "the install order is just the candidate when it has no dependencies");
    check(!report.cycle.has_value(), "no cycle is reported when there are no dependencies");
}

void test_satisfied_dependency() {
    const std::vector<InstalledPackageSnapshot> installed_set = {installed("com.example.b", "2.1.0")};
    const auto report =
        oep::installer::resolve_dependencies("com.example.a", "1.0.0", {dependency("com.example.b", ">=2.0.0")}, installed_set);
    check(report.result == DependencyResolutionResult::Resolved, "a satisfied required dependency resolves");
    check(report.entries.size() == 1 && report.entries[0].state == DependencyState::Satisfied,
          "the dependency entry is marked Satisfied");
    check(report.missing_required.empty() && report.conflicting.empty(),
          "no missing or conflicting packages are reported");
    check(report.install_order == (std::vector<std::string>{"com.example.b", "com.example.a"}),
          "the install order places the dependency before the candidate");
}

void test_missing_required_dependency_fails() {
    const auto report =
        oep::installer::resolve_dependencies("com.example.a", "1.0.0", {dependency("com.example.b", ">=1.0.0")}, {});
    check(report.result == DependencyResolutionResult::Failed, "a missing required dependency fails resolution");
    check(report.entries[0].state == DependencyState::Missing, "the entry is marked Missing");
    check(report.missing_required == std::vector<std::string>{"com.example.b"},
          "the missing package is named in missing_required");
    check(report.install_order.empty(), "install_order is empty for a failed resolution");
    check(!report.errors.empty(), "a failed resolution carries at least one error");
}

void test_missing_optional_dependency_does_not_fail() {
    const auto report = oep::installer::resolve_dependencies(
        "com.example.a", "1.0.0", {dependency("com.example.b", ">=1.0.0", /*optional=*/true)}, {});
    check(report.result == DependencyResolutionResult::Resolved, "a missing OPTIONAL dependency does not block resolution");
    check(report.entries[0].state == DependencyState::Optional, "the entry is marked Optional");
    check(report.missing_required.empty(), "an optional dependency never appears in missing_required");
}

void test_version_conflict_fails() {
    const std::vector<InstalledPackageSnapshot> installed_set = {installed("com.example.b", "1.0.0")};
    const auto report =
        oep::installer::resolve_dependencies("com.example.a", "1.0.0", {dependency("com.example.b", ">=2.0.0")}, installed_set);
    check(report.result == DependencyResolutionResult::Failed, "an unsatisfied version constraint fails resolution");
    check(report.entries[0].state == DependencyState::Conflicting, "the entry is marked Conflicting");
    check(report.conflicting == std::vector<std::string>{"com.example.b"},
          "the conflicting package is named in `conflicting`");
}

void test_malformed_constraint_reports_unknown() {
    const std::vector<InstalledPackageSnapshot> installed_set = {installed("com.example.b", "1.0.0")};
    const auto report =
        oep::installer::resolve_dependencies("com.example.a", "1.0.0", {dependency("com.example.b", "??nonsense")}, installed_set);
    check(report.result == DependencyResolutionResult::Failed, "a malformed constraint fails resolution");
    check(report.entries[0].state == DependencyState::Unknown, "the entry is marked Unknown");
}

void test_direct_cycle_two_packages() {
    // A (candidate) requires B; B (installed) requires A.
    const std::vector<InstalledPackageSnapshot> installed_set = {
        installed("com.example.b", "1.0.0", {dependency("com.example.a")}),
    };
    const auto report =
        oep::installer::resolve_dependencies("com.example.a", "1.0.0", {dependency("com.example.b")}, installed_set);
    check(report.result == DependencyResolutionResult::Failed, "a two-package cycle fails resolution");
    check(report.cycle.has_value(), "a cycle is reported");
    if (report.cycle.has_value()) {
        check(report.cycle->chain.front() == report.cycle->chain.back(),
              "the reported cycle chain starts and ends at the same package");
        check(report.cycle->chain.size() == 3, "a two-node cycle's chain has 3 entries (A, B, A)");
    }
    check(report.install_order.empty(), "install_order is empty when a cycle is detected");
}

void test_three_package_cycle_matches_pkg004_example() {
    // PKG-004 §10's own example: A requires B, B requires C, C requires A.
    const std::vector<InstalledPackageSnapshot> installed_set = {
        installed("B", "1.0.0", {dependency("C")}),
        installed("C", "1.0.0", {dependency("A")}),
    };
    const auto report = oep::installer::resolve_dependencies("A", "1.0.0", {dependency("B")}, installed_set);
    check(report.result == DependencyResolutionResult::Failed, "the PKG-004 §10 three-package cycle fails resolution");
    check(report.cycle.has_value(), "the three-package cycle is detected");
    if (report.cycle.has_value()) {
        check(report.cycle->chain.size() == 4, "a three-node cycle's chain has 4 entries (A, B, C, A)");
        check(report.cycle->chain.front() == "A" && report.cycle->chain.back() == "A",
              "the cycle chain both starts and ends at the candidate");
    }
}

void test_diamond_dependency_resolves_deterministically() {
    // A depends on B and C; both B and C depend on D. No cycle.
    const std::vector<InstalledPackageSnapshot> installed_set = {
        installed("B", "1.0.0", {dependency("D")}),
        installed("C", "1.0.0", {dependency("D")}),
        installed("D", "1.0.0"),
    };
    const auto report = oep::installer::resolve_dependencies("A", "1.0.0", {dependency("B"), dependency("C")}, installed_set);
    check(report.result == DependencyResolutionResult::Resolved, "a diamond dependency graph (no cycle) resolves");
    check(report.install_order.back() == "A", "the candidate is always last in the install order");
    check(report.install_order.front() == "D", "the shared transitive dependency comes first");

    // Determinism: running it again produces the exact same order.
    const auto report2 = oep::installer::resolve_dependencies("A", "1.0.0", {dependency("B"), dependency("C")}, installed_set);
    check(report.install_order == report2.install_order, "resolving the same inputs twice produces the same order");
}

void test_cycle_through_an_already_installed_optional_back_reference() {
    // B is already installed with an OPTIONAL dependency on A (A did not
    // exist when B was installed, which is exactly why the back-
    // reference had to be optional). Now resolving A, which requires B,
    // must still detect the cycle A -> B -> A: an optional edge on the
    // INSTALLED side still represents a real circular relationship, even
    // though it did not block B's own earlier install. This is also the
    // only way a required cycle can ever be constructed one
    // single-package install at a time (see
    // tests/runtime/dependency_resolution_integration_tests.cpp for the
    // full end-to-end version of this scenario).
    const std::vector<InstalledPackageSnapshot> installed_set = {
        installed("B", "1.0.0", {dependency("A", "", /*optional=*/true)}),
    };
    const auto report = oep::installer::resolve_dependencies("A", "1.0.0", {dependency("B")}, installed_set);
    check(report.result == DependencyResolutionResult::Failed,
          "a cycle reachable only through an installed package's OPTIONAL back-reference is still detected");
    check(report.cycle.has_value(), "the cycle is reported");
    if (report.cycle.has_value()) {
        check(report.cycle->chain == (std::vector<std::string>{"A", "B", "A"}),
              "the cycle chain is exactly A -> B -> A");
    }
}

void test_no_self_dependency_false_positive() {
    // A depends on B; B has no dependencies. Must NOT be reported as a
    // cycle just because DFS starts and ends its walk at A.
    const std::vector<InstalledPackageSnapshot> installed_set = {installed("B", "1.0.0")};
    const auto report = oep::installer::resolve_dependencies("A", "1.0.0", {dependency("B")}, installed_set);
    check(report.result == DependencyResolutionResult::Resolved, "a simple acyclic dependency is not mistaken for a cycle");
    check(!report.cycle.has_value(), "no cycle is reported for a simple linear dependency");
}

} // namespace

int main() {
    test_resolves_with_no_dependencies();
    test_satisfied_dependency();
    test_missing_required_dependency_fails();
    test_missing_optional_dependency_does_not_fail();
    test_version_conflict_fails();
    test_malformed_constraint_reports_unknown();
    test_direct_cycle_two_packages();
    test_three_package_cycle_matches_pkg004_example();
    test_cycle_through_an_already_installed_optional_back_reference();
    test_diamond_dependency_resolves_deterministically();
    test_no_self_dependency_false_positive();

    if (g_failures == 0) {
        std::cout << "All dependency_resolver tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " dependency_resolver test(s) failed.\n";
    return 1;
}
