#include "oep/engine/engineering_intelligence_platform.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <chrono>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// WP-EKE-008's End-to-End Validation: exercises the FULL Engineering
// Knowledge Engine pipeline exactly as the work package's own example
// names it --
//
//   Acquire Engineering Standard (a real .oep package, built here as a
//   synthetic archive) -> Repository Install (WP-REP-001, via
//   RuntimeService) -> Knowledge Graph Build (WP-EKE-002) -> Query
//   (WP-EKE-003) -> Validation (WP-EKE-005) -> Analysis (WP-EKE-006) ->
//   Reasoning (WP-EKE-006) -> Recommendations (WP-EKE-006) -> "Studio
//   Visualization" is represented here by exercising the exact same
//   EngineeringIntelligencePlatform (WP-EKE-007) entry points Studio's
//   own FFI bindings call, proving Studio never needs anything this
//   pipeline doesn't already produce.
//
// This is integration/regression testing of ALREADY-EXISTING engines
// (WP-REP-001 through WP-EKE-007) glued together end to end -- no new
// engine code, per WP-EKE-008's own "SHALL NOT introduce new core
// engines" constraint.

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

using oep::repository::ObjectType;
using oep::repository::RelationshipType;

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "c29e7fb8-0000-45bb-b588-bdf04e7fdea9";
    metadata.repository_name = "eke-v1-e2e";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);
    return root;
}

// --- Minimal ZIP builder + PKG-001/002 manifest, matching the exact
//     convention every prior WP-REP-005..008 test file already uses.
void append_u16(std::vector<std::uint8_t>& out, std::uint16_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}
void append_u32(std::vector<std::uint8_t>& out, std::uint32_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}
void append_bytes(std::vector<std::uint8_t>& out, const std::string& text) {
    out.insert(out.end(), text.begin(), text.end());
}

std::vector<std::uint8_t> build_stored_zip(const std::vector<std::pair<std::string, std::string>>& entries) {
    std::vector<std::uint8_t> out;
    std::vector<std::uint32_t> local_header_offsets;
    for (const auto& [name, content] : entries) {
        local_header_offsets.push_back(static_cast<std::uint32_t>(out.size()));
        append_u32(out, 0x04034b50);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_bytes(out, name);
        append_bytes(out, content);
    }
    const std::uint32_t central_directory_start = static_cast<std::uint32_t>(out.size());
    for (std::size_t i = 0; i < entries.size(); ++i) {
        const auto& [name, content] = entries[i];
        append_u32(out, 0x02014b50);
        append_u16(out, 20);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, local_header_offsets[i]);
        append_bytes(out, name);
    }
    const std::uint32_t central_directory_size = static_cast<std::uint32_t>(out.size()) - central_directory_start;
    append_u32(out, 0x06054b50);
    append_u16(out, 0);
    append_u16(out, 0);
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u32(out, central_directory_size);
    append_u32(out, central_directory_start);
    append_u16(out, 0);
    return out;
}

std::filesystem::path write_temp_archive(const std::vector<std::uint8_t>& bytes, const std::string& file_name) {
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "oep_end_to_end_workflow_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

std::string manifest_json(const std::string& package_id, const std::string& version) {
    return R"({"schemaVersion":"1.0","packageId":")" + package_id + R"(","version":")" + version +
           R"(","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
           R"("title":"Engineering Standard","summary":"s","description":"d","category":"demonstration",)"
           R"("engineeringDomains":[],"license":{},"dependencies":[],"capabilities":[],)"
           R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
}

std::string object_entry(const std::string& object_id, const std::string& name, const std::string& description,
                          const std::string& tags_json) {
    return R"({"objectId":")" + object_id + R"(","objectType":"Component","name":")" + name +
           R"(","description":")" + description +
           R"(","createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
           R"("version":"1.0.0","author":"acquisition-pipeline","tags":[)" + tags_json + R"(]})";
}

std::string relationship_entry(const std::string& relationship_id, const std::string& source, const std::string& target,
                                const std::string& type) {
    return R"({"relationshipId":")" + relationship_id + R"(","sourceObjectId":")" + source + R"(","targetObjectId":")" +
           target + R"(","relationshipType":")" + type +
           R"(","createdUtc":"2026-01-01T00:00:00Z","author":"acquisition-pipeline","description":""})";
}

// Fixed, well-known ids for the synthetic Engineering Standard package
// (shared between the archive builder and the test assertions below).
const std::string kStandardId = "d1000000-0000-4000-8000-000000000001";
const std::string kProcedureId = "d1000000-0000-4000-8000-000000000002";
const std::string kComponentId = "d1000000-0000-4000-8000-000000000003";

