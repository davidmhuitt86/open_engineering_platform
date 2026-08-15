#include "oep/archive/repository_template.hpp"

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/metadata.hpp"

#include <filesystem>
#include <fstream>
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

void write_raw(const std::filesystem::path& path, const std::string& contents) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file << contents;
}

void test_create_list_and_instantiate(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path source_root = scratch_dir / "source";
    const oep::repository::AuditStore audit(source_root / "repository" / "audit");
    const oep::repository::ObjectStore objects(source_root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(source_root / "repository" / "relationships", objects,
                                                             audit);

    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Standard Widget";
    object.version = "1.0.0";
    const oep::repository::LoadObjectResult created = objects.create(object);
    check(created.success, "creating the sample object succeeds");

    const std::filesystem::path templates_dir = scratch_dir / "templates";
    const oep::archive::TemplateStore store(templates_dir);

    const oep::archive::CreateTemplateResult create_result =
        store.create_template("Standard Kit", "A reusable starting point", "Jane", {"starter"}, "0.1.0", objects,
                               relationships, nullptr);
    check(create_result.success, "create_template succeeds");
    check(!create_result.manifest.template_id.empty(), "create_template assigns a template ID");
    check(create_result.manifest.template_name == "Standard Kit", "the manifest reports the given name");

    const oep::archive::ListTemplatesResult list_result = store.list_templates();
    check(list_result.success, "list_templates succeeds");
    check(list_result.templates.size() == 1, "list_templates finds the created template");

    const std::filesystem::path destination = scratch_dir / "instantiated";
    const oep::archive::InstantiateTemplateResult instantiate_result =
        store.instantiate_template(create_result.manifest.template_id, destination, "new-workshop");
    check(instantiate_result.success, "instantiate_template succeeds");

    const oep::repository::LoadMetadataResult new_metadata =
        oep::repository::load_metadata(destination / "repository.json");
    check(new_metadata.success, "the instantiated repository has valid metadata");
    check(new_metadata.metadata.repository_name == "new-workshop", "the instantiated repository has the given name");
    check(new_metadata.metadata.repository_id != create_result.manifest.template_id,
          "the instantiated repository gets a fresh repository ID, not the template's ID");

    const oep::repository::AuditStore new_audit(destination / "repository" / "audit");
    const oep::repository::ObjectStore new_objects(destination / "repository" / "objects", new_audit);
    const oep::repository::LoadObjectResult reloaded = new_objects.load(created.object.object_id);
    check(reloaded.success, "the instantiated repository contains the template's object under its original ID");
    check(reloaded.object.name == "Standard Widget", "the instantiated object preserves its name");
}

void test_instantiate_rejects_nonexistent_template(const std::filesystem::path& scratch_dir) {
    const oep::archive::TemplateStore store(scratch_dir / "templates-missing");
    const oep::archive::InstantiateTemplateResult result =
        store.instantiate_template("00000000-0000-4000-8000-000000000000", scratch_dir / "dest-missing", "x");
    check(!result.success, "instantiating a nonexistent template fails");
}

void test_instantiate_rejects_invalid_template(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path templates_dir = scratch_dir / "templates-invalid";
    write_raw(templates_dir / "bad-template.json",
              "{\n"
              "  \"templateManifest\": { \"templateId\": \"bad-template\" }\n"
              "}\n");

    const oep::archive::TemplateStore store(templates_dir);
    const oep::archive::InstantiateTemplateResult result =
        store.instantiate_template("bad-template", scratch_dir / "dest-invalid", "x");
    check(!result.success, "instantiating a template with an invalid manifest fails");
    check(!std::filesystem::exists(scratch_dir / "dest-invalid" / "repository.json"),
          "an invalid template never partially creates a destination repository");
}

void test_list_excludes_invalid_templates(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path templates_dir = scratch_dir / "templates-mixed";
    write_raw(templates_dir / "corrupt.json", "not valid json");

    const oep::archive::TemplateStore store(templates_dir);
    const oep::archive::ListTemplatesResult result = store.list_templates();
    check(result.success, "list_templates succeeds even with a corrupt template file present");
    check(result.templates.empty(), "list_templates excludes the corrupt template rather than crashing");
}

void test_list_empty_directory(const std::filesystem::path& scratch_dir) {
    const oep::archive::TemplateStore store(scratch_dir / "templates-empty");
    const oep::archive::ListTemplatesResult result = store.list_templates();
    check(result.success && result.templates.empty(), "listing an empty/nonexistent templates directory succeeds");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_repository_template_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_create_list_and_instantiate(scratch_dir);
    test_instantiate_rejects_nonexistent_template(scratch_dir);
    test_instantiate_rejects_invalid_template(scratch_dir);
    test_list_excludes_invalid_templates(scratch_dir);
    test_list_empty_directory(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All repository template tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " repository template test(s) failed.\n";
    return 1;
}
