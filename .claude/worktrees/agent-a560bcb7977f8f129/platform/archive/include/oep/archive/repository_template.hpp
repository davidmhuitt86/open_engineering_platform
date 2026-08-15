#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "oep/archive/template_manifest.hpp"
#include "oep/packages/package_manager.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"

namespace oep::archive {

struct CreateTemplateResult {
    bool success = false;
    std::string error;
    TemplateManifest manifest;
};

struct ListTemplatesResult {
    bool success = false;
    std::string error;
    std::vector<TemplateManifest> templates;
};

struct InstantiateTemplateResult {
    bool success = false;
    std::string error;
};

// Captures, lists, and instantiates Repository Templates, per
// OEP-SPEC-019-REPOSITORY_TEMPLATES. A template is a single JSON file
// (`<templateId>.json`) stored under a template store directory,
// reusing the same archive JSON codec Export/Import already use — a
// template is a named, reusable archive with its own manifest, not a
// second file format.
class TemplateStore {
public:
    explicit TemplateStore(std::filesystem::path root);

    // Captures the given repository's Engineering Objects,
    // Relationships, and (if `packages` is non-null) every currently
    // Loaded package's manifest into a new template. Validates the
    // resulting manifest before writing; refuses to create an invalid
    // template.
    CreateTemplateResult create_template(const std::string& template_name, const std::string& description,
                                          const std::string& author, const std::vector<std::string>& tags,
                                          const std::string& foundation_version,
                                          const oep::repository::ObjectStore& objects,
                                          const oep::repository::RelationshipStore& relationships,
                                          const oep::packages::PackageManager* packages) const;

    // Enumerates every template stored under `root`, validating each
    // manifest; a template that fails validation is excluded and
    // reported in `error` rather than silently skipped or crashing.
    ListTemplatesResult list_templates() const;

    // Instantiates the template `template_id` into a brand-new
    // repository at `destination`, named `new_repository_name`.
    // Validates the template's manifest and content before writing
    // anything; an invalid template is never instantiated. Objects and
    // Relationships keep their exact identifiers from the template;
    // the new repository gets a freshly generated repository ID.
    InstantiateTemplateResult instantiate_template(const std::string& template_id,
                                                    const std::filesystem::path& destination,
                                                    const std::string& new_repository_name) const;

private:
    std::filesystem::path root_;
    std::filesystem::path path_for(const std::string& template_id) const;
};

} // namespace oep::archive