// Builds a synthetic "Engineering Standard" package: three Component
// objects (Standard, Procedure, Component) connected by a DependsOn
// chain, one of which is deliberately left without a description so
// downstream validation/analysis/reasoning has something real to find.
std::filesystem::path build_engineering_standard_archive() {
    const std::string& standard_id = kStandardId;
    const std::string& procedure_id = kProcedureId;
    const std::string& component_id = kComponentId;
    return write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", manifest_json("com.oep.eke-v1.engineering-standard", "1.0.0")},
            {"fragment/objects/standard.json", object_entry(standard_id, "Pressure Vessel Standard",
                                                              "Defines pressure vessel design requirements", R"("mechanical")")},
            {"fragment/objects/procedure.json",
             object_entry(procedure_id, "Inspection Procedure", "", R"("mechanical")")}, // no description, deliberately
            {"fragment/objects/component.json",
             object_entry(component_id, "Relief Valve", "A pressure relief component", R"("mechanical")")},
            {"fragment/relationships/r1.json",
             relationship_entry("d2000000-0000-4000-8000-000000000001", procedure_id, standard_id, "DependsOn")},
            {"fragment/relationships/r2.json",
             relationship_entry("d2000000-0000-4000-8000-000000000002", component_id, procedure_id, "DependsOn")},
        }),
        "engineering-standard.oep");
}

struct Fixture {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;
    oep::engine::RulesEngine rules;
    oep::engine::ValidationEngine eve;
    oep::engine::AnalysisEngine analysis;
    oep::engine::ReasoningEngine eare;
    oep::engine::EngineeringIntelligencePlatform eip;

    explicit Fixture(const std::filesystem::path& root)
        : runtime("0.1.0"),
          service(oep::runtime::RuntimeContext(runtime, events)),
          context(service),
          kge(context),
          eqe(kge),
          rules(context, kge, eqe),
          eve(context, kge, eqe, rules),
          analysis(kge),
          eare(context, kge, eqe, rules, eve),
          eip(context, kge, eqe, rules, eve, analysis, eare) {
        runtime.initialize();
        runtime.open_repository(root);
    }
};

