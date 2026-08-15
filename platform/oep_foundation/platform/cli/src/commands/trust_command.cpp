#include "trust_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

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

void print_certificate(const oep::installer::PublisherCertificate& certificate) {
    std::cout << certificate.publisher_id << "\t" << certificate.publisher_name << "\t"
              << (certificate.revoked ? "Revoked" : "Trusted") << "\t" << certificate.fingerprint << "\t"
              << certificate.expires_utc << "\n";
}

} // namespace

std::string TrustCommand::name() const {
    return "trust";
}

std::string TrustCommand::description() const {
    return "Manage this repository's Trust Store (trusted publisher certificates, signature policy)";
}

int TrustCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'trust' requires a subcommand (trust, list, revoke, policy)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "trust") return trust(rest);
    if (subcommand == "list") return list(rest);
    if (subcommand == "revoke") return revoke(rest);
    if (subcommand == "policy") return policy(rest);

    std::cerr << "oep: unknown 'trust' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int TrustCommand::trust(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'trust trust' requires a publisher id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string publisher_id = remaining[0];

    std::string publisher_name;
    std::string public_key_hex;
    std::string expires_utc;
    std::string issuer;
    for (std::size_t i = 1; i < remaining.size(); ++i) {
        const std::string& flag = remaining[i];
        const bool has_value = i + 1 < remaining.size();
        if (flag == "--name" && has_value) {
            publisher_name = remaining[++i];
        } else if (flag == "--key" && has_value) {
            public_key_hex = remaining[++i];
        } else if (flag == "--expires" && has_value) {
            expires_utc = remaining[++i];
        } else if (flag == "--issuer" && has_value) {
            issuer = remaining[++i];
        } else {
            std::cerr << "oep: unrecognized argument '" << flag << "'\n";
            std::cerr << "Usage: " << usage() << "\n";
            return 1;
        }
    }
    if (public_key_hex.empty()) {
        std::cerr << "oep: 'trust trust' requires --key <64-hex-char Ed25519 public key>\n";
        return 1;
    }

    return with_open_repository(repository_path, [&](oep::runtime::FoundationRuntime& runtime) {
        oep::installer::PublisherCertificate certificate;
        certificate.publisher_id = publisher_id;
        certificate.publisher_name = publisher_name;
        certificate.public_key_hex = public_key_hex;
        certificate.expires_utc = expires_utc;
        certificate.issuer = issuer;

        const oep::runtime::RuntimeTrustResult added = runtime.trust_add_certificate(certificate);
        if (!added.success) {
            std::cerr << "oep: could not trust publisher: " << added.error << "\n";
            return 1;
        }
        std::cout << "Trusted publisher '" << publisher_id << "'\n";
        return 0;
    });
}

int TrustCommand::list(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    return with_open_repository(repository_path, [](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeCertificateListResult listed = runtime.trust_list_certificates();
        if (!listed.success) {
            std::cerr << "oep: could not list trusted certificates: " << listed.error << "\n";
            return 1;
        }
        if (listed.certificates.empty()) {
            std::cout << "No trusted publisher certificates.\n";
        } else {
            for (const oep::installer::PublisherCertificate& certificate : listed.certificates) {
                print_certificate(certificate);
            }
        }
        return 0;
    });
}

int TrustCommand::revoke(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'trust revoke' requires a publisher id\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string publisher_id = remaining[0];

    return with_open_repository(repository_path, [&publisher_id](oep::runtime::FoundationRuntime& runtime) {
        const oep::runtime::RuntimeTrustResult revoked = runtime.trust_revoke_certificate(publisher_id);
        if (!revoked.success) {
            std::cerr << "oep: could not revoke publisher: " << revoked.error << "\n";
            return 1;
        }
        std::cout << "Revoked publisher '" << publisher_id << "'\n";
        return 0;
    });
}

int TrustCommand::policy(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::string action = remaining.empty() ? "show" : remaining[0];

    return with_open_repository(repository_path, [&action](oep::runtime::FoundationRuntime& runtime) {
        if (action == "require") {
            const oep::runtime::RuntimeTrustResult set = runtime.trust_set_policy(true);
            if (!set.success) {
                std::cerr << "oep: could not set trust policy: " << set.error << "\n";
                return 1;
            }
            std::cout << "Trust policy: signatures now required.\n";
            return 0;
        }
        if (action == "allow-unsigned") {
            const oep::runtime::RuntimeTrustResult set = runtime.trust_set_policy(false);
            if (!set.success) {
                std::cerr << "oep: could not set trust policy: " << set.error << "\n";
                return 1;
            }
            std::cout << "Trust policy: unsigned packages now allowed.\n";
            return 0;
        }
        if (action != "show") {
            std::cerr << "oep: unknown 'trust policy' action '" << action << "' (expected show|require|allow-unsigned)\n";
            return 1;
        }
        const oep::runtime::RuntimeTrustPolicyResult policy = runtime.trust_get_policy();
        if (!policy.success) {
            std::cerr << "oep: could not read trust policy: " << policy.error << "\n";
            return 1;
        }
        std::cout << "Signatures required: " << (policy.require_signatures ? "yes" : "no") << "\n";
        return 0;
    });
}

} // namespace oep::cli::commands
