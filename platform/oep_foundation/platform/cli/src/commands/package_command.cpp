#include "package_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/installer/merge_engine.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"
#include "runtime_event_log.hpp"

namespace oep::cli::commands {

namespace {

// Every subcommand below follows the same open-work-shutdown shape; this
// helper owns the lifecycle so each subcommand only implements its work.
// Mirrors how other multi-verb commands in this CLI structure their
// per-subcommand runtime usage.
template <typename Work>
int with_open_repository(const std::filesystem::path& repository_path, Work&& work) {
    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const int exit_code = work(runtime);
    runtime.shutdown();
    return exit_code;
}

void print_package_line(const oep::installer::RepositoryRegistryEntry& package) {
    std::cout << package.package_id << "\t" << package.version << "\t" << package.title << "\t"
              << package.publisher_name << "\t" << package.runtime_state << "\t" << package.object_ids.size()
              << " object(s)\t" << package.relationship_ids.size() << " relationship(s)\t" << package.installed_utc
              << "\n";
}

} // namespace

std::string PackageCommand::name() const {
    return "package";
}

std::string PackageCommand::description() const {
    return "Install and query .oep packages via the Repository Registry";
}

int PackageCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'package' requires a subcommand (install, list, info, contents, verify, locate, search, "
                      "resolve, uninstall-impact, uninstall, update-impact, update, merge-plan, merge)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "install") return install(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "info") return info(rest);
    if (subcommand == "contents") return contents(rest);
    if (subcommand == "verify") return verify(rest);
    if (subcommand == "locate") return locate(rest);
    if (subcommand == "search") return search(rest);
    if (subcommand == "resolve") return resolve(rest);
    if (subcommand == "uninstall-impact") return uninstall_impact(rest);
    if (subcommand == "uninstall") return uninstall(rest);
    if (subcommand == "update-impact") return update_impact(rest);
    if (subcommand == "update") return update(rest);
    if (subcommand == "merge-plan") return merge_plan(rest);
    if (subcommand == "merge") return merge(rest);

    std::cerr << "oep: unknown 'package' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int PackageCommand::install(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package install' requires a package archive\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_path = remaining[0];

    return with_open_repository(repository_path, [&archive_path](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive_path);
        if (!result.success) {
            // Installation is atomic since WP-REP-003 (Repository
            // Transaction Engine): a failure has already been rolled back
            // by the Runtime; nothing was installed.
            global_event_bus().publish(oep::runtime::EventType::PackageInstallFailed, archive_path.string(),
                                        result.error);
            std::cerr << "oep: install failed: " << result.error << "\n";
            return 1;
        }

        global_event_bus().publish(oep::runtime::EventType::PackageInstalled, result.package_id,
                                    "version " + result.version);

        std::cout << "Installed package '" << result.package_id << "' version " << result.version << "\n";
        std::cout << "  Objects:       " << result.objects_created << "\n";
        std::cout << "  Relationships: " << result.relationships_created << "\n";
        return 0;
    });
}

int PackageCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    return with_open_repository(repository_path, [](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeInstalledPackagesResult result = runtime.list_installed_packages();
        if (!result.success) {
            std::cerr << "oep: could not list installed packages: " << result.error << "\n";
            return 1;
        }

        if (result.packages.empty()) {
            std::cout << "No packages installed.\n";
        } else {
            for (const oep::installer::RepositoryRegistryEntry& package : result.packages) {
                print_package_line(package);
            }
        }
        return 0;
    });
}

int PackageCommand::info(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package info' requires a package id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string package_id = remaining[0];

    return with_open_repository(repository_path, [&package_id](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeInstalledPackageResult result = runtime.get_installed_package(package_id);
        if (!result.success) {
            std::cerr << "oep: could not query the Repository Registry: " << result.error << "\n";
            return 1;
        }
        if (!result.installed) {
            std::cerr << "oep: package '" << package_id << "' is not installed\n";
            return 1;
        }

        const oep::installer::RepositoryRegistryEntry& entry = result.entry;
        std::cout << "Package ID:        " << entry.package_id << "\n";
        std::cout << "Version:           " << entry.version << "\n";
        std::cout << "Title:             " << entry.title << "\n";
        std::cout << "Summary:           " << entry.summary << "\n";
        std::cout << "Category:          " << entry.category << "\n";
        std::cout << "Publisher:         " << entry.publisher_name << " (" << entry.publisher_id << ")\n";
        std::cout << "Engineering Domains:";
        if (entry.engineering_domains.empty()) {
            std::cout << " (none)";
        } else {
            for (const std::string& domain : entry.engineering_domains) {
                std::cout << " " << domain;
            }
        }
        std::cout << "\n";
        std::cout << "Runtime State:     " << entry.runtime_state << "\n";
        std::cout << "Installed:         " << entry.installed_utc << "\n";
        std::cout << "Install Source:    " << entry.source << "\n";
        std::cout << "Installation Path: " << entry.installation_path << "\n";
        std::cout << "Package Hash:      " << (entry.package_hash.empty() ? "(not recorded)" : entry.package_hash)
                  << "\n";
        std::cout << "Trust Status:      " << (entry.trust_status.empty() ? "(not recorded)" : entry.trust_status);
        if (!entry.trust_fingerprint.empty()) {
            std::cout << " (fingerprint " << entry.trust_fingerprint << ")";
        }
        std::cout << "\n";
        std::cout << "Objects:           " << entry.object_ids.size() << "\n";
        std::cout << "Relationships:     " << entry.relationship_ids.size() << "\n";
        return 0;
    });
}

