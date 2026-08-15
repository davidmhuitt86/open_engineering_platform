#include "oep/archive/template_manifest.hpp"

#include <regex>

namespace oep::archive {

namespace {
const std::regex kSemanticVersionPattern("^[0-9]+\\.[0-9]+\\.[0-9]+$");
}

std::vector<std::string> validate_template_manifest(const TemplateManifest& manifest) {
    std::vector<std::string> errors;

    if (manifest.template_id.empty()) {
        errors.push_back("templateId is required");
    }
    if (manifest.template_name.empty()) {
        errors.push_back("templateName is required");
    }
    if (!std::regex_match(manifest.version, kSemanticVersionPattern)) {
        errors.push_back("version must be in the form major.minor.patch");
    }
    if (manifest.foundation_version.empty()) {
        errors.push_back("foundationVersion is required");
    }

    return errors;
}

} // namespace oep::archive
