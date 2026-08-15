#include "oep/installer/version_constraint.hpp"

#include <cctype>
#include <sstream>
#include <vector>

namespace oep::installer {

namespace {

// Parses one dot-separated numeric component starting at `pos`, stopping
// at '.', '-', '+', or end of string. Returns -1 if no digits were found.
int parse_component(const std::string& text, std::size_t& pos) {
    const std::size_t start = pos;
    while (pos < text.size() && std::isdigit(static_cast<unsigned char>(text[pos]))) {
        ++pos;
    }
    if (pos == start) {
        return -1;
    }
    return std::stoi(text.substr(start, pos - start));
}

} // namespace

ParseVersionResult parse_semantic_version(const std::string& text) {
    ParseVersionResult result;
    if (text.empty()) {
        result.error = "version string is empty";
        return result;
    }

    std::size_t pos = 0;
    const int major = parse_component(text, pos);
    if (major < 0) {
        result.error = "'" + text + "' does not start with a numeric major version component";
        return result;
    }
    int minor = 0;
    int patch = 0;
    if (pos < text.size() && text[pos] == '.') {
        ++pos;
        const int parsed_minor = parse_component(text, pos);
        if (parsed_minor < 0) {
            result.error = "'" + text + "' has a malformed minor version component";
            return result;
        }
        minor = parsed_minor;
    }
    if (pos < text.size() && text[pos] == '.') {
        ++pos;
        const int parsed_patch = parse_component(text, pos);
        if (parsed_patch < 0) {
            result.error = "'" + text + "' has a malformed patch version component";
            return result;
        }
        patch = parsed_patch;
    }
    // Anything remaining (a '-prerelease' and/or '+build' suffix) is
    // accepted but intentionally not parsed further -- see this module's
    // own doc comment on why pre-release precedence is out of scope.

    result.success = true;
    result.version = SemanticVersion{major, minor, patch};
    return result;
}

int compare_semantic_versions(const SemanticVersion& a, const SemanticVersion& b) {
    if (a.major != b.major) return a.major < b.major ? -1 : 1;
    if (a.minor != b.minor) return a.minor < b.minor ? -1 : 1;
    if (a.patch != b.patch) return a.patch < b.patch ? -1 : 1;
    return 0;
}

namespace {

std::vector<std::string> split_on_whitespace(const std::string& text) {
    std::vector<std::string> tokens;
    std::istringstream stream(text);
    std::string token;
    while (stream >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

// Splits a single constraint atom (e.g. ">=1.2.3", "~1.2", "1.0.0")
// into its operator (defaulting to "=" when none is written) and the
// version text that follows.
void split_operator(const std::string& atom, std::string& out_operator, std::string& out_version) {
    static const char* kTwoCharOperators[] = {">=", "<=", "!="};
    for (const char* op : kTwoCharOperators) {
        if (atom.compare(0, 2, op) == 0) {
            out_operator = op;
            out_version = atom.substr(2);
            return;
        }
    }
    static const char kOneCharOperators[] = {'>', '<', '=', '~', '^'};
    for (const char op : kOneCharOperators) {
        if (!atom.empty() && atom[0] == op) {
            out_operator = std::string(1, op);
            out_version = atom.substr(1);
            return;
        }
    }
    out_operator = "=";
    out_version = atom;
}

// Evaluates one constraint atom against `version`. Returns success=false
// only for a malformed atom (bad operator or unparseable version).
ConstraintCheckResult evaluate_atom(const SemanticVersion& version, const std::string& atom) {
    ConstraintCheckResult result;

    std::string op;
    std::string version_text;
    split_operator(atom, op, version_text);

    const ParseVersionResult parsed = parse_semantic_version(version_text);
    if (!parsed.success) {
        result.error = "malformed version constraint '" + atom + "': " + parsed.error;
        return result;
    }
    const SemanticVersion& target = parsed.version;
    const int cmp = compare_semantic_versions(version, target);

    if (op == "=") {
        result.satisfied = cmp == 0;
    } else if (op == "!=") {
        result.satisfied = cmp != 0;
    } else if (op == ">") {
        result.satisfied = cmp > 0;
    } else if (op == ">=") {
        result.satisfied = cmp >= 0;
    } else if (op == "<") {
        result.satisfied = cmp < 0;
    } else if (op == "<=") {
        result.satisfied = cmp <= 0;
    } else if (op == "~") {
        // Compatible: patch-level changes only, within the same minor.
        const SemanticVersion upper{target.major, target.minor + 1, 0};
        result.satisfied = compare_semantic_versions(version, target) >= 0 &&
                            compare_semantic_versions(version, upper) < 0;
    } else if (op == "^") {
        // Caret: changes that do not modify the left-most nonzero
        // component (standard npm-style semantics, including the 0.x
        // special cases).
        SemanticVersion upper;
        if (target.major > 0) {
            upper = SemanticVersion{target.major + 1, 0, 0};
        } else if (target.minor > 0) {
            upper = SemanticVersion{0, target.minor + 1, 0};
        } else {
            upper = SemanticVersion{0, 0, target.patch + 1};
        }
        result.satisfied = compare_semantic_versions(version, target) >= 0 &&
                            compare_semantic_versions(version, upper) < 0;
    } else {
        result.error = "unrecognized version constraint operator in '" + atom + "'";
        return result;
    }

    result.success = true;
    return result;
}

} // namespace

ConstraintCheckResult version_satisfies(const std::string& version, const std::string& constraint) {
    ConstraintCheckResult result;

    if (constraint.empty()) {
        result.success = true;
        result.satisfied = true;
        return result;
    }

    const ParseVersionResult parsed_version = parse_semantic_version(version);
    if (!parsed_version.success) {
        result.error = "malformed version '" + version + "': " + parsed_version.error;
        return result;
    }

    // Every space-separated atom must be satisfied (logical AND) --
    // PKG-004 §8's "version ranges" (e.g. ">=1.0.0 <2.0.0").
    for (const std::string& atom : split_on_whitespace(constraint)) {
        const ConstraintCheckResult atom_result = evaluate_atom(parsed_version.version, atom);
        if (!atom_result.success) {
            return atom_result;
        }
        if (!atom_result.satisfied) {
            result.success = true;
            result.satisfied = false;
            return result;
        }
    }

    result.success = true;
    result.satisfied = true;
    return result;
}

} // namespace oep::installer
