#include "package_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

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
        std::cerr << "oep: 'package' requires a subcommand (install, uninstall, list, info, contents, verify, "
                      "locate, search)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "install") return install(rest);
    if (subcommand == "uninstall") return uninstall(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "info") return info(rest);
    if (subcommand == "contents") return contents(rest);
    if (subcommand == "verify") return verify(rest);
    if (subcommand == "locate") return locate(rest);
    if (subcommand == "search") return search(rest);

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
            std::cerr << "oep: install failed: " << result.error << "\n";
            return 1;
        }

        std::cout << "Installed package '" << result.package_id << "' version " << result.version << "\n";
        std::cout << "  Objects:       " << result.objects_created << "\n";
        std::cout << "  Relationships: " << result.relationships_created << "\n";
        return 0;
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
        const oep::runtime::RuntimeUninstallResult result = runtime.uninstall_package(package_id);
        if (!result.success) {
            // Uninstall is atomic (WP-REP-003 Repository Transaction): a
            // failure has already been rolled back by the Runtime; the
            // package remains installed exactly as before.
            std::cerr << "oep: uninstall failed: " << result.error << "\n";
            return 1;
        }

        std::cout << "Uninstalled package '" << result.package_id << "' version " << result.version << "\n";
        std::cout << "  Objects:       " << result.objects_deleted << "\n";
        std::cout << "  Relationships: " << result.relationships_deleted << "\n";
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

} // namespace oep::cli::commands
