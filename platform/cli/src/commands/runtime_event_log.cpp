#include "runtime_event_log.hpp"

namespace oep::cli::commands {

oep::runtime::EventBus& global_event_bus() {
    static oep::runtime::EventBus bus;
    return bus;
}

} // namespace oep::cli::commands
