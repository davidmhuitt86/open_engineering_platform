#include "template_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string TemplateCommand::name() const {
    return "template";
}

std::string TemplateCommand::description() const {
    return "Create, list, and instantiate Repository Templates";
}

int TemplateCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'template' requires a subcommand (create, list, instantiate)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "create") return create(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "instantiate") return instantiate(rest);

    std::cerr << "oep: unknown 'template' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int TemplateCommand::create(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::filesystem::path templates_dir = extract_path_option(remaining, "--templates-dir");
    const bool include_packages = extract_flag(remaining, "--include-packages");

    std::string template_name;
    std::string description;
    std::string author;
    std::string tags_csv;

    for (std::size_t i = 0; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--name" && has_value) {
            template_name = remaining[++i];
        } else if (flag == "--description" && has_value) {
            description = remaining[++i];
        } else if (flag == "--author" && has_value) {
            author = remaining[++i];
        } else if (flag == "--tags" && has_value) {
            tags_csv = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << "Usage: oep template create --name <name> [--description <text>] [--author <name>] "
                         "[--tags a,b,c] [--include-packages] [--repository <path>] [--templates-dir <path>]\n";
            return 1;
        }
    }

    if (template_name.empty()) {
        std::cerr << "oep: 'template create' requires --name\n";
        return 1;
    }

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::runtime::RuntimeCreateTemplateResult result = runtime.create_template(
        templates_dir, template_name, description, author, split_csv(tags_csv), include_packages);
    if (!result.success) {
        std::cerr << "oep: could not create template: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Created template '" << result.manifest.template_id << "' ('" << result.manifest.template_name
               << "')\n";

    runtime.shutdown();
    return 0;
}

int TemplateCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path templates_dir = extract_path_option(remaining, "--templates-dir");

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeListTemplatesResult result = runtime.list_templates(templates_dir);
    if (!result.success) {
        std::cerr << "oep: could not list templates: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    if (result.templates.empty()) {
        std::cout << "No templates found.\n";
    } else {
        for (const oep::archive::TemplateManifest& manifest : result.templates) {
            std::cout << manifest.template_id << "\t" << manifest.template_name << "\t" << manifest.version << "\n";
        }
    }

    runtime.shutdown();
    return 0;
}

int TemplateCommand::instantiate(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path templates_dir = extract_path_option(remaining, "--templates-dir");

    if (remaining.size() < 2) {
        std::cerr << "oep: 'template instantiate' requires a template ID and a new repository name\n";
        std::cerr << "Usage: oep template instantiate <template-id> <new-repository-name> "
                     "[--templates-dir <path>]\n";
        return 1;
    }
    const std::string& template_id = remaining[0];
    const std::string& new_repository_name = remaining[1];
    const std::filesystem::path destination = std::filesystem::current_path() / new_repository_name;

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeInstantiateTemplateResult result =
        runtime.instantiate_template(templates_dir, template_id, destination, new_repository_name);
    if (!result.success) {
        std::cerr << "oep: could not instantiate template: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Instantiated template '" << template_id << "' as repository '" << new_repository_name << "' at "
               << destination.string() << "\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
