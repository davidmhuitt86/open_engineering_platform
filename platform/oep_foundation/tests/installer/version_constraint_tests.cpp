#include "oep/installer/version_constraint.hpp"

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

bool satisfies(const std::string& version, const std::string& constraint) {
    const oep::installer::ConstraintCheckResult result = oep::installer::version_satisfies(version, constraint);
    return result.success && result.satisfied;
}

void test_parse_semantic_version() {
    const oep::installer::ParseVersionResult full = oep::installer::parse_semantic_version("1.2.3");
    check(full.success && full.version.major == 1 && full.version.minor == 2 && full.version.patch == 3,
          "parses a full major.minor.patch version");

    const oep::installer::ParseVersionResult major_only = oep::installer::parse_semantic_version("2");
    check(major_only.success && major_only.version.major == 2 && major_only.version.minor == 0 &&
              major_only.version.patch == 0,
          "a bare major version defaults minor/patch to 0");

    const oep::installer::ParseVersionResult with_suffix = oep::installer::parse_semantic_version("1.2.3-beta.1+build.5");
    check(with_suffix.success && with_suffix.version.patch == 3,
          "a pre-release/build suffix is accepted (and ignored) rather than rejected");

    const oep::installer::ParseVersionResult malformed = oep::installer::parse_semantic_version("not-a-version");
    check(!malformed.success, "a non-numeric version is rejected");
}

void test_compare_semantic_versions() {
    using oep::installer::SemanticVersion;
    check(oep::installer::compare_semantic_versions({1, 0, 0}, {1, 0, 0}) == 0, "equal versions compare equal");
    check(oep::installer::compare_semantic_versions({1, 0, 0}, {2, 0, 0}) < 0, "major version dominates comparison");
    check(oep::installer::compare_semantic_versions({1, 5, 0}, {1, 4, 9}) > 0, "minor version compared when major is equal");
    check(oep::installer::compare_semantic_versions({1, 0, 1}, {1, 0, 2}) < 0, "patch version compared last");
}

void test_empty_constraint_always_satisfied() {
    check(satisfies("1.0.0", ""), "an empty constraint is always satisfied (PKG-002 'any version')");
}

void test_exact_and_comparison_operators() {
    check(satisfies("1.2.3", "1.2.3"), "a bare version means an exact match");
    check(satisfies("1.2.3", "=1.2.3"), "explicit '=' matches exactly");
    check(!satisfies("1.2.4", "=1.2.3"), "'=' rejects a different version");
    check(satisfies("1.2.4", "!=1.2.3"), "'!=' accepts a different version");
    check(!satisfies("1.2.3", "!=1.2.3"), "'!=' rejects the same version");
    check(satisfies("2.0.0", ">1.5.0"), "'>' accepts a strictly greater version");
    check(!satisfies("1.5.0", ">1.5.0"), "'>' rejects an equal version");
    check(satisfies("1.5.0", ">=1.5.0"), "'>=' accepts an equal version");
    check(satisfies("1.4.0", "<1.5.0"), "'<' accepts a strictly lesser version");
    check(satisfies("1.5.0", "<=1.5.0"), "'<=' accepts an equal version");
}

void test_compatible_tilde_operator() {
    check(satisfies("1.2.3", "~1.2.3"), "~1.2.3 accepts the exact version");
    check(satisfies("1.2.9", "~1.2.3"), "~1.2.3 accepts a higher patch");
    check(!satisfies("1.3.0", "~1.2.3"), "~1.2.3 rejects a higher minor");
    check(!satisfies("1.2.2", "~1.2.3"), "~1.2.3 rejects a lower patch");
}

void test_caret_operator() {
    check(satisfies("1.9.9", "^1.2.3"), "^1.2.3 accepts a higher minor/patch within major 1");
    check(!satisfies("2.0.0", "^1.2.3"), "^1.2.3 rejects a higher major");
    check(!satisfies("1.2.2", "^1.2.3"), "^1.2.3 rejects a lower patch");

    // 0.x special case: caret is much stricter for major == 0.
    check(satisfies("0.2.9", "^0.2.3"), "^0.2.3 accepts a higher patch within the same 0.x minor");
    check(!satisfies("0.3.0", "^0.2.3"), "^0.2.3 rejects a higher minor when major is 0");
}

void test_version_range() {
    check(satisfies("1.5.0", ">=1.0.0 <2.0.0"), "a space-separated range ANDs its atoms");
    check(!satisfies("2.0.0", ">=1.0.0 <2.0.0"), "a version outside the range is rejected");
}

void test_malformed_constraint_reports_error_not_false() {
    const oep::installer::ConstraintCheckResult result = oep::installer::version_satisfies("1.0.0", "??1.0.0");
    check(!result.success, "a malformed constraint reports success == false, distinct from 'not satisfied'");
    check(!result.error.empty(), "a malformed constraint carries a human-readable error");
}

} // namespace

int main() {
    test_parse_semantic_version();
    test_compare_semantic_versions();
    test_empty_constraint_always_satisfied();
    test_exact_and_comparison_operators();
    test_compatible_tilde_operator();
    test_caret_operator();
    test_version_range();
    test_malformed_constraint_reports_error_not_false();

    if (g_failures == 0) {
        std::cout << "All version_constraint tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " version_constraint test(s) failed.\n";
    return 1;
}
