#include "oep/installer/oep_package_manifest.hpp"

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

// A minimal, PKG-002 §5-complete manifest — the same shape
// `oep_exchange/packages/manifest/src/parse-manifest.ts`'s own tests use,
// so this module's acceptance criteria mirror that implementation's.
const char* kValidManifest = R"({
  "schemaVersion": "1.0",
  "packageId": "com.oep.demo.engineering-showcase",
  "version": "1.0.0",
  "publisher": {"id": "demo-publisher", "name": "OEP Demo Publisher"},
  "title": "Engineering Demo Package",
  "summary": "A minimal demonstration package.",
  "description": "Built to demonstrate the OEP package format.",
  "category": "demonstration",
  "engineeringDomains": ["Automotive", "Electrical"],
  "license": {},
  "dependencies": [],
  "capabilities": [],
  "repository": {},
  "statistics": {},
  "signatures": {},
  "build": {}
})";

void test_parses_a_valid_manifest() {
    const oep::installer::ParseManifestResult result = oep::installer::parse_oep_package_manifest(kValidManifest);
    check(result.success, "a complete PKG-002 manifest parses successfully");
    check(result.errors.empty(), "a valid manifest has no errors");
    check(result.manifest.package_id == "com.oep.demo.engineering-showcase", "packageId is read correctly");
    check(result.manifest.version == "1.0.0", "version is read correctly");
    check(result.manifest.publisher_id == "demo-publisher", "publisher.id is read correctly");
    check(result.manifest.publisher_name == "OEP Demo Publisher", "publisher.name is read correctly");
    check(result.manifest.title == "Engineering Demo Package", "title is read correctly");
    check(result.manifest.engineering_domains.size() == 2, "engineeringDomains is read correctly (WP-REP-002)");
    check(result.manifest.engineering_domains[0] == "Automotive", "engineeringDomains preserves array order");
}

void test_rejects_malformed_json() {
    const oep::installer::ParseManifestResult result = oep::installer::parse_oep_package_manifest("{not json");
    check(!result.success, "malformed JSON is rejected");
    check(!result.errors.empty(), "malformed JSON produces at least one error");
}

void test_rejects_a_non_object_manifest() {
    const oep::installer::ParseManifestResult result = oep::installer::parse_oep_package_manifest("[1,2,3]");
    check(!result.success, "a JSON array is rejected (must be an object)");
}

void test_rejects_a_manifest_missing_a_required_field() {
    // Same as kValidManifest but with "packageId" removed.
    const char* manifest = R"({
      "schemaVersion": "1.0",
      "version": "1.0.0",
      "publisher": {"id": "demo-publisher", "name": "OEP Demo Publisher"},
      "title": "t", "summary": "s", "description": "d", "category": "c",
      "engineeringDomains": [], "license": {}, "dependencies": [], "capabilities": [],
      "repository": {}, "statistics": {}, "signatures": {}, "build": {}
    })";
    const oep::installer::ParseManifestResult result = oep::installer::parse_oep_package_manifest(manifest);
    check(!result.success, "a manifest missing packageId is rejected");
    bool mentions_package_id = false;
    for (const std::string& error : result.errors) {
        if (error.find("packageId") != std::string::npos) mentions_package_id = true;
    }
    check(mentions_package_id, "the rejection names the missing field");
}

void test_rejects_a_manifest_with_wrong_field_types() {
    // engineeringDomains as a string instead of an array; publisher as a string instead of an object.
    const char* manifest = R"({
      "schemaVersion": "1.0", "packageId": "com.example.x", "version": "1.0.0",
      "publisher": "not-an-object",
      "title": "t", "summary": "s", "description": "d", "category": "c",
      "engineeringDomains": "not-an-array", "license": {}, "dependencies": [], "capabilities": [],
      "repository": {}, "statistics": {}, "signatures": {}, "build": {}
    })";
    const oep::installer::ParseManifestResult result = oep::installer::parse_oep_package_manifest(manifest);
    check(!result.success, "wrong field types are rejected");
    check(result.errors.size() >= 2, "both type mismatches (publisher, engineeringDomains) are reported");
}

void test_rejects_missing_publisher_id_and_name() {
    const char* manifest = R"({
      "schemaVersion": "1.0", "packageId": "com.example.x", "version": "1.0.0",
      "publisher": {},
      "title": "t", "summary": "s", "description": "d", "category": "c",
      "engineeringDomains": [], "license": {}, "dependencies": [], "capabilities": [],
      "repository": {}, "statistics": {}, "signatures": {}, "build": {}
    })";
    const oep::installer::ParseManifestResult result = oep::installer::parse_oep_package_manifest(manifest);
    check(!result.success, "a publisher object missing id/name is rejected");
    check(result.errors.size() == 2, "both publisher.id and publisher.name are reported missing");
}

} // namespace

int main() {
    test_parses_a_valid_manifest();
    test_rejects_malformed_json();
    test_rejects_a_non_object_manifest();
    test_rejects_a_manifest_missing_a_required_field();
    test_rejects_a_manifest_with_wrong_field_types();
    test_rejects_missing_publisher_id_and_name();

    if (g_failures == 0) {
        std::cout << "All OepPackageManifest tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " OepPackageManifest test(s) failed.\n";
    return 1;
}
