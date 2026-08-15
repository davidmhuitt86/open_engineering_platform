#include "intelligence_common.hpp"

#include <iostream>

#include "foundation_version.hpp"

namespace oep::cli::commands {

std::unique_ptr<OpenedIntelligencePlatform> open_intelligence_platform(const std::filesystem::path& repository_path) {
    auto platform = std::make_unique<OpenedIntelligencePlatform>(kFoundationVersion);
    platform->runtime.initialize();

    const oep::runtime::RuntimeResult opened = platform->runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        platform->runtime.shutdown();
        return nullptr;
    }

    return platform;
}

std::unique_ptr<OpenedIntelligencePlatform> open_and_ready_intelligence_platform(
    const std::filesystem::path& repository_path) {
    std::unique_ptr<OpenedIntelligencePlatform> platform = open_intelligence_platform(repository_path);
    if (platform == nullptr) return nullptr;

    const oep::engine::EngineeringContext::LoadGraphResult loaded = platform->context.load_graph();
    if (!loaded.success) {
        std::cerr << "oep: could not load the Runtime Graph: " << loaded.error << "\n";
        platform->runtime.shutdown();
        return nullptr;
    }

    const oep::engine::KnowledgeGraphEngine::BuildResult built = platform->kge.build_graph();
    if (!built.success) {
        std::cerr << "oep: could not build the Knowledge Graph: " << built.error << "\n";
        platform->runtime.shutdown();
        return nullptr;
    }

    return platform;
}

} // namespace oep::cli::commands
