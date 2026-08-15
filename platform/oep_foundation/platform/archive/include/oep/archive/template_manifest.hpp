#pragma once

#include <string>
#include <vector>

namespace oep::archive {

// Describes a Repository Template, per OEP-SPEC-019-REPOSITORY_TEMPLATES.
struct TemplateManifest {
    std::string template_id;
    std::string template_name;
    std::string version = "1.0.0";
    std::string description;
    std::string author;
    std::vector<std::string> tags;
    std::string foundation_version;
};

// Validates required fields and version format. Templates are
// validated by this both before creation and before instantiation —
// an invalid template is never instantiated.
std::vector<std::string> validate_template_manifest(const TemplateManifest& manifest);

} // namespace oep::archive
