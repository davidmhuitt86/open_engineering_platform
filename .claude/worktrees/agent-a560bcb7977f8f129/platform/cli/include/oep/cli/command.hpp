#pragma once

#include <string>
#include <vector>

namespace oep::cli {

// A Command is a single top-level CLI verb (e.g. "version").
// Future commands are added by implementing this interface and
// registering an instance with the CommandRegistry.
class Command {
public:
    virtual ~Command() = default;

    virtual std::string name() const = 0;
    virtual std::string description() const = 0;
    virtual int execute(const std::vector<std::string>& args) const = 0;

    // Full invocation syntax shown by `oep --help`, e.g. "oep open <repository>".
    // Commands that take arguments should override this; the default is
    // just the bare command name.
    virtual std::string usage() const { return "oep " + name(); }
};

} // namespace oep::cli