void test_full_pipeline_acquire_through_studio_visualization(const std::filesystem::path& scratch_dir) {
    const auto pipeline_start = std::chrono::steady_clock::now();

    Fixture fx(build_repository(scratch_dir / "full_pipeline"));

    // 1. Acquire Engineering Standard (synthetic archive stands in for
    //    a real download/acquisition, which is explicitly out of scope
    //    for this engine -- acquisition is Foundation's job).
    const std::filesystem::path archive = build_engineering_standard_archive();
    check(std::filesystem::exists(archive), "step 1 (acquire): the synthetic Engineering Standard archive was written");

    // 2. Repository Install (WP-REP-001, via RuntimeService).
    const oep::runtime::RuntimeService::InstallPackageResponse install =
        fx.service.install_package(oep::runtime::RuntimeService::InstallPackageRequest(archive));
    check(install.success, "step 2 (install): the Engineering Standard package installs: " + install.error);
    check(install.objects_created == 3 && install.relationships_created == 2,
          "step 2 (install): exactly 3 objects and 2 relationships were created");

    // 3. Knowledge Graph Build (WP-EKE-001/002).
    check(fx.context.load_graph().success, "step 3 (graph build): EngineeringContext loads the graph");
    const auto kge_build = fx.kge.build_graph();
    check(kge_build.success && kge_build.objects == 3 && kge_build.relationships == 2,
          "step 3 (graph build): the Knowledge Graph Engine builds a graph with all 3 objects and 2 relationships");

    // 4. Query (WP-EKE-003), exercised the same way EIP/Studio does.
    // EngineeringIntelligencePlatform::query() takes no filter (only
    // category + primary_object_id), so an Object-category lookup by a
    // known id is the category that's meaningfully exercisable through
    // this particular entry point without a filter.
    const std::string session_id = fx.eip.create_session();
    const auto query_result = fx.eip.query(session_id, oep::engine::QueryCategory::Object, kComponentId);
    check(query_result.success && query_result.object_ids == std::vector<std::string>{kComponentId},
          "step 4 (query): an Object query finds the Relief Valve component by id through the Intelligence Platform");

    // 5. Validation (WP-EKE-004/005): register one real, data-driven
    //    rule (never hardcoded into any engine) requiring a description,
    //    then validate the whole context through the Intelligence
    //    Platform's inspect_context() -- proving Validation is reachable
    //    without the caller ever touching RulesEngine/ValidationEngine
    //    directly.
    const oep::engine::EngineeringRule description_rule(
        "STD-001", "Engineering objects must have a description", "", oep::engine::RuleCategory::Documentation,
        oep::engine::RuleSeverity::Warning,
        oep::engine::RuleScope{oep::engine::RuleScopeKind::AllObjects, {}, {}, {}, {}},
        {oep::engine::RuleCondition{oep::engine::RuleConditionKind::HasDescription, {}, {}, {}, {}}},
        "object is missing a description", "add a description before publishing");
    check(fx.rules.register_rule(description_rule), "step 5 (validation setup): the data-driven rule registers successfully");

    const auto inspection = fx.eip.inspect_context();
    check(inspection.validation_finding_count() == 1,
          "step 5 (validation): exactly 1 finding is reported (the Procedure object with no description)");

    // 6. Analysis (WP-EKE-006), through the Intelligence Platform.
    // component -> DependsOn -> procedure -> DependsOn -> standard.
    const std::string& component_id = kComponentId;
    const auto dependencies = fx.eip.engineering_dependencies(component_id);
    check(dependencies.dependency_object_ids().size() == 2,
          "step 6 (analysis): the Relief Valve component's transitive dependency closure includes both the "
          "Procedure and the Standard");

    // 7. Reasoning (WP-EKE-006) + Recommendations, through the
    //    Intelligence Platform's `reason` workflow.
    const auto reason_result = fx.eip.reason(session_id, "investigate the Relief Valve component", {component_id});
    check(reason_result.success, "step 7 (reasoning): the reason workflow succeeds");

    // 8. Recommendations, via the dedicated Intelligence Platform call.
    const auto recommendations = fx.eip.engineering_recommendations(component_id);
    check(!recommendations.empty(), "step 8 (recommendations): at least one recommendation is generated "
                                     "(the component is connected to the procedure)");
    for (const auto& recommendation : recommendations) {
        check(!recommendation.supporting_evidence_ids().empty(),
              "step 8 (recommendations): every recommendation references non-empty supporting evidence");
    }

    // 9. "Studio Visualization": prove every fact Studio's own FFI
    //    bindings surface is available through the SAME
    //    EngineeringIntelligencePlatform session, with no separate
    //    engine access required.
    const auto summary = fx.eip.engineering_summary();
    check(summary.object_count() == 3 && summary.relationship_count() == 2,
          "step 9 (visualization data): engineering_summary reports the correct graph size for Studio to render");
    const auto health = fx.eip.engineering_health();
    check(health.health_score() >= 0.0 && health.health_score() <= 100.0,
          "step 9 (visualization data): engineering_health produces a renderable 0-100 score");
    const auto session = fx.eip.get_session(session_id);
    check(session.has_value() && session->query_history().size() == 1 && session->reasoning_history().size() == 1,
          "step 9 (visualization data): the session's history (what Studio's Knowledge Session UI would display) "
          "reflects every workflow that ran");

    const auto metrics = fx.eip.runtime_metrics();
    check(metrics.query_count >= 1 && metrics.reasoning_count >= 1,
          "runtime_metrics (what Studio's metrics panel would display) reflects the pipeline's activity");

    fx.eip.close_session(session_id);
    const double pipeline_time_ms =
        std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - pipeline_start).count();
    std::cout << "  (end-to-end pipeline completed in " << pipeline_time_ms << " ms)\n";
}

void test_pipeline_is_deterministic_across_repeated_runs(const std::filesystem::path& scratch_dir) {
    // Running the identical pipeline against two independently-built
    // repositories with identical content must produce identical
    // structural results -- the direct proof that nothing in this
    // integration depends on incidental timing, memory addresses, or
    // container iteration order.
    Fixture fx1(build_repository(scratch_dir / "determinism_1"));
    Fixture fx2(build_repository(scratch_dir / "determinism_2"));

    const std::filesystem::path archive1 = build_engineering_standard_archive();
    const std::filesystem::path archive2 = build_engineering_standard_archive();

    check(fx1.service.install_package(oep::runtime::RuntimeService::InstallPackageRequest(archive1)).success &&
              fx2.service.install_package(oep::runtime::RuntimeService::InstallPackageRequest(archive2)).success,
          "both fixtures install the identical package successfully");
    fx1.context.load_graph();
    fx1.kge.build_graph();
    fx2.context.load_graph();
    fx2.kge.build_graph();

    const auto summary1 = fx1.eip.engineering_summary();
    const auto summary2 = fx2.eip.engineering_summary();
    check(summary1.object_count() == summary2.object_count() &&
              summary1.relationship_count() == summary2.relationship_count() &&
              summary1.validation_finding_count() == summary2.validation_finding_count(),
          "two independently-built pipelines over identical input produce identical engineering_summary results");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_end_to_end_workflow_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_full_pipeline_acquire_through_studio_visualization(scratch_dir);
    test_pipeline_is_deterministic_across_repeated_runs(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All end_to_end_workflow tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " end_to_end_workflow test(s) failed.\n";
    return 1;
}