int PackageCommand::contents(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package contents' requires a package id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string package_id = remaining[0];

    return with_open_repository(repository_path, [&package_id](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeInstalledPackageResult result = runtime.get_installed_package(package_id);
        if (!result.success) {
            std::cerr << "oep: could not query the Repository Registry: " << result.error << "\n";
            return 1;
        }
        if (!result.installed) {
            std::cerr << "oep: package '" << package_id << "' is not installed\n";
            return 1;
        }

        std::cout << "Engineering Objects (" << result.entry.object_ids.size() << "):\n";
        for (const std::string& object_id : result.entry.object_ids) {
            const oep::repository::LoadObjectResult loaded = runtime.object_store()->load(object_id);
            if (loaded.success) {
                std::cout << "  " << object_id << "\t" << oep::repository::to_string(loaded.object.object_type)
                          << "\t" << loaded.object.name << "\n";
            } else {
                std::cout << "  " << object_id << "\t(no longer exists — see 'oep package verify')\n";
            }
        }

        std::cout << "Relationships (" << result.entry.relationship_ids.size() << "):\n";
        for (const std::string& relationship_id : result.entry.relationship_ids) {
            const oep::repository::LoadRelationshipResult loaded =
                runtime.relationship_store()->load(relationship_id);
            if (loaded.success) {
                std::cout << "  " << relationship_id << "\t"
                          << oep::repository::to_string(loaded.relationship.relationship_type) << "\t"
                          << loaded.relationship.source_object_id << " -> " << loaded.relationship.target_object_id
                          << "\n";
            } else {
                std::cout << "  " << relationship_id << "\t(no longer exists — see 'oep package verify')\n";
            }
        }
        return 0;
    });
}

int PackageCommand::verify(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package verify' requires a package id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string package_id = remaining[0];

    return with_open_repository(repository_path, [&package_id](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeVerifyPackageResult result = runtime.verify_package(package_id);
        if (!result.success) {
            std::cerr << "oep: verify failed: " << result.error << "\n";
            return 1;
        }

        std::cout << "Verification: " << (result.verified ? "OK" : "FAILED") << "\n";
        std::cout << "  Objects:       " << result.objects_present << "/" << result.objects_expected
                  << " present\n";
        std::cout << "  Relationships: " << result.relationships_present << "/" << result.relationships_expected
                  << " present\n";
        if (result.archive_available) {
            std::cout << "  Archive:       present, hash "
                      << (result.archive_hash_matches ? "matches" : "DOES NOT MATCH") << "\n";
        } else {
            std::cout << "  Archive:       no longer present (informational)\n";
        }
        for (const std::string& finding : result.findings) {
            std::cout << "  - " << finding << "\n";
        }
        return result.verified ? 0 : 1;
    });
}

int PackageCommand::locate(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package locate' requires an object or relationship id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string entity_id = remaining[0];

    return with_open_repository(repository_path, [&entity_id](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimePackageOwnerResult result = runtime.find_package_owner(entity_id);
        if (!result.success) {
            std::cerr << "oep: locate failed: " << result.error << "\n";
            return 1;
        }
        if (result.kind == oep::installer::OwnedEntityKind::None) {
            std::cout << "No installed package owns '" << entity_id << "'.\n";
            return 0;
        }
        const char* kind_name =
            result.kind == oep::installer::OwnedEntityKind::Object ? "Engineering Object" : "Relationship";
        std::cout << kind_name << " '" << entity_id << "' was installed by:\n";
        std::cout << "  " << result.owner.package_id << " " << result.owner.version << " (" << result.owner.title
                  << ")\n";
        return 0;
    });
}

int PackageCommand::search(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package search' requires a query\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string query = remaining[0];

    return with_open_repository(repository_path, [&query](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeSearchPackagesResult result = runtime.search_installed_packages(query);
        if (!result.success) {
            std::cerr << "oep: search failed: " << result.error << "\n";
            return 1;
        }
        if (result.packages.empty()) {
            std::cout << "No installed packages match '" << query << "'.\n";
        } else {
            for (const oep::installer::RepositoryRegistryEntry& package : result.packages) {
                print_package_line(package);
            }
        }
        return 0;
    });
}

