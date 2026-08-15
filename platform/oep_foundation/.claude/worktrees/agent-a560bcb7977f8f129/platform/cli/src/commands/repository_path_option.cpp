#include "repository_path_option.hpp"

#include <sstream>

namespace oep::cli::commands {

std::filesystem::path extract_path_option(std::vector<std::string>& args, const std::string& flag_name) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == flag_name && i + 1 < args.size()) {
            std::filesystem::path path = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i),
                       args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            return path;
        }
    }
    return std::filesystem::current_path();
}

bool extract_flag(std::vector<std::string>& args, const std::string& flag_name) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == flag_name) {
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i));
            return true;
        }
    }
    return false;
}

std::filesystem::path extract_repository_path(std::vector<std::string>& args) {
    return extract_path_option(args, "--repository");
}

std::vector<std::string> split_csv(const std::string& csv) {
    std::vector<std::string> values;
    std::stringstream stream(csv);
    std::string value;
    while (std::getline(stream, value, ',')) {
        if (!value.empty()) {
            values.push_back(value);
        }
    }
    return values;
}

} // namespace oep::cli::commands