int PackageCommand::resolve(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package resolve' requires a package archive\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_path = remaining[0];

    return with_open_repository(repository_path, [&archive_path](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeDependencyResolutionResult result =
            runtime.resolve_package_dependencies(archive_path);
        if (!result.success) {
            std::cerr << "oep: could not resolve dependencies: " << result.error << "\n";
            return 1;
        }

        const oep::installer::DependencyResolutionReport& report = result.report;
        std::cout << "Package:      " << report.candidate_package_id << " " << report.candidate_version << "\n";
        std::cout << "Result:       " << oep::installer::to_string(report.result) << "\n";

        if (report.entries.empty()) {
            std::cout << "Dependencies: (none declared)\n";
        } else {
            std::cout << "Dependencies:\n";
            for (const oep::installer::DependencyResolutionEntry& entry : report.entries) {
                std::cout << "  " << entry.package_id;
                if (!entry.version_constraint.empty()) std::cout << " " << entry.version_constraint;
                std::cout << "\t" << oep::installer::to_string(entry.state);
                if (!entry.installed_version.empty()) std::cout << "\t(installed " << entry.installed_version << ")";
                if (entry.optional) std::cout << "\t[optional]";
                std::cout << "\n";
            }
        }

        if (report.cycle.has_value()) {
            std::cout << "Cycle:       ";
            for (std::size_t i = 0; i < report.cycle->chain.size(); ++i) {
                std::cout << " " << report.cycle->chain[i];
                if (i + 1 != report.cycle->chain.size()) std::cout << " ->";
            }
            std::cout << "\n";
        }

        if (!report.install_order.empty()) {
            std::cout << "Install order:";
            for (const std::string& package_id : report.install_order) {
                std::cout << " " << package_id;
            }
            std::cout << "\n";
        }

        for (const std::string& error : report.errors) {
            std::cerr << "  error: " << error << "\n";
        }
        for (const std::string& warning : report.warnings) {
            std::cerr << "  warning: " << warning << "\n";
        }

        return report.result == oep::installer::DependencyResolutionResult::Resolved ? 0 : 1;
    });
}

int PackageCommand::uninstall_impact(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package uninstall-impact' requires a package id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string package_id = remaining[0];

    // WP-REP-007: uninstall/update are routed exclusively through
    // RuntimeService, unlike install/resolve above (which predate this
    // Work Package's "exclusive entry point" requirement).
    return with_open_repository(repository_path, [&package_id](oep::runtime::FoundationRuntime& runtime) {
        oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, global_event_bus()));
        const oep::runtime::RuntimeService::UninstallImpactReport report =
            service.analyze_uninstall_impact(oep::runtime::RuntimeService::AnalyzeUninstallImpactRequest(package_id));
        if (!report.success) {
            std::cerr << "oep: could not analyze uninstall impact: " << report.error << "\n";
            return 1;
        }

        std::cout << "Package:               " << package_id << "\n";
        std::cout << "Found:                 " << (report.found ? "yes" : "no") << "\n";
        std::cout << "Objects affected:      " << report.objects_affected << "\n";
        std::cout << "Relationships affected:" << " " << report.relationships_affected << "\n";
        if (report.blocking_dependents.empty()) {
            std::cout << "Blocking dependents:   (none)\n";
        } else {
            std::cout << "Blocking dependents:\n";
            for (const std::string& dependent : report.blocking_dependents) {
                std::cout << "  " << dependent << "\n";
            }
        }
        std::cout << "Removable:             " << (report.removable ? "yes" : "no") << "\n";

        return report.removable ? 0 : 1;
    });
}

int PackageCommand::uninstall(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package uninstall' requires a package id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string package_id = remaining[0];

    return with_open_repository(repository_path, [&package_id](oep::runtime::FoundationRuntime& runtime) {
        oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, global_event_bus()));
        const oep::runtime::RuntimeService::UninstallPackageResponse result =
            service.uninstall_package(oep::runtime::RuntimeService::UninstallPackageRequest(package_id));
        if (!result.success) {
            std::cerr << "oep: uninstall failed: " << result.error << "\n";
            return 1;
        }

        std::cout << "Uninstalled package '" << result.package_id << "'\n";
        std::cout << "  Objects removed:       " << result.objects_removed << "\n";
        std::cout << "  Relationships removed: " << result.relationships_removed << "\n";
        return 0;
    });
}

int PackageCommand::update_impact(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package update-impact' requires a package archive\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_path = remaining[0];

    return with_open_repository(repository_path, [&archive_path](oep::runtime::FoundationRuntime& runtime) {
        oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, global_event_bus()));
        const oep::runtime::RuntimeService::UpdateImpactReport report =
            service.analyze_update_impact(oep::runtime::RuntimeService::AnalyzeUpdateImpactRequest(archive_path));
        if (!report.success) {
            std::cerr << "oep: could not analyze update impact: " << report.error << "\n";
            return 1;
        }

        std::cout << "Currently installed: " << (report.currently_installed ? "yes" : "no") << "\n";
        std::cout << "Current version:     "
                  << (report.current_version.empty() ? "(none)" : report.current_version) << "\n";
        std::cout << "Candidate version:   " << report.candidate_version << "\n";
        std::cout << "Trust status:        " << (report.trust_status.empty() ? "(not recorded)" : report.trust_status)
                  << "\n";
        if (report.broken_dependents.empty()) {
            std::cout << "Broken dependents:   (none)\n";
        } else {
            std::cout << "Broken dependents:\n";
            for (const std::string& dependent : report.broken_dependents) {
                std::cout << "  " << dependent << "\n";
            }
        }
        std::cout << "Updatable:           " << (report.updatable ? "yes" : "no") << "\n";

        return report.updatable ? 0 : 1;
    });
}

int PackageCommand::update(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package update' requires a package archive\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_path = remaining[0];

    return with_open_repository(repository_path, [&archive_path](oep::runtime::FoundationRuntime& runtime) {
        oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, global_event_bus()));
        const oep::runtime::RuntimeService::UpdatePackageResponse result =
            service.update_package(oep::runtime::RuntimeService::UpdatePackageRequest(archive_path));
        if (!result.success) {
            std::cerr << "oep: update failed: " << result.error << "\n";
            return 1;
        }

        std::cout << "Updated package '" << result.package_id << "' from " << result.previous_version << " to "
                  << result.new_version << "\n";
        std::cout << "  Objects removed:       " << result.objects_removed << "\n";
        std::cout << "  Relationships removed: " << result.relationships_removed << "\n";
        std::cout << "  Objects created:       " << result.objects_created << "\n";
        std::cout << "  Relationships created: " << result.relationships_created << "\n";
        std::cout << "  Trust status:          " << result.trust_status << "\n";
        return 0;
    });
}

int PackageCommand::merge_plan(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package merge-plan' requires a package archive\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_path = remaining[0];

    return with_open_repository(repository_path, [&archive_path](oep::runtime::FoundationRuntime& runtime) {
        oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, global_event_bus()));
        const oep::runtime::RuntimeService::MergePlanReport report =
            service.plan_merge(oep::runtime::RuntimeService::PlanMergeRequest(archive_path));
        if (!report.success) {
            std::cerr << "oep: could not analyze merge plan: " << report.error << "\n";
            return 1;
        }

        std::cout << "Package:                " << report.package_id << "\n";
        std::cout << "Version:                " << report.version << "\n";
        std::cout << "Trust status:           "
                  << (report.trust_status.empty() ? "(not recorded)" : report.trust_status) << "\n";
        std::cout << "Already registered:     " << (report.already_registered ? "yes" : "no") << "\n";
        std::cout << "Objects to create:      " << report.plan.change_set.object_changes().size() << "\n";
        std::cout << "Relationships to create: " << report.plan.change_set.relationship_changes().size() << "\n";
        if (report.plan.conflicts.empty()) {
            std::cout << "Conflicts:              (none)\n";
        } else {
            std::cout << "Conflicts:\n";
            for (const oep::installer::MergeConflict& conflict : report.plan.conflicts) {
                std::cout << "  " << oep::installer::to_string(conflict.kind) << " " << conflict.entity_id << ": "
                          << conflict.detail << "\n";
            }
        }
        std::cout << "Mergeable:              " << (report.mergeable ? "yes" : "no") << "\n";

        return report.mergeable ? 0 : 1;
    });
}

int PackageCommand::merge(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'package merge' requires a package archive\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_path = remaining[0];

    return with_open_repository(repository_path, [&archive_path](oep::runtime::FoundationRuntime& runtime) {
        oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, global_event_bus()));
        const oep::runtime::RuntimeService::ExecuteMergeResponse result =
            service.execute_merge(oep::runtime::RuntimeService::ExecuteMergeRequest(archive_path));
        if (!result.success) {
            std::cerr << "oep: merge failed: " << result.error << "\n";
            return 1;
        }

        std::cout << "Merged package '" << result.package_id << "' version " << result.version << "\n";
        std::cout << "  Objects created:       " << result.objects_created << "\n";
        std::cout << "  Relationships created: " << result.relationships_created << "\n";
        std::cout << "  Trust status:          " << result.trust_status << "\n";
        return 0;
    });
}

} // namespace oep::cli::commands
